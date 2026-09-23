# Panel and Settings polish — 23 September 2026

Applied better-ui and emil-design-eng to the existing native SwiftUI surfaces. This review covers the implementation and the explicitly observed states below; it is not public-release approval.

## Surface consistency and hierarchy

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM, fixed | Sources/App/SettingsView.swift:30 | One 740-point scrolling settings form | 700×540 native window, fixed General / Connection / About sidebar | Stable navigation and shorter groups make controls easier to find. User explicitly chose a sidebar. |
| MEDIUM, fixed | Sources/App/SessionPanel.swift:132; Sources/App/BeamletSurface.swift:59 | Plain rows without hover/press treatment; all icons coral | Consistent regular-weight secondary icons, immediate row feedback, shortcut hints | Optical weight and motion restraint make frequent actions clear without drawing attention away from status. |
| LOW, fixed | Sources/App/SessionPanel.swift:64 | Container and row corners had no shared inset geometry | 16-point outer radius, 6-point inset, 10-point row radius | Concentric corners keep hover surfaces aligned with their container. |
| LOW, fixed | Resources/Info.plist:7; Resources/Beamlet.icns | No bundled app icon | Original cream Beamlet mark on a coral rounded tile, all macOS icon sizes | Gives permission prompts and other system surfaces a recognizable app identity. |
| MEDIUM, fixed | Sources/App/SettingsView.swift:31; Sources/App/SettingsView.swift:334 | Automatic split-view toolbar with redundant title and collapse button | Fixed sidebar, no toolbar, compact titleless native window controls | Remove unnecessary navigation and prevent accidental sidebar dismissal. |
| LOW, fixed | Sources/App/SettingsView.swift:72 | Native Label symbol spacing varied by glyph | 18-point symbol column, 10-point label gap, regular 13-point font and shorter brand-to-navigation gap | Consistent optical alignment; the native list retains keyboard selection. |
| LOW, fixed | Sources/App/BeamletSurface.swift:72 | Disabled text combined secondary color with reduced opacity | Primary text at 50% opacity | Keeps unavailable actions readable without making them appear enabled. |
| MEDIUM, fixed | Sources/App/SettingsView.swift:49; Sources/App/SettingsView.swift:337 | One flat title-bar strip spanning both columns | Each column extends its own background beneath the transparent title bar; native behind-window sidebar material on the left | Continuous surfaces match the Settings reference while content stays below window controls. Light appearance visually verified; this latest material change has not been rechecked in dark appearance. |

## Feedback and motion restraint

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM, fixed | Sources/App/SettingsView.swift:285; Sources/App/SystemServices.swift:77 | Allow notifications stayed visible after approval | Observable macOS authorization status; request only while undetermined; Settings action after denial; refresh on app activation | Feedback must represent the current state, with a useful action after denial. |
| MEDIUM, fixed | Sources/App/SessionPanel.swift:57 | QR layout animated even for keyboard activation | Immediate expansion | Frequent and keyboard actions should not be delayed by decorative layout motion. |
| LOW, fixed | Sources/App/BeamletSurface.swift:37 | Primary control only changed opacity on press | 0.96 pointer-press scale; static with Reduce Motion or keyboard input | Precise tactile feedback with accessible motion restraint. No custom timing or entrance animations. |
| LOW, fixed | Sources/App/SettingsView.swift:73 | Multiline switch labels exposed descriptions as their names | Explicit accessible switch names and relevant hints | Preserve clear names while retaining explanatory copy. |

## Verification

- SwiftPM build and local app packaging passed. XcodeGen project regenerated with the icon in its resource build phase.
- All 19 existing Swift tests passed on the final test run. The recovery integration test intermittently hit its 120ms startup deadline before the real PTY process could report its state. Its test-only deadline is now one second with a 12-second overall wait; the three-retry and cleared-link assertions are unchanged. Production timing is unchanged. The final run passed all 19 tests.
- Plist validation and strict deep verification of the local ad-hoc signature passed. This is not Developer ID signing or notarization.
- Visually inspected the light panel and the dark panel in Offline, Online, and expanded QR states; inspected all three Settings pages in light and dark appearance. General fits without scrolling; Connection shows chosen paths and setup in both collapsed and expanded states without clipping; About shows version, honest unconfigured updater, privacy text, and diagnostics.
- Verified the redundant permission button is absent in the running Settings preview. Inspected authorization refresh and denied/not-determined/error/loading branches in source.
- Expanded diagnostics through the actual disclosure arrow and verified the local events and Copy diagnostics control appear.
- Verified arrow-key navigation among all three sidebar sections and correct selected-state labels. The accessibility tree contains no toolbar or sidebar toggle.
- Verified keyboard Start reaches Online, QR expansion fits, and keyboard Stop returns Offline, clears the link actions, and collapses QR. Stopped the preview-owned connection after testing.
- Inspected offline, starting, reconnecting, stopping, attention, disabled, copied-link, QR, hover/pressed, and reduced-motion implementations in source. No connection lifecycle policy changed in this polish pass.
- Inspected the generated icon bitmap and verified the icon is packaged in both local and Xcode builds.

Not verified: a fresh macOS permission prompt displaying the new icon; live permission denial/revocation and System Settings deep link; accessibility display options in the running redesigned views; VoiceOver speech and complete keyboard traversal beyond sidebar and Start/Stop; slow-motion inspection of native system glass. Existing Xcode installation issues still prevent the full Xcode archive workflow.

The open Beamlet Settings Preview uses the same Settings view as the app, with a separate debug bundle identity. The regular app has also been rebuilt, but an already-running old instance needs restarting to load it.

Approve for the inspected UI-polish scope. The unverified checks above remain outstanding.
