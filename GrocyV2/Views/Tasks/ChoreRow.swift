import SwiftUI

struct ChoreRow: View {
    let detail: ChoreDetails
    let onExecute: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(detail.name)
                    .font(.subheadline.weight(.medium))

                if let desc = detail.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let last = detail.lastTrackedTime {
                    Text("Last done: \(last)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let nextDate = detail.nextDueDate {
                    Text(DateFormatters.shared.displayShort.string(from: nextDate))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(detail.isOverdue ? .red : .secondary)
                    if detail.isOverdue {
                        Text("OVERDUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }

                Button(action: onExecute) {
                    Text("Done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        detail.isOverdue ? .red : .accentColor
    }
}
