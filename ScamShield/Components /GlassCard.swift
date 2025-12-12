import SwiftUI

/// Glassmorphism card component
/// Replicates the glass effect from the web app
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Blur effect (ultraThinMaterial for dark mode)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // White overlay (8% opacity)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.glassWhite)

                    // Border (15% white)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.glassBorder, lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
}

/// Dark variant of GlassCard
struct GlassDarkCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.glassDark)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

/// Gold-tinted glass card (for badges, highlights)
struct GlassGoldCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        cornerRadius: CGFloat = 999, // Pill shape by default
        padding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, padding)
            .padding(.vertical, padding / 2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.sunrise.opacity(0.1))

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.sunrise.opacity(0.25), lineWidth: 1)
                }
            )
            .shadow(color: Color.sunrise.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Previews

#Preview("Glass Cards") {
    ZStack {
        AppGradients.nocturneUpper
            .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Glass Card")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                    Text("Standard glassmorphism effect")
                        .font(AppTypography.body)
                        .foregroundColor(.cloud)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassDarkCard {
                Text("Dark Glass Card")
                    .foregroundColor(.cloud)
            }

            GlassGoldCard {
                HStack {
                    Image(systemName: "sparkles")
                    Text("GOLD BADGE")
                }
                .font(AppTypography.badge)
                .foregroundColor(.sunrise)
            }
        }
        .padding()
    }
}
