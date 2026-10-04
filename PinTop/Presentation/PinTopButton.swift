import AppKit
import QuartzCore

@MainActor final class PinTopButton: NSButton {
    static let standardWidth: CGFloat = 96
    static let standardHeight: CGFloat = 28

    static func symbol(_ name: String, description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
    }

    override var isEnabled: Bool {
        didSet { updateAppearance(animated: false) }
    }

    private var tracking: NSTrackingArea?
    private var hovering = false
    private var pressing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isBordered = false
        bezelStyle = .rounded
        imagePosition = .imageLeft
        imageHugsTitle = true
        font = .systemFont(ofSize: 12, weight: .semibold)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        updateAppearance(animated: false)
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        updateAppearance(animated: true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        updateAppearance(animated: true)
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        pressing = true
        updateAppearance(animated: true)
        super.mouseDown(with: event)
        pressing = false
        updateAppearance(animated: true)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    private func updateAppearance(animated: Bool) {
        guard let layer else { return }
        let engaged = isEnabled && (hovering || pressing)
        let color = NSColor.labelColor.withAlphaComponent(engaged ? (pressing ? 0.2 : 0.11) : 0)
        contentTintColor = .labelColor
        let target = color.cgColor
        let shouldAnimate = animated && window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            let transition = CABasicAnimation(keyPath: "backgroundColor")
            transition.fromValue = layer.presentation()?.backgroundColor ?? layer.backgroundColor
            transition.toValue = target
            transition.duration = 0.14
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(transition, forKey: "PinTopButtonBackground")
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1.0
            scale.toValue = pressing ? 0.985 : 1.0
            scale.duration = 0.14
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(scale, forKey: "PinTopButtonScale")
        } else {
            layer.removeAnimation(forKey: "PinTopButtonBackground")
            layer.removeAnimation(forKey: "PinTopButtonScale")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.backgroundColor = target
        layer.transform = pressing && shouldAnimate ? CATransform3DMakeScale(0.985, 0.985, 1) : CATransform3DIdentity
        CATransaction.commit()
    }
}
