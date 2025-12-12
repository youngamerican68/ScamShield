import SwiftUI

/// Main scan screen - MVP version
struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @EnvironmentObject var appState: AppState
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            backgroundView

            // Content based on state
            Group {
                switch viewModel.scanState {
                case .idle:
                    scanInputView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .scanning(let phase):
                    ScanningView(phase: phase)
                        .transition(.opacity)

                case .complete(let result):
                    ResultsView(result: result, onScanAnother: viewModel.reset)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))

                case .error(let message):
                    errorView(message: message)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.scanState)
        }
        .onAppear {
            handleSharedContent()
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            AppGradients.nocturneUpper
                .ignoresSafeArea()

            StarFieldView(starCount: 30)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: - Scan Input View

    private var scanInputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Message Input
                messageInputSection

                // Context Selector
                contextSection

                // Known Contact Toggle
                knownContactSection

                // Scan Button
                scanButtonSection

                // Trust Indicators
                trustIndicators
            }
            .padding()
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Shield Icon
            Image(systemName: "shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppGradients.sunriseToEmber)
                .shadow(color: .sunrise.opacity(0.5), radius: 20)

            // Title
            Text("Scam Shield")
                .font(AppTypography.sectionTitle)
                .foregroundColor(.starlight)

            // Subtitle
            Text("Paste a suspicious message to scan")
                .font(AppTypography.body)
                .foregroundColor(.cloud)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Message Input

    private var messageInputSection: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $viewModel.messageText)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 120, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(AppTypography.body)
                    .foregroundColor(.starlight)
                    .padding()

                // Character count
                HStack {
                    Spacer()
                    Text("\(viewModel.characterCount)/8000")
                        .font(AppTypography.caption)
                        .foregroundColor(viewModel.isOverLimit ? .verdictDanger : .cloud.opacity(0.5))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .overlay(
            Group {
                if viewModel.messageText.isEmpty {
                    Text("Paste the suspicious text, email, or message here...")
                        .font(AppTypography.body)
                        .foregroundColor(.cloud.opacity(0.5))
                        .padding()
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            },
            alignment: .topLeading
        )
    }

    // MARK: - Context Selector

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who received this message?")
                .font(AppTypography.caption)
                .foregroundColor(.cloud.opacity(0.7))

            HStack(spacing: 8) {
                ForEach(ContextWhoFor.allCases, id: \.self) { context in
                    contextButton(for: context)
                }
            }
        }
    }

    private func contextButton(for context: ContextWhoFor) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            viewModel.contextWhoFor = context
        } label: {
            HStack(spacing: 6) {
                Image(systemName: context.icon)
                    .font(.caption)
                Text(context.displayName)
                    .font(AppTypography.caption)
            }
            .foregroundColor(viewModel.contextWhoFor == context ? .midnight : .cloud)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                viewModel.contextWhoFor == context
                    ? AppGradients.sunriseToEmber
                    : LinearGradient(colors: [Color.glassWhite], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        viewModel.contextWhoFor == context ? Color.clear : Color.glassBorder,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Known Contact Toggle

    private var knownContactSection: some View {
        GlassCard {
            Toggle(isOn: $viewModel.fromKnownContact) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundColor(.sunrise)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From a known contact")
                            .font(AppTypography.body)
                            .foregroundColor(.starlight)
                        Text("Saved in your phone or familiar sender")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.6))
                    }
                }
            }
            .tint(.sunrise)
            .onChange(of: viewModel.fromKnownContact) { _ in
                HapticManager.shared.selectionChanged()
            }
        }
    }

    // MARK: - Scan Button

    private var scanButtonSection: some View {
        PrimaryButton(
            "Scan Now",
            icon: "magnifyingglass",
            isEnabled: viewModel.canScan
        ) {
            Task {
                await viewModel.startScan()
            }
        }
    }

    // MARK: - Trust Indicators

    private var trustIndicators: some View {
        HStack(spacing: 24) {
            trustBadge(icon: "lock.fill", text: "Private")
            trustBadge(icon: "bolt.fill", text: "Instant")
            trustBadge(icon: "checkmark.seal.fill", text: "Free")
        }
        .padding(.top, 8)
    }

    private func trustBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.sunrise.opacity(0.7))
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(.cloud.opacity(0.7))
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.verdictWarning)

            Text("Something went wrong")
                .font(AppTypography.cardTitle)
                .foregroundColor(.starlight)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(.cloud)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PrimaryButton("Try Again", icon: "arrow.clockwise") {
                viewModel.scanState = .idle
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Handle Shared Content

    private func handleSharedContent() {
        if let text = appState.sharedText {
            viewModel.prePopulate(with: text)
            appState.sharedText = nil

            if appState.shouldAutoScan {
                appState.shouldAutoScan = false
                Task {
                    await viewModel.startScan()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScanView()
        .environmentObject(AppState())
}
