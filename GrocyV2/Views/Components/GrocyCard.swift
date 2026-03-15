import SwiftUI

struct GrocyCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    let count: Int?
    let action: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        systemImage: String,
        accentColor: Color = .accentColor,
        count: Int? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.count = count
        self.action = action
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var header: some View {
        if let action {
            Button(action: action) {
                headerContent
            }
            .buttonStyle(.plain)
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
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
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor.opacity(0.7))
            }
        }
    }
}
