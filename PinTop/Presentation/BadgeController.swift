import AppKit

@MainActor final class BadgeController: NSObject {
    private var panels: [UInt32: NSPanel] = [:]
    private var attachedSpaces: [UInt32: UInt64] = [:]
    private var attachingIDs: Set<UInt32> = []
    private var failedIDs: Set<UInt32> = []
    private var tracked: [UInt32: PinnedWindow] = [:]
    private var geometryTimer: Timer?
    private var bridge: SLSBridge?
    var onUnpin: ((UInt32) -> Void)?
    var onError: ((UInt32, String) -> Void)?
    var isEnabled = true {
        didSet { if !isEnabled { clear() } }
    }

    func configure(bridge: SLSBridge) { self.bridge = bridge }

    func synchronize(_ entries: [UInt32: PinCoordinator.Entry]) {
        guard isEnabled else { clear(); return }
        tracked = entries.mapValues { $0.pin }
        for id in Array(panels.keys) where entries[id] == nil {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
            attachedSpaces.removeValue(forKey: id)
            failedIDs.remove(id)
        }
        for (id, entry) in entries {
            guard entry.pin.visible,
                  let row = WindowCatalog.row(id: id),
                  let frame = frame(for: row) else {
                panels[id]?.orderOut(nil)
                continue
            }
            let panel = panels[id] ?? makePanel(id: id, frame: frame)
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            if let button = button(in: panel) {
                button.title = frame.width < 88 ? "取消" : "取消置顶"
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
            if attachedSpaces[id] != entry.pin.auxiliarySpace && !attachingIDs.contains(id) && !failedIDs.contains(id) {
                attachingIDs.insert(id)
                defer { attachingIDs.remove(id) }
                do {
                    try attach(panel, to: entry.pin.auxiliarySpace, above: id)
                    attachedSpaces[id] = entry.pin.auxiliarySpace
                } catch {
                    panel.orderOut(nil)
                    failedIDs.insert(id)
                    onError?(id, error.localizedDescription)
                }
            }
        }
        refreshGeometry()
        if tracked.isEmpty { stopGeometryTimer() }
        else { startGeometryTimer() }
    }

    private func startGeometryTimer() {
        guard geometryTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshGeometry() }
        }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        geometryTimer = timer
    }

    private func stopGeometryTimer() {
        geometryTimer?.invalidate()
        geometryTimer = nil
    }

    private func refreshGeometry() {
        guard !tracked.isEmpty else { return }
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        let visible = Dictionary(rows.compactMap { row -> (UInt32, [String: Any])? in
            guard let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  tracked[id] != nil else { return nil }
            return (id, row)
        }, uniquingKeysWith: { first, _ in first })
        for (id, panel) in panels {
            guard tracked[id]?.visible == true,
                  let row = visible[id], let targetFrame = frame(for: row) else {
                if panel.isVisible { panel.orderOut(nil) }
                continue
            }
            if panel.frame != targetFrame { panel.setFrame(targetFrame, display: true) }
            if let button = button(in: panel) {
                let title = targetFrame.width < 88 ? "取消" : "取消置顶"
                if button.title != title { button.title = title }
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
    }

    private func frame(for row: [String: Any]) -> NSRect? {
        guard let bounds = row[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let main = NSScreen.screens.first else { return nil }
        let badgeWidth = max(56, min(PinTopButton.standardWidth, width - 12))
        return NSRect(x: x + width - badgeWidth - 8,
                      y: main.frame.maxY - y - PinTopButton.standardHeight - 4,
                      width: badgeWidth, height: PinTopButton.standardHeight)
    }

    private func button(in panel: NSPanel) -> NSButton? {
        panel.contentView?.subviews.first(where: { $0 is NSButton }) as? NSButton
    }

    private func attach(_ panel: NSPanel, to space: UInt64, above target: UInt32) throws {
        guard let bridge, panel.windowNumber > 0 else {
            throw PinError.invalid("无法准备窗口上的置顶按钮")
        }
        let badge = UInt32(panel.windowNumber)
        try bridge.add([badge], to: space)
        let spaces = try RecoveryHelper.settle(bridge, id: badge) { $0.contains(space) }
        guard spaces.contains(space) else { throw PinError.invalid("置顶按钮未进入目标窗口的置顶层") }
        let deadline = Date().addingTimeInterval(1)
        while !isAbove(badge, target: target) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        guard isAbove(badge, target: target) else {
            throw PinError.invalid("置顶按钮仍被目标窗口遮挡")
        }
    }

    private func isAbove(_ badge: UInt32, target: UInt32) -> Bool {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        let ids = rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
        guard let badgeIndex = ids.firstIndex(of: badge), let targetIndex = ids.firstIndex(of: target) else {
            return false
        }
        return badgeIndex < targetIndex
    }

    private func makePanel(id: UInt32, frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.transient]
        let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 7
        material.layer?.masksToBounds = true
        material.layer?.borderWidth = 1
        material.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
        material.autoresizingMask = [.width, .height]
        let button = PinTopButton(frame: NSRect(origin: .zero, size: frame.size))
        button.image = PinTopButton.symbol("pin.fill", description: "已置顶")
        button.title = "取消置顶"
        button.autoresizingMask = [.width, .height]
        button.toolTip = "取消此窗口置顶"
        button.target = self
        button.action = #selector(clicked(_:))
        button.tag = Int(id)
        material.addSubview(button)
        panel.contentView = material
        panels[id] = panel
        return panel
    }

    @objc private func clicked(_ sender: NSButton) {
        onUnpin?(UInt32(sender.tag))
    }

    func clear() {
        stopGeometryTimer()
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()
        attachedSpaces.removeAll()
        attachingIDs.removeAll()
        failedIDs.removeAll()
        tracked.removeAll()
    }
}
