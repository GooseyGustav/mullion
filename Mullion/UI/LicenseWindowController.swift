import AppKit

@MainActor
final class LicenseWindowController: NSWindowController, NSTextFieldDelegate {
    private let license: MullionLicense
    private let keyField = NSTextField(string: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let activateButton = NSButton(title: "Activate", target: nil, action: nil)
    private let deactivateButton = NSButton(title: "Deactivate this Mac", target: nil, action: nil)
    private let buyButton = NSButton(title: "Buy Mullion", target: nil, action: nil)
    private let recoverButton = NSButton(title: "Recover key", target: nil, action: nil)

    init(license: MullionLicense) {
        self.license = license
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mullion License"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let content = NSView()
        window.contentView = content

        let title = NSTextField(labelWithString: "Activate Mullion")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        keyField.placeholderString = "MULL-XXXXX-XXXXX-XXXXX-XXXXX"
        keyField.delegate = self
        keyField.lineBreakMode = .byClipping

        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.textColor = .secondaryLabelColor

        activateButton.target = self
        activateButton.action = #selector(activateTapped)
        activateButton.keyEquivalent = "\r"

        deactivateButton.target = self
        deactivateButton.action = #selector(deactivateTapped)
        deactivateButton.bezelStyle = .inline

        buyButton.target = self
        buyButton.action = #selector(buyTapped)
        buyButton.bezelStyle = .rounded

        recoverButton.target = self
        recoverButton.action = #selector(recoverTapped)
        recoverButton.bezelStyle = .inline

        let buttonRow = NSStackView(views: [activateButton, deactivateButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let linkRow = NSStackView(views: [buyButton, recoverButton])
        linkRow.orientation = .horizontal
        linkRow.spacing = 8

        let stack = NSStackView(views: [title, keyField, buttonRow, statusLabel, linkRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            keyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 380),
        ])

        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        refresh()
        window?.center()
        super.showWindow(sender)
    }

    func refresh() {
        switch license.entitlement {
        case .licensed:
            statusLabel.stringValue = "Mullion is active on this Mac."
            statusLabel.textColor = .secondaryLabelColor
            activateButton.isEnabled = false
            deactivateButton.isEnabled = true
        case .trial(let days):
            statusLabel.stringValue = "Trial: \(days) day\(days == 1 ? "" : "s") remaining. Enter a license key to activate."
            statusLabel.textColor = .secondaryLabelColor
            activateButton.isEnabled = true
            deactivateButton.isEnabled = true
        case .expired:
            statusLabel.stringValue = "Your 14-day trial has ended. Enter a license key to continue using Mullion."
            statusLabel.textColor = .systemOrange
            activateButton.isEnabled = true
            deactivateButton.isEnabled = false
        case .revoked:
            statusLabel.stringValue = "This license has been revoked. Enter a different key or contact support."
            statusLabel.textColor = .systemRed
            activateButton.isEnabled = true
            deactivateButton.isEnabled = false
        case .needsActivation(let msg):
            statusLabel.stringValue = msg ?? "Enter a license key to activate Mullion."
            statusLabel.textColor = .systemOrange
            activateButton.isEnabled = true
            deactivateButton.isEnabled = true
        }
        if let err = license.lastError, !err.isEmpty, case .licensed = license.entitlement {} else if let err = license.lastError, !err.isEmpty {
            statusLabel.stringValue = err
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func activateTapped() {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        statusLabel.stringValue = "Activating…"
        statusLabel.textColor = .secondaryLabelColor
        activateButton.isEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.license.activate(key: key)
            self.activateButton.isEnabled = true
            self.refresh()
            NotificationCenter.default.post(name: .mullionEntitlementChanged, object: nil)
        }
    }

    @objc private func deactivateTapped() {
        statusLabel.stringValue = "Deactivating…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.license.deactivate()
            self.refresh()
            NotificationCenter.default.post(name: .mullionEntitlementChanged, object: nil)
        }
    }

    @objc private func buyTapped() {
        if let url = URL(string: "https://asifthatworks.com/mullion") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func recoverTapped() {
        if let url = URL(string: "https://asifthatworks.com/mullion/activate") {
            NSWorkspace.shared.open(url)
        }
    }
}
