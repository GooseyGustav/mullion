import Carbon.HIToolbox
import Foundation

/// Registers a single global hotkey using the Carbon Hot Key API.
///
/// Why Carbon and not `NSEvent.addGlobalMonitorForEvents`: a global monitor only
/// *observes* keys, so ⌥⇥ would still be delivered to the frontmost app. A Carbon
/// hot key consumes the combination, which is what a switcher needs.
///
/// Limitation in 0.1: one hotkey only (⌥⇥ forward). Shift-reverse and user-defined
/// shortcuts are a later milestone; arrows already work inside the overlay.
final class HotkeyMonitor {
    enum KeyCode {
        static let tab = UInt32(kVK_Tab)
    }

    enum Modifier {
        static let option = UInt32(optionKey)
    }

    var onPressed: (() -> Void)?

    private let keyCode: UInt32
    private let modifiers: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    deinit { unregister() }

    func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            { _, event, userData in
                                guard let userData, let event else { return noErr }
                                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                                return monitor.handle(event)
                            },
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x50464C48), id: 1) // 'PFLH'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        onPressed?()
        return noErr
    }
}
