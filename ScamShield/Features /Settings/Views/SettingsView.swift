import SwiftUI

/// Settings view with SMS Protection setup
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage("highContrastEnabled") private var highContrastEnabled = false

    var body: some View {
        ZStack {
            // Background
            AppGradients.nocturneUpper
                .ignoresSafeArea()

            StarFieldView(starCount: 20)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Email Scanning Card (Primary feature for elderly)
                    emailScanningCard

                    // SMS Protection Card
                    smsProtectionCard

                    // Trusted Contacts Card
                    trustedContactsCard

                    // Accessibility Section
                    accessibilitySection

                    // About Section
                    aboutSection
                }
                .padding()
            }
        }
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
        .onAppear {
            viewModel.checkSMSFilterStatus()
            viewModel.loadTrustedContacts()
            viewModel.checkScamShieldContactStatus()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Settings")
                .font(AppTypography.sectionTitle)
                .foregroundColor(.starlight)

            Text("Set up email and SMS protection")
                .font(AppTypography.body)
                .foregroundColor(.cloud)
        }
        .padding(.top, 8)
    }

    // MARK: - Email Scanning Card

    private var emailScanningCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.title2)
                        .foregroundStyle(AppGradients.sunriseToEmber)

                    Text("Email Scanning")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)

                    Spacer()

                    // Status indicator
                    emailStatusBadge
                }

                // Description
                Text("Forward suspicious emails to check them instantly. Results appear in your scan history.")
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)

                // Success message
                if viewModel.showContactSaveSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.verdictSafe)
                        Text("Contact saved! Type \"Scam\" when forwarding emails.")
                            .font(AppTypography.caption)
                            .foregroundColor(.verdictSafe)
                    }
                    .padding(.vertical, 8)
                    .transition(.opacity)
                }

                // Error message
                if let error = viewModel.contactSaveError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.verdictDanger)
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(.verdictDanger)
                    }
                    .padding(.vertical, 8)
                }

                // Main action - Save to Contacts or Already Saved
                if viewModel.isScamShieldContactSaved {
                    // Already saved - show success state
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.verdictSafe)
                            Text("\"Scam Shield\" saved to Contacts")
                                .font(AppTypography.body)
                                .foregroundColor(.verdictSafe)
                        }

                        Text("To scan an email: tap Forward, type \"Scam\", and send to Scam Shield.")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.8))
                    }
                } else {
                    // Not saved - show big save button
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .background(Color.glassBorder)

                        Text("Step 1: Save to Contacts")
                            .font(AppTypography.body.bold())
                            .foregroundColor(.starlight)

                        Text("This lets you easily forward emails by typing \"Scam\" in the To: field.")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.8))

                        Button {
                            Task {
                                await viewModel.saveScamShieldContact()
                            }
                        } label: {
                            HStack {
                                if viewModel.isSavingContact {
                                    ProgressView()
                                        .tint(.midnight)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                }
                                Text(viewModel.isSavingContact ? "Saving..." : "Save \"Scam Shield\" to Contacts")
                            }
                            .font(AppTypography.body.bold())
                            .foregroundColor(.midnight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppGradients.sunriseToEmber)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isSavingContact)
                    }
                }

                // Copy address option (secondary)
                Divider()
                    .background(Color.glassBorder)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your scan address:")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.7))
                        Text(viewModel.emailScanAddress)
                            .font(AppTypography.caption.monospaced())
                            .foregroundColor(.sunrise)
                    }

                    Spacer()

                    Button {
                        viewModel.copyEmailAddress()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.sunrise)
                            .padding(8)
                            .background(Color.glassWhite)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var emailStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isScamShieldContactSaved ? Color.verdictSafe : Color.sunrise)
                .frame(width: 8, height: 8)

            Text(viewModel.isScamShieldContactSaved ? "Ready" : "Set Up")
                .font(AppTypography.caption)
                .foregroundColor(viewModel.isScamShieldContactSaved ? .verdictSafe : .sunrise)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.glassWhite)
        )
    }

    // MARK: - SMS Protection Card

    private var smsProtectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundStyle(AppGradients.sunriseToEmber)

                    Text("SMS Protection")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)

                    Spacer()

                    // Status indicator
                    statusBadge
                }

                // Description
                Text("Automatically filter suspicious SMS messages from unknown senders. Messages from your contacts are always allowed.")
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)

                // Setup instructions
                if !viewModel.isSMSFilterEnabled {
                    setupInstructions
                }
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isSMSFilterEnabled ? Color.verdictSafe : Color.cloud.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(viewModel.isSMSFilterEnabled ? "Active" : "Not Set Up")
                .font(AppTypography.caption)
                .foregroundColor(viewModel.isSMSFilterEnabled ? .verdictSafe : .cloud.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.glassWhite)
        )
    }

    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.glassBorder)

            Text("How to Enable")
                .font(AppTypography.body.bold())
                .foregroundColor(.starlight)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Open iPhone Settings")
                instructionRow(number: 2, text: "Tap Messages")
                instructionRow(number: 3, text: "Tap Unknown & Spam")
                instructionRow(number: 4, text: "Enable Scam Shield")
            }

            Button {
                viewModel.openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(AppTypography.body)
                .foregroundColor(.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppGradients.sunriseToEmber)
                .cornerRadius(12)
            }
            .padding(.top, 4)
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(AppTypography.caption.bold())
                .foregroundColor(.midnight)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.sunrise)
                )

            Text(text)
                .font(AppTypography.body)
                .foregroundColor(.cloud)
        }
    }

    // MARK: - Trusted Contacts Card

    private var trustedContactsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(AppGradients.sunriseToEmber)

                    Text("Trusted Contacts")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)

                    Spacer()

                    Text("\(viewModel.trustedContactCount)")
                        .font(AppTypography.body.bold())
                        .foregroundColor(.sunrise)
                }

                // Description
                Text("Messages from these contacts will always be allowed through the SMS filter.")
                    .font(AppTypography.body)
                    .foregroundColor(.cloud)

                // Sync status
                if viewModel.contactsPermissionGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.verdictSafe)
                        Text("Synced from your Contacts")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud.opacity(0.7))
                    }

                    // Sync button
                    Button {
                        Task {
                            await viewModel.syncTrustedContacts()
                        }
                    } label: {
                        HStack {
                            if viewModel.isSyncing {
                                ProgressView()
                                    .tint(.cloud)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(viewModel.isSyncing ? "Syncing..." : "Sync Now")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(.starlight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.glassWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.glassBorder, lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.isSyncing)
                } else {
                    // Permission needed
                    Button {
                        Task {
                            await viewModel.requestContactsPermission()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Grant Contacts Access")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(.midnight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppGradients.sunriseToEmber)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack {
                    Image(systemName: "eye")
                        .font(.title2)
                        .foregroundStyle(AppGradients.sunriseToEmber)

                    Text("Accessibility")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                // High Contrast Toggle
                Toggle(isOn: $highContrastEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("High Contrast Mode")
                            .font(AppTypography.body)
                            .foregroundColor(.starlight)
                        Text("Makes text easier to read")
                            .font(AppTypography.caption)
                            .foregroundColor(.cloud)
                    }
                }
                .tint(.sunrise)

                // Info about system settings
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.cloud.opacity(0.5))
                    Text("iOS Accessibility settings are also respected")
                        .font(AppTypography.caption)
                        .foregroundColor(.cloud.opacity(0.7))
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundColor(.sunrise)

                    Text("About SMS Filtering")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.starlight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    bulletPoint("Works for SMS/MMS from unknown senders only")
                    bulletPoint("iMessages are not filtered (Apple restriction)")
                    bulletPoint("Filtered messages go to Junk folder, not deleted")
                    bulletPoint("You can always view filtered messages in Messages app")
                }
            }
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.sunrise)
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(.cloud.opacity(0.8))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
