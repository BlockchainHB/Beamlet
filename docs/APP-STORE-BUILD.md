# App Store distribution work

Updated 2026-09-23. **A store-specific compatibility build exists; it is not submission-ready.**

## Implemented

- `BeamletStore` scheme and separate `BeamletRunnerStore` target.
- App Sandbox, outbound network and user-selected file permissions; app-scoped bookmarks.
- Sandboxed runner inherits its parent's sandbox. No private or temporary-exception entitlements.
- Store target neither links nor embeds Sparkle and does not expose a third-party update UI. Direct distribution retains its separate updater.
- Store selections persist security-scoped bookmarks, renew stale bookmarks and request reselection on errors. Selections cannot be replaced while the managed process is running.
- Store variant requires explicit file choices rather than silently looking in the host home directory. Its conflict detection does not claim visibility into unrelated processes.
- Privacy manifest for app-owned preferences, Developer Tools category, legal copyright, and links to the published privacy/terms/support site.
- Machine-local team selection through an ignored `Release.local.xcconfig`.

## Build and validate

Requires Xcode with Icon Composer support and XcodeGen. The source targets macOS 14; that minimum OS still needs runtime testing.

```sh
bash scripts/build-store.sh
```

This creates `build/BeamletStore.xcarchive` with locally signed sandboxed code. It defaults to ad-hoc signing and is **not an App Store distribution archive**. Xcode Organizer requires the actual team, valid distribution credentials/profile, final bundle registration and a functional reviewed implementation before upload.

To provide local team settings, copy `Config/Release.local.xcconfig.example` to `Release.local.xcconfig` at the repository root. Never commit certificates, private keys, provisioning profiles or account credentials.

The validator checks entitlements, nested signatures, required resources, absence of Sparkle and preview flags. It does not certify runtime compatibility or App Review eligibility.

## Verification performed

- Xcode Release build and archive: passed.
- Store packaging validator: passed.
- Swift app/core regression tests: 19 passed.
- Real PTY lifecycle tests: 5 passed, covering cleanup, duplicate ownership, final output and bounded termination.
- Sandboxed bundled-runner probe: `container_home=true`, `runner_exit=0`, `BEAMLET_SANDBOX_PTY_OK`.
- Installed Claude binary without a user selection grant: `runner_exit=127`, `BEAMLET_RUNNER_ERROR: executable unavailable`.
- Selected-executable probe: built successfully, but live native file-picker verification is blocked while the Mac is locked. This is a different test from the no-grant case above.
- Sign-in, live Remote Control and clean-machine sandbox flow: not verified.

Reproduce the safe supervisor test:

```sh
bash scripts/probe-sandbox.sh
# Optional: version-only test of your installed executable, without a file-picker grant.
bash scripts/probe-sandbox.sh /absolute/path/to/claude
```

For the native picker experiment, build `bash scripts/build-picker-probe.sh`, launch the resulting app from Finder, and select only the Claude executable. It runs `--version`; no account credentials or live sessions are needed.

## Remaining release blockers

The architecture still depends on separately installed Claude Code and its existing configuration/authentication. File access is not evidence of permission to execute arbitrary external code, inherit every dynamic grant, access external Keychain items or redistribute Claude. These must be validated through a supported design. The store target is explicitly labeled as a compatibility build in Settings until this work is resolved.

Do not upload the current build as a functional release or use an unsandboxed helper installer as an assumed workaround. Apple requires appropriately sandboxed, self-contained Mac apps; approval of other Claude-related utilities does not establish approval of this process-launching design.

A redistributable bundled runtime would require appropriate rights and supported authentication/tool access. A direct Developer ID-signed and notarized release remains a separate route if the core behavior cannot be preserved within App Store constraints.

## Public pages

- https://blockchainhb.github.io/Beamlet/privacy/
- https://blockchainhb.github.io/Beamlet/terms/
- https://blockchainhb.github.io/Beamlet/support/

The free/MIT/source-release choices and public support email were confirmed by the owner. Store submission, financial/legal account declarations and public binary release have not occurred.

## Primary references

- [Apple App Review Guidelines, 2.4.5 and 4.2.3](https://developer.apple.com/app-store/review/guidelines/)
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Sandbox file access and bookmarks](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Sandbox helper behavior](https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations)
- [Claude Remote Control](https://code.claude.com/docs/en/remote-control)
