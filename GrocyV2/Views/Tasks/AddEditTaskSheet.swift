import SwiftUI

struct AddEditTaskSheet: View {
    @Environment(TasksViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    let existingTask: GrocyTask?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var selectedCategoryId: Int? = nil
    @State private var isSubmitting = false
    @State private var submitError: String?

    private var isEditing: Bool { existingTask != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }

                if !vm.categories.isEmpty {
                    Section("Category") {
                        Picker("Category", selection: $selectedCategoryId) {
                            Text("None").tag(nil as Int?)
                            ForEach(vm.categories) { cat in
                                Text(cat.name).tag(cat.id as Int?)
                            }
                        }
                    }
                }

                if let submitError {
                    Section {
                        Label(submitError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Add") { submit() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let task = existingTask else { return }
        name = task.name
        description = task.description ?? ""
        selectedCategoryId = task.categoryId
        if let d = task.dueDateParsed {
            hasDueDate = true
            dueDate = d
        }
    }

    private func submit() {
        guard let client = appVM.client else { return }
        isSubmitting = true
        submitError = nil
        let dueDateStr = hasDueDate ? DateFormatters.shared.apiDate.string(from: dueDate) : nil
        let desc = description.isEmpty ? nil : description
        Task {
            if let task = existingTask {
                await vm.updateTask(client: client, id: task.id, name: name.trimmingCharacters(in: .whitespaces), description: desc, dueDate: dueDateStr, categoryId: selectedCategoryId)
            } else {
                await vm.createTask(client: client, name: name.trimmingCharacters(in: .whitespaces), description: desc, dueDate: dueDateStr, categoryId: selectedCategoryId)
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
