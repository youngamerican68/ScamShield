import SwiftUI

/// The Scam Shield owl mascot with different moods
struct MascotView: View {
    enum Mood: String, CaseIterable {
        case idle = "owl-idle"
        case defaultPose = "owl-default"
        case scanning = "owl-scanning"
        case safe = "owl-safe"
        case warning = "owl-warning"
        case danger = "owl-danger"

        /// Get mood from ScamVerdict
        static func from(verdict: ScamVerdict) -> Mood {
            switch verdict {
            case .highScam:
                return .danger
            case .suspicious:
                return .warning
            case .noObviousScam:
                return .safe
            }
        }
    }

    let mood: Mood
    var size: CGFloat = 120
    var animate: Bool = true

    @State private var isAnimating = false

    var body: some View {
        Image(mood.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(isAnimating && animate ? 1.05 : 1.0)
            .animation(
                animate ? Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true) : nil,
                value: isAnimating
            )
            .onAppear {
                if animate {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Convenience Initializers

extension MascotView {
    /// Create mascot from a verdict
    init(verdict: ScamVerdict, size: CGFloat = 120, animate: Bool = true) {
        self.mood = Mood.from(verdict: verdict)
        self.size = size
        self.animate = animate
    }
}

// MARK: - Preview

#Preview("All Moods") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(MascotView.Mood.allCases, id: \.self) { mood in
                VStack {
                    MascotView(mood: mood, size: 100)
                    Text(mood.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color.midnight)
}

#Preview("Verdict Moods") {
    HStack(spacing: 24) {
        VStack {
            MascotView(verdict: .noObviousScam)
            Text("Safe")
        }
        VStack {
            MascotView(verdict: .suspicious)
            Text("Warning")
        }
        VStack {
            MascotView(verdict: .highScam)
            Text("Danger")
        }
    }
    .padding()
    .background(Color.midnight)
}
