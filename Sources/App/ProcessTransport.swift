import Foundation

@MainActor
final class ProcessTransport {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var finished = false
    private let runnerURL: URL?
    var onData: ((Data) -> Void)?
    var onExit: ((Int32) -> Void)?

    init(runnerURL: URL? = nil) { self.runnerURL = runnerURL }

    func start(executable: URL, folder: URL, lock: URL) throws {
        guard let runner = runnerURL ?? Bundle.main.resourceURL?.deletingLastPathComponent().appendingPathComponent("Helpers/BeamletRunner"),
              FileManager.default.isExecutableFile(atPath: runner.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        process.executableURL = runner
        process.arguments = [executable.path, folder.path, lock.path, "remote-control"]
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["PATH"] = [executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin",
                               "/usr/bin", "/bin", "/usr/sbin", "/sbin", environment["PATH"] ?? ""].joined(separator: ":")
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()
        // Only the runner holds these ends now. EOF reliably follows runner exit.
        try? output.fileHandleForWriting.close()
        try? input.fileHandleForReading.close()
        let reader = output.fileHandleForReading
        let process = process
        // A single producer enqueues output before exit; no termination-handler race
        // can drop the last authentication error or session URL.
        DispatchQueue(label: "app.beamlet.output").async { [weak self] in
            while true {
                let data = reader.availableData
                if data.isEmpty { break }
                DispatchQueue.main.async { [weak self] in self?.onData?(data) }
            }
            process.waitUntilExit()
            let status = process.terminationStatus
            try? reader.close()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.finished = true
                try? self.input.fileHandleForWriting.close()
                self.onExit?(status)
            }
        }
    }

    func interrupt() {
        guard !finished else { return }
        try? input.fileHandleForWriting.write(contentsOf: Data("I".utf8))
    }
}
