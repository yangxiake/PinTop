import AppKit
import ApplicationServices

@MainActor final class PinCoordinator {
    struct Entry {
        var pin: PinnedWindow
        let directory: URL
        let nonce: String
        let helper: Process
        let axWindow: AXUIElement?
    }

    private let bridge: SLSBridge
    private(set) var entries: [UInt32: Entry] = [:]
    private var changing = false
    var onChange: (() -> Void)?
    var onError: ((String) -> Void)?

    init() throws { bridge = try SLSBridge() }

    func toggle(_ id: UInt32) throws {
        if entries[id] != nil { try unpin(id); return }
        try pin(id)
    }

    func pin(_ id: UInt32) throws {
        guard !changing else { throw PinError.invalid("正在处理另一个窗口") }
        guard entries[id] == nil else { return }
        guard WindowCatalog.isOrdinary(id: id, ownPID: getpid()),
              let pid = WindowCatalog.owner(id: id) else { throw PinError.invalid("只能钉住普通应用窗口") }
        changing = true
        defer { changing = false }
        let identity = WindowIdentity(windowID: id, process: try ProcessIdentity.read(pid: pid))
        let original = try bridge.spaces(for: [id])
        let managed = try DesktopTopology.managedIDs(bridge)
        guard !original.isEmpty, Set(original).isSubset(of: managed) else {
            throw PinError.invalid("窗口的原桌面无法确认")
        }
        let displayID = DesktopTopology.displayIdentifier(forWindow: id)
        let current = try DesktopTopology.currentIDs(bridge, displayID: displayID)
        guard !Set(original).isDisjoint(with: current) else {
            throw PinError.invalid("目标窗口不在当前桌面")
        }
        let auxiliary = try bridge.createOverlay()
        let nonce = UUID().uuidString
        var directory: URL?
        var helper: Process?
        var attached = false
        do {
            let folder = try RecoveryFiles.create(nonce: nonce)
            directory = folder
            let journal = RecoveryJournal(nonce: nonce, parent: getpid(),
                                          parentIdentity: try ProcessIdentity.read(pid: getpid()),
                                          bootSeconds: try RecoveryFiles.bootSeconds(), identity: identity,
                                          originalSpaces: original, auxiliarySpace: auxiliary)
            try RecoveryFiles.write(journal, to: folder.appendingPathComponent("journal.json"))
            let child = Process()
            child.executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            child.arguments = ["--recovery-helper", folder.appendingPathComponent("journal.json").path, nonce]
            let logURL = folder.appendingPathComponent("helper.log")
            _ = FileManager.default.createFile(atPath: logURL.path, contents: nil,
                                               attributes: [.posixPermissions: 0o600])
            let log = try FileHandle(forWritingTo: logURL)
            child.standardOutput = log
            child.standardError = log
            try child.run()
            helper = child
            let deadline = Date().addingTimeInterval(5)
            var acknowledged = false
            while Date() < deadline && child.isRunning {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                if let bytes = try? Data(contentsOf: folder.appendingPathComponent("ack.json")),
                   let ack = try? JSONDecoder().decode(RecoveryACK.self, from: bytes),
                   ack.nonce == nonce, ack.parent == getpid(),
                   ack.helper == child.processIdentifier,
                   ack.helperIdentity == (try? ProcessIdentity.read(pid: child.processIdentifier)),
                   ack.auxiliarySpace == auxiliary {
                    acknowledged = true
                    break
                }
            }
            guard acknowledged && child.isRunning else { throw PinError.invalid("恢复进程未就绪") }
            guard WindowCatalog.validate(identity), Set(try bridge.spaces(for: [id])) == Set(original) else {
                throw PinError.invalid("准备期间窗口身份或桌面发生变化")
            }
            try bridge.add([id], to: auxiliary)
            attached = true
            try bridge.setVisible(true, space: auxiliary)
            let actual = try RecoveryHelper.settle(bridge, id: id) { $0.contains(auxiliary) }
            guard actual.contains(auxiliary), Set(original).isSubset(of: Set(actual)),
                  WindowCatalog.validate(identity), child.isRunning else {
                throw PinError.invalid("置顶成员关系验证失败")
            }
            let orderDeadline = Date().addingTimeInterval(1.5)
            var above = WindowCatalog.aboveOrdinaryOverlaps(id: id, ownPID: getpid())
            while above != true && Date() < orderDeadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                above = WindowCatalog.aboveOrdinaryOverlaps(id: id, ownPID: getpid())
            }
            guard above == true else {
                throw PinError.invalid("窗口仍被普通窗口遮挡；请先点亮目标窗口再钉住")
            }
            let pin = PinnedWindow(identity: identity, auxiliarySpace: auxiliary,
                                   originalSpaces: original, displayID: displayID,
                                   title: WindowCatalog.title(id: id), visible: true)
            entries[id] = Entry(pin: pin, directory: folder, nonce: nonce, helper: child,
                                axWindow: AXWindowCatalog.windowElement(id: id))
            onChange?()
        } catch {
            // If rollback fails, keep the ACKed helper armed for parent-exit recovery.
            do {
                if attached && WindowCatalog.validate(identity) {
                    try bridge.remove([id], from: auxiliary)
                    let actual = try RecoveryHelper.settle(bridge, id: id) { !$0.contains(auxiliary) }
                    guard !actual.contains(auxiliary) else { throw PinError.invalid("置顶回滚未确认") }
                }
                try bridge.destroy(auxiliary)
                if let directory {
                    try Data(nonce.utf8).write(to: directory.appendingPathComponent("disarmed"), options: .atomic)
                }
                if helper?.isRunning == true { helper?.terminate() }
            } catch {
                onError?("置顶失败且清理待恢复：\(error.localizedDescription)")
            }
            throw error
        }
    }

    func unpin(_ id: UInt32) throws {
        guard !changing else { throw PinError.invalid("正在处理另一个窗口") }
        guard let entry = entries[id] else { return }
        changing = true
        defer { changing = false }
        let pin = entry.pin
        if WindowCatalog.validate(pin.identity) {
            let before = try bridge.spaces(for: [id])
            if before.contains(pin.auxiliarySpace) {
                try bridge.remove([id], from: pin.auxiliarySpace)
                let after = try RecoveryHelper.settle(bridge, id: id) { !$0.contains(pin.auxiliarySpace) }
                guard !after.contains(pin.auxiliarySpace) else {
                    throw PinError.invalid("取消置顶未完成，恢复进程仍在守护")
                }
            }
        }
        try bridge.destroy(pin.auxiliarySpace)
        try Data(entry.nonce.utf8).write(to: entry.directory.appendingPathComponent("disarmed"), options: .atomic)
        if entry.helper.isRunning { entry.helper.terminate() }
        entries.removeValue(forKey: id)
        onChange?()
    }

    func unpinAll() {
        for id in Array(entries.keys) {
            do { try unpin(id) } catch { onError?("取消窗口 \(id) 失败：\(error.localizedDescription)") }
        }
    }

    func membershipVerified(_ id: UInt32) throws -> Bool {
        guard let pin = entries[id]?.pin, WindowCatalog.validate(pin.identity) else { return false }
        let actual = try bridge.spaces(for: [id])
        return actual.contains(pin.auxiliarySpace) &&
               Set(pin.originalSpaces).isSubset(of: Set(actual))
    }

    func reconcile() {
        guard !changing else { return }
        do {
            for id in Array(entries.keys) {
                guard let entry = entries[id] else { continue }
                if !entry.helper.isRunning {
                    onError?("恢复进程已退出，正在取消窗口 \(id) 的置顶")
                    try unpin(id)
                    continue
                }
                if !WindowCatalog.validate(entry.pin.identity) {
                    let sameProcess = (try? ProcessIdentity.read(pid: entry.pin.identity.process.pid)) ==
                                      entry.pin.identity.process
                    if !sameProcess || AXWindowCatalog.state(of: entry.axWindow) == .closed {
                        try unpin(id)
                    } else if entry.pin.visible {
                        try bridge.setVisible(false, space: entry.pin.auxiliarySpace)
                        entries[id]?.pin.visible = false
                        onChange?()
                    }
                    continue
                }
                if try !membershipVerified(id) {
                    onError?("窗口 \(id) 的置顶成员关系已失效，正在取消")
                    try unpin(id)
                    continue
                }
                let current = try DesktopTopology.currentIDs(bridge, displayID: entry.pin.displayID)
                let shouldShow = !Set(entry.pin.originalSpaces).isDisjoint(with: current) &&
                                 WindowCatalog.isVisibleOnScreen(id: id)
                if shouldShow != entry.pin.visible {
                    try bridge.setVisible(shouldShow, space: entry.pin.auxiliarySpace)
                    entries[id]?.pin.visible = shouldShow
                    onChange?()
                }
            }
        } catch {
            let reason = error.localizedDescription
            for id in Array(entries.keys) where entries[id]?.pin.visible == true {
                guard let space = entries[id]?.pin.auxiliarySpace else { continue }
                do {
                    try bridge.setVisible(false, space: space)
                    entries[id]?.pin.visible = false
                } catch {
                    onError?("窗口 \(id) 暂停置顶失败：\(error.localizedDescription)")
                }
            }
            onChange?()
            onError?("桌面状态无法确认，已暂停置顶：\(reason)")
        }
    }

    func pinFrontmost() throws { try toggle(AXWindowCatalog.focusedWindowID()) }
}
