import SwiftUI

struct AnimatedCheckmark: View {
    let isChecked: Bool
    let action: () -> Void

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.3
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                scale = 1.0
            }
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                .scaleEffect(scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isChecked)
        }
        .buttonStyle(.plain)
    }
}
