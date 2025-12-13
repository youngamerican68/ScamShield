import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    // MARK: - UI Elements

    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let openButton = UIButton(type: .system)
    private let iconImageView = UIImageView()

    // MARK: - Properties

    private var payloadID: String?
    private var didAttemptOpen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.016, green: 0.031, blue: 0.071, alpha: 1.0) // midnight
        configureUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAttemptOpen else { return }
        didAttemptOpen = true
        startFlow()
    }

    // MARK: - UI Configuration

    private func configureUI() {
        // Shield icon
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        iconImageView.image = UIImage(systemName: "shield.fill", withConfiguration: config)
        iconImageView.tintColor = UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1.0) // sunrise
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Status label
        statusLabel.text = "Preparing scan..."
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 17, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Spinner
        spinner.color = UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1.0)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        // Open button (hidden initially)
        openButton.setTitle("Open Scam Shield", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        openButton.setTitleColor(.black, for: .normal)
        openButton.backgroundColor = UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1.0)
        openButton.layer.cornerRadius = 12
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(openButtonTapped), for: .touchUpInside)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        view.addSubview(iconImageView)
        view.addSubview(spinner)
        view.addSubview(statusLabel)
        view.addSubview(openButton)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),

            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            openButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            openButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 200),
            openButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Main Flow

    private func startFlow() {
        extractSharedText { [weak self] text in
            guard let self else { return }

            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.statusLabel.text = "No text found to scan."
                self.spinner.stopAnimating()
                self.showOpenFallback()
                return
            }

            // Validate and trim text (max 8000 chars)
            let trimmed = String(text.prefix(8000))
            let id = UUID().uuidString
            self.payloadID = id

            // Create and save payload
            let payload = SharePayload(
                id: id,
                text: trimmed,
                createdAt: Date(),
                source: .shareExtension
            )
            ShareStore.save(payload)

            // Try to open main app
            self.tryOpenMainApp(id: id)
        }

        // Timeout fallback (don't leave user stuck)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            if self.openButton.isHidden {
                self.showOpenFallback()
            }
        }
    }

    // MARK: - Open Main App

    private func tryOpenMainApp(id: String) {
        guard let url = URL(string: "scamshield://scan?id=\(id)") else {
            spinner.stopAnimating()
            showOpenFallback()
            return
        }

        statusLabel.text = "Opening Scam Shield..."

        extensionContext?.open(url, completionHandler: { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }

                if success {
                    // Give the system a moment, then dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.extensionContext?.completeRequest(returningItems: nil)
                    }
                } else {
                    self.spinner.stopAnimating()
                    self.showOpenFallback()
                }
            }
        })
    }

    // MARK: - Fallback UI

    private func showOpenFallback() {
        statusLabel.text = "Tap to open Scam Shield"
        spinner.stopAnimating()
        openButton.isHidden = false
    }

    @objc private func openButtonTapped() {
        guard let id = payloadID else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        // Try again
        spinner.startAnimating()
        openButton.isHidden = true
        tryOpenMainApp(id: id)
    }

    // MARK: - Extract Shared Text

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        // Prefer plain text
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    completion(item as? String)
                }
            }
            return
        }

        // Fallback: URL -> string
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        completion(url.absoluteString)
                    } else {
                        completion(nil)
                    }
                }
            }
            return
        }

        completion(nil)
    }
}

// MARK: - Share Payload (embedded for extension)

enum ShareSource: String, Codable {
    case shareExtension
    case clipboard
}

struct SharePayload: Codable {
    let id: String
    let text: String
    let createdAt: Date
    let source: ShareSource
}

enum ShareStore {
    static let appGroupID = "group.com.scamshield.shared"
    static let payloadsKey = "sharePayloadsById"

    static func save(_ payload: SharePayload) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var dict = (defaults.dictionary(forKey: payloadsKey) as? [String: Data]) ?? [:]

        if let data = try? JSONEncoder().encode(payload) {
            dict[payload.id] = data
            defaults.set(dict, forKey: payloadsKey)
            defaults.synchronize()
        }
    }
}
