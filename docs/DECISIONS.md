# Architecture decisions

## ADR 001 — Native app with a single lifecycle owner

Accepted. Use SwiftUI `MenuBarExtra` with window style, an AppKit application delegate for termination, and one main-actor controller for the running session. A typed reducer owns transitions and retry budgeting; the controller performs effects. Views read state and send actions. Keep process details out of views and use a narrow transport boundary for tests.

Avoid a permanent daemon: the user explicitly wants Quit to stop the process. A local process supervisor/PTY transport may be necessary for terminal consent/output behavior; it must be owned by Beamlet and shut down on app termination. No process-name-wide killing or persisted-PID termination.

## ADR 002 — CLI remains the execution authority

Accepted. Launch the installed executable with argument arrays and an explicit working directory. Resolve known install locations and allow an executable override; do not execute arbitrary login shell scripts merely to find PATH. Never read auth tokens or implement Anthropic's private APIs. Do not automatically answer trust or consent prompts.

Start with `remote-control` and documented conservative flags only where installed-version evidence supports them. Use a PTY when needed for CLI terminal behavior; keep raw transport output transient and out of logs. Maintain an adapter with captured, sanitized fixtures for supported output shapes. An unknown shape must yield uncertainty, not fabricated online state.

## ADR 003 — Evidence-based status and bounded recovery

Accepted. Distinguish process existence, session registration, and connection health. A validated session URL proves registration, not indefinite ongoing connectivity. Recognized connection events drive online/reconnecting state; unknown output must not invent state. OS network loss and sleep invalidate online state. Add a startup deadline and handle hung shutdown.

Retry transient termination at 2, 5, and 15 seconds. Reset the consecutive retry budget only after a sustained healthy interval (60 seconds), not merely after a new URL, preventing fast crash loops. Authentication, trust, consent, unsupported CLI, and missing executable failures stop retries. Explicit Stop cancels pending retries before signaling. Every asynchronous event has a generation identity so stale output/exit callbacks cannot revive a stopped or replaced session.

Use SIGINT for normal stop. If it fails to exit, report stopping and escalate only against positively owned processes after a bounded grace period. Distinguish an unexpectedly dead app from a normal quit; do not trust old PID files. Inspect authoritative process identity before identifying a conflict, and do not signal external processes.

## ADR 004 — Local settings and diagnostics

Accepted. UserDefaults stores preferences only. No credentials or conversation data. Diagnostics store fixed event categories and scrubbed short messages; redact links, home paths, tokens, and control sequences before retaining. Copying diagnostics is explicit. Keep a bounded in-memory history; avoid saving raw CLI output.

Use native ServiceManagement for login item preferences and IOKit assertions for idle-sleep prevention. Release assertions immediately on stop/failure/quit or battery transition. Network/sleep listeners must be removable and not create duplicate recovery timers.

## ADR 005 — Distribution and updates

Accepted. XcodeGen project, Swift Package Manager for Sparkle, application bundle with hardened runtime for releases. No App Sandbox entitlement: the app must run the user's CLI and access selected developer folders. This does not disable Claude Code's own sandbox or permissions.

Sparkle owns signed update verification. No feed URL, public signing key, or public repository will be invented. Local builds explicitly indicate updates are not configured until real release configuration exists. Block update installation/relaunch while Remote Control or its shutdown is active; defer rather than silently stop work. Keep update telemetry/system-profile collection disabled. Public release uses Developer ID signing and notarization, then a signed appcast. Local development signing is not proof of distributability.

## Sources

- https://code.claude.com/docs/en/remote-control
- https://developer.apple.com/documentation/swiftui/menubarextra
- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/programmatic-setup/
