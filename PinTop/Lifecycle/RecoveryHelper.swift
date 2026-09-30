import AppKit
import Darwin

@MainActor enum RecoveryHelper {
    static func run(journalURL: URL, nonce: String) throws {
        let journal = try JSONDecoder().decode(RecoveryJournal.self, from: Data(contentsOf: journalURL))
        let directory = journalURL.deletingLastPathComponent()
        guard directory.lastPathComponent == nonce, journal.nonce == nonce,
              journal.parent == getppid(), journal.parent > 1,
              journal.parentIdentity == (try? ProcessIdentity.read(pid: journal.parent)),
              journal.bootSeconds == (try? RecoveryFiles.bootSeconds()),
              !journal.originalSpaces.isEmpty,
              !journal.originalSpaces.contains(journal.auxiliarySpace),
              WindowCatalog.validate(journal.identity) else {
            throw PinError.invalid("恢复进程身份校验失败")
        }
        let bridge = try SLSBridge()
        guard !(try DesktopTopology.managedIDs(bridge)).contains(journal.auxiliarySpace),
              Set(try bridge.spaces(for: [journal.identity.windowID])) == Set(journal.originalSpaces) else {
            throw PinError.invalid("恢复前拓扑不符")
        }
        let source = DispatchSource.makeProcessSource(identifier: journal.parent, eventMask: .exit, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                let disarmURL = directory.appendingPathComponent("disarmed")
                if (try? String(contentsOf: disarmURL, encoding: .utf8)) == nonce { exit(0) }
                do {
                    try recover(journal, bridge: bridge)
                    try Data("PASS".utf8).write(to: directory.appendingPathComponent("result"), options: .atomic)
                    exit(0)
                } catch {
                    try? Data("FAIL \(error)".utf8).write(to: directory.appendingPathComponent("result"), options: .atomic)
                    exit(1)
                }
            }
        }
        source.resume()
        let ack = RecoveryACK(nonce: nonce, helper: getpid(), parent: journal.parent,
                              helperIdentity: try ProcessIdentity.read(pid: getpid()),
                              auxiliarySpace: journal.auxiliarySpace)
        try RecoveryFiles.write(ack, to: directory.appendingPathComponent("ack.json"))
        withExtendedLifetime(source) { RunLoop.current.run() }
    }

    static func recoverAbandoned() throws -> [String] {
        let root = try RecoveryFiles.root()
        let bridge = try SLSBridge()
        let directories = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        var problems: [String] = []
        for directory in directories {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let journalURL = directory.appendingPathComponent("journal.json")
            guard let bytes = try? Data(contentsOf: journalURL),
                  let journal = try? JSONDecoder().decode(RecoveryJournal.self, from: bytes),
                  journal.nonce == directory.lastPathComponent else { continue }
            let ackURL = directory.appendingPathComponent("ack.json")
            let ack = (try? Data(contentsOf: ackURL)).flatMap { try? JSONDecoder().decode(RecoveryACK.self, from: $0) }
            let parentAlive = (try? ProcessIdentity.read(pid: journal.parent)) == journal.parentIdentity
            let helperAlive = ack.flatMap { (try? ProcessIdentity.read(pid: $0.helper)) == $0.helperIdentity } ?? false
            if parentAlive || helperAlive { continue }
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("disarmed").path) ||
                FileManager.default.fileExists(atPath: directory.appendingPathComponent("result").path) {
                try? FileManager.default.removeItem(at: directory)
                continue
            }
            do {
                guard journal.bootSeconds == (try RecoveryFiles.bootSeconds()),
                      WindowCatalog.validate(journal.identity),
                      !journal.originalSpaces.isEmpty,
                      !journal.originalSpaces.contains(journal.auxiliarySpace),
                      !(try DesktopTopology.managedIDs(bridge)).contains(journal.auxiliarySpace) else {
                    throw PinError.invalid("身份或系统启动记录不符")
                }
                let membership = try bridge.spaces(for: [journal.identity.windowID])
                guard membership.contains(journal.auxiliarySpace),
                      Set(journal.originalSpaces).isSubset(of: Set(membership)) else {
                    throw PinError.invalid("当前成员关系与恢复记录不符")
                }
                try recover(journal, bridge: bridge)
                try Data("PASS startup".utf8).write(to: directory.appendingPathComponent("result"), options: .atomic)
            } catch {
                problems.append("\(directory.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return problems
    }

    static func recover(_ journal: RecoveryJournal, bridge: SLSBridge) throws {
        let id = journal.identity.windowID
        // A closed or replaced window cannot safely be addressed by its old number.
        if WindowCatalog.validate(journal.identity) {
            let before = try bridge.spaces(for: [id])
            if before.contains(journal.auxiliarySpace) {
                try bridge.remove([id], from: journal.auxiliarySpace)
                let after = try settle(bridge, id: id) { !$0.contains(journal.auxiliarySpace) }
                guard !after.contains(journal.auxiliarySpace) else {
                    throw PinError.invalid("恢复进程无法撤销辅助成员")
                }
            }
        }
        guard !(try DesktopTopology.managedIDs(bridge)).contains(journal.auxiliarySpace) else {
            throw PinError.invalid("辅助 Space 已变为 managed，拒绝销毁")
        }
        try bridge.destroy(journal.auxiliarySpace)
    }

    static func settle(_ bridge: SLSBridge, id: UInt32, timeout: TimeInterval = 2,
                       condition: ([UInt64]) -> Bool) throws -> [UInt64] {
        let deadline = Date().addingTimeInterval(timeout)
        var actual = try bridge.spaces(for: [id])
        while !condition(actual) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            actual = try bridge.spaces(for: [id])
        }
        return actual
    }
}
