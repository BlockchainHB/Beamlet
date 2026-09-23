import Foundation

public enum SessionPhase: String, Equatable, Sendable {
    case offline = "Offline"
    case starting = "Starting"
    case online = "Online"
    case reconnecting = "Reconnecting"
    case stopping = "Stopping"
    case attention = "Needs attention"
}

public enum SetupIssue: String, Error, Equatable, Sendable {
    case login, trust, consent, policy, unsupported, executable, folder, conflict, runner

    public var message: String {
        switch self {
        case .login: return "Sign in to Claude Code to enable Remote Control."
        case .trust: return "Open Claude Code in this folder and accept workspace trust."
        case .consent: return "Enable Remote Control once in Terminal to finish setup."
        case .policy: return "Claude's account, provider, or organization settings prevent Remote Control."
        case .unsupported: return "This Claude Code version doesn't support the requested command."
        case .executable: return "Choose your installed Claude Code executable in Settings."
        case .folder: return "Choose an existing starting folder other than your home folder."
        case .conflict: return "Remote Control is already running here outside Beamlet. Leave it running, or stop it in its own terminal."
        case .runner: return "The bundled process runner could not start. Reinstall Beamlet."
        }
    }
}

/// Pure lifecycle policy. Transport callbacks must match `generation` before calling it.
public struct SessionState: Equatable, Sendable {
    public private(set) var phase: SessionPhase = .offline
    public private(set) var detail = "Ready when you are."
    public private(set) var sessionURL: URL?
    public private(set) var issue: SetupIssue?
    public private(set) var generation = UUID()
    public private(set) var attempts = 0
    public private(set) var wantsRunning = false
    public private(set) var connectedAt: Date?
    public private(set) var ownsProcess = false

    public init() {}
    public var isBusy: Bool { wantsRunning || ownsProcess }
    public var canOpenSession: Bool { phase == .online && sessionURL != nil }

    public mutating func begin(userInitiated: Bool) {
        if userInitiated { attempts = 0 }
        wantsRunning = true
        ownsProcess = true
        generation = UUID()
        phase = .starting
        issue = nil
        sessionURL = nil
        connectedAt = nil
        detail = "Connecting this Mac to Claude…"
    }

    public mutating func registered(_ url: URL, now: Date = Date()) {
        guard wantsRunning, ownsProcess, phase != .stopping else { return }
        sessionURL = url
        phase = .online
        detail = "Ready in Claude on your other devices."
        if connectedAt == nil { connectedAt = now }
    }

    public mutating func interrupted(_ message: String) {
        guard wantsRunning, phase != .stopping else { return }
        phase = .reconnecting
        detail = message
        connectedAt = nil
        sessionURL = nil
    }

    public mutating func stop() {
        wantsRunning = false
        sessionURL = nil
        connectedAt = nil
        phase = ownsProcess ? .stopping : .offline
        detail = ownsProcess ? "Finishing the connection…" : "Remote Control is stopped."
        issue = nil
    }

    public mutating func requireSetup(_ error: SetupIssue) {
        wantsRunning = false
        issue = error
        phase = .attention
        detail = error.message
        sessionURL = nil
        connectedAt = nil
    }

    public mutating func fail(_ message: String) {
        wantsRunning = false
        phase = .attention
        detail = message
        sessionURL = nil
        connectedAt = nil
    }

    /// Returns one bounded retry delay. A clean CLI exit is intentional and stays stopped.
    public mutating func exited(code: Int32, now: Date = Date()) -> TimeInterval? {
        ownsProcess = false
        sessionURL = nil
        if phase == .attention { return nil }
        guard wantsRunning, code != 0 else {
            wantsRunning = false
            connectedAt = nil
            phase = .offline
            detail = "Remote Control is stopped."
            return nil
        }
        if let connectedAt, now.timeIntervalSince(connectedAt) >= 60 { attempts = 0 }
        connectedAt = nil
        let delays: [TimeInterval] = [2, 5, 15]
        guard attempts < delays.count else {
            fail("Couldn't reconnect after three attempts. Try again when you're ready.")
            return nil
        }
        let delay = delays[attempts]
        attempts += 1
        phase = .reconnecting
        detail = "Trying again in \(Int(delay))s · attempt \(attempts) of 3"
        return delay
    }
}
