import SwiftUI

struct AppTypography {
    // MARK: - Headings (System Serif - New York)

    /// Hero title - 48pt
    static let heroTitle = Font.system(size: 48, weight: .semibold, design: .serif)

    /// Section title - 32pt
    static let sectionTitle = Font.system(size: 32, weight: .semibold, design: .serif)

    /// Card title - 24pt
    static let cardTitle = Font.system(size: 24, weight: .semibold, design: .serif)

    /// Verdict title - 28pt bold
    static let verdictTitle = Font.system(size: 28, weight: .bold, design: .serif)

    // MARK: - Body Text (SF Pro)

    /// Large body - 18pt
    static let bodyLarge = Font.system(size: 18, weight: .regular)

    /// Standard body - 16pt
    static let body = Font.system(size: 16, weight: .regular)

    /// Caption - 14pt
    static let caption = Font.system(size: 14, weight: .regular)

    /// Small label - 12pt
    static let label = Font.system(size: 12, weight: .medium)

    // MARK: - Special

    /// Button text - 18pt bold
    static let buttonText = Font.system(size: 18, weight: .bold)

    /// Navigation title - 20pt semibold serif
    static let navTitle = Font.system(size: 20, weight: .semibold, design: .serif)

    /// Badge text - 14pt medium, all caps
    static let badge = Font.system(size: 14, weight: .medium)
}

// MARK: - View Modifiers for Typography

extension View {
    func heroTitleStyle() -> some View {
        self
            .font(AppTypography.heroTitle)
            .foregroundColor(.starlight)
    }

    func sectionTitleStyle() -> some View {
        self
            .font(AppTypography.sectionTitle)
            .foregroundColor(.starlight)
    }

    func cardTitleStyle() -> some View {
        self
            .font(AppTypography.cardTitle)
            .foregroundColor(.starlight)
    }

    func bodyStyle() -> some View {
        self
            .font(AppTypography.body)
            .foregroundColor(.cloud)
    }

    func captionStyle() -> some View {
        self
            .font(AppTypography.caption)
            .foregroundColor(.cloud.opacity(0.7))
    }
}
