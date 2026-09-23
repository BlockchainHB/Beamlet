# Glass and motion review

Scope: menu panel, Settings navigation, General, Connection, About, setup/diagnostics disclosure, QR, copy feedback, loading/error states, and native window controls.

## Glass implementation

Apple recommends the native glass button styles for standard actions. Beamlet now uses `glassProminent` instead of its custom ButtonStyle, manual press scale, opacity, and foreground-color heuristics. The system owns the glass control's interaction. [Apple: Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Apple: glassProminent](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent).

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM, fixed in source | Sources/App/BeamletSurface.swift:25 | Custom interactive glass plus manual press scale and inactive color overrides | Native `glassProminent`, capsule shape, existing coral tint | Avoid competing custom/system feedback and use the standard control's state handling. |
| LOW, fixed in source | Sources/App/BeamletSurface.swift:29 | Solid fallback for older macOS and Reduce Transparency | Solid fallback also under Increase Contrast | Preserve readable control boundaries without relying on glass. |
| MEDIUM, fixed in source | Sources/App/SettingsView.swift:337 | Settings stayed in accessory mode, lacked minimize support | Native close/minimize controls and foreground activation while Settings is open; menu-bar operation remains independent | Make Settings discoverable in the Dock and preserve normal window controls. No Done button. |

There is one explicit Liquid Glass control in the panel. A `GlassEffectContainer` would provide no multi-element composition benefit here. The Settings sidebar deliberately remains a native `NSVisualEffectView` with `.sidebar` material; content groups remain readable surfaces. No glass layers were added to forms, QR codes, status text, or every row. No glass morphing is needed because there is no group of glass surfaces joining/splitting.

Build and the existing 19 tests passed. The corrected preview was checked live: native close keeps the process running and switches it to accessory mode; reopening restores the Settings window; minimizing retains foreground/Dock presence and reopening restores it. The retained window reference and synchronous close observer resolve the earlier inaccessible-window issue. The panel's native glass button appearance and accessibility display settings have not been exhaustively exercised.

### Native window control appearance

Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) guidance says standard controls adopt the refreshed appearance when rebuilt with the current SDK. Beamlet already uses AppKit's actual standard window buttons; no custom traffic-light drawing is necessary.

Local evidence: Xcode 27's SwiftPM backend compiled against SDK 27 but recorded `sdk 14.0` in the executable's `LC_BUILD_VERSION`, reproducible in a fresh scratch build. Switching `scripts/build-local.sh` to `--build-system native` with the selected SDK records `minos 14.0` and `sdk 27.0`. This preserves the deployment minimum and enables the current native appearance. The rebuilt Settings preview visibly has refreshed traffic lights, switches, and grouped form styling, with no extra toolbar or Done button. The green zoom control remains disabled because the Settings content has a fixed size; this is separate from glass styling. See [Apple: Tailor macOS windows with SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10148/).

## Animation opportunity audit (read-only)

The supplied `find-animation-opportunities` skill is a search/report skill. No new animation is implemented from this audit. Frequencies below are expectations for this utility, not measured usage.

| # | Location | Today | Purpose | Frequency | Suggested motion |
| --- | --- | --- | --- | --- | --- |
| 1 | Sources/App/SessionPanel.swift:54 | Copy action swaps a link icon for a checkmark instantly; the label confirms success | Feedback | Occasional, pointer-initiated copies only | Optional: crossfade only the fixed-width icon with opacity 0→1 over 150ms, curve `(0.23, 1, 0.32, 1)`. Update the text immediately. Reduce Motion: opacity only over 80ms. Keyboard activation: immediate, no animation. Do not animate width or row position. |

The candidate passes the gate: infrequent feedback, clear confirmation purpose, 150ms budget, and no movement of readable information. It is optional; the current checkmark and text already communicate success.

### Rejected candidates

- `Sources/App/SettingsView.swift:39` — sidebar page slides/staggers. Rejected by frequency/keyboard gate; navigation must stay immediate.
- `Sources/App/SessionPanel.swift:59` — animating the whole panel's height when revealing QR. Rejected by function gate; the menu panel must stay stable and the code should be immediately scannable. Keyboard activation is also disqualifying.
- `Sources/App/SessionPanel.swift:20` — bouncing or morphing Online/Offline text. Rejected by function gate; this is connection information the user needs to read. Keep the native progress indicator during genuinely pending work.
- `Sources/App/SettingsView.swift:166,217` — custom staggered setup/diagnostic entrances. Rejected by function gate; instructional text and logs need stable positions. Native disclosure behavior is sufficient.
- `Sources/App/BeamletSurface.swift:38` — springy row hover or press movement. Rejected by frequency gate; immediate shading already supplies feedback.

Buttons use native feedback; there are no custom drag interactions, toast queues, celebration/first-run sequences, or dynamic list inserts that warrant an additional motion system. Form switches and window minimization remain system-owned. Error text and permission-state changes remain direct and readable.

### Verdict

The app needs very little added motion. Replacing the custom glass button behavior with the native control is the most valuable simplification. The only optional new animation is copy-confirmation icon feedback. If selected later, the read-only skill's implementation handoff is `improve-animations plan pointer-only copy-confirmation opacity crossfade`.

Approve the corrected window lifecycle and native SDK appearance based on the live preview checks above. The source-level glass and motion review is complete; panel glass rendering and accessibility display variants remain limited verification areas. No performance measurements are claimed.
