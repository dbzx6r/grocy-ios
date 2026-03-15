import SwiftUI

struct OverdueCard: View {
    let tasks: [GrocyTask]
    let chores: [ChoreDetails]
    let onNavigate: (() -> Void)?

    init(tasks: [GrocyTask], chores: [ChoreDetails], onNavigate: (() -> Void)? = nil) {
        self.tasks = tasks
        self.chores = chores
        self.onNavigate = onNavigate
    }

    var body: some View {
        GrocyCard(
            title: "Overdue",
            systemImage: "clock.badge.exclamationmark.fill",
            accentColor: .purple,
            count: tasks.count + chores.count,
            action: onNavigate
        ) {
            VStack(spacing: 6) {
                ForEach(tasks.prefix(3)) { task in
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(.purple)
                            .font(.caption)
                        Text(task.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let due = task.dueDateParsed {
                            Text(DateFormatters.shared.displayShort.string(from: due))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                ForEach(chores.prefix(3)) { detail in
                    HStack {
                        Image(systemName: "arrow.2.circlepath")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text(detail.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let next = detail.nextDueDate {
                            Text(DateFormatters.shared.displayShort.string(from: next))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }
}
