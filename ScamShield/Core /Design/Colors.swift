import SwiftUI

// MARK: - Nocturne Palette
extension Color {
    // Primary Dark
    static let midnight = Color(hex: "#040812")
    static let midnight50 = Color(hex: "#1a2a4a")
    static let midnight100 = Color(hex: "#152238")
    static let midnight200 = Color(hex: "#0f1a2a")

    // Secondary Dark
    static let navy = Color(hex: "#152238")
    static let navyLight = Color(hex: "#1e3050")
    static let navyDark = Color(hex: "#0c1525")

    // Primary Accent - Gold
    static let sunrise = Color(hex: "#e8c27f")
    static let sunriseLight = Color(hex: "#f0d49f")
    static let sunriseDark = Color(hex: "#d4a85f")

    // Secondary Accent - Orange
    static let ember = Color(hex: "#d67c45")
    static let emberLight = Color(hex: "#e09565")
    static let emberDark = Color(hex: "#b86530")

    // Text Colors
    static let starlight = Color.white
    static let cloud = Color(hex: "#c4d4e0")
    static let cloudLight = Color(hex: "#dbe7f0")
    static let cloudDark = Color(hex: "#9ab5c8")

    // Silhouette
    static let silhouette = Color(hex: "#0a0a0a")

    // Verdict Colors
    static let verdictDanger = Color(hex: "#dc2626")
    static let verdictDangerLight = Color(hex: "#fef2f2")
    static let verdictWarning = Color(hex: "#d97706")
    static let verdictWarningLight = Color(hex: "#fffbeb")
    static let verdictSafe = Color(hex: "#16a34a")
    static let verdictSafeLight = Color(hex: "#f0fdf4")

    // Glass Effect Colors
    static let glassWhite = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.15)
    static let glassHighlight = Color.white.opacity(0.25)
    static let glassDark = Color(hex: "#040812").opacity(0.6)
}

// MARK: - Color Themes
struct AppColors {
    // Convenience accessors
    static let background = Color.midnight
    static let cardBackground = Color.glassWhite
    static let primaryAccent = Color.sunrise
    static let secondaryAccent = Color.ember
    static let primaryText = Color.starlight
    static let secondaryText = Color.cloud
}

// MARK: - High Contrast Mode Support

/// Environment key for high contrast mode
struct HighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var highContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

/// View modifier to apply high contrast adjustments
struct HighContrastModifier: ViewModifier {
    @AppStorage("highContrastEnabled") private var highContrastEnabled = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var isHighContrast: Bool {
        highContrastEnabled || reduceTransparency
    }

    func body(content: Content) -> some View {
        content
            .environment(\.highContrast, isHighContrast)
    }
}

extension View {
    /// Apply high contrast mode based on user settings and iOS accessibility
    func respectHighContrast() -> some View {
        modifier(HighContrastModifier())
    }
}
