import AppKit
import Combine
import BeamletCore

@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var state = SessionState()
    @Published private(set) var diagnostics = Diagnostics()
    @Published private(set) var activeFolder: String?
    let preferences: Preferences
    let power = PowerManager()
    let services: SystemServices
    private let runnerURL: URL?
    private let confirmationTimeout: TimeInterval
    private let retryDelayScale: Double
    private let detectConflict: @Sendable (URL) -> Bool
    private var transport: ProcessTransport?
    private var parser = CLIOutputParser()
    private var pending: Task<Void, Never>?
    private var startupDeadline: Task<Void, Never>?
    private var recoveryDeadline: Task<Void, Never>?
    private var restartAfterExit = false
    private var subscriptions = Set<AnyCancellable>()
    private var powerTimer: Timer?
    private var networkAvailable = true
    private var sleeping = false
    private var checking = false
    private var operation = UUID()
    var onFullyStopped: (() -> Void)?

    var isBusy: Bool { state.isBusy || checking }

    init(preferences: Preferences, services: SystemServices? = nil, runnerURL: URL? = nil,
         confirmationTimeout: TimeInterval = 90, retryDelayScale: Double = 1,
         detectConflict: @escaping @Sendable (URL) -> Bool = CLIInstallation.hasExternalServer) {
        self.preferences = preferences
        self.services = services ?? SystemServices()
        self.runnerURL = runnerURL
        self.confirmationTimeout = confirmationTimeout
        self.retryDelayScale = retryDelayScale
        self.detectConflict = detectConflict
        let services = self.services
        services.onNetwork = { [weak self] available in self?.networkChanged(available) }
        services.onSleep = { [weak self] in
            guard let self else { return }
            self.sleeping = true
            self.parser.invalidateConnection()
            self.recoveryDeadline?.cancel()
            self.recoveryDeadline = nil
            self.state.interrupted("Mac is sleeping. Reconnecting after wake…")
            self.refreshPower()
        }
        services.onWake = { [weak self] in
            guard let self else { return }
            self.sleeping = false
            self.networkChanged(self.networkAvailable)
            self.refreshPower()
        }
        preferences.$keepAwake.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refreshPower() }
        }.store(in: &subscriptions)
        powerTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPower() }
        }
        diagnostics.record("Beamlet started")
    }

    func startAutomaticallyIfNeeded() {
        if preferences.autoStart && !preferences.manuallyStopped { start() }
    }

    func start() {
        guard !isBusy else { return }
        preferences.manuallyStopped = false
        launch(userInitiated: true)
    }

    private func launch(userInitiated: Bool) {
        guard transport == nil, !checking else { return }
        guard !preferences.folder.isEmpty else { failSetup(.folder); return }
        let folder = preferences.folderURL
        guard let executable = CLIInstallation.executable(override: preferences.executable) else {
            failSetup(.executable); return
        }
        do { try CLIInstallation.validate(folder: folder) }
        catch { failSetup(.folder); return }
        checking = true
        state.begin(userInitiated: userInitiated)
        activeFolder = folder.path
        let token = UUID()
        operation = token
        let detectConflict = detectConflict
        pending = Task { [weak self] in
            let conflict = await Task.detached { detectConflict(folder) }.value
            guard let self, !Task.isCancelled, self.operation == token, self.state.wantsRunning else { return }
            self.checking = false
            if conflict {
                self.failSetup(.conflict)
                _ = self.state.exited(code: 1)
                return
            }
            self.spawn(executable: executable, folder: folder)
        }
    }

    private func spawn(executable: URL, folder: URL) {
        parser = CLIOutputParser()
        let child = ProcessTransport(runnerURL: runnerURL)
        let generation = state.generation
        child.onData = { [weak self] data in
            guard let self, self.state.generation == generation else { return }
            for event in self.parser.consume(data) { self.receive(event) }
        }
        child.onExit = { [weak self] status in
            guard let self, self.state.generation == generation else { return }
            for event in self.parser.finish() { self.receive(event) }
            self.ended(status)
        }
        do {
            transport = child
            try child.start(executable: executable, folder: folder, lock: CLIInstallation.lockURL(folder: folder))
            diagnostics.record("Remote Control process started")
            startupDeadline?.cancel()
            startupDeadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.confirmationTimeout ?? 90))
                guard !Task.isCancelled, let self, self.state.generation == generation,
                      self.state.phase == .starting else { return }
                self.state.fail("Claude hasn't reported a session link. Complete setup in Terminal, then try again.")
                self.transport?.interrupt()
                self.attention()
            }
            refreshPower()
        } catch {
            transport = nil
            failSetup(.runner)
            _ = state.exited(code: 1)
        }
    }

    private func receive(_ event: CLIEvent) {
        switch event {
        case .registered(let url):
            guard networkAvailable, !sleeping else { parser.invalidateConnection(); return }
            state.registered(url)
            if state.phase == .online {
                startupDeadline?.cancel()
                recoveryDeadline?.cancel()
                recoveryDeadline = nil
                diagnostics.record("Claude reported a session link")
            }
        case .setup(let issue):
            guard state.wantsRunning else { return }
            failSetup(issue)
            transport?.interrupt()
        case .reconnecting:
            state.interrupted("Claude is restoring its connection…")
            diagnostics.record("CLI reported a connection interruption")
            awaitReconnection()
        }
        refreshPower()
    }

    private func ended(_ status: Int32) {
        transport = nil
        startupDeadline?.cancel()
        recoveryDeadline?.cancel()
        recoveryDeadline = nil
        diagnostics.record("Remote Control exited (\(status))")
        let effectiveStatus: Int32 = restartAfterExit && state.wantsRunning ? 1 : status
        restartAfterExit = false
        if let delay = state.exited(code: effectiveStatus) {
            scheduleRetry(delay)
        } else if state.phase == .attention { attention() }
        refreshPower()
        if !isBusy { activeFolder = nil; onFullyStopped?() }
    }

    private func scheduleRetry(_ delay: TimeInterval) {
        pending?.cancel()
        let token = operation
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay * (self?.retryDelayScale ?? 1)))
            guard !Task.isCancelled, let self, self.operation == token, self.state.wantsRunning else { return }
            guard self.networkAvailable, !self.sleeping else {
                self.state.interrupted("Waiting for this Mac's connection…")
                return
            }
            self.launch(userInitiated: false)
        }
    }

    func stop(explicit: Bool = true) {
        if explicit { preferences.manuallyStopped = true }
        operation = UUID()
        pending?.cancel()
        startupDeadline?.cancel()
        recoveryDeadline?.cancel()
        recoveryDeadline = nil
        restartAfterExit = false
        checking = false
        state.stop()
        if let transport { transport.interrupt() }
        else { _ = state.exited(code: 0); activeFolder = nil; onFullyStopped?() }
        diagnostics.record("Stop requested")
        refreshPower()
    }

    private func networkChanged(_ available: Bool) {
        networkAvailable = available
        guard state.wantsRunning else { return }
        if !available {
            parser.invalidateConnection()
            recoveryDeadline?.cancel()
            recoveryDeadline = nil
            state.interrupted("Waiting for a network connection…")
        } else if !sleeping, transport == nil, !checking {
            // Reuse the allocated attempt instead of consuming attempts while offline.
            scheduleRetry(2)
        } else if state.phase == .reconnecting {
            state.interrupted("Network restored. Waiting for Claude to reconnect…")
            awaitReconnection()
        }
        refreshPower()
    }

    private func awaitReconnection() {
        guard networkAvailable, !sleeping, state.wantsRunning, transport != nil,
              recoveryDeadline == nil else { return }
        let generation = state.generation
        recoveryDeadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.confirmationTimeout ?? 90))
            guard !Task.isCancelled, let self, self.state.generation == generation,
                  self.state.phase == .reconnecting, self.state.wantsRunning else { return }
            self.restartAfterExit = true
            self.diagnostics.record("Reconnection confirmation timed out")
            self.transport?.interrupt()
        }
    }

    private func failSetup(_ issue: SetupIssue) {
        recoveryDeadline?.cancel()
        recoveryDeadline = nil
        state.requireSetup(issue)
        diagnostics.record("Setup required: \(issue.rawValue)")
        refreshPower()
        attention()
    }

    private func attention() {
        if preferences.notifications { services.notifyAttention(state.detail) }
    }

    private func refreshPower() {
        power.update(enabled: preferences.keepAwake, running: state.ownsProcess && state.wantsRunning && !sleeping)
    }

    func openSession() {
        guard state.canOpenSession, let url = state.sessionURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copySession() {
        guard state.canOpenSession, let url = state.sessionURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    func copyDiagnostics() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development"
        let text = "Beamlet \(version)\nState: \(state.phase.rawValue)\n" + diagnostics.entries.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
