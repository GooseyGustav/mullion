import AppKit
import ApplicationServices

/// Resolves the Accessibility element for a `WindowItem` by title and frame.
///
/// Kept separate from activation and closing so both use the same matching rules:
/// the list the user saw may be a few hundred milliseconds old, so the element is
/// re-queried rather than cached (elements can be invalidated by a window closing).
enum AXWindowLookup {
    static func window(for item: WindowItem) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(item.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return nil
        }

        var bestMatch: AXUIElement?
        var bestScore = CGFloat.greatestFiniteMagnitude

        for element in elements {
            guard let origin = point(element, kAXPositionAttribute),
                  let size = size(element, kAXSizeAttribute) else { continue }

            let frame = CGRect(origin: origin, size: size)
            let score = abs(frame.origin.x - item.bounds.origin.x)
                + abs(frame.origin.y - item.bounds.origin.y)
                + abs(frame.width - item.bounds.width)
                + abs(frame.height - item.bounds.height)

            let title = copy(element, kAXTitleAttribute) as? String ?? ""

            if title == item.title && score < bestScore {
                bestScore = score
                bestMatch = element
            } else if bestMatch == nil, score <= 2 {
                bestScore = score
                bestMatch = element
            }
        }
        return bestMatch
    }

    static func copy(_ element: AXUIElement, _ attribute: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let raw = copy(element, attribute), CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let raw = copy(element, attribute), CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
