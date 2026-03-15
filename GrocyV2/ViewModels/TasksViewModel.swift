import Foundation
import Observation

@Observable
@MainActor
final class TasksViewModel {
    var tasks: [GrocyTask] = []
    var chores: [ChoreDetails] = []
    var categories: [TaskCategory] = []
    var isLoading = false
    var error: String?
    var selectedTab: TaskTab = .tasks
    var showCompleted = false

    enum TaskTab: String, CaseIterable {
        case tasks = "Tasks"
        case chores = "Chores"
    }

    var visibleTasks: [GrocyTask] {
        showCompleted ? tasks : tasks.filter { !$0.isDone }
    }

    var groupedTasks: [(category: String, tasks: [GrocyTask])] {
        let grouped = Dictionary(grouping: visibleTasks) { task -> String in
            if let cid = task.categoryId,
               let cat = categories.first(where: { $0.id == cid }) {
                return cat.name
            }
            return "General"
        }
        return grouped.sorted { a, b in
            let aOverdue = a.value.contains { $0.isOverdue }
            let bOverdue = b.value.contains { $0.isOverdue }
            if aOverdue != bOverdue { return aOverdue }
            return a.key < b.key
        }.map { ($0.key, $0.value) }
    }

    var overdueTaskCount: Int { tasks.filter { $0.isOverdue }.count }
    var overdueChoreCount: Int { chores.filter { $0.isOverdue }.count }

    func load(client: GrocyAPIClient) async {
        isLoading = true
        error = nil
        do {
            async let tasksResult = client.getTasks()
            async let choresResult = client.getChores()
            async let categoriesResult = client.getTaskCategories()
            tasks = try await tasksResult
            chores = try await choresResult
            categories = try await categoriesResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func completeTask(client: GrocyAPIClient, id: Int) async {
        do {
            try await client.completeTask(id: id)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                let t = tasks[idx]
                tasks[idx] = GrocyTask(
                    id: t.id, name: t.name, description: t.description,
                    dueDate: t.dueDate, done: .int(1),
                    doneTimestamp: DateFormatters.shared.apiDateTime.string(from: .now),
                    categoryId: t.categoryId, assignedToUserId: t.assignedToUserId,
                    userfields: t.userfields, rowCreatedTimestamp: t.rowCreatedTimestamp
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func undoTask(client: GrocyAPIClient, id: Int) async {
        do {
            try await client.undoTask(id: id)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func executeChore(client: GrocyAPIClient, id: Int) async {
        do {
            try await client.executeChore(id: id)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
