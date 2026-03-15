import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var volatileStock: VolatileStock?
    var isLoading = false
    var error: String?
    var lastRefresh: Date?

    var expiringSoon: [StockItem] { volatileStock?.dueSoon ?? [] }
    var overdue: [StockItem] { volatileStock?.overdue ?? [] }
    var expired: [StockItem] { volatileStock?.expired ?? [] }
    var missing: [MissingProduct] { volatileStock?.missing ?? [] }

    var overdueTasksCount: Int = 0
    var overdueChoresCount: Int = 0
    var tasks: [GrocyTask] = []
    var chores: [ChoreDetails] = []

    var hasAlerts: Bool {
        !expiringSoon.isEmpty || !overdue.isEmpty || !expired.isEmpty || !missing.isEmpty ||
        overdueTasksCount > 0 || overdueChoresCount > 0
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    func load(client: GrocyAPIClient) async {
        isLoading = true
        error = nil
        do {
            async let volatile = client.getVolatileStock(dueSoonDays: 7)
            async let tasksResult = client.getTasks()
            async let choresResult = client.getChores()
            volatileStock = try await volatile
            tasks = try await tasksResult
            chores = try await choresResult
            overdueTasksCount = tasks.filter { $0.isOverdue }.count
            overdueChoresCount = chores.filter { $0.isOverdue }.count
            lastRefresh = .now
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh(client: GrocyAPIClient) async {
        await load(client: client)
    }
}
