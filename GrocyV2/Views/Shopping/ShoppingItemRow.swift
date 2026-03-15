import SwiftUI

struct ShoppingItemRow: View {
    let item: ShoppingListItem
    let products: [Product]
    let onToggle: () -> Void

    private var resolvedProduct: Product? {
        guard let pid = item.productId else { return nil }
        return products.first { $0.id == pid }
    }

    var body: some View {
        HStack(spacing: 12) {
            AnimatedCheckmark(isChecked: item.isDone, action: onToggle)

            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedProduct?.name ?? item.note ?? "Item")
                    .font(.subheadline.weight(.medium))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: item.isDone)

                if let note = item.note, resolvedProduct != nil {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(item.amount, specifier: "%.0f") \(unitLabel)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var unitLabel: String {
        item.amount == 1 ? "unit" : "units"
    }
}
