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
    @State private var externalLookup: ExternalBarcodeLookup?
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

            // Top bar
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
                    Text(onProductPicked != nil ? "Scan to Select Product" : "Scan Barcode")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }
                .padding()
                Spacer()
            }

            // Camera warm-up overlay — hides auto-exposure burst
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
        .onAppear { checkCameraPermission() }
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
                NotFoundCard(
                    barcode: scannedBarcode ?? "",
                    externalInfo: externalLookup,
                    onDismiss: { resetScan() }
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private func checkCameraPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraPermission == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        }
        // Fade out the warm-up overlay after camera has had time to calibrate exposure
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.5)) { cameraReady = true }
        }
    }

    private func lookupBarcode(_ barcode: String) async {
        guard let client = appVM.client else { return }
        isSearching = true
        notFound = false
        foundProduct = nil
        actionResult = nil
        HapticManager.shared.impact(.medium)
        do {
            foundProduct = try await client.getProductByBarcode(barcode)
        } catch NetworkError.notFound {
            externalLookup = try? await client.lookupExternalBarcode(barcode)
            notFound = true
        } catch {
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
        externalLookup = nil
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
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        // Delay scan start so camera AE stabilizes — prevents overexposed startup frames
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
    @State private var scanLineOffset: CGFloat = -80

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
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: 260, height: 160)
                    .overlay(viewfinderCorners)
                    .overlay(
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(height: 2)
                            .offset(y: scanLineOffset)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    )
                    .clipped()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scanLineOffset = 80
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
                Color.accentColor,
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

// MARK: - NotFoundCard

struct NotFoundCard: View {
    let barcode: String
    let externalInfo: ExternalBarcodeLookup?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(externalInfo?.name ?? "Product Not Found")
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

            if let info = externalInfo {
                if let group = info.productGroup {
                    Label(group, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label(
                    "Found via Open Food Facts — add this product in Grocy first.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.leading)
            } else {
                Label(
                    "This barcode isn't linked to any product. Add it in Grocy first.",
                    systemImage: "barcode.viewfinder"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
    }
}
