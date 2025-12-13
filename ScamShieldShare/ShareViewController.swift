import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let iconImageView = UIImageView()

    // MARK: - Properties
    private var sharedText: String = ""
    private let appGroupID = "group.com.scamshield.shared"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedText()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Dark background with blur
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        // Container card
        containerView.backgroundColor = UIColor(red: 0.016, green: 0.031, blue: 0.071, alpha: 0.95)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Shield icon
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        iconImageView.image = UIImage(systemName: "shield.fill", withConfiguration: config)
        iconImageView.tintColor = UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1.0) // sunrise color
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)

        // Title
        titleLabel.text = "Scam Shield"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Preview label
        previewLabel.text = "Loading..."
        previewLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        previewLabel.textColor = UIColor(red: 0.77, green: 0.83, blue: 0.88, alpha: 1.0) // cloud color
        previewLabel.textAlignment = .center
        previewLabel.numberOfLines = 3
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(previewLabel)

        // Scan button
        scanButton.setTitle("Scan for Scams", for: .normal)
        scanButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        scanButton.setTitleColor(.black, for: .normal)
        scanButton.backgroundColor = UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1.0)
        scanButton.layer.cornerRadius = 12
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        containerView.addSubview(scanButton)

        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.setTitleColor(UIColor(red: 0.77, green: 0.83, blue: 0.88, alpha: 1.0), for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            previewLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            scanButton.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 24),
            scanButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            scanButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            scanButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Extract Shared Text
    private func extractSharedText() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments else {
            previewLabel.text = "No text found"
            return
        }

        for provider in itemProviders {
            // Check for plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            self?.sharedText = text
                            self?.updatePreview(text)
                        }
                    }
                }
                return
            }

            // Check for URL (which may contain text)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.sharedText = url.absoluteString
                            self?.updatePreview(url.absoluteString)
                        }
                    }
                }
                return
            }
        }

        previewLabel.text = "No text found to scan"
    }

    private func updatePreview(_ text: String) {
        let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
        previewLabel.text = "\"\(preview)\""
    }

    // MARK: - Actions
    @objc private func scanTapped() {
        guard !sharedText.isEmpty else {
            showError("No text to scan")
            return
        }

        // Save text to App Group UserDefaults
        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            userDefaults.set(sharedText, forKey: "pendingScanText")
            userDefaults.set(Date(), forKey: "pendingScanTimestamp")
            userDefaults.synchronize()
        }

        // Open main app via URL scheme
        let url = URL(string: "scamshield://scan")!

        // Use responder chain to open URL
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }

        // Alternative method using openURL selector
        let selector = sel_registerName("openURL:")
        var currentResponder: UIResponder? = self
        while currentResponder != nil {
            if currentResponder!.responds(to: selector) {
                currentResponder!.perform(selector, with: url)
                break
            }
            currentResponder = currentResponder?.next
        }

        // Complete the extension
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ScamShieldShare", code: 0, userInfo: nil))
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ScamShieldShare", code: 1, userInfo: nil))
        })
        present(alert, animated: true)
    }
}
