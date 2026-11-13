import AppKit

/// The three miniature titlebar controls shown when a tile is hovered.
///
/// Drawn as one view instead of three buttons so the cluster can occupy exactly the
/// app-icon slot: 6 pt dots with 3 pt gaps make 24 pt, the same width as the icon
/// plus its title gap. The title therefore never shifts when the controls appear.
///
/// Colours and left-to-right order follow a real macOS titlebar:
/// red = close, yellow = minimize, green = zoom.
final class TrafficLightsView: NSView, NSViewToolTipOwner {
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?
    var onZoom: (() -> Void)?

    static let diameter: CGFloat = 6
    static let spacing: CGFloat = 3
    static let width: CGFloat = diameter * 3 + spacing * 2
    static let height: CGFloat = 18

    private var hoveredIndex: Int?
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addToolTip(bounds, owner: self, userData: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: Self.width, height: Self.height) }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved,
                                            .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let index = index(at: convert(event.locationInWindow, from: nil))
        guard index != hoveredIndex else { return }
        hoveredIndex = index
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        guard hoveredIndex != nil else { return }
        hoveredIndex = nil
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Actions

    override func mouseDown(with event: NSEvent) {
        switch index(at: convert(event.locationInWindow, from: nil)) {
        case 0: onClose?()
        case 1: onMinimize?()
        case 2: onZoom?()
        default: break
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let step = Self.diameter + Self.spacing
        for index in 0..<3 {
            let x = CGFloat(index) * step
            let y = (bounds.height - Self.diameter) / 2
            let rect = NSRect(x: x, y: y, width: Self.diameter, height: Self.diameter)

            let base = Theme.trafficColors[index]
            let color = hoveredIndex == index
                ? base.blended(withFraction: 0.22, of: .white) ?? base
                : base
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()

            NSColor.black.withAlphaComponent(0.18).setStroke()
            let outline = NSBezierPath(ovalIn: rect.insetBy(dx: 0.25, dy: 0.25))
            outline.lineWidth = 0.5
            outline.stroke()
        }
    }

    // MARK: - Tooltips

    func view(_ view: NSView,
              stringForToolTip tag: NSView.ToolTipTag,
              point: NSPoint,
              userData data: UnsafeMutableRawPointer?) -> String {
        switch index(at: point) {
        case 0: return "Close window"
        case 1: return "Minimize window"
        case 2: return "Zoom window"
        default: return ""
        }
    }

    /// Maps a point to the nearest dot. The view is narrow; snapping means the gaps
    /// between dots still hit a control instead of doing nothing.
    private func index(at point: NSPoint) -> Int? {
        guard bounds.contains(point) else { return nil }
        let step = Self.diameter + Self.spacing
        let centers = (0..<3).map { CGFloat($0) * step + Self.diameter / 2 }
        return centers.enumerated().min {
            abs($0.element - point.x) < abs($1.element - point.x)
        }?.offset
    }
}
