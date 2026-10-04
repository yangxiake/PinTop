import AppKit
@preconcurrency import CoreGraphics
import ApplicationServices

@MainActor final class NeedleController: NSObject {
    private let bridge: SLSBridge
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var outline: NSPanel?
    private var selectionHint: NSPanel?
    private var candidate: UInt32?
    private var selectedID: UInt32?
    private let onSelect: (UInt32) -> Void
    private let onError: (String) -> Void
    var isActive: Bool { tap != nil }
    private(set) var eventCount = 0
    var hoverWindowID: UInt32? { candidate }

    init(onSelect: @escaping (UInt32) -> Void, onError: @escaping (String) -> Void) throws {
        bridge = try SLSBridge()
        self.onSelect = onSelect
        self.onError = onError
        super.init()
    }

    func start() throws {
        guard tap == nil else { return }
        guard AXWindowCatalog.permission(prompt: true) else {
            throw PinError.invalid("针模式需要辅助功能权限")
        }
        let mask = (1 << CGEventType.mouseMoved.rawValue) |
                   (1 << CGEventType.leftMouseDown.rawValue) |
                   (1 << CGEventType.leftMouseUp.rawValue) |
                   (1 << CGEventType.keyDown.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask),
                                           callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<NeedleController>.fromOpaque(refcon).takeUnretainedValue()
            return MainActor.assumeIsolated { controller.handle(type: type, event: event) }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw PinError.invalid("无法开启针模式事件捕获；请检查辅助功能授权")
        }
        let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        tap = port
        source = runSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        let point = CGEvent(source: nil)?.location ?? .zero
        showHint()
        update(point)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        candidate = nil
        selectedID = nil
        outline?.orderOut(nil)
        outline = nil
        selectionHint?.orderOut(nil)
        selectionHint = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        eventCount += 1
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop()
            onError("针模式事件捕获已停止")
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            stop()
            return nil
        }
        if type == .mouseMoved {
            update(event.location)
        } else if type == .leftMouseDown {
            // A click must use its own position: the pointer may have moved without
            // a mouseMoved event reaching this tap (for example after a Space change).
            update(event.location)
            guard let id = candidate else { return Unmanaged.passUnretained(event) }
            selectedID = id
            return nil
        } else if type == .leftMouseUp, let id = selectedID {
            stop()
            DispatchQueue.main.async { [onSelect] in onSelect(id) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func update(_ point: CGPoint) {
        let id = (try? bridge.window(at: point)) ?? 0
        guard id != 0, WindowCatalog.isOrdinary(id: id, ownPID: getpid()),
              let row = WindowCatalog.row(id: id),
              let bounds = row[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
              let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double,
              let main = NSScreen.screens.first else {
            candidate = nil
            outline?.orderOut(nil)
            return
        }
        candidate = id
        let frame = NSRect(x: x, y: main.frame.maxY - y - h, width: w, height: h)
        if outline == nil {
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            view.layer?.borderColor = NSColor.controlAccentColor.cgColor
            view.layer?.borderWidth = 3
            view.layer?.cornerRadius = 7
            panel.contentView = view
            outline = panel
        }
        outline?.setFrame(frame, display: true)
        outline?.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        outline?.orderFrontRegardless()
    }

    private func showHint() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = NSRect(x: screen.visibleFrame.midX - 170,
                           y: screen.visibleFrame.maxY - 54,
                           width: 340, height: 40)
        if selectionHint == nil {
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            let view = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            view.layer?.cornerRadius = 8
            view.layer?.masksToBounds = true
            let pin = NSImageView(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "选择窗口") ?? NSImage())
            pin.contentTintColor = .controlAccentColor
            pin.frame = NSRect(x: 12, y: 12, width: 16, height: 16)
            view.addSubview(pin)
            let label = NSTextField(labelWithString: "点按窗口以置顶 · Esc 退出")
            label.font = .systemFont(ofSize: 12)
            label.frame = NSRect(x: 36, y: 11, width: 210, height: 18)
            view.addSubview(label)
            let cancel = NSButton(title: "取消选择", target: self, action: #selector(cancelSelection))
            cancel.frame = NSRect(x: 250, y: 8, width: 78, height: 24)
            cancel.bezelStyle = .rounded
            cancel.controlSize = .small
            view.addSubview(cancel)
            panel.contentView = view
            selectionHint = panel
        }
        selectionHint?.orderFrontRegardless()
    }

    @objc private func cancelSelection() { stop() }
}
