import SwiftUI

struct DemoIntroView: View {
    @Environment(AppViewModel.self) private var appVM
    let onBack: () -> Void
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                Text("Try the Demo")
                    .font(.title.bold())

                Text("Connect to **demo.grocy.info**, the official Grocy demo server. It's pre-loaded with sample data so you can explore all features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                DemoNote(icon: "info.circle", text: "Demo data may reset periodically")
                DemoNote(icon: "lock.open", text: "No account or setup required")
                DemoNote(icon: "arrow.triangle.2.circlepath", text: "Switch to your server anytime in Settings")
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)

            if let err = appVM.connectionError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                Task {
                    _ = await appVM.connectDemo()
                }
            } label: {
                Group {
                    if appVM.isValidating {
                        ProgressView().tint(.white)
                    } else {
                        Label("Explore Demo", systemImage: "arrow.right.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(appVM.isValidating)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.headline)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct DemoNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
