import AppKit
import CoreGraphics

/// Builds the glass panel and the grid of window cells, and reflects selection.
/// No window-list, capture, or activation logic lives here.
///
/// Composition, back to front:
///
///     NSVisualEffectView (.hudWindow, .behindWindow)   one blur for the whole panel
///     tint view                                        light scrim for contrast
///     sheen gradient                                   bright top edge, fading out
///     foot gradient                                    dark bottom edge, fading up
///     NSStackView grid                                 translucent gradient cells
final class SwitcherView: NSView {
    private let blur = NSVisualEffectView()
    private let tint = NSView()
    private let grid = NSStackView()
    private var cells: [WindowCellView] = []
    private var cellsByID: [CGWindowID: WindowCellView] = [:]

    /// Called when a tile's close, minimize, or zoom control is clicked.
    var onClose: ((CGWindowID) -> Void)?
    var onMinimize: ((CGWindowID) -> Void)?
    var onZoom: ((CGWindowID) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = Theme.cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = Theme.panelBorder.cgColor

        blur.material = Theme.panelMaterial
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        tint.wantsLayer = true
        tint.layer?.backgroundColor = Theme.panelTint.cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tint)

        let sheen = GradientView(colors: Theme.sheenColors, locations: Theme.sheenLocations)
        sheen.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheen)

        let foot = GradientView(colors: Theme.footColors, locations: Theme.footLocations)
        foot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(foot)

        grid.orientation = .vertical
        grid.alignment = .centerX
        grid.spacing = Theme.gap
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)

        for view in [blur, tint, sheen, foot] {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: topAnchor, constant: Theme.padding),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.padding),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.padding),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.padding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Rebuilds the grid from scratch. Cheap enough for a switcher (tens of cells).
    func render(_ items: [WindowItem], selected: Int) {
        for view in grid.arrangedSubviews {
            grid.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        cells = []
        cellsByID = [:]

        let columns = Self.columns(for: items.count)
        var index = 0
        while index < items.count {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = Theme.gap

            for _ in 0..<columns where index < items.count {
                let item = items[index]
                let cell = WindowCellView(item: item)
                cell.onClose = { [weak self] in self?.onClose?(cell.windowID) }
                cell.onMinimize = { [weak self] in self?.onMinimize?(cell.windowID) }
                cell.onZoom = { [weak self] in self?.onZoom?(cell.windowID) }
                cells.append(cell)
                cellsByID[item.id] = cell
                row.addArrangedSubview(cell)
                index += 1
            }
            grid.addArrangedSubview(row)
        }
        updateSelection(selected)
    }

    func updateSelection(_ selected: Int) {
        for (index, cell) in cells.enumerated() {
            cell.isSelected = index == selected
        }
    }

    /// Applies thumbnails as they arrive. Cells for windows that disappeared are
    /// simply ignored, so a capture finishing after dismissal is harmless.
    func applyThumbnails(_ images: [CGWindowID: CGImage]) {
        for (id, image) in images {
            cellsByID[id]?.setThumbnail(image)
        }
    }

    /// Column count for `count` windows.
    ///
    /// Four is the maximum, but the last row should not be a lonely tile: five
    /// windows lay out as 3+2 rather than 4+1, six as 3+3, seven as 4+3. Ties go to
    /// the wider option so the panel stays short.
    static func columns(for count: Int) -> Int {
        guard count > 1 else { return 1 }
        let limit = min(Theme.maximumColumns, count)
        guard limit > 1 else { return 1 }

        var best = limit
        var bestWaste = Int.max
        for candidate in 2...limit {
            let rows = (count + candidate - 1) / candidate
            guard rows <= 3 else { continue }
            let waste = rows * candidate - count
            if waste < bestWaste || (waste == bestWaste && candidate > best) {
                best = candidate
                bestWaste = waste
            }
        }
        return best
    }

    /// Panel size. Uniform cells mean this is a plain rows × columns calculation, so
    /// the panel can be sized before it is shown — no visible resize on first display.
    static func size(for items: [WindowItem]) -> NSSize {
        let columns = columns(for: items.count)
        let rows = max(1, (items.count + columns - 1) / columns)
        let width = CGFloat(columns) * Theme.cellWidth
            + CGFloat(columns - 1) * Theme.gap
            + Theme.padding * 2
        let height = CGFloat(rows) * WindowCellView.height
            + CGFloat(rows - 1) * Theme.gap
            + Theme.padding * 2
        return NSSize(width: width, height: height)
    }
}
