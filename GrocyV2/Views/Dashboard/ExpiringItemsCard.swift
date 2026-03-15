import SwiftUI

struct ExpiringItemsCard: View {
    let expiringSoon: [StockItem]
    let overdue: [StockItem]
    let expired: [StockItem]
    let onNavigate: (() -> Void)?

    init(expiringSoon: [StockItem], overdue: [StockItem], expired: [StockItem], onNavigate: (() -> Void)? = nil) {
        self.expiringSoon = expiringSoon
        self.overdue = overdue
        self.expired = expired
        self.onNavigate = onNavigate
    }

    @State private var isExpanded = false

    private var sortedItems: [StockItem] { expired + overdue + expiringSoon }
    private var visibleItems: [StockItem] {
        isExpanded ? sortedItems : Array(sortedItems.prefix(5))
    }
    private var totalCount: Int { sortedItems.count }
    private var hiddenCount: Int { max(0, totalCount - 5) }

    var body: some View {
        GrocyCard(
            title: "Expiring Items",
            systemImage: "calendar.badge.exclamationmark",
            accentColor: .orange,
            count: totalCount,
            action: onNavigate
        ) {
            if sortedItems.isEmpty {
                Text("Nothing expiring soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleItems) { item in
                        ExpiringItemRow(item: item)
                    }
                    if hiddenCount > 0 || isExpanded {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Show less" : "+ \(hiddenCount) more")
                                    .font(.caption.weight(.medium))
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ExpiringItemRow: View {
    let item: StockItem

    var body: some View {
        HStack {
            statusDot
            Text(item.product?.name ?? "Unknown")
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            ExpiryBadge(item: item)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }

    private var dotColor: Color {
        switch item.expiryStatus {
        case .expired, .urgent: return .red
        case .soon: return .orange
        default: return .green
        }
    }
}
