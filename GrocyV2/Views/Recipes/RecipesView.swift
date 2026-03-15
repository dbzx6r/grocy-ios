import SwiftUI

struct RecipesView: View {
    @Environment(RecipesViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM

    @State private var showCreateRecipe = false
    @State private var showAddMealPlan = false
    @State private var addMealPlanDay: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: Bindable(vm).selectedTab) {
                    ForEach(RecipesViewModel.RecipeTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if vm.isLoading && vm.recipes.isEmpty {
                        ShimmerList()
                    } else {
                        switch vm.selectedTab {
                        case .recipes: recipesContent
                        case .mealPlan: mealPlanContent
                        }
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.selectedTab == .recipes {
                        Button {
                            showCreateRecipe = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                guard let client = appVM.client else { return }
                await vm.load(client: client)
            }
            .sheet(isPresented: $showCreateRecipe) {
                CreateRecipeSheet { name, description, servings in
                    guard let client = appVM.client else { return }
                    await vm.createRecipe(client: client, name: name, description: description, baseServings: servings)
                }
            }
            .sheet(isPresented: $showAddMealPlan) {
                AddMealPlanSheet(day: addMealPlanDay, recipes: vm.recipes) { recipeId, servings in
                    guard let client = appVM.client else { return }
                    await vm.addToMealPlan(client: client, day: addMealPlanDay, recipeId: recipeId, servings: servings)
                }
            }
        }
        .task {
            guard let client = appVM.client else { return }
            if vm.recipes.isEmpty { await vm.load(client: client) }
        }
    }

    @ViewBuilder
    private var recipesContent: some View {
        if vm.filteredRecipes.isEmpty {
            EmptyStateView(
                systemImage: "fork.knife",
                title: "No Recipes",
                subtitle: "Tap + to create your first recipe."
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(vm.filteredRecipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeCard(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var mealPlanContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        vm.selectedWeekOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }

                Spacer()

                Text(weekLabel)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        vm.selectedWeekOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.weekDays, id: \.self) { day in
                        MealPlanDayCard(
                            day: day,
                            items: vm.mealPlanItems(for: day),
                            recipes: vm.recipes,
                            onAdd: {
                                addMealPlanDay = day
                                showAddMealPlan = true
                            }
                        ) { id in
                            guard let client = appVM.client else { return }
                            await vm.removeFromMealPlan(client: client, id: id)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var weekLabel: String {
        guard let first = vm.weekDays.first, let last = vm.weekDays.last else { return "This Week" }
        let df = DateFormatters.shared.apiDate
        guard let startDate = df.date(from: first), let endDate = df.date(from: last) else { return "This Week" }
        let display = DateFormatters.shared.displayShort
        return "\(display.string(from: startDate)) – \(display.string(from: endDate))"
    }
}

// MARK: - RecipeCard

struct RecipeCard: View {
    let recipe: Recipe
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let filename = recipe.pictureFileName,
                   let url = appVM.client?.productPictureURL(filename: filename, height: 150) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            recipePlaceholder
                        }
                    }
                } else {
                    recipePlaceholder
                }
            }
            .frame(height: 120)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let servings = recipe.baseServings {
                    Text("\(servings, specifier: "%.0f") servings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var recipePlaceholder: some View {
        ZStack {
            Color.accentColor.opacity(0.1)
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor.opacity(0.5))
        }
    }
}

// MARK: - MealPlanDayCard

struct MealPlanDayCard: View {
    let day: String
    let items: [MealPlanItem]
    let recipes: [Recipe]
    let onAdd: () -> Void
    let onRemove: (Int) async -> Void

    private var displayDate: String {
        guard let date = DateFormatters.shared.apiDate.date(from: day) else { return day }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        day == DateFormatters.shared.apiDate.string(from: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            dayHeader
            itemsContent
        }
        .padding(14)
        .background(
            isToday
                ? Color.accentColor.opacity(0.08)
                : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isToday ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var dayHeader: some View {
        HStack {
            Text(displayDate)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            if isToday {
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
            Spacer()
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var itemsContent: some View {
        if items.isEmpty {
            Text("Nothing planned")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .italic()
        } else {
            ForEach(items) { item in
                if let recipe = recipes.first(where: { $0.id == item.recipeId }) {
                    MealPlanItemRow(recipe: recipe, item: item, onRemove: onRemove)
                }
            }
        }
    }
}

// MARK: - MealPlanItemRow
struct MealPlanItemRow: View {
    let recipe: Recipe
    let item: MealPlanItem
    let onRemove: (Int) async -> Void

    var body: some View {
        HStack {
            Image(systemName: "fork.knife.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(recipe.name)
                .font(.subheadline)
            if let servings = item.recipeServings {
                Text(String(format: "×%.0f", servings))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await onRemove(item.id) }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - CreateRecipeSheet

struct CreateRecipeSheet: View {
    let onSave: (String, String?, Double) async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var baseServings: Double = 2
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Servings") {
                    Stepper(value: $baseServings, in: 1...100, step: 1) {
                        HStack {
                            Text("Base Servings")
                            Spacer()
                            Text("\(Int(baseServings))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            isSaving = true
                            Task {
                                await onSave(name, description.isEmpty ? nil : description, baseServings)
                                dismiss()
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

// MARK: - AddMealPlanSheet

struct AddMealPlanSheet: View {
    let day: String
    let recipes: [Recipe]
    let onSave: (Int, Double) async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRecipeId: Int?
    @State private var servings: Double = 1
    @State private var isSaving = false

    private var displayDate: String {
        guard let date = DateFormatters.shared.apiDate.date(from: day) else { return day }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Day") {
                    Text(displayDate)
                        .foregroundStyle(.secondary)
                }

                Section("Recipe") {
                    if recipes.isEmpty {
                        Text("No recipes available. Create one in the Recipes tab.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("Select Recipe", selection: $selectedRecipeId) {
                            Text("Choose…").tag(Int?.none)
                            ForEach(recipes) { recipe in
                                Text(recipe.name).tag(Int?.some(recipe.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                Section("Servings") {
                    Stepper(value: $servings, in: 0.5...100, step: 0.5) {
                        HStack {
                            Text("Servings")
                            Spacer()
                            Text(servings.formatted(.number.precision(.fractionLength(0...1))))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add") {
                            guard let recipeId = selectedRecipeId else { return }
                            isSaving = true
                            Task {
                                await onSave(recipeId, servings)
                                dismiss()
                            }
                        }
                        .disabled(selectedRecipeId == nil)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                selectedRecipeId = recipes.first?.id
            }
        }
    }
}
