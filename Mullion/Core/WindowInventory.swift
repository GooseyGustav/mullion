import AppKit
import ApplicationServices

/// Source of the window list. A protocol so tests or future backends can be swapped
/// in without touching the UI.
protocol WindowInventory {
    /// Windows in front-to-back order, excluding Mullion itself.
    func windows() -> [WindowItem]
}

/// Default inventory: CoreGraphics for z-order and visibility, Accessibility for
/// titles and window identity.
///
/// Why both:
/// - `CGWindowListCopyWindowInfo` gives the authoritative front-to-back ordering and
///   the set of windows actually on screen, but `kCGWindowName` is withheld unless the
///   process has Screen Recording permission.
/// - The Accessibility API gives titles without that permission, but not z-order.
///
/// The two lists are correlated by app (pid) and window frame. AX is IPC, so the
/// per-app queries run concurrently: this is the slowest part of opening the
/// switcher, and serialising ~10 apps cost several hundred milliseconds.
final class AccessibilityWindowInventory: WindowInventory {
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func windows() -> [WindowItem] {
        let screens = onScreenWindows()
        guard !screens.isEmpty else { return [] }

        // Group the CG entries per app, preserving front-to-back order.
        var pidsInOrder: [pid_t] = []
        var screensByPID: [pid_t: [CGScreenWindow]] = [:]
        for window in screens {
            if screensByPID[window.pid] == nil { pidsInOrder.append(window.pid) }
            screensByPID[window.pid, default: []].append(window)
        }

        let axQueries = axWindows(for: pidsInOrder)

        var result: [WindowItem] = []
        for pid in pidsInOrder {
            guard let cgWindows = screensByPID[pid],
                  let app = NSRunningApplication(processIdentifier: pid) else { continue }

            switch axQueries[pid] {
            case .windows(let axWindows):
                // Each app's CG windows are matched at most once to an AX window.
                var used = Set<Int>()
                for cgWindow in cgWindows {
                    let match = match(cgWindow, among: axWindows, usedIndexes: &used)
                    result.append(cgWindow.item(
                        appName: app.localizedName ?? "Unknown",
                        title: match?.title ?? "",
                        icon: app.icon,
                        isMinimized: match?.isMinimized ?? false
                    ))
                }
            default:
                // App refuses Accessibility: still list its windows, title = app name.
                for cgWindow in cgWindows {
                    result.append(cgWindow.item(appName: app.localizedName ?? "Unknown",
                                                title: "",
                                                icon: app.icon))
                }
            }
        }
        return result
    }

    // MARK: - CoreGraphics

    private struct CGScreenWindow {
        let id: CGWindowID
        let pid: pid_t
        let bounds: CGRect

        func item(appName: String, title: String, icon: NSImage?, isMinimized: Bool = false) -> WindowItem {
            WindowItem(id: id, pid: pid, appName: appName, title: title,
                       bounds: bounds, isMinimized: isMinimized, icon: icon)
        }
    }

    private func onScreenWindows() -> [CGScreenWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return raw.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ownPID,
                  let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 80, bounds.height >= 60,
                  let alpha = entry[kCGWindowAlpha as String] as? Double, alpha > 0
            else { return nil }
            return CGScreenWindow(id: id, pid: pid, bounds: bounds)
        }
    }

    // MARK: - Accessibility

    private enum AXQuery {
        case windows([AXWindow])
        case unavailable
    }

    private struct AXWindow {
        let element: AXUIElement
        let title: String
        let bounds: CGRect
        let isMinimized: Bool
    }

    /// Queries every app in parallel. AX round-trips are the dominant cost of a
    /// snapshot, so this turns a serial ~300 ms into roughly the slowest single app.
    private func axWindows(for pids: [pid_t]) -> [pid_t: AXQuery] {
        var queries: [pid_t: AXQuery] = [:]
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: pids.count) { index in
            let pid = pids[index]
            let query: AXQuery
            if let windows = Self.axWindows(for: pid) {
                query = .windows(windows)
            } else {
                query = .unavailable
            }
            lock.lock()
            queries[pid] = query
            lock.unlock()
        }
        return queries
    }

    private static func axWindows(for pid: pid_t) -> [AXWindow]? {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return nil
        }

        // One IPC round-trip per window instead of five. `CopyMultipleAttributeValues`
        // returns `kCFNull` for attributes the window does not support, so the batch
        // is still usable when (for example) a window has no document path.
        let attributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXDocumentAttribute as CFString,
            kAXPositionAttribute as CFString,
            kAXSizeAttribute as CFString,
            kAXMinimizedAttribute as CFString,
        ]

        return elements.compactMap { element in
            var rawValues: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(element,
                                                         attributes as CFArray,
                                                         AXCopyMultipleAttributeOptions(rawValue: 0),
                                                         &rawValues) == .success,
                  let values = rawValues as? [Any], values.count == attributes.count else {
                return nil
            }

            let title = (values[0] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (values[1] as? String)
                ?? ""

            guard let origin = pointValue(values[2]),
                  let size = sizeValue(values[3]) else { return nil }
            let minimized = values[4] as? Bool ?? false

            return AXWindow(element: element,
                            title: title,
                            bounds: CGRect(origin: origin, size: size),
                            isMinimized: minimized)
        }
    }

    /// Finds the AX element that corresponds to a CG window by comparing frames.
    /// AX frames are in the same top-left-origin space as CG window bounds.
    private func match(_ window: CGScreenWindow, among candidates: [AXWindow], usedIndexes: inout Set<Int>) -> AXWindow? {
        for (index, candidate) in candidates.enumerated() where !usedIndexes.contains(index) {
            if abs(candidate.bounds.origin.x - window.bounds.origin.x) <= 2,
               abs(candidate.bounds.origin.y - window.bounds.origin.y) <= 2,
               abs(candidate.bounds.width - window.bounds.width) <= 2,
               abs(candidate.bounds.height - window.bounds.height) <= 2 {
                usedIndexes.insert(index)
                return candidate
            }
        }
        return nil
    }

    // MARK: - AX helpers

    private static func copy(_ element: AXUIElement, _ attribute: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func pointValue(_ raw: Any?) -> CGPoint? {
        guard let raw, CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    /// Decodes the `AXValue` boxed size returned by Accessibility.
    private static func sizeValue(_ raw: Any?) -> CGSize? {
        guard let raw, CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
