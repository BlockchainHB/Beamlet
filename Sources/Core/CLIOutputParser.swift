import Foundation

public enum CLIEvent: Equatable, Sendable {
    case registered(URL)
    case setup(SetupIssue)
    case reconnecting
}

/// Retains only a bounded transient line. Never expose raw CLI output to diagnostics/UI.
public struct CLIOutputParser {
    private var line: [UInt8] = []
    private var escape: Escape = .none
    private enum Escape { case none, start, csi, osc, oscEnd }
    private var lastURL: URL?
    private var lastSetup: SetupIssue?
    public init() {}

    /// OS sleep/network events invalidate evidence even if the CLI hasn't printed an error.
    public mutating func invalidateConnection() {
        lastURL = nil
        line.removeAll(keepingCapacity: true)
        escape = .none
    }

    public mutating func consume(_ data: Data) -> [CLIEvent] {
        var events: [CLIEvent] = []
        for byte in data {
            switch escape {
            case .start:
                escape = byte == 91 ? .csi : byte == 93 ? .osc : .none
                continue
            case .csi:
                if (64...126).contains(byte) { escape = .none }
                continue
            case .osc:
                if byte == 7 { escape = .none }
                else if byte == 27 { escape = .oscEnd }
                continue
            case .oscEnd:
                escape = byte == 92 ? .none : .osc
                continue
            case .none: break
            }
            if byte == 27 { escape = .start; continue }
            if byte == 10 || byte == 13 {
                events += parseLine(String(decoding: line, as: UTF8.self))
                line.removeAll(keepingCapacity: true)
            } else if byte >= 32 || byte == 9 {
                line.append(byte)
                if line.count > 16_384 { line.removeFirst(line.count - 16_384) }
            }
        }
        // Consent questions can have no trailing newline. Never accept a partial URL here.
        let partial = String(decoding: line, as: UTF8.self).lowercased()
        if partial.contains("enable remote control?"), lastSetup != .consent {
            lastSetup = .consent
            events.append(.setup(.consent))
        }
        return events
    }

    public mutating func finish() -> [CLIEvent] {
        defer { line.removeAll() }
        return parseLine(String(decoding: line, as: UTF8.self))
    }

    public static func validatedSessionURL(_ text: String) -> URL? {
        guard let parts = URLComponents(string: text), parts.scheme == "https",
              parts.host == "claude.ai", parts.user == nil, parts.password == nil,
              parts.port == nil, parts.fragment == nil
        else { return nil }
        if parts.path.range(of: #"^/code/session_[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return parts.url
        }
        // Current server-mode CLI exposes an environment link before a session is attached.
        if parts.path == "/code", let query = parts.queryItems, query.count == 1,
           query[0].name == "environment", let identifier = query[0].value,
           identifier.range(of: #"^[A-Za-z0-9_-]{1,256}$"#, options: .regularExpression) != nil {
            return parts.url
        }
        return nil
    }

    private mutating func parseLine(_ text: String) -> [CLIEvent] {
        let lower = text.lowercased()
        let issue: SetupIssue?
        if lower.contains("must be logged in") || lower.contains("/login to sign in") ||
            lower.contains("full-scope login") || lower.contains("subscription auth") ||
            lower.contains("requires a claude.ai subscription") { issue = .login }
        else if lower.contains("workspace not trusted") { issue = .trust }
        else if lower.contains("enable remote control?") { issue = .consent }
        else if lower.contains("remote control is disabled") || lower.contains("remote control isn't enabled") ||
            lower.contains("remote control is not yet enabled") || lower.contains("only available when using claude") ||
            lower.contains("requires feature-flag evaluation") { issue = .policy }
        else if lower.contains("unknown command") || lower.contains("unknown option") { issue = .unsupported }
        else if lower.contains("beamlet_runner_error") { issue = .runner }
        else { issue = nil }
        if let issue, lastSetup != issue {
            lastSetup = issue
            return [.setup(issue)]
        }
        if lower.contains("reconnecting") || lower.contains("server unreachable") ||
            lower.contains("connection lost") || lower.contains("network connection lost") {
            lastURL = nil
            return [.reconnecting]
        }
        guard lastSetup == nil else { return [] }
        guard let regex = try? NSRegularExpression(pattern: #"https://[^\s<>\"'\x1B]+"#) else { return [] }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let candidate = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ").,;"))
            if let url = Self.validatedSessionURL(candidate), url != lastURL {
                lastURL = url
                return [.registered(url)]
            }
        }
        return []
    }
}
