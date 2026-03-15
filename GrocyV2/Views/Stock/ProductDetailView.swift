import SwiftUI
import Charts

struct ProductDetailView: View {
    let stockItem: StockItem
    @Environment(AppViewModel.self) private var appVM
    @State private var details: ProductDetails?
    @State private var entries: [StockEntry] = []
    @State private var priceHistory: [ProductPriceHistory] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddSheet = false
    @State private var showConsumeSheet = false
    @State private var showTransferSheet = false
    @State private var selectedDetailTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                productHeader
                actionRow

                Picker("Detail", selection: $selectedDetailTab) {
                    Text("Overview").tag(0)
                    Text("Stock Entries").tag(1)
                    Text("Price History").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else {
                    switch selectedDetailTab {
                    case 0: overviewSection
                    case 1: entriesSection
                    case 2: priceHistorySection
                    default: EmptyView()
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(stockItem.product?.name ?? "Product")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            AddStockSheet(productId: stockItem.productId, productName: stockItem.product?.name ?? "")
                .environment(appVM)
        }
        .sheet(isPresented: $showConsumeSheet) {
            ConsumeStockSheet(
                productId: stockItem.productId,
                productName: stockItem.product?.name ?? "",
                currentAmount: stockItem.amount
            )
            .environment(appVM)
        }
        .task {
            await loadDetails()
        }
    }

    // MARK: - Product Header

    @ViewBuilder
    private var productHeader: some View {
        VStack(spacing: 12) {
            if let filename = stockItem.product?.pictureFileName,
               let url = appVM.client?.productPictureURL(filename: filename, height: 200) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    default:
                        productPlaceholder
                    }
                }
            } else {
                productPlaceholder
            }

            HStack(spacing: 20) {
                stockStatBadge(value: String(format: "%.0f", stockItem.amount), label: "In Stock", color: .green)
                if let opened = stockItem.amountOpened, opened > 0 {
                    stockStatBadge(value: String(format: "%.0f", opened), label: "Opened", color: .orange)
                }
                stockStatBadge(value: expiryText, label: "Expires", color: expiryColor)
            }
            .padding(.bottom, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var productPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(height: 120)
            Image(systemName: "refrigerator.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green.opacity(0.6))
        }
    }

    // MARK: - Action Row

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 12) {
            actionButton("Add", icon: "plus.circle.fill", color: .green) {
                showAddSheet = true
            }
            actionButton("Consume", icon: "minus.circle.fill", color: .orange) {
                showConsumeSheet = true
            }
            actionButton("Open", icon: "lock.open.fill", color: .blue) {
                guard let client = appVM.client else { return }
                Task {
                    _ = try? await client.openStock(productId: stockItem.productId)
                    await loadDetails()
                }
            }
            actionButton("Transfer", icon: "arrow.left.arrow.right", color: .purple) {
                showTransferSheet = true
            }
        }
        .padding(.horizontal)
    }

    private func actionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let desc = stockItem.product?.description, !desc.isEmpty {
                infoRow(label: "Description", value: desc)
            }
            if let min = stockItem.product?.minStockAmount {
                infoRow(label: "Min Stock", value: String(format: "%.0f", min))
            }
            if let cal = stockItem.product?.calories {
                infoRow(label: "Calories", value: String(format: "%.0f kcal", cal))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Stock Entries

    @ViewBuilder
    private var entriesSection: some View {
        if entries.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "No Entries",
                subtitle: "No individual stock entries found for this product."
            )
        } else {
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Qty: \(entry.amount, specifier: "%.0f")")
                                .font(.subheadline.weight(.medium))
                            if let date = entry.bestBeforeDate {
                                Text("Best before: \(date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let price = entry.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if entry.open?.isTrue == true {
                            Label("Open", systemImage: "lock.open.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Price History

    @ViewBuilder
    private var priceHistorySection: some View {
        if priceHistory.isEmpty {
            EmptyStateView(
                systemImage: "chart.line.uptrend.xyaxis",
                title: "No Price History",
                subtitle: "Price history will appear once you start tracking prices."
            )
        } else {
            Chart(priceHistory) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(Color.accentColor)
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 200)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func stockStatBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var expiryText: String {
        guard let date = stockItem.bestBeforeDate, date != "2999-12-31" else { return "No date" }
        guard let parsed = DateFormatters.shared.apiDate.date(from: date) else { return "Unknown" }
        return DateFormatters.shared.displayShort.string(from: parsed)
    }

    private var expiryColor: Color {
        switch stockItem.expiryStatus {
        case .fresh: return .green
        case .soon: return .orange
        case .urgent, .expired: return .red
        case .noDate: return .secondary
        }
    }

    private func loadDetails() async {
        guard let client = appVM.client else { return }
        isLoading = true
        async let detailsResult = try? client.getProductDetails(id: stockItem.productId)
        async let entriesResult = try? client.getProductEntries(id: stockItem.productId)
        async let historyResult = try? client.getProductPriceHistory(id: stockItem.productId)
        details = await detailsResult
        entries = await entriesResult ?? []
        priceHistory = await historyResult ?? []
        isLoading = false
    }
}
