import AppKit

// Mullion is a menu-bar-only app (LSUIElement = true in Info.plist), so it has no
// Dock icon and no main window. All setup happens in AppDelegate.
let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
