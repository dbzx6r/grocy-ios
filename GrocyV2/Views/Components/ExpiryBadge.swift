import SwiftUI

struct ExpiryBadge: View {
    let status: ExpiryStatus
    let label: String?

    init(item: StockItem) {
        self.status = item.expiryStatus
        self.label = DateFormatters.shared.daysLabel(for: item.bestBeforeDate)
    }

    init(status: ExpiryStatus, label: String?) {
        self.status = status
        self.label = label
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        }
    }

    private var color: Color {
        switch status {
        case .fresh:           return .green
        case .soon:            return .orange
        case .urgent, .expired: return .red
        case .noDate:          return .secondary
        }
    }
}
