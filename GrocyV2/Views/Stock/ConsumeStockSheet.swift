import SwiftUI

struct ConsumeStockSheet: View {
    let productId: Int
    let productName: String
    let currentAmount: Double
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 1
    @State private var spoiled = false
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Stepper("\(amount, specifier: "%.0f")", value: $amount, in: 1...max(1, currentAmount), step: 1)
                    }
                    HStack {
                        Text("In stock")
                        Spacer()
                        Text("\(currentAmount, specifier: "%.0f")")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Mark as spoiled", isOn: $spoiled)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Consume Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else if didSucceed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Consume")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let client = appVM.client else { return }
        isSubmitting = true
        do {
            _ = try await client.consumeStock(productId: productId, amount: amount, spoiled: spoiled)
            HapticManager.shared.success()
            withAnimation { didSucceed = true }
            try? await Task.sleep(for: .seconds(0.8))
            dismiss()
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
        }
        isSubmitting = false
    }
}
