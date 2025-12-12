import SwiftUI

/// Results display view
struct ResultsView: View {
    let result: ScamCheckResult
    let onScanAnother: () -> Void

    @State private var isAnimated = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Verdict Card
                verdictCard
                    .modifier(StaggeredFadeIn(index: 0, isAnimated: isAnimated))

                // Warning Banner (if applicable)
                if let warning = result.verdict.warningMessage {
                    warningBanner(warning)
                        .modifier(StaggeredFadeIn(index: 1, isAnimated: isAnimated))
                }

                // Summary
                summarySection
                    .modifier(StaggeredFadeIn(index: 2, isAnimated: isAnimated))

                // Tactics (if any)
                if !result.tactics.isEmpty {
                    tacticsSection
                        .modifier(StaggeredFadeIn(index: 3, isAnimated: isAnimated))
                }

                // Safe Steps
                safeStepsSection
                    .modifier(StaggeredFadeIn(index: 4, isAnimated: isAnimated))

                // Actions
                actionsSection
                    .modifier(StaggeredFadeIn(index: 5, isAnimated: isAnimated))
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimated = true
            }
        }
    }

    // MARK: - Verdict Card

    private var verdictCard: some View {
        HStack(spacing: 16) {
            // Left color bar
            Rectangle()
                .fill(result.verdict.color)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 8) {
                // Icon + Title
                HStack(spacing: 12) {
                    Image(systemName: result.verdict.icon)
                        .font(.system(size: 36))
                        .foregroundColor(result.verdict.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.verdict.shortTitle)
                            .font(AppTypography.verdictTitle)
                            .foregroundColor(.starlight)

                        Text("Confidence: \(result.confidencePercent)")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.7))
                    }
                }

                // Full title
                Text(result.verdict.title)
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)
            }
            .padding(.vertical, 16)

            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.verdict.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(result.verdict.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Warning Banner

    private func warningBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.verdict == .highScam ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                .font(.title2)

            Text(message)
                .font(AppTypography.body)
        }
        .foregroundColor(result.verdict == .highScam ? .white : .midnight)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.verdict.color)
        )
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Summary", systemImage: "doc.text")
                    .font(AppTypography.caption)
                    .foregroundColor(.sunrise)

                Text(result.summary)
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tactics Section

    private var tacticsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("How they might be trying to trick you", systemImage: "eye.trianglebadge.exclamationmark")
                    .font(AppTypography.caption)
                    .foregroundColor(.verdictWarning)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.tactics, id: \.self) { tactic in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.verdictWarning)
                            Text(tactic)
                                .font(AppTypography.body)
                                .foregroundColor(.cloud)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Safe Steps Section

    private var safeStepsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Safe next steps", systemImage: "checkmark.shield")
                    .font(AppTypography.caption)
                    .foregroundColor(.verdictSafe)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(result.safeSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            // Number badge
                            Text("\(index + 1)")
                                .font(AppTypography.caption)
                                .foregroundColor(.midnight)
                                .frame(width: 24, height: 24)
                                .background(Color.verdictSafe)
                                .clipShape(Circle())

                            Text(step)
                                .font(AppTypography.body)
                                .foregroundColor(.cloud)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            PrimaryButton("Scan Another Message", icon: "arrow.clockwise") {
                onScanAnother()
            }

            // Future: Share button
            // SecondaryButton("Share Result", icon: "square.and.arrow.up") { }
        }
        .padding(.top, 8)
    }
}

// MARK: - Staggered Animation Modifier

struct StaggeredFadeIn: ViewModifier {
    let index: Int
    let isAnimated: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isAnimated ? 1 : 0)
            .offset(y: isAnimated ? 0 : 30)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(Double(index) * 0.1),
                value: isAnimated
            )
    }
}

// MARK: - Preview

#Preview("Danger Result") {
    ZStack {
        AppGradients.nocturneUpper
            .ignoresSafeArea()

        ResultsView(result: ScamCheckAPI.mockDangerResult) { }
    }
}

#Preview("Safe Result") {
    ZStack {
        AppGradients.nocturneUpper
            .ignoresSafeArea()

        ResultsView(result: ScamCheckAPI.mockSafeResult) { }
    }
}
