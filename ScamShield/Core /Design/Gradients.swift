import SwiftUI

struct AppGradients {
    // MARK: - Background Gradients

    /// Full nocturne sky gradient (hero background)
    /// Replicates: midnight → navy → blue → sunrise → ember
    static let nocturneFullVertical = LinearGradient(
        colors: [
            Color.midnight,
            Color.navy,
            Color(hex: "#2a4a6a"),
            Color.sunrise,
            Color.ember
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Upper nocturne (dark sections)
    static let nocturneUpper = LinearGradient(
        colors: [
            Color.midnight,
            Color.navy,
            Color.navyLight
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Mid nocturne (for content sections)
    static let nocturneMid = LinearGradient(
        colors: [
            Color.navy,
            Color.navyLight,
            Color(hex: "#2a4a6a")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Accent Gradients

    /// Primary button gradient (sunrise to ember)
    static let sunriseToEmber = LinearGradient(
        colors: [Color.sunrise, Color.ember],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical version for icons
    static let sunriseToEmberVertical = LinearGradient(
        colors: [Color.sunrise, Color.ember],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Glow Effects

    /// Sunrise glow (radial, for bottom of hero)
    static let sunriseGlow = RadialGradient(
        colors: [
            Color.sunrise.opacity(0.25),
            Color.ember.opacity(0.15),
            Color.clear
        ],
        center: .bottom,
        startRadius: 0,
        endRadius: 400
    )

    /// Gold glow for buttons/highlights
    static let goldGlow = RadialGradient(
        colors: [
            Color.sunrise.opacity(0.4),
            Color.sunrise.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )

    // MARK: - Verdict Gradients

    static let dangerGradient = LinearGradient(
        colors: [Color.verdictDanger.opacity(0.2), Color.verdictDanger.opacity(0.05)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color.verdictWarning.opacity(0.2), Color.verdictWarning.opacity(0.05)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let safeGradient = LinearGradient(
        colors: [Color.verdictSafe.opacity(0.2), Color.verdictSafe.opacity(0.05)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
