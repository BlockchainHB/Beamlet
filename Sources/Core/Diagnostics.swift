import Foundation

public struct Diagnostics {
    public private(set) var entries: [String] = []
    private let limit: Int
    public init(limit: Int = 100) { self.limit = max(1, limit) }

    public mutating func record(_ message: String, now: Date = Date()) {
        entries.append("\(now.formatted(.iso8601))  \(Self.redact(message))")
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
    }

    public static func redact(_ message: String) -> String {
        var value = String(message.prefix(2048))
        let patterns = [
            #"\x1B\[[0-?]*[ -/]*[@-~]"#,
            #"https?://[^\s]+"#,
            #"(?i)(?:sk-ant-|sk-|bearer\s+)[A-Za-z0-9_./+\-=]+"#,
            #"(?i)(?:token|secret|password|api[_-]?key)\s*[:=]\s*[^\s,;]+"#,
            #"/(?:Users|home)/[^\s]+"#,
            #"session_[A-Za-z0-9_-]+"#
        ]
        for pattern in patterns {
            value = value.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
        }
        return value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init).joined()
    }
}
