import SwiftUI

/// Individual star data
struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat      // 0-1 normalized position
    let y: CGFloat      // 0-1 normalized position
    let size: CGFloat   // 1-3 points
    let delay: Double   // Animation delay
    let duration: Double // Animation duration
}

/// Animated twinkling star field background
/// Replicates the star effect from the web app's Hero section
struct StarFieldView: View {
    let starCount: Int
    @State private var stars: [Star] = []

    init(starCount: Int = 50) {
        self.starCount = starCount
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(stars) { star in
                StarView(star: star)
                    .position(
                        x: star.x * geometry.size.width,
                        y: star.y * geometry.size.height
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        stars = (0..<starCount).map { _ in
            Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...0.6), // Only in top 60%
                size: randomStarSize(),
                delay: Double.random(in: 0...5),
                duration: Double.random(in: 2...5)
            )
        }
    }

    private func randomStarSize() -> CGFloat {
        let rand = Double.random(in: 0...1)
        if rand > 0.7 {
            return 3 // Large (30%)
        } else if rand > 0.4 {
            return 2 // Medium (30%)
        } else {
            return 1 // Small (40%)
        }
    }
}

/// Individual animated star
struct StarView: View {
    let star: Star
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: star.size, height: star.size)
            .shadow(color: .white.opacity(glowOpacity), radius: star.size * 2)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: star.duration)
                    .repeatForever(autoreverses: true)
                    .delay(star.delay)
                ) {
                    opacity = 1.0
                }
            }
    }

    private var glowOpacity: Double {
        switch star.size {
        case 1: return 0.3
        case 2: return 0.5
        default: return 0.7
        }
    }
}

// MARK: - Preview

#Preview("Star Field") {
    ZStack {
        AppGradients.nocturneFullVertical
            .ignoresSafeArea()

        StarFieldView(starCount: 50)
            .ignoresSafeArea()

        Text("Scam Shield")
            .font(AppTypography.heroTitle)
            .foregroundColor(.starlight)
    }
}
