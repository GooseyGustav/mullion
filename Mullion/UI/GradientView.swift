import AppKit

/// A view whose background is a vertical gradient.
///
/// Used instead of `CAGradientLayer` directly so the gradient resizes with the view
/// on every layout pass; cell sizes change when the panel is rebuilt.
final class GradientView: NSView {
    private let gradientLayer = CAGradientLayer()

    var colors: [NSColor] {
        didSet { gradientLayer.colors = colors.map(\.cgColor) }
    }

    var locations: [NSNumber] {
        didSet { gradientLayer.locations = locations }
    }

    init(colors: [NSColor], locations: [NSNumber] = [0, 1]) {
        self.colors = colors
        self.locations = locations
        super.init(frame: .zero)
        wantsLayer = true
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.locations = locations
        // AppKit's coordinate space is bottom-up: (0.5, 1) is the top edge.
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}
