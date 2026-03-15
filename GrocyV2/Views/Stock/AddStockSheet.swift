import SwiftUI

struct AddStockSheet: View {
    let productId: Int
    let productName: String
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 1
    @State private var bestBeforeDate: Date = .now.addingTimeInterval(86400 * 14)
    @State private var hasExpiry = false
    @State private var price: String = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Quantity") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Stepper("\(amount, specifier: "%.0f")", value: $amount, in: 1...999, step: 1)
                    }
                }

                Section("Expiry Date") {
                    Toggle("Set expiry date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Best before", selection: $bestBeforeDate, displayedComponents: .date)
                    }
                }

                Section("Price (optional)") {
                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add to Stock")
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
                            Text("Add")
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
        error = nil
        let dateStr = hasExpiry ? DateFormatters.shared.apiDate.string(from: bestBeforeDate) : nil
        let priceVal = Double(price.replacingOccurrences(of: ",", with: "."))
        do {
            _ = try await client.addStock(productId: productId, amount: amount, bestBeforeDate: dateStr, price: priceVal)
            HapticManager.shared.success()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { didSucceed = true }
            try? await Task.sleep(for: .seconds(0.8))
            dismiss()
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
        }
        isSubmitting = false
    }
}
