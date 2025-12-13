import UIKit

/// Manages haptic feedback throughout the app
/// Following Chris Ro's approach: haptics on every meaningful interaction
final class HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    // MARK: - Prepare (call before expected interaction)

    func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Button Interactions

    /// Light tap for standard buttons
    func buttonTap() {
        impactLight.impactOccurred()
    }

    /// Medium tap for primary actions
    func primaryButtonTap() {
        impactMedium.impactOccurred()
    }

    // MARK: - Scan Lifecycle

    /// When user initiates a scan
    func scanStart() {
        impactMedium.impactOccurred()
    }

    /// When scan phase changes (searching → analyzing, etc.)
    func scanPhaseChange() {
        impactLight.impactOccurred()
    }

    /// When verdict is revealed - varies by result
    func verdictReveal(_ verdict: ScamVerdict) {
        switch verdict {
        case .highScam:
            notification.notificationOccurred(.error)
        case .suspicious:
            notification.notificationOccurred(.warning)
        case .noObviousScam:
            notification.notificationOccurred(.success)
        }
    }

    // MARK: - Selection & Navigation

    /// Toggle or segment selection changed
    func selectionChanged() {
        selection.selectionChanged()
    }

    /// Page swipe in onboarding
    func pageSwipe() {
        impactLight.impactOccurred()
    }

    // MARK: - Notifications

    /// When an error occurs
    func error() {
        notification.notificationOccurred(.error)
    }

    /// When a success action occurs
    func success() {
        notification.notificationOccurred(.success)
    }
}
