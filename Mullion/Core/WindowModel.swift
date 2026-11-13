import AppKit

/// A single switchable window, as the UI needs it.
///
/// `id` is the CoreGraphics window number (`CGWindowID`), which is stable for the
/// lifetime of the window and is what lets us correlate the on-screen ordering from
/// `CGWindowList` with the Accessibility element used for activation.
struct WindowItem: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    /// Window title from the Accessibility API. Falls back to the app name when an
    /// app does not expose one (some Electron/Java apps, or windows still loading).
    let title: String
    let bounds: CGRect
    let isMinimized: Bool
    let icon: NSImage?

    /// Text shown under the icon. Keeps the cell from collapsing when a title is empty.
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appName : title
    }
}

extension WindowItem: Hashable {
    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
