import SwiftUI

struct AddEditChoreSheet: View {
    @Environment(TasksViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    /// Pass choreId for editing; nil for create
    let choreId: Int?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var periodType: ChorePeriodType = .daily
    @State private var periodInterval: Int = 1
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var submitError: String?

    private var isEditing: Bool { choreId != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    enum ChorePeriodType: String, CaseIterable, Identifiable {
        case hourly, daily, weekly, monthly, yearly
        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
        var intervalLabel: String {
            switch self {
            case .hourly: return "hours"
            case .daily: return "days"
            case .weekly: return "weeks"
            case .monthly: return "months"
            case .yearly: return "years"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chore Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Schedule") {
                    Picker("Repeats", selection: $periodType) {
                        ForEach(ChorePeriodType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Stepper("Every \(periodInterval) \(periodType.intervalLabel)", value: $periodInterval, in: 1...365)
                }

                if let submitError {
                    Section {
                        Label(submitError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Chore" : "New Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting || isLoading {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Add") { submit() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
            .task { await prefill() }
        }
    }

    private func prefill() async {
        guard let choreId, let client = appVM.client else { return }
        isLoading = true
        if let chore = try? await client.getChoreObject(id: choreId) {
            name = chore.name
            description = chore.description ?? ""
            if let pt = chore.periodType, let matched = ChorePeriodType(rawValue: pt) {
                periodType = matched
            }
            if let days = chore.periodDays {
                periodInterval = max(1, Int(days))
            }
        }
        isLoading = false
    }

    private func submit() {
        guard let client = appVM.client else { return }
        isSubmitting = true
        submitError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let desc = description.isEmpty ? nil : description
        Task {
            if let choreId {
                await vm.updateChore(client: client, id: choreId, name: trimmedName, description: desc, periodType: periodType.rawValue, periodInterval: periodInterval)
            } else {
                await vm.createChore(client: client, name: trimmedName, description: desc, periodType: periodType.rawValue, periodInterval: periodInterval)
            }
            if vm.error == nil {
                HapticManager.shared.success()
                dismiss()
            } else {
                submitError = vm.error
                isSubmitting = false
            }
        }
    }
}
