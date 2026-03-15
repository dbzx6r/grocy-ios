import SwiftUI

struct PutAwayView: View {
    @Environment(ShoppingViewModel.self) private var vm
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [PutAwayEntry] = []
    @State private var noteItems: [ShoppingListItem] = []
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            List {
                if !entries.isEmpty {
                    Section {
                        ForEach($entries) { $entry in
                            PutAwayRow(entry: $entry)
                        }
                    } header: {
                        Label("Adding to Pantry", systemImage: "refrigerator")
                    }
                }

                if !noteItems.isEmpty {
                    Section {
                        ForEach(noteItems) { item in
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundStyle(.secondary)
                                Text(item.note ?? "Item")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("No product linked")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Label("Notes only — skipped", systemImage: "text.badge.minus")
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
            .listStyle(.insetGrouped)
            .navigationTitle("Put Away")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button {
                            confirm()
                        } label: {
                            Text("Add to Pantry")
                                .fontWeight(.semibold)
                        }
                        .disabled(entries.isEmpty)
                    }
                }
            }
            .onAppear { buildEntries() }
        }
        .overlay {
            if showConfetti {
                ConfettiBurst()
                    .allowsHitTesting(false)
            }
        }
    }

    private func buildEntries() {
        // Build entries synchronously with name/expiry info
        var built: [PutAwayEntry] = vm.doneItems.compactMap { item -> PutAwayEntry? in
            guard let productId = item.productId else { return nil }
            let product = item.product ?? vm.products.first(where: { $0.id == productId })
            let name = product?.name ?? "Product #\(productId)"
            let defaultDays = product?.defaultBestBeforeDays ?? 0
            let hasExpiry = defaultDays > 0
            let expiryDate: Date = hasExpiry
                ? Calendar.current.date(byAdding: .day, value: defaultDays, to: .now) ?? .now
                : .now
            // Pre-fill the product's default location if set
            let defaultLocationId = product?.locationId
            return PutAwayEntry(
                id: item.id,
                productId: productId,
                productName: name,
                barcode: nil,
                amount: item.amount,
                hasExpiry: hasExpiry,
                expiryDate: expiryDate,
                locationId: defaultLocationId,
                price: ""
            )
        }
        entries = built
        noteItems = vm.doneItems.filter { $0.productId == nil }

        // Fetch barcodes concurrently so Kroger lookup can use UPC
        guard let client = appVM.client else { return }
        Task {
            await withTaskGroup(of: (Int, String?).self) { group in
                for entry in built {
                    group.addTask {
                        let barcodes = try? await client.getProductBarcodes(productId: entry.productId)
                        return (entry.productId, barcodes?.first?.barcode)
                    }
                }
                for await (productId, barcode) in group {
                    if let barcode, let idx = entries.firstIndex(where: { $0.productId == productId }) {
                        entries[idx].barcode = barcode
                    }
                }
            }
        }
    }

    private func confirm() {
        guard let client = appVM.client else { return }
        isSubmitting = true
        submitError = nil
        Task {
            do {
                try await vm.putAway(client: client, entries: entries)
                HapticManager.shared.success()
                withAnimation { showConfetti = true }
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } catch {
                submitError = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

private struct PutAwayRow: View {
    @Binding var entry: PutAwayEntry
    @Environment(ShoppingViewModel.self) private var vm
    @FocusState private var priceFocused: Bool

    @State private var isFetchingPrice = false
    @State private var priceSource: String? = nil
    @State private var priceFetchError: String? = nil
    @State private var needsZipCode = false

    private var krogerEnabled: Bool {
        UserDefaults.standard.bool(forKey: "kroger_enabled") &&
        !(KeychainHelper.shared.load(key: "kroger_client_id") ?? "").isEmpty &&
        !(KeychainHelper.shared.load(key: "kroger_client_secret") ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product name header
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline)
                Text(entry.productName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.bottom, 12)

            // Quantity
            HStack {
                Label("Quantity", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: $entry.amount,
                    in: 0.5...999,
                    step: 0.5
                ) {
                    Text(entry.amount.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.subheadline.monospacedDigit())
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }

            Divider().padding(.vertical, 8)

            // Price (optional)
            HStack {
                Label("Price (optional)", systemImage: "dollarsign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0.00", text: $entry.price)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 80)
                    .focused($priceFocused)
            }

            // Price source / fetch button row
            if krogerEnabled {
                HStack {
                    if let source = priceSource {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if needsZipCode {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label(
                                priceFetchError ?? "Add zip code in Settings →",
                                systemImage: "location"
                            )
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    } else if let err = priceFetchError {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Spacer()
                    }
                    Spacer()
                    if isFetchingPrice {
                        ProgressView().controlSize(.mini)
                    } else {
                        Button {
                            fetchKrogerPrice()
                        } label: {
                            Label("Fetch Price", systemImage: "tag")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.top, 4)
            }

            Divider().padding(.vertical, 8)

            // Storage location
            if !vm.locations.isEmpty {
                HStack {
                    Label("Store In", systemImage: "archivebox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("No specific location") { entry.locationId = nil }
                        Divider()
                        ForEach(vm.locations) { loc in
                            Button(loc.name) { entry.locationId = loc.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(vm.locations.first(where: { $0.id == entry.locationId })?.name ?? "Any")
                                .font(.subheadline)
                                .foregroundStyle(entry.locationId != nil ? .primary : .secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider().padding(.vertical, 8)
            }

            // Best Before toggle
            HStack {
                Label("Best Before", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $entry.hasExpiry.animation())
                    .labelsHidden()
                    .tint(Color.accentColor)
            }

            // Date picker — only when toggle is on
            if entry.hasExpiry {
                HStack {
                    Spacer()
                    DatePicker(
                        "",
                        selection: $entry.expiryDate,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { priceFocused = false }
    }

    private func fetchKrogerPrice() {
        isFetchingPrice = true
        priceSource = nil
        priceFetchError = nil
        needsZipCode = false
        // Prefer UPC barcode for exact Kroger match; fall back to product name
        let searchTerm = entry.barcode ?? entry.productName
        Task {
            do {
                let result = try await KrogerService.shared.lookupPrice(searchTerm: searchTerm)
                let displayPrice = result.promo ?? result.regular
                await MainActor.run {
                    entry.price = String(format: "%.2f", displayPrice)
                    let store = result.storeName.map { " · \($0)" } ?? ""
                    priceSource = "via Kroger\(store)"
                    isFetchingPrice = false
                }
            } catch KrogerServiceError.noLocation, KrogerServiceError.locationNotFound {
                await MainActor.run {
                    needsZipCode = true
                    priceFetchError = KrogerServiceError.locationNotFound.localizedDescription
                    isFetchingPrice = false
                }
            } catch KrogerServiceError.notFound {
                // If UPC search failed and we haven't tried name yet, retry with name
                if entry.barcode != nil {
                    Task {
                        do {
                            let result = try await KrogerService.shared.lookupPrice(searchTerm: entry.productName)
                            let displayPrice = result.promo ?? result.regular
                            await MainActor.run {
                                entry.price = String(format: "%.2f", displayPrice)
                                let store = result.storeName.map { " · \($0)" } ?? ""
                                priceSource = "via Kroger\(store)"
                                isFetchingPrice = false
                            }
                        } catch KrogerServiceError.noLocation, KrogerServiceError.locationNotFound {
                            await MainActor.run {
                                needsZipCode = true
                                isFetchingPrice = false
                            }
                        } catch {
                            await MainActor.run {
                                priceFetchError = "Price not found"
                                isFetchingPrice = false
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        priceFetchError = "Price not found"
                        isFetchingPrice = false
                    }
                }
            } catch {
                await MainActor.run {
                    priceFetchError = error.localizedDescription
                    isFetchingPrice = false
                }
            }
        }
    }
}
