import SwiftUI

struct LowStockCard: View {
    let missing: [MissingProduct]
    let onNavigate: (() -> Void)?

    init(missing: [MissingProduct], onNavigate: (() -> Void)? = nil) {
        self.missing = missing
        self.onNavigate = onNavigate
    }

    var body: some View {
        GrocyCard(
            title: "Low / Out of Stock",
            systemImage: "cart.badge.minus",
            accentColor: .red,
            count: missing.count,
            action: onNavigate
        ) {
            if missing.isEmpty {
                Text("All products are stocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(missing.prefix(5)) { item in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text(item.product?.name ?? item.name ?? "Unknown")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            if let amt = item.amountMissing {
                                Text("Need \(amt, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if missing.count > 5 {
                        Text("+ \(missing.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
