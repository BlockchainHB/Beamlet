# Beamlet product plan

## Outcome and authorization

Replace the need to keep a terminal open to start, monitor, and stop Claude Code Remote Control. macOS only; personal use first, with a public GitHub release intended later. The user authorized a build goal after a grouped planning interview. Do not publish source, releases, or X posts without authorization.

The requested `grill-with-docs` skill was read. Its entire operational instruction is to call the Skill tool for `grilling` and `domain-modeling`. Neither dependency was found in local skill locations, and no Skill tool is available. The grouped interview in this conversation supplied the requirements; these documents capture its decisions without claiming the missing workflow ran.

## Agreed requirements

- Name: Beamlet. Tagline: Claude, within reach.
- Native compact menu bar panel, original sunburst/connection mark, system light/dark appearance, restrained terracotta accent.
- macOS 14+; use newer system styling when available. SwiftUI and AppKit, not a browser shell.
- Assume installed Claude Code. Terminal may open during initial login, workspace trust, and consent.
- Remember one starting folder. Offer the user's `~/dev` when present; use a chooser for other users. Never silently use the home directory.
- Start the normal remote-control server; do not change global Claude permissions, models, settings, or authentication.
- States: offline, starting, online, reconnecting, stopping, needs attention. Process alive is not sufficient evidence of online.
- Stop means normal Ctrl+C-equivalent shutdown. Quit stops app-owned Remote Control too.
- Open/copy the validated HTTPS Claude session link and show a QR code. Do not invent a desktop deep-link protocol.
- Separate launch-at-login and auto-start settings. Optional keep-awake.
- Three retries with backoff for transient failures. Setup/auth/trust failures require intervention. No retry loop after explicit Stop.
- Leave externally started Claude processes alone; warn if a conflicting external server is detected in the chosen folder.
- Notify only on failed recovery or required setup. Local bounded diagnostic history, redacted before display/export, no transcript logging by default.
- No wrapper analytics or automatic crash uploads.
- Sparkle in-app updates; never automatically terminate an active Remote Control process to install an update.
- Signed/notarized GitHub distribution, with credentials retained in Keychain or release-secret storage.

## Final interview items: proposed defaults

These recommendations were asked but not individually answered before the build goal was authorized. Record them as defaults, not user-confirmed answers; all are reversible settings/behavior.

1. First-run login, auto-start, and keep-awake preferences are off.
2. Explicit Stop persists a suppression flag until Start is pressed again, including across relaunches.
3. Keep-awake prevents idle system sleep only on AC power; it does not promise closed-lid operation.
4. Folder changes while running apply on the next start; the UI explains this without silently restarting.

## Non-goals

Chat UI, terminal emulator UI, arbitrary external-process takeover, project orchestration, automatic CLI updates, custom remote transport, cloud backend, analytics, Windows, session billing/usage monitoring, disabling Claude permission prompts.

## Implementation order

1. Document contract and inspect installed CLI capabilities without launching unattended sessions.
2. Build a testable lifecycle model, output parser, bounded diagnostics, process ownership, and retry policy.
3. Add native panel/settings, login item, sleep/network integration, setup affordances, link/QR actions, and notifications.
4. Integrate Sparkle and reproducible local build/release scripts.
5. Verify failure paths with an explicit local fixture, inspect the rendered app, then verify real CLI startup/shutdown after login.

## Current evidence

2026-09-23: empty workspace; no Git repository. Xcode and XcodeGen available, Swift 6.4, host macOS 27. Installed Claude Code 2.1.234. `claude remote-control --help` exits 1 because Remote Control authentication is missing. The current online documentation includes newer features: capability assumptions must be tested, not copied blindly. Apple Development signing identity exists; Developer ID Application was not listed.
