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

    // Sheet state
    var showAddEditTask = false
    var showAddEditChore = false
    var editingTask: GrocyTask? = nil
    var editingChoreId: Int? = nil

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

    func createTask(client: GrocyAPIClient, name: String, description: String?, dueDate: String?, categoryId: Int?) async {
        do {
            try await client.createTask(name: name, description: description, dueDate: dueDate, categoryId: categoryId)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateTask(client: GrocyAPIClient, id: Int, name: String, description: String?, dueDate: String?, categoryId: Int?) async {
        do {
            try await client.updateTask(id: id, name: name, description: description, dueDate: dueDate, categoryId: categoryId)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(client: GrocyAPIClient, id: Int) async {
        tasks.removeAll { $0.id == id }
        do {
            try await client.deleteTask(id: id)
        } catch {
            self.error = error.localizedDescription
            await load(client: client)
        }
    }

    func createChore(client: GrocyAPIClient, name: String, description: String?, periodType: String, periodInterval: Int) async {
        do {
            try await client.createChore(name: name, description: description, periodType: periodType, periodInterval: periodInterval)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateChore(client: GrocyAPIClient, id: Int, name: String, description: String?, periodType: String, periodInterval: Int) async {
        do {
            try await client.updateChore(id: id, name: name, description: description, periodType: periodType, periodInterval: periodInterval)
            await load(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteChore(client: GrocyAPIClient, id: Int) async {
        chores.removeAll { $0.id == id }
        do {
            try await client.deleteChore(id: id)
        } catch {
            self.error = error.localizedDescription
            await load(client: client)
        }
    }
}
