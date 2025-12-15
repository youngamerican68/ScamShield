import SwiftUI

/// Animated scanning state view
struct ScanningView: View {
    let phase: ScanPhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated Mascot with Pulse Rings
            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.sunrise.opacity(0.3), lineWidth: 2)
                        .frame(width: 140 + CGFloat(index * 50))
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - pulseScale)
                }

                // Scanning owl mascot
                MascotView(mood: .scanning, size: 140, animate: false)
                    .shadow(color: .sunrise.opacity(0.5), radius: 20)
            }
            .frame(height: 220)

            // Phase Text with Shimmer
            Text(phase.rawValue)
                .font(AppTypography.bodyLarge)
                .foregroundColor(.cloud)
                .overlay(
                    shimmerOverlay
                )
                .animation(.easeInOut(duration: 0.3), value: phase)

            // Progress Dots
            HStack(spacing: 12) {
                ForEach(Array(ScanPhase.allCases.enumerated()), id: \.element) { index, scanPhase in
                    Circle()
                        .fill(phaseIndex(phase) >= index ? Color.sunrise : Color.navy)
                        .frame(width: 10, height: 10)
                        .scaleEffect(scanPhase == phase ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3), value: phase)
                }
            }

            Spacer()

            // Tip
            VStack(spacing: 8) {
                Text("Analysis typically takes 5-15 seconds")
                    .font(AppTypography.caption)
                    .foregroundColor(.cloud.opacity(0.5))
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Shimmer Overlay

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.6), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 80)
        .offset(x: shimmerOffset)
        .mask(
            Text(phase.rawValue)
                .font(AppTypography.bodyLarge)
        )
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }

        // Shimmer animation
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 300
        }
    }

    // MARK: - Helpers

    private func phaseIndex(_ phase: ScanPhase) -> Int {
        ScanPhase.allCases.firstIndex(of: phase) ?? 0
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppGradients.nocturneUpper
            .ignoresSafeArea()

        StarFieldView(starCount: 30)
            .ignoresSafeArea()

        ScanningView(phase: .analyzing)
    }
}
