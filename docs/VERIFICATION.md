> Historical implementation checks follow. The current distribution route is GitHub; see [DIRECT-RELEASE.md](DIRECT-RELEASE.md). For the nonshipping store experiment, see [APP-STORE-BUILD.md](APP-STORE-BUILD.md).

# Verification and release gates

Completion requires evidence for every row. Tests against fixtures do not prove real CLI compatibility.

| Gate | Evidence required | Current status |
| --- | --- | --- |
| Planning before implementation | Product plan, ADRs, design, glossary committed to workspace first | Written |
| Native build | Reproducible Xcode build for macOS 14+, launchable app bundle | Pending |
| CLI discovery/setup | Missing executable, auth, trust, and consent paths visibly actionable | Auth error observed in installed CLI |
| Actual connection | Authenticated CLI start, usable link, mobile/browser confirmation | Blocked on CLI login |
| Honest status | Captured supported events, URL validation, malformed/unknown output, network/sleep invalidation | Pending |
| Ownership | External process untouched; simultaneous starts prevented; stale callbacks ignored | Pending |
| Stop and Quit | SIGINT behavior and children shutdown verified; no delayed restart | Pending |
| Recovery | Three backoff attempts, no auth retry, no fast-crash reset loophole | Pending |
| Sleep/wake | Assertion creation/release, battery policy, network restoration | Pending |
| Preferences | Login integration, folder persistence, manual-stop persistence | Pending |
| UI | Rendered light/dark states, keyboard and accessibility checks, QR/link actions | Pending |
| Diagnostics | Bounds, redaction, no raw transcript persistence or analytics | Pending |
| Updates | Sparkle wired, active-session installation gate tested, valid signed update installed | Pending real feed/key |
| Distribution | Developer ID archive export, notarization, staple verification | Developer ID certificate not listed |
| Release documentation | Reproducible release steps, configuration, ownership, known limits | Pending |

## Focused adversarial tests

Chunk-split URLs/escape sequences; ANSI and carriage-return output; malformed or hostile URL hosts; setup errors preceding exit; exit before output drains; double Start; Stop during backoff; Quit during startup; stale termination callbacks; repeated quick registrations/crashes; executable/folder paths with spaces; network loss without exit; laptop sleep; missing directory; conflicting external server; shutdown timeout; app termination; update while active; secrets and paths in diagnostic messages.

## Release configuration still needed

Final GitHub repository/HTTPS appcast URL, Sparkle public signing key generated via its tools with private material retained in Keychain, Developer ID Application signing identity and notarization profile. Do not publish or invent these values. Local code and UI can be completed before this configuration exists, but a live update or signed public release must not be claimed verified.
