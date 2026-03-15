import SwiftUI

struct ShoppingItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AnimatedCheckmark(isChecked: item.isDone, action: onToggle)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.product?.name ?? item.note ?? "Item")
                    .font(.subheadline.weight(.medium))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: item.isDone)

                if let note = item.note, item.product != nil {
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
