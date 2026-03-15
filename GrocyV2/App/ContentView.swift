import SwiftUI
import Observation

struct ContentView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var dashboardVM = DashboardViewModel()
    @State private var stockVM = StockViewModel()
    @State private var shoppingVM = ShoppingViewModel()
    @State private var tasksVM = TasksViewModel()
    @State private var recipesVM = RecipesViewModel()
    @State private var showScanner = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var lastDBTime: String?

    var body: some View {
        TabView(selection: Bindable(appVM).selectedTab) {
            Tab("Dashboard", systemImage: "house.fill", value: 0) {
                DashboardView()
                    .environment(dashboardVM)
                    .environment(appVM)
            }
            Tab("Stock", systemImage: "refrigerator.fill", value: 1) {
                StockView()
                    .environment(stockVM)
                    .environment(appVM)
            }
            Tab("Shopping", systemImage: "cart.fill", value: 2) {
                ShoppingView()
                    .environment(shoppingVM)
                    .environment(appVM)
            }
            Tab("Tasks", systemImage: "checklist", value: 3) {
                TasksChoresView()
                    .environment(tasksVM)
                    .environment(appVM)
            }
            Tab("Recipes", systemImage: "fork.knife", value: 4) {
                RecipesView()
                    .environment(recipesVM)
                    .environment(appVM)
            }
        }
        .overlay(alignment: .bottom) {
            if appVM.isDemoMode {
                DemoBanner()
                    .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView()
                .environment(appVM)
        }
        .task {
            await loadAll()
            startPolling()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }

    private func loadAll() async {
        guard let client = appVM.client else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await dashboardVM.load(client: client) }
            group.addTask { await stockVM.load(client: client) }
            group.addTask { await shoppingVM.load(client: client) }
            group.addTask { await tasksVM.load(client: client) }
            group.addTask { await recipesVM.load(client: client) }
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let client = appVM.client else { continue }
                do {
                    let changed = try await client.getDBChangedTime()
                    if changed.changedTime != lastDBTime {
                        lastDBTime = changed.changedTime
                        await loadAll()
                    }
                } catch {}
            }
        }
    }
}

struct DemoBanner: View {
    var body: some View {
        Label("Demo Mode — demo.grocy.info", systemImage: "flask.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .shadow(radius: 4)
    }
}
