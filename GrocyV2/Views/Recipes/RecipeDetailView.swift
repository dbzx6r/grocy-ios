import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(AppViewModel.self) private var appVM
    @State private var positions: [RecipePosition] = []
    @State private var fulfillment: [RecipeFulfillment] = []
    @State private var isLoading = true
    @State private var isAddingToList = false
    @State private var isConsuming = false
    @State private var successMessage: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recipe image
                if let filename = recipe.pictureFileName,
                   let url = appVM.client?.productPictureURL(filename: filename, height: 300) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill().frame(height: 220).clipped()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }

                // Info row
                HStack(spacing: 20) {
                    if let servings = recipe.baseServings {
                        Label("\(servings, specifier: "%.0f") servings", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let productId = recipe.productId {
                        Label("ID \(productId)", systemImage: "number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Description
                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Ingredients section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ingredients", systemImage: "list.bullet")
                        .font(.headline)
                        .padding(.horizontal)

                    if isLoading {
                        ShimmerList(count: 4)
                    } else if positions.isEmpty {
                        Text("No ingredients listed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(positions) { pos in
                                IngredientRow(
                                    position: pos,
                                    fulfillment: fulfillment.first(where: { $0.productId == pos.productId })
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Fulfillment summary bar
                if !fulfillment.isEmpty {
                    let satisfied = fulfillment.filter { $0.needFulfilled?.isTrue == true }.count
                    let total = fulfillment.count
                    FulfillmentBar(satisfied: satisfied, total: total)
                        .padding(.horizontal)
                }

                // Success message
                if let msg = successMessage {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }

                // Error message
                if let err = error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { await addMissingToList() }
                    } label: {
                        Label(
                            isAddingToList ? "Adding..." : "Add Missing to Shopping List",
                            systemImage: "cart.badge.plus"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.blue)
                    }
                    .disabled(isAddingToList)

                    Button {
                        Task { await consumeIngredients() }
                    } label: {
                        Label(
                            isConsuming ? "Consuming..." : "Consume Ingredients",
                            systemImage: "minus.circle.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.orange)
                    }
                    .disabled(isConsuming)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.vertical)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadDetails() }
    }

    // MARK: - Private methods

    private func loadDetails() async {
        guard let client = appVM.client else { return }
        isLoading = true
        async let posResult = try? client.getRecipePositions(recipeId: recipe.id)
        async let fulResult = try? client.getRecipeFulfillment(recipeId: recipe.id)
        positions = await posResult ?? []
        fulfillment = await fulResult ?? []
        isLoading = false
    }

    private func addMissingToList() async {
        guard let client = appVM.client else { return }
        isAddingToList = true
        do {
            try await client.addRecipeMissingToShoppingList(recipeId: recipe.id)
            HapticManager.shared.success()
            withAnimation { successMessage = "Added to shopping list!" }
            Task {
                try? await Task.sleep(for: .seconds(2))
                successMessage = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
        isAddingToList = false
    }

    private func consumeIngredients() async {
        guard let client = appVM.client else { return }
        isConsuming = true
        do {
            try await client.consumeRecipe(recipeId: recipe.id)
            HapticManager.shared.success()
            withAnimation { successMessage = "Ingredients consumed!" }
            Task {
                try? await Task.sleep(for: .seconds(2))
                successMessage = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
        isConsuming = false
    }
}

// MARK: - IngredientRow

struct IngredientRow: View {
    let position: RecipePosition
    let fulfillment: RecipeFulfillment?

    var isFulfilled: Bool { fulfillment?.needFulfilled?.isTrue == true }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isFulfilled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isFulfilled ? .green : .secondary)
                .font(.subheadline)

            Text(position.product?.name ?? "Product #\(position.productId)")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
                Text("\(position.amount, specifier: "%.0f")")
                    .font(.subheadline.weight(.medium))
                if let inStock = fulfillment?.amountInStock {
                    Text("/ \(inStock, specifier: "%.0f") in stock")
                        .font(.caption)
                        .foregroundStyle(isFulfilled ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isFulfilled ? 0.85 : 1.0)
    }
}

// MARK: - FulfillmentBar

struct FulfillmentBar: View {
    let satisfied: Int
    let total: Int

    private var ratio: Double { total > 0 ? Double(satisfied) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stock Fulfillment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(satisfied)/\(total) ingredients")
                    .font(.caption)
                    .foregroundStyle(satisfied == total ? .green : .orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(satisfied == total ? Color.green : Color.orange)
                        .frame(width: geo.size.width * ratio, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ratio)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
