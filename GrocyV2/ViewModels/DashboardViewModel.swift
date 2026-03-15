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
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let v = try? await client.getVolatileStock(dueSoonDays: 30) {
                    await MainActor.run { self.volatileStock = v }
                }
            }
            group.addTask {
                if let t = try? await client.getTasks() {
                    await MainActor.run {
                        self.tasks = t
                        self.overdueTasksCount = t.filter { $0.isOverdue }.count
                    }
                }
            }
            group.addTask {
                if let c = try? await client.getChores() {
                    await MainActor.run {
                        self.chores = c
                        self.overdueChoresCount = c.filter { $0.isOverdue }.count
                    }
                }
            }
        }
        lastRefresh = .now
        isLoading = false
    }

    func refresh(client: GrocyAPIClient) async {
        await load(client: client)
    }
}
