import XCTest
@testable import BeamletCore

final class ParserTests: XCTestCase {
    func testEveryByteBoundaryWithANSIAndUnicode() {
        let text = "\u{1b}[32m✦ https://claude.ai/code/session_abc123?foo=bar\u{1b}[0m\r\n"
        let data = Data(text.utf8)
        for split in 0...data.count {
            var parser = CLIOutputParser()
            let events = parser.consume(data.prefix(split)) + parser.consume(data.suffix(data.count - split))
            XCTAssertEqual(events, [.registered(URL(string: "https://claude.ai/code/session_abc123?foo=bar")!)])
        }
    }

    func testRejectsUntrustedURLsAndNonSessions() {
        for text in ["https://claude.ai.evil.test/code/session_a", "https://claude.ai@evil.test/code/session_a",
                     "http://claude.ai/code/session_a", "https://claude.ai:444/code/session_a",
                     "https://claude.ai/code/onboarding", "https://claude.ai/code/session_a/other",
                     "https://claude.ai/code/session_a#fragment", "https://claude.ai/code?environment=",
                     "https://claude.ai/code?environment=env_a&environment=env_b",
                     "https://claude.ai/code?environment=env_a&redirect=https://evil.test",
                     "https://claude.ai/code?environment=https://evil.test",
                     "https://claude.ai/code?environment=env_a%0Aevil"] {
            XCTAssertNil(CLIOutputParser.validatedSessionURL(text))
        }
    }

    func testCurrentServerEnvironmentLinkAcrossEveryByteBoundary() {
        let url = URL(string: "https://claude.ai/code?environment=env_fixture123")!
        // Sanitized shape observed from the installed 2.1.281 server, 2026-09-23.
        let data = Data("\u{1b}[32m·✔︎· Connected · dev · HEAD\r\nContinue coding in the Claude mobile app or \(url.absoluteString)\r\n".utf8)
        for split in 0...data.count {
            var parser = CLIOutputParser()
            let events = parser.consume(data.prefix(split)) + parser.consume(data.suffix(data.count - split))
            XCTAssertEqual(events, [.registered(url)])
        }
    }

    func testOSInterruptionAllowsSameEnvironmentLinkAgain() {
        var parser = CLIOutputParser()
        let data = Data("https://claude.ai/code?environment=env_fixture\n".utf8)
        XCTAssertEqual(parser.consume(data).count, 1)
        parser.invalidateConnection()
        XCTAssertEqual(parser.consume(data).count, 1)
    }

    func testSetupErrorsAndPromptWithoutNewline() {
        var parser = CLIOutputParser()
        XCTAssertEqual(parser.consume(Data("Error: You must be logged in to use Remote Control.\n".utf8)), [.setup(.login)])
        XCTAssertTrue(parser.consume(Data("https://claude.ai/code/session_test\n".utf8)).isEmpty)
        parser = CLIOutputParser()
        XCTAssertEqual(parser.consume(Data("Enable Remote Control? (y/n) ".utf8)), [.setup(.consent)])
    }

    func testUnknownOutputIsNotOnline() {
        var parser = CLIOutputParser()
        XCTAssertTrue(parser.consume(Data("Connected to an MCP server\nDoing work\n".utf8)).isEmpty)
    }

    func testReconnectAllowsSameLinkAgain() {
        var parser = CLIOutputParser()
        let data = Data("https://claude.ai/code/session_test\n".utf8)
        XCTAssertEqual(parser.consume(data).count, 1)
        XCTAssertTrue(parser.consume(data).isEmpty)
        XCTAssertEqual(parser.consume(Data("Reconnecting…\n".utf8)), [.reconnecting])
        XCTAssertEqual(parser.consume(data).count, 1)
    }

    func testDiagnosticsBoundAndRedaction() {
        var log = Diagnostics(limit: 2)
        log.record("first")
        log.record("token=private-value /Users/alice/secret.txt https://claude.ai/code/session_secret")
        log.record("Authorization: Bearer abc123")
        XCTAssertEqual(log.entries.count, 2)
        let joined = log.entries.joined()
        for secret in ["alice", "secret.txt", "private-value", "abc123", "session_secret"] {
            XCTAssertFalse(joined.contains(secret))
        }
    }
}
