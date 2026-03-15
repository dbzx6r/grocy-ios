import SwiftUI

struct ExpiringItemsCard: View {
    let expiringSoon: [StockItem]
    let overdue: [StockItem]
    let expired: [StockItem]

    private var allItems: [StockItem] {
        (expired + overdue + expiringSoon).prefix(5).map { $0 }
    }

    private var totalCount: Int { expired.count + overdue.count + expiringSoon.count }

    var body: some View {
        GrocyCard(
            title: "Expiring Items",
            systemImage: "calendar.badge.exclamationmark",
            accentColor: .orange,
            count: totalCount
        ) {
            if allItems.isEmpty {
                Text("Nothing expiring soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(allItems) { item in
                        ExpiringItemRow(item: item)
                    }
                    if totalCount > 5 {
                        Text("+ \(totalCount - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
