import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit

/// Composition root: owns the long-lived objects and wires them together.
///
/// Layering (see docs/ARCHITECTURE.md):
///
///     EventTap (⌘⇥, always on) ──▶ SwitcherController ──▶ WindowInventory ──▶ Accessibility
///                                             │          └──▶ ThumbnailProvider ──▶ ScreenCaptureKit
///                                             ▼
///                                       SwitcherPanel ──▶ WindowActivator
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var accessibilityItem: NSMenuItem?
    private var screenRecordingItem: NSMenuItem?

    private let inventory = AccessibilityWindowInventory()
    private lazy var switcher = SwitcherController(inventory: inventory)
    private lazy var eventTap = EventTap { [weak self] event in
        self?.switcher.handleGlobal(event) ?? false
    }
    /// Only used when the session tap cannot be created (no Accessibility).
    private let fallbackHotkey = HotkeyMonitor(keyCode: HotkeyMonitor.KeyCode.tab,
                                               modifiers: HotkeyMonitor.Modifier.option)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("launch bundle=\(Bundle.main.bundlePath)")
        AppLog.write(AppLog.permissionSnapshot("startup"))

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
                    self.switcher.show()
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
    }

    @objc private func showSwitcher() {
        switcher.show()
    }

    @objc private func openAccessibilitySettings() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        probeScreenCapture()
        Permissions.openScreenRecordingSettings()
    }

    private func refreshPermissionItems() {
        accessibilityItem?.title = Permissions.hasAccessibility
            ? "Accessibility: granted"
            : "Accessibility: needed — click to open Settings…"
        screenRecordingItem?.title = Permissions.hasScreenRecording
            ? "Screen Recording: granted"
            : "Screen Recording: needed — click to open Settings…"
    }
}
