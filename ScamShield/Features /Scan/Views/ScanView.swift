import SwiftUI
import UIKit

/// Main scan screen - MVP version
struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isTextFieldFocused: Bool
    @State private var showSettings = false

    // Clipboard tracking - persist across launches to avoid repeat prompting
    @AppStorage("pasteboardLastHandledChangeCount") private var lastHandledChangeCount: Int = 0
    @AppStorage("pasteboardLastDismissedChangeCount") private var lastDismissedChangeCount: Int = 0
    @State private var showClipboardBanner = false
    @State private var clipboardBannerState: ClipboardBannerState = .ready

    private enum ClipboardBannerState {
        case ready
        case scanning
        case error
    }

    var body: some View {
        NavigationStack {
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
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.cloud)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onAppear {
            viewModel.checkContactsPermission()
            handleSharedContent()
            checkClipboardAvailability()
        }
        .onChange(of: appState.sharedText) { newText in
            if newText != nil {
                handleSharedContent()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkClipboardAvailability()
            }
        }
        .onChange(of: viewModel.scanState) { newState in
            // Re-check clipboard when returning to idle (after "Scan Another")
            if case .idle = newState {
                checkClipboardAvailability()
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        AppGradients.nocturneUpper
            .ignoresSafeArea()
    }

    // MARK: - Scan Input View

    private var scanInputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Clipboard Banner (shown above header when available)
                if showClipboardBanner {
                    clipboardBannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Header
                headerSection

                // Message Input
                messageInputSection

                // Scan Button
                scanButtonSection

                // Trust Indicators
                trustIndicators
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    // MARK: - Clipboard Banner (Primary CTA for elderly users)

    private var clipboardBannerView: some View {
        VStack(spacing: 12) {
            // Main scan button - state-dependent content
            Button {
                scanFromClipboard()
            } label: {
                HStack(spacing: 12) {
                    switch clipboardBannerState {
                    case .ready:
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 24))
                        Text("Scan Message I Copied")
                            .font(.system(size: 18, weight: .semibold))

                    case .scanning:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .midnight))
                        Text("Scanning...")
                            .font(.system(size: 18, weight: .semibold))

                    case .error:
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 24))
                        Text("Try Again")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(clipboardBannerState == .error ? Color.verdictWarning : Color.sunrise)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(clipboardBannerState == .scanning)

            // State-dependent helper text
            switch clipboardBannerState {
            case .ready:
                Text("Tip: In Messages, press and hold → Copy")
                    .font(.system(size: 13))
                    .foregroundColor(.cloud.opacity(0.6))

            case .scanning:
                Text("Reading your copied message...")
                    .font(.system(size: 13))
                    .foregroundColor(.cloud.opacity(0.6))

            case .error:
                Text("Couldn't read the copied text. Please copy again.")
                    .font(.system(size: 13))
                    .foregroundColor(.verdictWarning.opacity(0.8))
            }

            // Dismiss option (small, secondary) - hidden during scanning
            if clipboardBannerState != .scanning {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        lastDismissedChangeCount = UIPasteboard.general.changeCount
                        showClipboardBanner = false
                        clipboardBannerState = .ready
                    }
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 14))
                        .foregroundColor(.cloud.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke((clipboardBannerState == .error ? Color.verdictWarning : Color.sunrise).opacity(0.4), lineWidth: 1)
                )
        )
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
                    .onChange(of: viewModel.messageText) { newText in
                        // Auto-detect contacts when text is pasted
                        if !newText.isEmpty {
                            Task {
                                await viewModel.checkForKnownContact(messageText: newText)
                            }
                        }
                    }

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

    // MARK: - Handle Shared Content (from Share Extension)

    private func handleSharedContent() {
        guard let text = appState.sharedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Populate text field
        viewModel.prePopulate(with: String(text.prefix(8000)), senderPhone: nil)

        // Clear app state
        let shouldAutoScan = appState.shouldAutoScan
        appState.sharedText = nil
        appState.shouldAutoScan = false

        // Hide clipboard banner since we have content
        showClipboardBanner = false

        // Auto-scan only for share extension (not clipboard)
        if shouldAutoScan {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // Brief delay for UI
                await viewModel.startScan()
            }
        }
    }

    // MARK: - Clipboard Detection (NO read on launch, just availability check)

    private func checkClipboardAvailability() {
        // Don't check if we're not in idle state or already have text
        guard case .idle = viewModel.scanState,
              viewModel.messageText.isEmpty else {
            showClipboardBanner = false
            return
        }

        // Non-invasive check: does pasteboard have strings? (doesn't read content)
        guard UIPasteboard.general.hasStrings else {
            showClipboardBanner = false
            return
        }

        // Check change count to avoid repeat prompts
        let currentChangeCount = UIPasteboard.general.changeCount
        if currentChangeCount == lastHandledChangeCount ||
           currentChangeCount == lastDismissedChangeCount {
            showClipboardBanner = false
            return
        }

        // Show banner (without reading clipboard content yet)
        withAnimation(.easeOut(duration: 0.3)) {
            clipboardBannerState = .ready
            showClipboardBanner = true
        }
    }

    // MARK: - Scan from Clipboard (reads content only when user taps)

    private func scanFromClipboard() {
        // If in error state, user tapped "Try Again" - reset to ready first
        if clipboardBannerState == .error {
            withAnimation(.easeOut(duration: 0.15)) {
                clipboardBannerState = .ready
            }
            return
        }

        // Immediate visual feedback - show scanning state
        withAnimation(.easeOut(duration: 0.15)) {
            clipboardBannerState = .scanning
        }

        let pb = UIPasteboard.general
        lastHandledChangeCount = pb.changeCount

        // Debug logging
        print("[Clipboard] hasStrings: \(pb.hasStrings)")
        print("[Clipboard] changeCount: \(pb.changeCount)")
        print("[Clipboard] string: \(pb.string ?? "nil")")

        // Read clipboard content ONLY after user explicitly taps
        guard let text = pb.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[Clipboard] ERROR: Failed to read clipboard or empty content")
            // Show error state with friendly message
            withAnimation(.easeOut(duration: 0.2)) {
                clipboardBannerState = .error
            }
            return
        }

        print("[Clipboard] SUCCESS: Read \(text.count) characters")

        // Populate text field first
        viewModel.prePopulate(with: String(text.prefix(8000)), senderPhone: nil)

        // Hide banner to reveal the populated text field
        withAnimation {
            showClipboardBanner = false
            clipboardBannerState = .ready
        }

        // Give user 1.5 seconds to see their message before scanning
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await viewModel.startScan()
        }
    }
}

// MARK: - Preview

#Preview {
    ScanView()
        .environmentObject(AppState())
}
