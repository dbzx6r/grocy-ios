import SwiftUI
import VisionKit
import AVFoundation

// MARK: - BarcodeScannerView

struct BarcodeScannerView: View {
    var onProductPicked: ((Product) -> Void)? = nil

    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var scannedBarcode: String?
    @State private var foundProduct: ProductDetails?
    @State private var isSearching = false
    @State private var notFound = false
    @State private var actionResult: String?
    @State private var isPerformingAction = false
    @State private var offProduct: OFFProduct?       // Open Food Facts result
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var cameraReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraPermission == .denied || cameraPermission == .restricted {
                cameraPermissionDenied
            } else if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(scannedBarcode: $scannedBarcode)
                    .ignoresSafeArea()
            } else {
                unsupportedView
            }

            ScannerOverlay()

            // Top bar — only our title; DataScannerViewController guidance is disabled
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                    Text("Scan Barcode")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }
                .padding()
                Spacer()
            }

            // Camera warm-up overlay — hidden once AE has stabilised
            if !cameraReady {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Preparing camera…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .transition(.opacity)
            }

            // Result panel
            VStack {
                Spacer()
                resultPanel
            }
        }
        .task {
            // Permission check
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraPermission == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraPermission = granted ? .authorized : .denied
            }
            // Wait for camera auto-exposure to stabilise before revealing preview
            await warmUpCamera()
        }
        .onChange(of: scannedBarcode) { _, newValue in
            guard let barcode = newValue else { return }
            Task { await lookupBarcode(barcode) }
        }
    }

    // MARK: - Result Panel

    @ViewBuilder
    private var resultPanel: some View {
        VStack(spacing: 0) {
            if isSearching {
                HStack {
                    ProgressView()
                    Text("Looking up barcode...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else if let product = foundProduct {
                ProductFoundCard(
                    product: product,
                    onProductPicked: onProductPicked != nil ? { onProductPicked?(product.product); dismiss() } : nil,
                    onAdd: { await performAdd(product: product) },
                    onConsume: { await performConsume(product: product) },
                    onOpen: { await performOpen(product: product) },
                    onDismiss: { resetScan() },
                    isPerformingAction: isPerformingAction,
                    actionResult: actionResult
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else if notFound {
                if let off = offProduct {
                    // OFF has data — offer auto-import
                    ImportProductCard(
                        offProduct: off,
                        barcode: scannedBarcode ?? "",
                        onImported: { product in
                            if let pick = onProductPicked {
                                pick(product)
                                dismiss()
                            } else {
                                resetScan()
                            }
                        },
                        onDismiss: { resetScan() }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    NotFoundCard(
                        barcode: scannedBarcode ?? "",
                        onDismiss: { resetScan() }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: foundProduct?.product.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notFound)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearching)
    }

    // MARK: - Permission / Unsupported Views

    @ViewBuilder
    private var cameraPermissionDenied: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Please enable camera access in Settings to scan barcodes.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.6))
            Text("Scanner Not Available")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("DataScannerViewController is not available on this device or simulator.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Private helpers

    /// Polls AVCaptureDevice.isAdjustingExposure until the camera AE has settled,
    /// then fades out the warm-up overlay.  Hard fallback at 5 seconds.
    private func warmUpCamera() async {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let deadline = Date().addingTimeInterval(5.0)
        var stableCount = 0
        // Require 5 consecutive 100 ms intervals of AE being stable (= 500 ms stability)
        let requiredStable = 5

        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            if let dev = device, !dev.isAdjustingExposure {
                stableCount += 1
                if stableCount >= requiredStable { break }
            } else {
                stableCount = 0
            }
        }

        withAnimation(.easeOut(duration: 0.5)) { cameraReady = true }
    }

    private func lookupBarcode(_ barcode: String) async {
        guard let client = appVM.client else { return }
        isSearching = true
        notFound = false
        foundProduct = nil
        offProduct = nil
        actionResult = nil
        HapticManager.shared.impact(.medium)
        do {
            foundProduct = try await client.getProductByBarcode(barcode)
        } catch {
            // Grocy returns 400 (not 404) for unknown barcodes, plus any other
            // error should still attempt external lookup.
            if let result = try? await client.fetchOpenFoodFacts(barcode: barcode) {
                offProduct = result
            } else {
                offProduct = try? await client.fetchUPCItemDB(barcode: barcode)
            }
            notFound = true
        }
        isSearching = false
    }

    private func performAdd(product: ProductDetails) async {
        guard let client = appVM.client, let barcode = scannedBarcode else { return }
        isPerformingAction = true
        do {
            _ = try await client.addStockByBarcode(barcode)
            HapticManager.shared.success()
            withAnimation { actionResult = "Added 1 \(product.product.name) to stock ✓" }
        } catch {
            actionResult = "Error: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
        isPerformingAction = false
    }

    private func performConsume(product: ProductDetails) async {
        guard let client = appVM.client, let barcode = scannedBarcode else { return }
        isPerformingAction = true
        do {
            _ = try await client.consumeStockByBarcode(barcode)
            HapticManager.shared.success()
            withAnimation { actionResult = "Consumed 1 \(product.product.name) ✓" }
        } catch {
            actionResult = "Error: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
        isPerformingAction = false
    }

    private func performOpen(product: ProductDetails) async {
        guard let client = appVM.client else { return }
        isPerformingAction = true
        do {
            _ = try await client.openStock(productId: product.product.id)
            HapticManager.shared.success()
            withAnimation { actionResult = "Marked \(product.product.name) as opened ✓" }
        } catch {
            actionResult = "Error: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
        isPerformingAction = false
    }

    private func resetScan() {
        scannedBarcode = nil
        foundProduct = nil
        notFound = false
        actionResult = nil
        offProduct = nil
    }
}

// MARK: - DataScannerRepresentable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedBarcode: String?

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,       // we have our own title; no "Find Nearby Barcodes" text
            isHighlightingEnabled: false    // no green rectangle drawn around detected barcodes
        )
        vc.delegate = context.coordinator
        // Delay scan start so camera AE stabilizes — warmUpCamera() handles the overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            try? vc.startScanning()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedBarcode: $scannedBarcode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var scannedBarcode: String?
        private var lastScanned: String?
        private var lastScanTime: Date = .distantPast

        init(scannedBarcode: Binding<String?>) {
            self._scannedBarcode = scannedBarcode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    let now = Date()
                    let value = barcode.payloadStringValue ?? ""
                    guard !value.isEmpty,
                          value != lastScanned || now.timeIntervalSince(lastScanTime) > 3
                    else { continue }
                    lastScanned = value
                    lastScanTime = now
                    Task { @MainActor [weak self] in
                        self?.scannedBarcode = value
                    }
                }
            }
        }
    }
}

// MARK: - ScannerOverlay

struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Dimmed background with transparent cutout
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .ignoresSafeArea()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: 260, height: 160)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Viewfinder border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 260, height: 160)
                    .overlay(viewfinderCorners)
            }
        }
    }

    private var viewfinderCorners: some View {
        ZStack {
            CornerAccent(corner: "topLeading")
            CornerAccent(corner: "topTrailing")
            CornerAccent(corner: "bottomLeading")
            CornerAccent(corner: "bottomTrailing")
        }
    }
}

// MARK: - CornerAccent

struct CornerAccent: View {
    let corner: String
    var size: CGFloat = 20
    var thickness: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let x: CGFloat = corner.contains("trailing") ? w - size : 0
            let y: CGFloat = corner.contains("bottom") ? h - size : 0

            Path { path in
                if corner == "topLeading" {
                    path.move(to: CGPoint(x: x, y: y + size))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + size, y: y))
                } else if corner == "topTrailing" {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + size, y: y))
                    path.addLine(to: CGPoint(x: x + size, y: y + size))
                } else if corner == "bottomLeading" {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + size))
                    path.addLine(to: CGPoint(x: x + size, y: y + size))
                } else {
                    path.move(to: CGPoint(x: x, y: y + size))
                    path.addLine(to: CGPoint(x: x + size, y: y + size))
                    path.addLine(to: CGPoint(x: x + size, y: y))
                }
            }
            .stroke(
                Color.white,
                style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 260, height: 160)
    }
}

// MARK: - ProductFoundCard

struct ProductFoundCard: View {
    let product: ProductDetails
    var onProductPicked: (() -> Void)? = nil
    let onAdd: () async -> Void
    let onConsume: () async -> Void
    let onOpen: () async -> Void
    let onDismiss: () -> Void
    let isPerformingAction: Bool
    let actionResult: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.product.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Product found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let amount = product.stockAmount {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.0f in stock", amount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }

            if let pickAction = onProductPicked {
                // Picker mode: single "Use This Product" button
                Button(action: pickAction) {
                    Label("Use This Product", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else if let result = actionResult {
                Text(result)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(result.contains("Error") ? .red : .green)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                HStack(spacing: 10) {
                    scanActionButton("Add", icon: "plus.circle.fill", color: .green) { await onAdd() }
                    scanActionButton("Consume", icon: "minus.circle.fill", color: .orange) { await onConsume() }
                    scanActionButton("Open", icon: "lock.open.fill", color: .blue) { await onOpen() }
                }
                .disabled(isPerformingAction)
                .overlay {
                    if isPerformingAction { ProgressView() }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
    }

    private func scanActionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button { Task { await action() } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ImportProductCard

struct ImportProductCard: View {
    let offProduct: OFFProduct
    let barcode: String
    let onImported: (Product) -> Void
    let onDismiss: () -> Void

    @Environment(AppViewModel.self) private var appVM
    @State private var productName: String
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importedProduct: Product?

    init(offProduct: OFFProduct, barcode: String, onImported: @escaping (Product) -> Void, onDismiss: @escaping () -> Void) {
        self.offProduct = offProduct
        self.barcode = barcode
        self.onImported = onImported
        self.onDismiss = onDismiss
        // Pre-fill with brand + name for a clean product name
        let name: String
        if let brand = offProduct.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
           !brand.isEmpty, let pn = offProduct.productName, !pn.isEmpty {
            name = "\(brand) \(pn)"
        } else {
            name = offProduct.displayName
        }
        _productName = State(initialValue: name)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption.weight(.bold))
                        Text("Found on Open Food Facts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text("Barcode: \(barcode)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }

            // OFF product details
            HStack(spacing: 12) {
                if let imgUrl = offProduct.imageFrontUrl, let url = URL(string: imgUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let brand = offProduct.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(offProduct.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        if let qty = offProduct.quantity {
                            Label(qty, systemImage: "scalemass.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let kcal = offProduct.kcalPer100g {
                            Label(String(format: "%.0f kcal/100g", kcal), systemImage: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Divider()

            // Editable product name
            VStack(alignment: .leading, spacing: 6) {
                Text("Product name in Grocy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Product name", text: $productName)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }

            // Error
            if let err = importError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }

            // Import button
            if let imported = importedProduct {
                Label("\"\(imported.name)\" imported!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    Task { await importToGrocy() }
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(isImporting ? "Importing…" : "Import to Grocy")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(productName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isImporting || productName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
    }

    private func importToGrocy() async {
        guard let client = appVM.client else { return }
        let name = productName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isImporting = true
        importError = nil
        do {
            try await importToGrocyAttempt(client: client, name: name)
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
        isImporting = false
    }

    /// Core import logic with up to 3 automatic retries for transient server errors.
    /// Home-lab servers (RPi, NAS) can return malformed responses under load; retrying
    /// 400 ms later resolves the issue without any user action.
    private func importToGrocyAttempt(client: GrocyAPIClient, name: String) async throws {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                try await _importToGrocy(client: client, name: name)
                return
            } catch NetworkError.decodingError, NetworkError.invalidResponse {
                lastError = NetworkError.decodingError(
                    NSError(domain: "parse", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Could not parse server response."])
                )
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(400))
                }
            }
        }
        throw lastError ?? NetworkError.invalidResponse
    }

    private func _importToGrocy(client: GrocyAPIClient, name: String) async throws {
        async let qusTask = client.getQuantityUnits()
        async let locsTask = client.getLocations()
        async let productsTask = client.getProducts()
        let (qus, locs, existingProducts) = try await (qusTask, locsTask, productsTask)

        guard let defaultQu = qus.first else {
            throw ImportError.missingQuantityUnits
        }
        guard let defaultLoc = locs.first else {
            throw ImportError.missingLocations
        }

        // If a product with this name already exists, reuse it instead of creating a duplicate
        let productId: Int
        if let existing = existingProducts.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            productId = existing.id
        } else {
            let descParts = [
                offProduct.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
                offProduct.quantity
            ].compactMap { $0 }.filter { !$0.isEmpty }
            let desc: String? = descParts.isEmpty ? nil : descParts.joined(separator: " — ")

            productId = try await client.createProduct(
                name: name,
                calories: offProduct.kcalPer100g,
                description: desc,
                defaultQuId: defaultQu.id,
                defaultLocationId: defaultLoc.id
            )
        }

        // Link barcode (ignore duplicate-barcode errors gracefully)
        try? await client.linkBarcode(productId: productId, barcode: barcode)

        // Small pause to let the Grocy server finish writing before reading details
        try? await Task.sleep(for: .milliseconds(200))

        let details = try await client.getProductDetails(id: productId)
        HapticManager.shared.success()
        withAnimation { importedProduct = details.product }
        try? await Task.sleep(for: .seconds(1.2))
        onImported(details.product)
    }

    private enum ImportError: LocalizedError {
        case missingQuantityUnits
        case missingLocations

        var errorDescription: String? {
            switch self {
            case .missingQuantityUnits: return "No quantity units found. Set up quantity units in Grocy first."
            case .missingLocations: return "No locations found. Set up at least one location in Grocy first."
            }
        }
    }
}

// MARK: - NotFoundCard

struct NotFoundCard: View {
    let barcode: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Product Not Found")
                        .font(.headline)
                    Text("Barcode: \(barcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            Label(
                "This barcode isn't in Grocy or Open Food Facts. Add it manually in Grocy.",
                systemImage: "barcode.viewfinder"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
    }
}
