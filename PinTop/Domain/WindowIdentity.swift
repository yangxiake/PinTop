import AppKit
import ApplicationServices
import Darwin

struct ProcessIdentity: Codable, Equatable {
    let pid: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let executablePath: String

    static func read(pid: pid_t) throws -> Self {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_pid == UInt32(pid), info.pbi_uid == getuid() else {
            throw PinError.invalid("进程身份无法验证")
        }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
            throw PinError.invalid("进程路径无法验证")
        }
        let path = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return Self(pid: pid, startSeconds: info.pbi_start_tvsec,
                    startMicroseconds: info.pbi_start_tvusec,
                    executablePath: URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path)
    }
}

struct WindowIdentity: Codable, Equatable {
    let windowID: UInt32
    let process: ProcessIdentity
}

struct PinnedWindow: Codable {
    let identity: WindowIdentity
    let auxiliarySpace: UInt64
    let originalSpaces: [UInt64]
    let displayID: String?
    let title: String
    var visible: Bool
}

enum PinError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

enum WindowCatalog {
    static func visibleOrdinary(ownPID: pid_t) -> [UInt32] {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  ordinary(row, ownPID: ownPID) else { return nil }
            return id
        }
    }

    static func row(id: UInt32) -> [String: Any]? {
        (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?
            .first { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id }
    }

    static func owner(id: UInt32) -> pid_t? {
        (row(id: id)?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
    }

    static func title(id: UInt32) -> String {
        guard let row = row(id: id) else { return "窗口 \(id)" }
        let app = row[kCGWindowOwnerName as String] as? String ?? "应用"
        let title = row[kCGWindowName as String] as? String ?? ""
        return title.isEmpty ? app : "\(app) · \(title)"
    }

    static func isVisibleOnScreen(id: UInt32) -> Bool {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        return rows.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id }
    }

    static func isOrdinary(id: UInt32, ownPID: pid_t) -> Bool {
        guard isVisibleOnScreen(id: id), let row = row(id: id) else { return false }
        return ordinary(row, ownPID: ownPID)
    }

    private static func ordinary(_ row: [String: Any], ownPID: pid_t) -> Bool {
        guard let pid = (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
              pid != ownPID, pid > 1,
              let layer = (row[kCGWindowLayer as String] as? NSNumber)?.intValue,
              layer == 0,
              let bounds = row[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
              width >= 80, height >= 60 else { return false }
        let name = row[kCGWindowOwnerName as String] as? String ?? ""
        return !["Dock", "Window Server", "SystemUIServer", "universalAccessAuthWarn"].contains(name)
    }

    static func aboveOrdinaryOverlaps(id: UInt32, ownPID: pid_t) -> Bool? {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        guard let index = rows.firstIndex(where: {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
        }), let target = bounds(rows[index]) else { return nil }
        for row in rows[..<index] {
            guard let other = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  other != id,
                  (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != ownPID,
                  (row[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let frame = bounds(row), frame.intersects(target) else { continue }
            return false
        }
        return true
    }

    private static func bounds(_ row: [String: Any]) -> CGRect? {
        guard let b = row[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? Double, let y = b["Y"] as? Double,
              let w = b["Width"] as? Double, let h = b["Height"] as? Double else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    static func validate(_ identity: WindowIdentity) -> Bool {
        guard let actual = try? ProcessIdentity.read(pid: identity.process.pid),
              actual == identity.process,
              owner(id: identity.windowID) == identity.process.pid else { return false }
        return true
    }
}
