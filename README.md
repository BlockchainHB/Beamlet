# Beamlet

**Claude, within reach.** A native macOS menu bar companion for Claude Code Remote Control.

Beamlet owns the `claude remote-control` process it starts, shows its connection state, and stops it when you press Stop or quit. Conversations stay in Claude's existing clients.

Status: source available; development builds only. No public binary or App Store release yet.

- [Product plan](docs/PLAN.md)
- [Architecture decisions](docs/DECISIONS.md)
- [Design specification](docs/DESIGN.md)
- [Glossary](docs/GLOSSARY.md)
- [Verification and release gates](docs/VERIFICATION.md)

Independent community utility; not an Anthropic product. Claude Code must already be installed. Its authentication, permissions, network connections, and data policies remain its own.

## Build

Install Xcode and XcodeGen, then:

```sh
bash scripts/build-local.sh
```

Open `build/Beamlet.app` to use the current direct-distribution development build.
The app requires a compatible Claude Code installation and completed login, workspace trust and Remote Control consent.

A separate `BeamletStore` scheme isolates sandboxing, privacy resources and App Store-only update behavior. See [App Store build status](docs/APP-STORE-BUILD.md) before using it: **App Sandbox blocks the current external CLI launch design; do not submit this build.**

## Support and policies

[Support](https://blockchainhb.github.io/Beamlet/support/) · [Privacy](https://blockchainhb.github.io/Beamlet/privacy/) · [Terms](https://blockchainhb.github.io/Beamlet/terms/)

Free and open source under the [MIT License](LICENSE). Third-party dependencies retain their own licenses.
