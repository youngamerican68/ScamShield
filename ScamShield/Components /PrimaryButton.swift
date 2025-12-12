import SwiftUI

/// Primary CTA button with sunrise-ember gradient
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                HapticManager.shared.primaryButtonTap()
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .midnight))
                        .scaleEffect(0.9)
                } else if let icon = icon {
                    Image(systemName: icon)
                }

                Text(title)
            }
            .font(AppTypography.buttonText)
            .foregroundColor(.midnight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isEnabled
                    ? AppGradients.sunriseToEmber
                    : LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(
                color: isEnabled ? Color.sunrise.opacity(0.4) : Color.clear,
                radius: 16,
                x: 0,
                y: 8
            )
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isEnabled ? 1.0 : 0.98)
        .animation(.spring(response: 0.3), value: isEnabled)
    }
}

/// Secondary/outline button style
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(AppTypography.buttonText)
            .foregroundColor(.cloud)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.glassBorder, lineWidth: 1)
            )
        }
    }
}

/// Small inline button
struct InlineButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = .sunrise,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(AppTypography.caption)
            }
            .foregroundColor(color)
        }
    }
}

// MARK: - Previews

#Preview("Buttons") {
    ZStack {
        AppGradients.nocturneUpper
            .ignoresSafeArea()

        VStack(spacing: 20) {
            PrimaryButton("Scan Now", icon: "magnifyingglass") {
                print("Tapped!")
            }

            PrimaryButton("Loading...", isLoading: true) {}

            PrimaryButton("Disabled", isEnabled: false) {}

            SecondaryButton("Check Another", icon: "arrow.clockwise") {
                print("Secondary tapped!")
            }

            InlineButton("Learn more", icon: "arrow.right") {
                print("Inline tapped!")
            }
        }
        .padding()
    }
}
