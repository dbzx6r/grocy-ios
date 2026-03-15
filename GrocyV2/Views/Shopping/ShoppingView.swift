import SwiftUI

struct ShoppingView: View {
    @Environment(ShoppingViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @State private var showAddSheet = false
    @State private var showClearConfirm = false
    @State private var showDeleteListConfirm = false
    @State private var showNewListAlert = false
    @State private var newListName = ""
    @State private var completionEffect = false
    @State private var showPutAway = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ShimmerList()
                } else if vm.items.isEmpty {
                    if let error = vm.error {
                        EmptyStateView(
                            systemImage: "exclamationmark.triangle",
                            title: "Failed to Load",
                            subtitle: error,
                            actionTitle: "Retry"
                        ) {
                            guard let client = appVM.client else { return }
                            Task { await vm.load(client: client) }
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "cart",
                            title: "Shopping List Empty",
                            subtitle: "Add items or tap Auto-fill to populate from low stock.",
                            actionTitle: "Add Item"
                        ) { showAddSheet = true }
                    }
                } else {
                    shoppingList
                }
            }
            .navigationTitle("Shopping")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: Bindable(vm).searchText, prompt: "Search items...")
            .toolbar { toolbarContent }
            .refreshable {
                guard let client = appVM.client else { return }
                await vm.load(client: client)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddShoppingItemSheet()
                .environment(vm)
                .environment(appVM)
        }
        .sheet(isPresented: $showPutAway) {
            PutAwayView()
                .environment(vm)
                .environment(appVM)
        }
        .overlay {
            if completionEffect {
                ConfettiBurst()
                    .allowsHitTesting(false)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            completionEffect = false
                        }
                    }
            }
        }
        .confirmationDialog(
            "Clear all completed items?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Done Items", role: .destructive) {
                guard let client = appVM.client else { return }
                Task { await vm.clearDone(client: client) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \"\(vm.shoppingLists.first(where: { $0.id == vm.selectedListId })?.name ?? "this list")\"?",
            isPresented: $showDeleteListConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete List", role: .destructive) {
                guard let client = appVM.client else { return }
                Task { await vm.deleteCurrentList(client: client) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Shopping List", isPresented: $showNewListAlert) {
            TextField("List name", text: $newListName)
            Button("Create") {
                let name = newListName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                guard let client = appVM.client else { return }
                Task { await vm.createList(client: client, name: name) }
                newListName = ""
            }
            Button("Cancel", role: .cancel) { newListName = "" }
        }
        .task {
            guard let client = appVM.client else { return }
            await vm.load(client: client)
        }
        .onChange(of: vm.selectedListId) { _, _ in
            guard let client = appVM.client else { return }
            Task { await vm.load(client: client) }
        }
    }

    @ViewBuilder
    private var shoppingList: some View {
        List {
            ForEach(vm.groupedPending, id: \.group) { group in
                Section(group.group) {
                    ForEach(group.items) { item in
                        ShoppingItemRow(item: item, products: vm.products) {
                            guard let client = appVM.client else { return }
                            Task {
                                await vm.toggleDone(client: client, item: item)
                                let allDone = vm.pendingItems.isEmpty
                                if allDone {
                                    withAnimation { completionEffect = true }
                                    HapticManager.shared.success()
                                } else {
                                    HapticManager.shared.impact(.light)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                guard let client = appVM.client else { return }
                                Task { await vm.deleteItem(client: client, id: item.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !vm.doneItems.isEmpty {
                Section {
                    DisclosureGroup("\(vm.doneItems.count) completed item\(vm.doneItems.count == 1 ? "" : "s")") {
                        ForEach(vm.doneItems) { item in
                            ShoppingItemRow(item: item, products: vm.products) {
                                guard let client = appVM.client else { return }
                                Task { await vm.toggleDone(client: client, item: item) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    guard let client = appVM.client else { return }
                                    Task { await vm.deleteItem(client: client, id: item.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    guard let client = appVM.client else { return }
                    Task {
                        await vm.autoFillMissing(client: client)
                        HapticManager.shared.impact(.medium)
                    }
                } label: {
                    Label("Auto-fill Missing", systemImage: "wand.and.stars")
                }

                Divider()

                Button {
                    newListName = ""
                    showNewListAlert = true
                } label: {
                    Label("New List", systemImage: "plus.rectangle.on.rectangle")
                }

                if vm.shoppingLists.count > 1 {
                    Button(role: .destructive) {
                        showDeleteListConfirm = true
                    } label: {
                        Label("Delete Current List", systemImage: "trash")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear Done Items", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }

            Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }

            if !vm.doneItems.isEmpty {
                Button {
                    showPutAway = true
                } label: {
                    Label("Put Away", systemImage: "tray.and.arrow.down.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .tint(.accentColor)
                .transition(.scale.combined(with: .opacity))
            }
        }

        ToolbarItem(placement: .principal) {
            if vm.shoppingLists.count > 1 {
                Picker("List", selection: Bindable(vm).selectedListId) {
                    ForEach(vm.shoppingLists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
                .pickerStyle(.menu)
                .fontWeight(.semibold)
            }
        }
    }
}
