import AppKit

/// Visual constants for the switcher overlay. Kept in one place so the layout math
/// in `SwitcherController`, `SwitcherView` and `WindowCellView` cannot drift apart.
///
/// Tile geometry mimics a real window: a header row with the app icon and the
/// window title, then the preview. Every preview uses the same 16:10 box; the window
/// image is aspect-fit inside it, so nothing is cropped. Odd aspect ratios show glass
/// at the edges, which is what keeps every tile in the grid the same size.
///
/// Glass is one behind-window blur for the panel; tiles are dark translucent
/// gradients with no border, so the blurred backdrop reads through them.
enum Theme {
    static let cellWidth: CGFloat = 288
    static let cellPadding: CGFloat = 10
    static let headerHeight: CGFloat = 22
    static let headerGap: CGFloat = 8
    static let gap: CGFloat = 10
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 20
    static let cellCornerRadius: CGFloat = 12
    static let thumbnailCornerRadius: CGFloat = 8

    /// Every preview is the same 16:10 box (the usual macOS window shape). Windows
    /// are aspect-fit inside it, never cropped and never resized to their own aspect —
    /// that is what keeps the grid proportional. A portrait window like Mail shows
    /// glass at the sides; a 21:9 window shows glass above and below. The alternative
    /// (sizing tiles to each window) makes one tile twice as tall as its neighbours.
    static let thumbnailHeight: CGFloat = 168
    static var thumbnailWidth: CGFloat { cellWidth - cellPadding * 2 }

    /// Capture resolution. 1× the tile width is soft on retina; 2× is sharp but the
    /// slowest option. 1.5× is the speed/sharpness balance: previews still look clean
    /// at normal viewing distance and captures finish noticeably sooner.
    static let thumbnailCaptureScale: CGFloat = 1.5

    /// Maximum cells per row before wrapping.
    static let maximumColumns = 4

    // MARK: - Glass

    /// `.hudWindow` is neutral and keeps the previews legible without tinting them.
    static let panelMaterial: NSVisualEffectView.Material = .hudWindow
    /// Light scrim only: the desktop behind the panel should stay visible.
    static let panelTint = NSColor(calibratedWhite: 0.03, alpha: 0.14)
    static let panelBorder = NSColor.white.withAlphaComponent(0.18)

    /// Specular sheen: a bright top edge fading out by ~30% height, which is what
    /// reads as "glass" rather than "dark rectangle".
    static let sheenColors = [NSColor.white.withAlphaComponent(0.15),
                              NSColor.white.withAlphaComponent(0.01)]
    static let sheenLocations: [NSNumber] = [0, 0.30]

    /// Slight darkening at the bottom edge to give the panel thickness.
    static let footColors = [NSColor.black.withAlphaComponent(0.14), .clear]
    static let footLocations: [NSNumber] = [0, 0.28]

    /// Dark translucent tiles over the blur: this is what makes them read as glass
    /// on both light and dark desktops. White fills turn grey over a light backdrop.
    static let cellFillColors = [NSColor(calibratedWhite: 0, alpha: 0.32),
                                 NSColor(calibratedWhite: 0, alpha: 0.14)]
    static let cellFillSelectedColors = [NSColor(calibratedWhite: 0, alpha: 0.44),
                                         NSColor(calibratedWhite: 0, alpha: 0.22)]

    /// A faint specular wash on each tile's top edge. Glass has a lit edge; without
    /// this the dark fills read as flat plastic.
    static let cellSheenColors = [NSColor.white.withAlphaComponent(0.12),
                                  NSColor.white.withAlphaComponent(0.0)]
    static let cellSheenLocations: [NSNumber] = [0, 0.45]

    /// Only the selected tile draws a stroke.
    static let cellBorderSelected = NSColor(calibratedRed: 0.44, green: 0.68, blue: 1.0, alpha: 0.95)

    /// Placeholder well while a capture is in flight. Cleared once an image lands.
    static let thumbnailWell = NSColor(calibratedWhite: 0, alpha: 0.22)

    static let titleColor = NSColor.white
    static let subtitleColor = NSColor(calibratedWhite: 0.78, alpha: 1.0)

    /// Miniature titlebar controls, shown when a tile is hovered. These are the real
    /// macOS traffic-light colours, slightly softened so they sit inside the glass
    /// instead of glowing through it.
    static let trafficColors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.37, blue: 0.34, alpha: 1.0), // close
        NSColor(srgbRed: 0.99, green: 0.74, blue: 0.18, alpha: 1.0), // minimize
        NSColor(srgbRed: 0.16, green: 0.78, blue: 0.25, alpha: 1.0), // zoom
    ]

    // MARK: - Elevation

    static let selectionShadowColor = NSColor.black.withAlphaComponent(0.50)
    static let selectionShadowRadius: CGFloat = 12
    static let selectionShadowOpacity: Float = 0.9
}
