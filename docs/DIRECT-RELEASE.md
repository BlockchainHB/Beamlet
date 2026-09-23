# Direct distribution

Beamlet ships through GitHub Releases. The `Beamlet` scheme is the direct build; `BeamletStore` is an experimental, nonshipping target.

## Current status

The first public beta is being prepared. Developer ID export now passes: all seven executables have matching team signatures, hardened runtime and secure timestamps. Apple has received the build through Xcode for notarization; acceptance and final packaged-app verification are pending. The universal direct Release archive and its layout validator pass; 19 Swift regression tests and five PTY lifecycle tests pass.

The first release uses manual downloads from GitHub. Sparkle is present but unconfigured: no background update requests or automatic installations. Settings links to Releases. A future automatic-update rollout must establish a signing key, signed appcast, update-host privacy disclosure and upgrade test first.

## One-time owner setup

1. In Xcode → Settings → Accounts → your Apple Developer team → Manage Certificates, create a **Developer ID Application** certificate. The private key must remain in your Keychain.
2. Set the non-secret `BEAMLET_TEAM_ID` environment variable to the Apple team that owns the certificate.
3. Prefer the Xcode account route below if Xcode is already signed in. Alternatively, configure a `notarytool` Keychain profile or use Xcode Organizer's Developer ID distribution workflow. For the CLI, run `xcrun notarytool store-credentials Beamlet-Notary` yourself in Terminal and answer its secure prompts. Do not paste credentials into chat, shell history, source files, or GitHub issues.
4. Set `BEAMLET_NOTARY_PROFILE=Beamlet-Notary` when using the script. A profile name is not a credential.

Apple's [Developer ID documentation](https://developer.apple.com/developer-id/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) describe these requirements.

## Build → sign → notarize → package

Run from a clean checkout of the release commit with the selected Xcode toolchain:

```sh
bash scripts/release.sh archive
BEAMLET_TEAM_ID=YOUR_TEAM_ID bash scripts/release.sh export
bash scripts/release.sh notarize-xcode
bash scripts/release.sh finish-notarization-xcode
bash scripts/release.sh package
```

- `archive` builds Release for both Apple Silicon and Intel, with real Icon Composer assets. It seeds ad-hoc hardened-runtime flags on the app and runner because Xcode preserves those flags during export. These intermediate signatures are not distribution signatures.
- `export` requires an existing Developer ID Application identity and delegates nested signing to Xcode. It does not create certificates or ask for account credentials.
- `notarize-xcode` uploads for notarization using the account already signed into Xcode. `finish-notarization-xcode` exports the accepted app and validates its ticket. If Apple reports processing, wait and retry the finish stage; do not re-upload. No separate password is needed for this route.
- As an alternative, `notarize` uses a `BEAMLET_NOTARY_PROFILE` Keychain profile and records the submission ID locally. If waiting is interrupted, resume with `finish-notarization`; do not resubmit the same build just to poll it.
- `finish-notarization` requires Apple's Accepted result before stapling, then checks the ticket and Gatekeeper assessment.
- `package` refuses an app without a valid stapled ticket. It preserves framework symlinks with `ditto` and creates a versioned universal ZIP and SHA-256 checksum in `build/release/`.

If using Organizer to notarize, place its exported `Beamlet.app` in `build/DeveloperID/` and run the validator with `--notarized`, then the package stage. Never substitute the ad-hoc app from `build-local.sh`.

The validator checks every Mach-O executable for Developer ID signing, consistent team, secure timestamp and hardened runtime. It rejects common development/weakening entitlements, validates nested signatures, and checks architecture, privacy and license resources. It verifies the package; it does not replace functional QA.

## Verify the actual download

1. Extract the final ZIP into a fresh folder and run `python3 scripts/validate-release.py /path/to/Beamlet.app --notarized`.
2. Confirm normal first launch, menu bar panel, Settings traffic lights, manual update link and notification behavior.
3. With a configured Claude account, confirm Start → Online → usable remote session → Stop. Confirm Quit ends the owned process, and does not terminate unrelated terminal sessions.
4. Confirm workspace selection and sign-in errors remain actionable on a clean user profile.
5. Record the tested macOS, CPU, Claude CLI version and source commit in the release notes. Do not infer older macOS/Intel runtime coverage from universal compilation.

## Publish

The initial version is a **prerelease** while broader OS/hardware coverage is pending. Create a draft against the exact commit, attach only validated assets, and inspect the draft before publishing. Release notes live in `docs/releases/`.

```sh
gh release create v0.1.0 --repo BlockchainHB/Beamlet --target EXACT_COMMIT \
  --draft --prerelease --title 'Beamlet 0.1.0 — Public Beta' \
  --notes-file docs/releases/v0.1.0.md

gh release upload v0.1.0 --repo BlockchainHB/Beamlet \
  build/release/Beamlet-0.1.0-universal.zip \
  build/release/Beamlet-0.1.0-universal.zip.sha256
```

Do not overwrite a published artifact. Fixes use a new version/build/tag. After publication, verify the downloaded checksum and signature and update the README/site to the exact public download. GitHub's `releases/latest` endpoint does not select prereleases; use the explicit beta tag or the releases index.

Signing keys, profiles, archives and internal release drafts remain ignored by Git. Repository license and bundled dependency notices are retained in the app. No command in this guide disables Gatekeeper or strips quarantine.
