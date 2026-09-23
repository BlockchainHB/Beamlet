import XCTest
import BeamletCore
@testable import Beamlet

@MainActor
final class SessionControllerTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private func fixture(_ script: String, timeout: Double = 2,
                         conflict: @escaping @Sendable (URL) -> Bool = { _ in false }) throws
        -> (SessionController, URL, String) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Beamlet test \(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let executable = folder.appendingPathComponent("fake claude")
        try ("#!/bin/sh\n" + script).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let suite = "BeamletTests.\(UUID())"
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)
        preferences.folder = folder.path
        preferences.executable = executable.path
        preferences.notifications = false
        let session = SessionController(preferences: preferences, services: SystemServices(observeSystem: false),
                                        runnerURL: root.appendingPathComponent(".build/debug/BeamletRunner"),
                                        confirmationTimeout: timeout, retryDelayScale: 0.01, detectConflict: conflict)
        return (session, folder, suite)
    }

    private func until(_ condition: () -> Bool, timeout: Double = 5,
                       file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(condition(), "Timed out waiting for state", file: file, line: line)
    }

    private func clean(_ value: (SessionController, URL, String)) async throws {
        value.0.stop()
        try await until { !value.0.isBusy }
        if let lock = try? CLIInstallation.lockURL(folder: value.1) { try? FileManager.default.removeItem(at: lock) }
        try FileManager.default.removeItem(at: value.1)
        UserDefaults.standard.removePersistentDomain(forName: value.2)
    }

    func testFinalAuthOutputSurvivesExitAndDoesNotRetry() async throws {
        let value = try fixture("printf 'You must be logged in to use Remote Control.\\n'\nexit 1\n")
        value.0.start()
        try await until { value.0.state.phase == .attention && !value.0.isBusy }
        XCTAssertEqual(value.0.state.issue, .login)
        XCTAssertEqual(value.0.state.attempts, 0)
        try await clean(value)
    }

    func testNetworkRecoveryAcceptsSameLinkAndStopPersists() async throws {
        let value = try fixture("trap 'exit 0' INT TERM\nwhile :; do printf 'https://claude.ai/code?environment=env_fixture\\n'; sleep 0.1; done\n")
        value.0.start()
        value.0.start() // A second click must not launch another child.
        try await until { value.0.state.canOpenSession }
        let generation = value.0.state.generation
        value.0.services.onNetwork?(false)
        XCTAssertFalse(value.0.state.canOpenSession)
        value.0.services.onNetwork?(true)
        try await until { value.0.state.canOpenSession }
        XCTAssertEqual(value.0.state.generation, generation)
        value.0.stop()
        try await until { !value.0.isBusy }
        XCTAssertTrue(value.0.preferences.manuallyStopped)
        value.0.preferences.autoStart = true
        value.0.startAutomaticallyIfNeeded()
        XCTAssertFalse(value.0.isBusy)
        try await clean(value)
    }

    func testRepeatedReconnectTimeoutExhaustsThreeRetries() async throws {
        // Real PTY process startup must not race the deadline this test uses for recovery.
        let value = try fixture("trap 'exit 0' INT TERM\nprintf 'Reconnecting...\\n'\nwhile :; do sleep 0.1; done\n", timeout: 1)
        value.0.start()
        try await until({ value.0.state.phase == .attention && !value.0.isBusy }, timeout: 12)
        XCTAssertEqual(value.0.state.attempts, 3)
        XCTAssertNil(value.0.state.sessionURL)
        try await clean(value)
    }

    func testStopDuringConflictProbePreventsLateSpawn() async throws {
        let value = try fixture("touch launched\n", conflict: { _ in Thread.sleep(forTimeInterval: 0.15); return false })
        value.0.start()
        value.0.stop()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(value.0.isBusy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: value.1.appendingPathComponent("launched").path))
        try await clean(value)
    }

    func testBlankFolderIsActionableAndNeverLaunches() async throws {
        let value = try fixture("touch launched\n")
        value.0.preferences.folder = ""
        value.0.start()
        XCTAssertEqual(value.0.state.issue, .folder)
        XCTAssertFalse(value.0.isBusy)
        try await clean(value)
    }
}
