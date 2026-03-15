import SwiftUI

struct TasksChoresView: View {
    @Environment(TasksViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: Bindable(vm).selectedTab) {
                    ForEach(TasksViewModel.TaskTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if vm.isLoading && vm.tasks.isEmpty && vm.chores.isEmpty {
                        ShimmerList()
                    } else {
                        switch vm.selectedTab {
                        case .tasks:
                            tasksContent
                        case .chores:
                            choresContent
                        }
                    }
                }
            }
            .navigationTitle("Tasks & Chores")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { vm.showCompleted.toggle() }
                    } label: {
                        Image(systemName: vm.showCompleted ? "eye.slash" : "eye")
                    }
                }
            }
            .refreshable {
                guard let client = appVM.client else { return }
                await vm.load(client: client)
            }
        }
        .overlay {
            if showConfetti {
                ConfettiBurst()
                    .allowsHitTesting(false)
            }
        }
        .task {
            guard let client = appVM.client else { return }
            if vm.tasks.isEmpty && vm.chores.isEmpty {
                await vm.load(client: client)
            }
        }
    }

    @ViewBuilder
    private var tasksContent: some View {
        if vm.visibleTasks.isEmpty {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: vm.showCompleted ? "No Tasks" : "All Done!",
                subtitle: vm.showCompleted ? "No tasks found." : "You have no pending tasks 🎉"
            )
        } else {
            List {
                ForEach(vm.groupedTasks, id: \.category) { group in
                    Section(group.category) {
                        ForEach(group.tasks) { task in
                            TaskRow(task: task) {
                                guard let client = appVM.client else { return }
                                Task {
                                    await vm.completeTask(client: client, id: task.id)
                                    HapticManager.shared.success()
                                    withAnimation { showConfetti = true }
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        showConfetti = false
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    guard let client = appVM.client else { return }
                                    Task { await vm.completeTask(client: client, id: task.id) }
                                } label: {
                                    Label("Done", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                if task.isDone {
                                    Button {
                                        guard let client = appVM.client else { return }
                                        Task { await vm.undoTask(client: client, id: task.id) }
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: vm.visibleTasks.map { $0.id })
        }
    }

    @ViewBuilder
    private var choresContent: some View {
        if vm.chores.isEmpty {
            EmptyStateView(
                systemImage: "arrow.2.circlepath.circle",
                title: "No Chores",
                subtitle: "Create chores in your Grocy server."
            )
        } else {
            List {
                ForEach(vm.chores) { detail in
                    ChoreRow(detail: detail) {
                        guard let client = appVM.client else { return }
                        Task {
                            await vm.executeChore(client: client, id: detail.chore.id)
                            HapticManager.shared.success()
                            withAnimation { showConfetti = true }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                showConfetti = false
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            guard let client = appVM.client else { return }
                            Task { await vm.executeChore(client: client, id: detail.chore.id) }
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
