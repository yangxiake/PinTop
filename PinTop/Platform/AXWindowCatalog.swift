import AppKit
import ApplicationServices

@MainActor enum AXWindowCatalog {
    static func windowTitle(id: UInt32) -> String {
        let fallback = (WindowCatalog.row(id: id)?[kCGWindowName as String] as? String) ?? ""
        guard let element = windowElement(id: id) else {
            return fallback.isEmpty ? "授权后显示窗口标题" : fallback
        }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success,
              let title = value as? String, !title.isEmpty else {
            return fallback.isEmpty ? "未命名窗口" : fallback
        }
        return title
    }

    static func displayTitle(id: UInt32) -> String {
        let app = (WindowCatalog.row(id: id)?[kCGWindowOwnerName as String] as? String) ?? "应用"
        return "\(app) · \(windowTitle(id: id))"
    }

    static func permission(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    enum WindowState { case alive, closed, unknown }

    static func windowElement(id: UInt32) -> AXUIElement? {
        guard permission(prompt: false),
              let pid = WindowCatalog.owner(id: id),
              let row = WindowCatalog.row(id: id),
              let bounds = row[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
              let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AnyObject] else { return nil }
        var best: (AXUIElement, Double)?
        for object in windows where CFGetTypeID(object) == AXUIElementGetTypeID() {
            let element = unsafeDowncast(object, to: AXUIElement.self)
            guard let geometry = geometry(of: element) else { continue }
            let score = abs(geometry.0.x - x) + abs(geometry.0.y - y) +
                        abs(geometry.1.width - w) + abs(geometry.1.height - h)
            if score < (best?.1 ?? .infinity) { best = (element, score) }
        }
        guard let best, best.1 < 30 else { return nil }
        return best.0
    }

    static func state(of element: AXUIElement?) -> WindowState {
        guard let element else { return .unknown }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        if result == .success { return .alive }
        if result == .invalidUIElement { return .closed }
        return .unknown
    }

    private static func geometry(of element: AXUIElement) -> (CGPoint, CGSize)? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let p = position, let s = size,
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(s, to: AXValue.self), .cgSize, &dimensions) else { return nil }
        return (point, dimensions)
    }


    static func focusedWindowID() throws -> UInt32 {
        guard permission(prompt: true) else { throw PinError.invalid("请先在系统设置中授予辅助功能权限") }
        guard let app = NSWorkspace.shared.frontmostApplication else { throw PinError.invalid("找不到活动应用") }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &result) == .success,
              let window = result else { throw PinError.invalid("活动应用没有可访问的焦点窗口") }
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else { throw PinError.invalid("焦点窗口类型无效") }
        let candidate = unsafeDowncast(window, to: AXUIElement.self)
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(candidate, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(candidate, kAXSizeAttribute as CFString, &size) == .success,
              let p = position, let s = size,
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else {
            throw PinError.invalid("无法读取焦点窗口位置")
        }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(s, to: AXValue.self), .cgSize, &dimensions) else {
            throw PinError.invalid("无法读取焦点窗口大小")
        }
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        let matches = rows.filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == app.processIdentifier &&
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
        }
        let scored: [(UInt32, Double)] = matches.compactMap { row in
            guard let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let b = row[kCGWindowBounds as String] as? [String: Any],
                  let x = b["X"] as? Double, let y = b["Y"] as? Double,
                  let w = b["Width"] as? Double, let h = b["Height"] as? Double else { return nil }
            let score = abs(x - point.x) + abs(y - point.y) + abs(w - dimensions.width) + abs(h - dimensions.height)
            return (id, score)
        }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < 30 else {
            throw PinError.invalid("无法将辅助功能窗口与真实窗口对应")
        }
        return best.0
    }
}
