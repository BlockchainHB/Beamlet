import XCTest
@testable import BeamletCore

final class LifecycleTests: XCTestCase {
    func testRepeatedQuickConnectionsCannotResetRetryBudget() {
        var state = SessionState()
        let now = Date()
        state.begin(userInitiated: true)
        for expected in [2.0, 5.0, 15.0] {
            state.registered(URL(string: "https://claude.ai/code/session_test")!, now: now)
            XCTAssertEqual(state.exited(code: 1, now: now.addingTimeInterval(1)), expected)
            state.begin(userInitiated: false)
        }
        state.registered(URL(string: "https://claude.ai/code/session_test")!, now: now)
        XCTAssertNil(state.exited(code: 1, now: now.addingTimeInterval(1)))
        XCTAssertEqual(state.phase, .attention)
        XCTAssertFalse(state.isBusy)
    }

    func testStopDuringBackoffNeverRestarts() {
        var state = SessionState()
        state.begin(userInitiated: true)
        XCTAssertNotNil(state.exited(code: 1))
        state.stop()
        XCTAssertFalse(state.wantsRunning)
        XCTAssertEqual(state.phase, .offline)
    }

    func testLateRegistrationCannotReviveStoppedSession() {
        var state = SessionState()
        state.begin(userInitiated: true)
        state.stop()
        state.registered(URL(string: "https://claude.ai/code/session_test")!)
        XCTAssertEqual(state.phase, .stopping)
        XCTAssertNil(state.sessionURL)
        XCTAssertNil(state.exited(code: 130))
        XCTAssertEqual(state.phase, .offline)
    }

    func testSetupErrorSurvivesExitWithoutRetry() {
        var state = SessionState()
        state.begin(userInitiated: true)
        state.requireSetup(.login)
        XCTAssertTrue(state.ownsProcess)
        XCTAssertNil(state.exited(code: 1))
        XCTAssertEqual(state.issue, .login)
        XCTAssertEqual(state.phase, .attention)
        XCTAssertFalse(state.ownsProcess)
    }

    func testHealthyIntervalResetsRetryBudgetAndCleanExitStaysStopped() {
        var state = SessionState()
        state.begin(userInitiated: true)
        _ = state.exited(code: 1)
        state.begin(userInitiated: false)
        let now = Date()
        state.registered(URL(string: "https://claude.ai/code/session_test")!, now: now)
        XCTAssertEqual(state.exited(code: 1, now: now.addingTimeInterval(61)), 2)
        state.begin(userInitiated: false)
        XCTAssertNil(state.exited(code: 0))
        XCTAssertFalse(state.wantsRunning)
    }

    func testConnectivityLossInvalidatesLink() {
        var state = SessionState()
        state.begin(userInitiated: true)
        state.registered(URL(string: "https://claude.ai/code/session_test")!)
        state.interrupted("Network unavailable")
        XCTAssertEqual(state.phase, .reconnecting)
        XCTAssertFalse(state.canOpenSession)
        XCTAssertNil(state.connectedAt)
    }
}
