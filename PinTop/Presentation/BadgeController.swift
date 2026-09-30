import AppKit

@MainActor final class BadgeController: NSObject {
    private var panels: [UInt32: NSPanel] = [:]
    private var attachedSpaces: [UInt32: UInt64] = [:]
    private var attachingIDs: Set<UInt32> = []
    private var failedIDs: Set<UInt32> = []
    private var bridge: SLSBridge?
    var onUnpin: ((UInt32) -> Void)?
    var onError: ((UInt32, String) -> Void)?
    var isEnabled = true {
        didSet { if !isEnabled { clear() } }
    }

    func configure(bridge: SLSBridge) { self.bridge = bridge }

    func synchronize(_ entries: [UInt32: PinCoordinator.Entry]) {
        guard isEnabled else { clear(); return }
        for id in Array(panels.keys) where entries[id] == nil {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
            attachedSpaces.removeValue(forKey: id)
            failedIDs.remove(id)
        }
        for (id, entry) in entries {
            guard entry.pin.visible,
                  let row = WindowCatalog.row(id: id),
                  let bounds = row[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double,
                  let main = NSScreen.screens.first else {
                panels[id]?.orderOut(nil)
                continue
            }
            let badgeWidth = max(66, min(136, width - 12))
            let frame = NSRect(x: x + max(6, width - badgeWidth - 8),
                               y: main.frame.maxY - y - 32,
                               width: badgeWidth, height: 28)
            let panel = panels[id] ?? makePanel(id: id, frame: frame)
            panel.setFrame(frame, display: true)
            if let button = panel.contentView as? NSButton {
                button.title = badgeWidth < 110 ? "取消" : "已置顶 · 取消"
            }
            panel.orderFrontRegardless()
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
        panel.backgroundColor = .controlAccentColor
        panel.isOpaque = true
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.transient]
        let button = NSButton(frame: NSRect(origin: .zero, size: frame.size))
        button.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "已置顶")
        button.imagePosition = .imageLeft
        button.isBordered = false
        button.contentTintColor = .white
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.title = "已置顶 · 取消"
        button.autoresizingMask = [.width, .height]
        button.toolTip = "取消此窗口置顶"
        button.target = self
        button.action = #selector(clicked(_:))
        button.tag = Int(id)
        panel.contentView = button
        panels[id] = panel
        return panel
    }

    @objc private func clicked(_ sender: NSButton) {
        onUnpin?(UInt32(sender.tag))
    }

    func clear() {
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()
        attachedSpaces.removeAll()
        failedIDs.removeAll()
    }
}
