import SwiftUI

struct StockView: View {
    @Environment(StockViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @State private var showScanner = false
    @State private var showAddProduct = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.stockItems.isEmpty {
                    ShimmerList()
                } else if vm.filteredItems.isEmpty && !vm.searchText.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No Results",
                        subtitle: "No products match \"\(vm.searchText)\""
                    )
                } else if vm.stockItems.isEmpty {
                    EmptyStateView(
                        systemImage: "refrigerator",
                        title: "No Stock",
                        subtitle: "Your pantry is empty. Start by scanning a barcode or adding products."
                    )
                } else {
                    stockList
                }
            }
            .navigationTitle("Stock")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: Bindable(vm).searchText, prompt: "Search products...")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .refreshable {
                guard let client = appVM.client else { return }
                await vm.load(client: client)
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView()
                .environment(appVM)
        }
        .task {
            guard let client = appVM.client else { return }
            if vm.stockItems.isEmpty {
                await vm.load(client: client)
            }
        }
    }

    @ViewBuilder
    private var stockList: some View {
        List {
            ForEach(vm.groupedItems, id: \.group) { group in
                Section(group.group) {
                    ForEach(group.items) { item in
                        NavigationLink(destination: ProductDetailView(stockItem: item)) {
                            StockItemRow(item: item, vm: vm)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                guard let client = appVM.client else { return }
                                Task { await vm.quickAdd(client: client, productId: item.productId) }
                            } label: {
                                Label("Add 1", systemImage: "plus.circle.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                guard let client = appVM.client else { return }
                                Task { await vm.quickConsume(client: client, productId: item.productId) }
                            } label: {
                                Label("Use 1", systemImage: "minus.circle.fill")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct StockItemRow: View {
    let item: StockItem
    let vm: StockViewModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(indicatorColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.product?.name ?? "Unknown")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(item.amount, specifier: "%.0f") \(vm.unitName(for: item.product?.quIdStock))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let loc = item.product?.locationId {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(vm.locationName(for: loc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
            ExpiryBadge(item: item)
        }
    }

    private var indicatorColor: Color {
        switch item.expiryStatus {
        case .fresh, .noDate: return .green
        case .soon: return .orange
        case .urgent, .expired: return .red
        }
    }
}
