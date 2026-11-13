import AppKit

/// The switcher state machine: idle → visible → (commit | cancel) → idle.
///
/// Owns the panel, the item list, the selected index, and the thumbnail request.
/// Input arrives through `handleGlobal(_:)`, driven by the app-wide `EventTap`, so
/// the overlay never needs to become the active application.
final class SwitcherController {
    private enum Action {
        case cycle(Int)
        case commit
        case cancel
        case close
        case minimize
    }

    private let inventory: WindowInventory
    private let thumbnails: ThumbnailProvider
    private let panel = SwitcherPanel()
    private let content = SwitcherView()

    private var items: [WindowItem] = []
    private var selectedIndex = 0
    private var flagsMonitor: Any?

    /// Set when the session tap could not be created (no Accessibility). The panel
    /// then has to take key focus and Option-release is used instead of Command.
    var usesPanelFallback = false

    var isVisible: Bool { panel.isVisible }

    init(inventory: WindowInventory,
         thumbnails: ThumbnailProvider = ScreenCaptureThumbnailProvider()) {
        self.inventory = inventory
        self.thumbnails = thumbnails
        panel.contentView = content
        panel.onKeyDown = { [weak self] event in
            self?.handle(event) ?? false
        }
        content.onClose = { [weak self] id in
            self?.closeWindow(id: id)
        }
        content.onMinimize = { [weak self] id in
            self?.minimizeWindow(id: id)
        }
        content.onZoom = { [weak self] id in
            self?.zoomWindow(id: id)
        }
    }

    // MARK: - Global input

    /// Every key event in the session passes through here while Mullion runs.
    ///
    /// Returns `true` to swallow the event. Swallowing ⌘⇥ is what replaces the
    /// native app switcher: the event never reaches the Dock, so there is no system
    /// setting to disable and no conflict between the two switchers.
    func handleGlobal(_ event: EventTap.Event) -> Bool {
        if isVisible {
            return handleVisible(event)
        }
        guard case .keyDown(let code, let flags) = event,
              code == 48, // Tab
              flags.contains(.maskCommand) else {
            return false
        }
        DispatchQueue.main.async { [weak self] in self?.show() }
        return true
    }

    private func handleVisible(_ event: EventTap.Event) -> Bool {
        switch event {
        case .flagsChanged(let flags):
            // Command is the switcher modifier: releasing it commits.
            if !flags.contains(.maskCommand) {
                DispatchQueue.main.async { [weak self] in self?.commit() }
            }
            return false
        case .keyDown(let code, let flags):
            guard let action = action(for: code,
                                      shift: flags.contains(.maskShift),
                                      command: flags.contains(.maskCommand)) else {
                return false
            }
            DispatchQueue.main.async { [weak self] in self?.perform(action) }
            return true
        }
    }

    // MARK: - Lifecycle

    func show() {
        let started = Date()
        let snapshot = inventory.windows()
        let inventoryMS = Date().timeIntervalSince(started) * 1000
        guard !snapshot.isEmpty else { return }

        items = snapshot
        // Start on the second item: the first is the window the user is already in.
        selectedIndex = snapshot.count > 1 ? 1 : 0

        content.render(snapshot, selected: selectedIndex)
        let size = SwitcherView.size(for: snapshot)
        panel.setContentSize(size)
        panel.setFrameOrigin(origin(for: size))

        // Paint the previous presentation's frames before any capture work starts.
        content.applyThumbnails(thumbnails.cached(snapshot.map(\.id)))

        if usesPanelFallback {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            installFlagsMonitor()
        } else {
            panel.orderFrontRegardless()
        }

        AppLog.write(String(format: "show windows=%d inventory=%.0f ms fallback=%@",
                            snapshot.count, inventoryMS,
                            usesPanelFallback ? "true" : "false"))
        captureThumbnails(for: snapshot)
    }

    func cycle(by delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
        content.updateSelection(selectedIndex)
    }

    func commit() {
        guard panel.isVisible, items.indices.contains(selectedIndex) else { return }
        let chosen = items[selectedIndex]
        dismiss()
        WindowActivator.activate(chosen)
    }

    func cancel() {
        dismiss()
    }

    private func dismiss() {
        removeFlagsMonitor()
        panel.orderOut(nil)
        items = []
    }

    /// Captures in two waves: the cells the user can see first, then the rest.
    /// Re-opening within the provider's freshness window captures nothing at all.
    private func captureThumbnails(for snapshot: [WindowItem]) {
        let width = Theme.thumbnailWidth * Theme.thumbnailCaptureScale
        let firstWave = Array(snapshot.prefix(Theme.maximumColumns * 2))
        let secondWave = Array(snapshot.dropFirst(firstWave.count))

        Task { @MainActor [thumbnails, content] in
            content.applyThumbnails(await thumbnails.capture(firstWave, maximumWidth: width))
            guard self.panel.isVisible, !secondWave.isEmpty else { return }
            content.applyThumbnails(await thumbnails.capture(secondWave, maximumWidth: width))
        }
    }

    // MARK: - Key mapping

    /// Fallback path only: the panel is key and receives key events directly.
    private func handle(_ event: NSEvent) -> Bool {
        guard let action = action(for: event.keyCode,
                                  shift: event.modifierFlags.contains(.shift),
                                  command: event.modifierFlags.contains(.command)) else {
            return false
        }
        perform(action)
        return true
    }

    private func action(for code: UInt16, shift: Bool, command: Bool) -> Action? {
        switch code {
        case 13 where command: // ⌘W
            return .close
        case 46 where command: // ⌘M
            return .minimize
        case 48: // Tab
            return .cycle(shift ? -1 : 1)
        case 36, 76: // Return / Enter
            return .commit
        case 53: // Escape
            return .cancel
        case 123: // Left
            return .cycle(-1)
        case 124: // Right
            return .cycle(1)
        case 125: // Down
            return .cycle(min(Theme.maximumColumns, items.count))
        case 126: // Up
            return .cycle(-min(Theme.maximumColumns, items.count))
        default:
            return nil
        }
    }

    private func perform(_ action: Action) {
        switch action {
        case .cycle(let delta): cycle(by: delta)
        case .commit: commit()
        case .cancel: cancel()
        case .close: closeSelected()
        case .minimize: minimizeSelected()
        }
    }

    // MARK: - Closing, minimizing, zooming

    private func closeSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        closeWindow(id: items[selectedIndex].id)
    }

    private func minimizeSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        minimizeWindow(id: items[selectedIndex].id)
    }

    /// Closes a window and removes its tile. The panel stays open so several windows
    /// can be closed in a row.
    private func closeWindow(id: CGWindowID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let closed = WindowCloser.close(item)
        AppLog.write("close window id=\(id) ok=\(closed)")
        if closed { removeTile(id: id) }
    }

    /// Minimizes a window and removes its tile. Like close, the panel stays open: the
    /// action is about clearing windows out of the way, not leaving the switcher.
    private func minimizeWindow(id: CGWindowID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let minimized = WindowCloser.minimize(item)
        AppLog.write("minimize window id=\(id) ok=\(minimized)")
        if minimized { removeTile(id: id) }
    }

    /// Zooms the window and switches to it. Unlike close/minimize, the result is only
    /// visible if the panel gets out of the way, so this one commits the selection.
    private func zoomWindow(id: CGWindowID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let zoomed = WindowCloser.zoom(item)
        AppLog.write("zoom window id=\(id) ok=\(zoomed)")
        dismiss()
        WindowActivator.activate(item)
    }

    private func removeTile(id: CGWindowID) {
        items.removeAll { $0.id == id }
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, items.count - 1)
        content.render(items, selected: selectedIndex)
        let size = SwitcherView.size(for: items)
        panel.setContentSize(size)
        panel.setFrameOrigin(origin(for: size))
        content.applyThumbnails(thumbnails.cached(items.map(\.id)))
    }

    /// Fallback only: commits when the user lets go of Option.
    private func installFlagsMonitor() {
        removeFlagsMonitor()
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            if !event.modifierFlags.contains(.option) {
                self.commit()
            }
            return event
        }
    }

    private func removeFlagsMonitor() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    // MARK: - Placement

    /// The screen containing the mouse pointer.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    /// Centres the panel on the screen containing the mouse pointer.
    private func origin(for size: NSSize) -> NSPoint {
        guard let visible = activeScreen()?.visibleFrame else { return .zero }
        return NSPoint(x: visible.midX - size.width / 2,
                       y: visible.midY - size.height / 2)
    }
}
