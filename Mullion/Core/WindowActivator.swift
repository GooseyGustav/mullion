import AppKit
import ApplicationServices

/// Raising a specific window needs both Accessibility (to target the window element)
/// and NSRunningApplication (to bring the owning app forward).
enum WindowActivator {
    static func activate(_ item: WindowItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }

        if let window = AXWindowLookup.window(for: item) {
            // Un-minimize before raising; otherwise the raise is a no-op for some apps.
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)

            let appElement = AXUIElementCreateApplication(item.pid)
            AXUIElementSetAttributeValue(appElement,
                                         kAXFocusedWindowAttribute as CFString,
                                         window)
        }

        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
