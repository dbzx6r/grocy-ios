import SwiftUI

struct AddShoppingItemSheet: View {
    @Environment(ShoppingViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product? = nil
    @State private var note = ""
    @State private var amount: Double = 1
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var searchText = ""

    private var filteredProducts: [Product] {
        searchText.isEmpty
            ? vm.products
            : vm.products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    if let product = selectedProduct {
                        HStack {
                            Text(product.name)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button("Change") { selectedProduct = nil }
                                .font(.caption)
                        }
                    } else {
                        TextField("Search products...", text: $searchText)
                        if !searchText.isEmpty {
                            ForEach(filteredProducts.prefix(8)) { product in
                                Button {
                                    selectedProduct = product
                                    searchText = ""
                                    HapticManager.shared.selection()
                                } label: {
                                    Text(product.name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Section("Note (optional)") {
                    TextField("e.g. organic, large size...", text: $note)
                }

                Section("Quantity") {
                    Stepper("\(amount, specifier: "%.0f")", value: $amount, in: 1...99, step: 1)
                }
            }
            .navigationTitle("Add to List")
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
                            Text("Add").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting || (selectedProduct == nil && note.isEmpty))
                }
            }
        }
    }

    private func submit() async {
        guard let client = appVM.client else { return }
        isSubmitting = true
        await vm.addItem(
            client: client,
            productId: selectedProduct?.id,
            note: note.isEmpty ? nil : note,
            amount: amount
        )
        HapticManager.shared.success()
        withAnimation { didSucceed = true }
        try? await Task.sleep(for: .seconds(0.6))
        dismiss()
        isSubmitting = false
    }
}
