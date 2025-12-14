import SwiftUI

/// Displays the user's scan history
struct ScanHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ScanHistoryViewModel()
    @State private var selectedScan: ScanHistoryItem?

    var body: some View {
        ZStack {
            // Background
            AppGradients.nocturneUpper
                .ignoresSafeArea()

            StarFieldView(starCount: 15)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Content
            if viewModel.isLoading && viewModel.scans.isEmpty {
                loadingView
            } else if viewModel.showEmptyState {
                emptyStateView
            } else if let error = viewModel.errorMessage, viewModel.scans.isEmpty {
                errorView(error)
            } else {
                scanListView
            }
        }
        .navigationTitle("Scan History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.cloud)
                }
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .sheet(item: $selectedScan) { scan in
            ScanDetailView(scan: scan)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.sunrise)
                .scaleEffect(1.5)

            Text("Loading scan history...")
                .font(AppTypography.body)
                .foregroundColor(.cloud)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(AppGradients.sunriseToEmber)

            VStack(spacing: 8) {
                Text("No Scans Yet")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(.starlight)

                Text("Your scan history will appear here.\nForward a suspicious email or paste a message to get started.")
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Scan Something")
                    .font(AppTypography.body.bold())
                    .foregroundColor(.midnight)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppGradients.sunriseToEmber)
                    .cornerRadius(12)
            }
        }
        .padding(32)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.verdictWarning)

            VStack(spacing: 8) {
                Text("Couldn't Load History")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(.starlight)

                Text(error)
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(AppTypography.body.bold())
                .foregroundColor(.midnight)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(AppGradients.sunriseToEmber)
                .cornerRadius(12)
            }
        }
        .padding(32)
    }

    // MARK: - Scan List

    private var scanListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Header with count
                HStack {
                    Text("\(viewModel.total) scan\(viewModel.total == 1 ? "" : "s")")
                        .font(AppTypography.caption)
                        .foregroundColor(.cloud.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Scan items
                ForEach(viewModel.scans) { scan in
                    ScanHistoryRow(scan: scan)
                        .onTapGesture {
                            selectedScan = scan
                            HapticManager.shared.buttonTap()
                        }
                        .onAppear {
                            // Load more when reaching end
                            if scan.id == viewModel.scans.last?.id {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                }

                // Loading more indicator
                if viewModel.isLoading && !viewModel.scans.isEmpty {
                    ProgressView()
                        .tint(.sunrise)
                        .padding()
                }

                // Bottom padding
                Spacer()
                    .frame(height: 20)
            }
            .padding(.horizontal)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Scan History Row

struct ScanHistoryRow: View {
    let scan: ScanHistoryItem

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Verdict icon
                ZStack {
                    Circle()
                        .fill(scan.verdictEnum.backgroundColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: scan.verdictEnum.icon)
                        .font(.title3)
                        .foregroundColor(scan.verdictEnum.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Subject/preview
                    Text(scan.previewText)
                        .font(AppTypography.body)
                        .foregroundColor(.starlight)
                        .lineLimit(1)

                    // Meta info
                    HStack(spacing: 8) {
                        // Source
                        HStack(spacing: 4) {
                            Image(systemName: scan.source.icon)
                            Text(scan.source.displayName)
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(.cloud.opacity(0.7))

                        // Dot separator
                        Text("•")
                            .foregroundColor(.cloud.opacity(0.5))

                        // Date
                        Text(scan.formattedDate)
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.7))
                    }
                }

                Spacer()

                // Verdict badge
                Text(scan.verdictEnum.shortTitle)
                    .font(AppTypography.caption.bold())
                    .foregroundColor(scan.verdictEnum.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(scan.verdictEnum.backgroundColor)
                    )
            }
        }
    }
}

// MARK: - Scan Detail View

struct ScanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let scan: ScanHistoryItem

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradients.nocturneUpper
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Verdict header
                        verdictHeader

                        // Summary card
                        summaryCard

                        // Tactics card (if any)
                        if !scan.tactics.isEmpty {
                            tacticsCard
                        }

                        // Safe steps card (if any)
                        if !scan.safeSteps.isEmpty {
                            safeStepsCard
                        }

                        // Meta info
                        metaCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.cloud)
                    }
                }
            }
        }
    }

    private var verdictHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(scan.verdictEnum.backgroundColor)
                    .frame(width: 80, height: 80)

                Image(systemName: scan.verdictEnum.icon)
                    .font(.system(size: 36))
                    .foregroundColor(scan.verdictEnum.color)
            }

            Text(scan.verdictEnum.title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(scan.verdictEnum.color)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.sunrise)
                    Text("Summary")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                Text(scan.summary)
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)
            }
        }
    }

    private var tacticsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.verdictWarning)
                    Text("Red Flags Detected")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scan.tactics, id: \.self) { tactic in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.verdictWarning)
                            Text(tactic)
                                .font(AppTypography.body)
                                .foregroundColor(.cloud)
                        }
                    }
                }
            }
        }
    }

    private var safeStepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.verdictSafe)
                    Text("Recommended Actions")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(scan.safeSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(AppTypography.body.bold())
                                .foregroundColor(.sunrise)
                                .frame(width: 24, alignment: .leading)
                            Text(step)
                                .font(AppTypography.body)
                                .foregroundColor(.cloud)
                        }
                    }
                }
            }
        }
    }

    private var metaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.cloud.opacity(0.7))
                    Text("Details")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                VStack(spacing: 8) {
                    metaRow(label: "Source", value: scan.source.displayName, icon: scan.source.icon)
                    metaRow(label: "From Domain", value: scan.fromDomain.isEmpty ? "Unknown" : scan.fromDomain, icon: "globe")
                    metaRow(label: "Scanned", value: scan.formattedDate, icon: "clock")
                }
            }
        }
    }

    private func metaRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.cloud.opacity(0.5))
                .frame(width: 20)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(.cloud.opacity(0.7))
            Spacer()
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(.cloud)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScanHistoryView()
    }
}
