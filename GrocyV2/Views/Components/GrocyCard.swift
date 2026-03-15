import SwiftUI

struct GrocyCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    let count: Int?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        systemImage: String,
        accentColor: Color = .accentColor,
        count: Int? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.count = count
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(accentColor)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor, in: Capsule())
                }
            }
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
