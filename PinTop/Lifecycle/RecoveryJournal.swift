import Foundation
import Darwin

struct RecoveryJournal: Codable {
    let nonce: String
    let parent: pid_t
    let parentIdentity: ProcessIdentity
    let bootSeconds: UInt64
    let identity: WindowIdentity
    let originalSpaces: [UInt64]
    let auxiliarySpace: UInt64
}

struct RecoveryACK: Codable {
    let nonce: String
    let helper: pid_t
    let parent: pid_t
    let helperIdentity: ProcessIdentity
    let auxiliarySpace: UInt64
}

enum RecoveryFiles {
    static func bootSeconds() throws -> UInt64 {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else {
            throw PinError.invalid("无法验证本次系统启动")
        }
        return UInt64(boot.tv_sec)
    }

    static func root() throws -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = support.appendingPathComponent("PinTop/Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        return root
    }

    static func create(nonce: String) throws -> URL {
        let directory = try root().appendingPathComponent(nonce, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        return directory
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        let bytes = try JSONEncoder().encode(value)
        guard FileManager.default.createFile(atPath: temporary.path, contents: bytes,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw PinError.invalid("无法创建恢复记录")
        }
        let handle = try FileHandle(forWritingTo: temporary)
        try handle.synchronize()
        try handle.close()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.moveItem(at: temporary, to: url)
        let directoryFD = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
        if directoryFD >= 0 { _ = fsync(directoryFD); _ = close(directoryFD) }
    }
}
