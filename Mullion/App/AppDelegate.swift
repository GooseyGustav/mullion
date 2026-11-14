import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit
import Sparkle

/// Composition root: owns the long-lived objects and wires them together.
///
/// Layering (see docs/ARCHITECTURE.md):
///
///     EventTap (⌘⇥, always on) ──▶ SwitcherController ──▶ WindowInventory ──▶ Accessibility
///                                             │          └──▶ ThumbnailProvider ──▶ ScreenCaptureKit
///                                             ▼
///                                       SwitcherPanel ──▶ WindowActivator
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var accessibilityItem: NSMenuItem?
    private var screenRecordingItem: NSMenuItem?
    private var licenseItem: NSMenuItem?
    private var licenseWindowController: LicenseWindowController?
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true,
                                                                 updaterDelegate: nil,
                                                                 userDriverDelegate: nil)

    private let license = MullionLicense.shared
    private let inventory = AccessibilityWindowInventory()
    private lazy var switcher = SwitcherController(inventory: inventory)
    private lazy var eventTap = EventTap { [weak self] event in
        self?.handleGlobal(event) ?? false
    }
    /// Only used when the session tap cannot be created (no Accessibility).
    private let fallbackHotkey = HotkeyMonitor(keyCode: HotkeyMonitor.KeyCode.tab,
                                               modifiers: HotkeyMonitor.Modifier.option)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("launch bundle=\(Bundle.main.bundlePath)")
        AppLog.write(AppLog.permissionSnapshot("startup"))

        installURLHandler()
        installStatusItem()
        // Closes over the controller, so start the tap after both exist.
        _ = switcher

        if eventTap.start() {
            AppLog.write("hotkey: command-tab via session tap")
        } else {
            // Without Accessibility the tap is refused; fall back to ⌥⇥ + panel keys.
            switcher.usesPanelFallback = true
            fallbackHotkey.onPressed = { [weak self] in
                guard let self else { return }
                if self.switcher.isVisible {
                    self.switcher.cycle(by: 1)
                } else {
                    self.requestShowSwitcher()
                }
            }
            fallbackHotkey.register()
            AppLog.write("hotkey: option-tab fallback (no Accessibility)")
        }

        if !Permissions.hasAccessibility {
            Permissions.requestAccessibility()
        }
        if !Permissions.hasScreenRecording {
            Permissions.requestScreenRecording()
        }
        refreshPermissionItems()
        AppLog.write(AppLog.permissionSnapshot("after-requests"))

        license.refreshInBackground()

        // An app only appears in the Screen Recording pane after it actually tries to
        // capture. Probe once at launch so the entry is registered even if the user
        // never opens the switcher first.
        probeScreenCapture()

        // Warm the Accessibility pipeline off the main thread. The first AX snapshot
        // after launch costs ~200 ms of framework setup; every later one is ~10 ms.
        // Paying that at launch means the first ⌘⇥ is as fast as the twentieth.
        DispatchQueue.global(qos: .utility).async { [inventory] in
            let started = Date()
            let count = inventory.windows().count
            AppLog.write(String(format: "inventory prewarm windows=%d ms=%.0f", count,
                                Date().timeIntervalSince(started) * 1000))
        }

        NotificationCenter.default.addObserver(forName: .mullionShowLicenseWindow, object: nil, queue: .main) { [weak self] _ in
            self?.showLicenseWindow()
        }
        NotificationCenter.default.addObserver(forName: .mullionEntitlementChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refreshPermissionItems()
        }
    }

    /// Gates global switcher activation on entitlement, but forwards events to the
    /// live switcher when it is already visible so commit/cycle/close still work.
    private func handleGlobal(_ event: EventTap.Event) -> Bool {
        if switcher.isVisible {
            return switcher.handleGlobal(event)
        }
        guard case .keyDown(let code, let flags) = event,
              code == 48, flags.contains(.maskCommand) else { return false }
        DispatchQueue.main.async { [weak self] in self?.requestShowSwitcher() }
        return true
    }

    private func requestShowSwitcher() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.license.reevaluate()
            if self.license.entitlement.canUseSwitcher {
                self.switcher.show()
            } else {
                self.showLicenseWindow()
            }
        }
    }

    /// Asks ScreenCaptureKit for the shareable content list. The call itself is the
    /// thing that triggers the TCC prompt and registers Mullion in the pane.
    ///
    /// The app is activated first: macOS is far more willing to show a screen
    /// recording prompt for an app the user is currently interacting with, and a
    /// background agent can otherwise get an immediate implicit denial.
    private func probeScreenCapture() {
        if !Permissions.hasScreenRecording {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                  onScreenWindowsOnly: true)
                AppLog.write("screen probe ok windows=\(content.windows.count)")
            } catch {
                AppLog.write("screen probe failed: \(error.localizedDescription)")
                _ = Permissions.requestScreenRecording()
            }
            await MainActor.run {
                self.refreshPermissionItems()
                if Permissions.hasScreenRecording {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermissionItems()
        AppLog.write(AppLog.permissionSnapshot("did-become-active"))
        if Permissions.hasScreenRecording {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTap.stop()
        fallbackHotkey.unregister()
    }

    // MARK: - URL / license

    private func installURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc @MainActor private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        license.handle(url: url)
        showLicenseWindow()
    }

    @MainActor func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            license.handle(url: url)
        }
        if !urls.isEmpty { showLicenseWindow() }
    }

    @objc private func showLicenseWindow() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.license.reevaluate()
            if self.licenseWindowController == nil {
                self.licenseWindowController = LicenseWindowController(license: self.license)
            }
            self.licenseWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.refreshPermissionItems()
        }
    }

    // MARK: - Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle",
                                     accessibilityDescription: "Mullion")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Switcher  (⌘⇥)",
                     action: #selector(showSwitcher),
                     keyEquivalent: "")
        menu.addItem(.separator())

        licenseItem = menu.addItem(withTitle: "License…",
                                   action: #selector(openLicense),
                                   keyEquivalent: "")
        menu.addItem(.separator())

        accessibilityItem = menu.addItem(withTitle: "Accessibility",
                                         action: #selector(openAccessibilitySettings),
                                         keyEquivalent: "")
        screenRecordingItem = menu.addItem(withTitle: "Screen Recording",
                                           action: #selector(openScreenRecordingSettings),
                                           keyEquivalent: "")

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mullion",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        item.menu = menu
        statusItem = item
        refreshPermissionItems()
    }

    @objc private func showSwitcher() {
        requestShowSwitcher()
    }

    @objc private func openLicense() {
        showLicenseWindow()
    }

    @objc private func openAccessibilitySettings() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        probeScreenCapture()
        Permissions.openScreenRecordingSettings()
    }

    @MainActor private func refreshPermissionItems() {
        accessibilityItem?.title = Permissions.hasAccessibility
            ? "Accessibility: granted"
            : "Accessibility: needed — click to open Settings…"
        screenRecordingItem?.title = Permissions.hasScreenRecording
            ? "Screen Recording: granted"
            : "Screen Recording: needed — click to open Settings…"
        switch license.entitlement {
        case .licensed:
            licenseItem?.title = "License: Active"
        case .trial(let days):
            licenseItem?.title = "License: Trial (\(days)d left)…"
        case .expired:
            licenseItem?.title = "License: Trial ended — Activate…"
        case .revoked:
            licenseItem?.title = "License: Revoked — Activate…"
        case .needsActivation(let msg):
            licenseItem?.title = msg ?? "License: Activate…"
        }
    }
}
