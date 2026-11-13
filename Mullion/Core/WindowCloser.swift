import AppKit
import ApplicationServices

/// Closes a window through its Accessibility close button.
///
/// This is the only reliable way to close a *specific* window: sending ⌘W to the app
/// would close whichever window it considers focused, which may not be the tile the
/// user clicked.
enum WindowCloser {
    @discardableResult
    static func close(_ item: WindowItem) -> Bool {
        guard let window = AXWindowLookup.window(for: item) else { return false }

        guard let raw = AXWindowLookup.copy(window, kAXCloseButtonAttribute),
              CFGetTypeID(raw as CFTypeRef) == AXUIElementGetTypeID() else {
            return false
        }
        let button = unsafeBitCast(raw as AnyObject, to: AXUIElement.self)
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    /// Minimizes without activating the app. Setting the minimized attribute is more
    /// widely supported than pressing a minimize button, and some apps expose the
    /// button only while focused.
    @discardableResult
    static func minimize(_ item: WindowItem) -> Bool {
        guard let window = AXWindowLookup.window(for: item) else { return false }
        return AXUIElementSetAttributeValue(window,
                                            kAXMinimizedAttribute as CFString,
                                            kCFBooleanTrue) == .success
    }

    /// Performs the green-button zoom. Apps that do not expose a zoom button return
    /// false; the caller then falls back to simply activating the window.
    @discardableResult
    static func zoom(_ item: WindowItem) -> Bool {
        guard let window = AXWindowLookup.window(for: item),
              let raw = AXWindowLookup.copy(window, kAXZoomButtonAttribute),
              CFGetTypeID(raw as CFTypeRef) == AXUIElementGetTypeID() else {
            return false
        }
        let button = unsafeBitCast(raw as AnyObject, to: AXUIElement.self)
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }
}
