import SwiftUI

struct ShoppingView: View {
    @Environment(ShoppingViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @State private var showAddSheet = false
    @State private var showClearConfirm = false
    @State private var completionEffect = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ShimmerList()
                } else if vm.items.isEmpty {
                    EmptyStateView(
                        systemImage: "cart",
                        title: "Shopping List Empty",
                        subtitle: "Add items or tap Auto-fill to populate from low stock.",
                        actionTitle: "Add Item"
                    ) { showAddSheet = true }
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
        .task {
            guard let client = appVM.client else { return }
            if vm.items.isEmpty { await vm.load(client: client) }
        }
    }

    @ViewBuilder
    private var shoppingList: some View {
        List {
            if vm.shoppingLists.count > 1 {
                Section {
                    Picker("List", selection: Bindable(vm).selectedListId) {
                        ForEach(vm.shoppingLists) { list in
                            Text(list.name).tag(list.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            ForEach(vm.groupedPending, id: \.group) { group in
                Section(group.group) {
                    ForEach(group.items) { item in
                        ShoppingItemRow(item: item) {
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
                            ShoppingItemRow(item: item) {
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
        }
    }
}
