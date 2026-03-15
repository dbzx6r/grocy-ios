import UIKit

final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()
    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func success() { notification(.success) }
    func error()   { notification(.error) }
    func warning() { notification(.warning) }
}
