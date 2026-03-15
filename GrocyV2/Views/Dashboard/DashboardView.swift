import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(DashboardViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.greeting + "!")
                                .font(.title2.weight(.semibold))
                            Text(statusSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    if vm.isLoading && vm.volatileStock == nil {
                        ShimmerList(count: 3)
                    } else if !vm.hasAlerts {
                        AllGoodView()
                    } else {
                        cardStack
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                guard let client = appVM.client else { return }
                await vm.refresh(client: client)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appVM)
        }
        .task {
            guard let client = appVM.client else { return }
            if vm.volatileStock == nil {
                await vm.load(client: client)
            }
        }
    }

    @ViewBuilder
    private var cardStack: some View {
        VStack(spacing: 16) {
            if !vm.expiringSoon.isEmpty || !vm.overdue.isEmpty || !vm.expired.isEmpty {
                ExpiringItemsCard(
                    expiringSoon: vm.expiringSoon,
                    overdue: vm.overdue,
                    expired: vm.expired,
                    onNavigate: { appVM.selectedTab = 1 }
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !vm.missing.isEmpty {
                LowStockCard(missing: vm.missing, onNavigate: { appVM.selectedTab = 2 })
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if vm.overdueTasksCount > 0 || vm.overdueChoresCount > 0 {
                OverdueCard(
                    tasks: vm.tasks.filter { $0.isOverdue },
                    chores: vm.chores.filter { $0.isOverdue },
                    onNavigate: { appVM.selectedTab = 3 }
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.hasAlerts)
    }

    private var statusSubtitle: String {
        if vm.isLoading { return "Refreshing..." }
        let count = vm.expiringSoon.count + vm.expired.count + vm.overdue.count + vm.missing.count
        if count == 0 { return "Everything looks great 🎉" }
        return "\(count) item\(count == 1 ? "" : "s") need attention"
    }
}

private struct AllGoodView: View {
    @State private var scale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce)
            }
            VStack(spacing: 8) {
                Text("All stocked up!")
                    .font(.title2.weight(.semibold))
                Text("No expiring items, missing stock, or overdue tasks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
    }
}
