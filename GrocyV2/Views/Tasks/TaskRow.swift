import SwiftUI

struct TaskRow: View {
    let task: GrocyTask
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AnimatedCheckmark(isChecked: task.isDone, action: onComplete)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)

                if let desc = task.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let due = task.dueDateParsed {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(DateFormatters.shared.displayShort.string(from: due))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    if task.isOverdue {
                        Text("OVERDUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}
