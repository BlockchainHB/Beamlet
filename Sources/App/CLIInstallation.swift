import Foundation
import CryptoKit
import BeamletCore

enum CLIInstallation {
    static func executable(override: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = override.isEmpty
            ? ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            : [(override as NSString).expandingTildeInPath]
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            .map { URL(fileURLWithPath: $0) }
    }

    static func validate(folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue,
              folder != FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath()
        else { throw SetupIssue.folder }
    }

    static func lockURL(folder: URL) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true).appendingPathComponent("Beamlet/Locks")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let key = SHA256.hash(data: Data(folder.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(key + ".lock")
    }

    /// Read-only best-effort conflict discovery. Never signal these PIDs.
    static func hasExternalServer(in folder: URL) -> Bool {
        guard let snapshot = capture("/bin/ps", ["-axo", "pid=,args="]) else { return false }
        for line in snapshot.split(separator: "\n") {
            guard !line.contains("BeamletRunner"),
                  line.range(of: #"(?:^|\s)(?:\S*/)?claude\s+(?:remote-control|rc)(?:\s|$)"#, options: .regularExpression) != nil,
                  let pid = line.split(whereSeparator: { $0.isWhitespace }).first,
                  Int32(pid) != nil,
                  let cwd = capture("/usr/sbin/lsof", ["-a", "-p", String(pid), "-d", "cwd", "-Fn"])
            else { continue }
            for entry in cwd.split(separator: "\n") where entry.hasPrefix("n") {
                let path = URL(fileURLWithPath: String(entry.dropFirst())).resolvingSymlinksInPath()
                if path == folder { return true }
            }
        }
        return false
    }

    private static func capture(_ path: String, _ arguments: [String]) -> String? {
        let task = Process(), pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
