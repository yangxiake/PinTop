import AppKit

@MainActor enum DesktopTopology {
    static func currentIDs(_ bridge: SLSBridge, displayID: String? = nil) throws -> Set<UInt64> {
        var ids: Set<UInt64> = []
        for display in try bridge.managedDisplaySpaces() {
            if let displayID,
               (display["Display Identifier"] as? String)?.uppercased() != displayID.uppercased() {
                continue
            }
            if let current = display["Current Space"] as? [String: Any],
               let id = current["ManagedSpaceID"] as? NSNumber { ids.insert(id.uint64Value) }
        }
        return ids
    }

    static func displayIdentifier(forWindow id: UInt32) -> String? {
        guard let row = WindowCatalog.row(id: id),
              let b = row[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? Double, let y = b["Y"] as? Double,
              let w = b["Width"] as? Double, let h = b["Height"] as? Double else { return nil }
        let frame = CGRect(x: x, y: y, width: w, height: h)
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetDisplaysWithRect(frame, UInt32(displayIDs.count), &displayIDs, &count) == .success,
              count > 0 else { return nil }
        let best = displayIDs.prefix(Int(count)).max {
            let a = CGDisplayBounds($0).intersection(frame)
            let b = CGDisplayBounds($1).intersection(frame)
            return a.width * a.height < b.width * b.height
        }
        guard let best, let uuid = CGDisplayCreateUUIDFromDisplayID(best)?.takeRetainedValue(),
              let identifier = CFUUIDCreateString(nil, uuid) else { return nil }
        return identifier as String
    }

    static func managedIDs(_ bridge: SLSBridge) throws -> Set<UInt64> {
        var result: Set<UInt64> = []
        func visit(_ value: Any) {
            if let object = value as? [String: Any] {
                if let id = object["ManagedSpaceID"] as? NSNumber { result.insert(id.uint64Value) }
                for child in object.values { visit(child) }
            } else if let array = value as? [Any] {
                for child in array { visit(child) }
            }
        }
        visit(try bridge.managedDisplaySpaces())
        return result
    }
}
