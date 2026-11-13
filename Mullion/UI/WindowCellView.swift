import AppKit

/// One window in the switcher grid.
///
/// Layout mirrors a real window: a header row with the app icon and the window title,
/// then the preview, aspect-fit inside a uniform preview box. Nothing is cropped and
/// the preview has no frame — the tile around it is the only surface.
///
/// Hovering replaces the app icon with miniature traffic lights (close, minimize,
/// zoom) in exactly the same slot, so the title never shifts.
final class WindowCellView: NSView {
    let windowID: CGWindowID

    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?
    var onZoom: (() -> Void)?

    private let fill: GradientView
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let trafficLights = TrafficLightsView()
    private let thumbnailWell = NSView()
    private let thumbnailView = NSImageView()
    private let placeholderIcon = NSImageView()
    private var isHovered = false

    var isSelected: Bool = false {
        didSet { applySelection() }
    }

    // MARK: - Geometry

    /// Height of every tile. Uniform tiles are what make the grid read as a grid.
    static var height: CGFloat {
        Theme.cellPadding * 2 + Theme.headerHeight + Theme.headerGap + Theme.thumbnailHeight
    }

    // MARK: - Init

    init(item: WindowItem) {
        self.windowID = item.id
        self.fill = GradientView(colors: Theme.cellFillColors)
        super.init(frame: NSRect(x: 0, y: 0, width: Theme.cellWidth,
                                 height: Self.height))

        wantsLayer = true
        layer?.cornerRadius = Theme.cellCornerRadius
        layer?.borderWidth = 0

        fill.layer?.cornerRadius = Theme.cellCornerRadius
        fill.layer?.masksToBounds = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)

        let sheen = GradientView(colors: Theme.cellSheenColors,
                                 locations: Theme.cellSheenLocations)
        sheen.layer?.cornerRadius = Theme.cellCornerRadius
        sheen.layer?.masksToBounds = true
        sheen.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheen)

        // Header: app icon immediately left of the title.
        iconView.image = item.icon ?? NSImage(systemSymbolName: "macwindow",
                                               accessibilityDescription: item.appName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.stringValue = item.displayTitle
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = Theme.titleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        trafficLights.onClose = { [weak self] in self?.onClose?() }
        trafficLights.onMinimize = { [weak self] in self?.onMinimize?() }
        trafficLights.onZoom = { [weak self] in self?.onZoom?() }
        trafficLights.alphaValue = 0
        trafficLights.isHidden = true
        trafficLights.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trafficLights)

        // Preview: no frame, no border, rounded corners only.
        thumbnailWell.wantsLayer = true
        thumbnailWell.layer?.cornerRadius = Theme.thumbnailCornerRadius
        thumbnailWell.layer?.masksToBounds = true
        thumbnailWell.layer?.backgroundColor = Theme.thumbnailWell.cgColor
        thumbnailWell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thumbnailWell)

        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = Theme.thumbnailCornerRadius
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailWell.addSubview(thumbnailView)

        placeholderIcon.image = item.icon ?? NSImage(systemSymbolName: "macwindow",
                                                     accessibilityDescription: nil)
        placeholderIcon.imageScaling = .scaleProportionallyUpOrDown
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        thumbnailWell.addSubview(placeholderIcon)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Theme.cellWidth),
            heightAnchor.constraint(equalToConstant: Self.height),

            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: trailingAnchor),

            sheen.topAnchor.constraint(equalTo: topAnchor),
            sheen.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheen.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheen.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.cellPadding),
            iconView.centerYAnchor.constraint(equalTo: topAnchor, constant: Theme.cellPadding + Theme.headerHeight / 2),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Theme.cellPadding),

            trafficLights.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.cellPadding),
            trafficLights.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            trafficLights.widthAnchor.constraint(equalToConstant: TrafficLightsView.width),
            trafficLights.heightAnchor.constraint(equalToConstant: TrafficLightsView.height),

            thumbnailWell.topAnchor.constraint(equalTo: topAnchor,
                                                constant: Theme.cellPadding + Theme.headerHeight + Theme.headerGap),
            thumbnailWell.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.cellPadding),
            thumbnailWell.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.cellPadding),
            thumbnailWell.heightAnchor.constraint(equalToConstant: Theme.thumbnailHeight),
            thumbnailWell.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Theme.cellPadding),

            thumbnailView.topAnchor.constraint(equalTo: thumbnailWell.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbnailWell.bottomAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: thumbnailWell.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: thumbnailWell.trailingAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: thumbnailWell.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: thumbnailWell.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 40),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self,
                                       userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }

    /// Fades the icon out and the traffic lights in, in the same slot. The completion
    /// guard matters: re-entering during the fade must not hide the controls.
    private func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        if hovered { trafficLights.isHidden = false }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.allowsImplicitAnimation = true
            iconView.animator().alphaValue = hovered ? 0 : 1
            trafficLights.animator().alphaValue = hovered ? 1 : 0
        } completionHandler: { [weak self] in
            guard let self, !self.isHovered else { return }
            self.trafficLights.isHidden = true
        }
    }

    /// Called when a capture completes. The placeholder disappears and the well loses
    /// its tint so the preview sits directly on the glass.
    func setThumbnail(_ image: CGImage?) {
        guard let image else { return }
        thumbnailView.image = NSImage(cgImage: image, size: .zero)
        placeholderIcon.isHidden = true
        thumbnailWell.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func applySelection() {
        guard let layer else { return }
        fill.colors = isSelected ? Theme.cellFillSelectedColors : Theme.cellFillColors

        if isSelected {
            layer.borderWidth = 2
            layer.borderColor = Theme.cellBorderSelected.cgColor
            layer.shadowColor = Theme.selectionShadowColor.cgColor
            layer.shadowRadius = Theme.selectionShadowRadius
            layer.shadowOpacity = Theme.selectionShadowOpacity
            layer.shadowOffset = CGSize(width: 0, height: -3)
        } else {
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        }
    }
}
