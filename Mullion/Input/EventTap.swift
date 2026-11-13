import AppKit
import CoreGraphics

/// Session-level keyboard tap used while the switcher is visible.
///
/// Why not `NSEvent` monitors: they only see events delivered to this app, so the
/// overlay works only if Mullion is the active application and the panel is the
/// key window. A switcher must not depend on that — it should leave focus where it
/// is and still receive Tab, arrows, Return, Escape and the Option release.
///
/// Requires Accessibility permission. If the tap cannot be created, the controller
/// falls back to the panel's local key handling.
final class EventTap {
    enum Event {
        case keyDown(code: UInt16, flags: CGEventFlags)
        case flagsChanged(flags: CGEventFlags)
    }

    /// Return `true` to swallow the event, `false` to let it through.
    private let handler: (Event) -> Bool
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(handler: @escaping (Event) -> Bool) {
        self.handler = handler
    }

    deinit { stop() }

    var isRunning: Bool { tap != nil }

    /// Returns `false` when Accessibility permission is missing or the tap is refused.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, userInfo in
                                              guard let userInfo else {
                                                  return Unmanaged.passUnretained(event)
                                              }
                                              let eventTap = Unmanaged<EventTap>
                                                  .fromOpaque(userInfo)
                                                  .takeUnretainedValue()
                                              return eventTap.process(type: type, event: event)
                                          },
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            AppLog.write("EventTap: creation failed (no Accessibility?)")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLog.write("EventTap: started")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.tap = nil
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.source = nil
        }
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap that takes too long; re-enable instead of dying.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            // Never swallow modifier changes: another app may be tracking them.
            _ = handler(.flagsChanged(flags: event.flags))
            return Unmanaged.passUnretained(event)
        }

        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let handled = handler(.keyDown(code: code, flags: event.flags))
        return handled ? nil : Unmanaged.passUnretained(event)
    }
}
