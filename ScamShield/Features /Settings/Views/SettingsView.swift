import SwiftUI

/// Settings view with SMS Protection setup
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()

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

                    // SMS Protection Card
                    smsProtectionCard

                    // Trusted Contacts Card
                    trustedContactsCard

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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Settings")
                .font(AppTypography.sectionTitle)
                .foregroundColor(.starlight)

            Text("Configure SMS protection")
                .font(AppTypography.body)
                .foregroundColor(.cloud)
        }
        .padding(.top, 8)
    }

    // MARK: - SMS Protection Card

    private var smsProtectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack {
                    Image(systemName: "message.badge.shield.fill")
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
