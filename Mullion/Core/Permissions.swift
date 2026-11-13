import AppKit
import CoreGraphics

/// Accessibility is required for window titles and raising a window.
/// Screen Recording is required only for thumbnails; without it the switcher still
/// works and shows app icons instead.
enum Permissions {
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to add Mullion under
    /// System Settings ▸ Privacy & Security ▸ Accessibility.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system prompt. Returns the current state; the user may still need to
    /// toggle the switch in System Settings.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
