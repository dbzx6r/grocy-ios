import SwiftUI

struct ShimmerRow: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: 120, height: 10)
            }
            Spacer()
        }
        .foregroundStyle(
            LinearGradient(
                stops: [
                    .init(color: Color(.systemGray5), location: phase - 0.3),
                    .init(color: Color(.systemGray6), location: phase),
                    .init(color: Color(.systemGray5), location: phase + 0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

struct ShimmerList: View {
    var count: Int = 6

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                ShimmerRow()
            }
        }
        .padding()
    }
}
