import UIKit

enum JeevesHaptics {
    /// Consent prompt received
    static func consentPrompt() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Consent approved
    static func approved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Action blocked
    static func blocked() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Kill switch activated
    static func killSwitch() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
