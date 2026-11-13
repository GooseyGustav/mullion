import AppKit

/// Borderless, floating panel that hosts the switcher grid.
///
/// It is a `.nonactivatingPanel` so it does not steal the target app's activation
/// state, but it still overrides `canBecomeKey` because it must receive Tab,
/// arrow, Return and Escape while visible.
final class SwitcherPanel: NSPanel {
    /// Returns `true` when the controller handled the key.
    var onKeyDown: ((NSEvent) -> Bool)?

    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isMovable = false
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}
