import SwiftUI

struct WelcomeView: View {
    let onConnect: () -> Void
    let onDemo: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.4), radius: 24, x: 0, y: 8)

                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: iconScale)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            Spacer().frame(height: 32)

            // Title
            VStack(spacing: 8) {
                Text("Grocy v2")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your pantry, beautifully managed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: titleOffset)
            .opacity(iconOpacity)

            Spacer().frame(height: 24)

            // Feature bullets
            VStack(alignment: .leading, spacing: 16) {
                FeatureBullet(icon: "barcode.viewfinder", color: .green, title: "Scan & Track", subtitle: "Scan barcodes to manage stock instantly")
                FeatureBullet(icon: "cart.fill", color: .blue, title: "Smart Shopping", subtitle: "Auto-fill lists from what you're out of")
                FeatureBullet(icon: "checklist", color: .orange, title: "Tasks & Chores", subtitle: "Keep the household running smoothly")
                FeatureBullet(icon: "fork.knife", color: .pink, title: "Recipes", subtitle: "Plan meals and cook from your pantry")
            }
            .padding(.horizontal, 32)
            .opacity(buttonsOpacity)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onConnect) {
                    Label("Connect My Server", systemImage: "network")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }

                Button(action: onDemo) {
                    Label("Try Demo", systemImage: "flask.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(buttonsOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                buttonsOpacity = 1.0
            }
        }
    }
}

private struct FeatureBullet: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
