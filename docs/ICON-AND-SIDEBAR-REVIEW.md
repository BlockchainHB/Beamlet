# Icon and sidebar refinement

Apple recommends avoiding redundant logos within an app and allowing the system to apply lighting and masking to layered app icons. Sources: [Branding](https://developer.apple.com/design/human-interface-guidelines/branding), [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons), [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| LOW, fixed | Sources/App/SettingsView.swift:31 | A brand header pushed navigation down | Navigation begins below the window controls with 12-point top padding | Remove redundant branding and keep navigation compact. The mark remains in About, not General. |
| MEDIUM, fixed | Resources/Beamlet.icon/icon.json:1; scripts/build-local.sh:17; project.yml:34 | Flat `.icns` with a painted rim, gradient and shadow | Icon Composer source with a separate SVG mark; compiled native asset catalog plus generated compatibility icon | Let the system own lighting, depth, masking and appearance variants. |
| LOW, fixed | Resources/Beamlet.icon/Assets/BeamletMark.svg:1 | Mark occupied about 58% of the canvas width, appearing small beside other Dock icons | Foreground scaled 1.3× around the canvas center, now about 75% wide | Match visual weight while preserving clear margins and the native background. Default and clear-dark exports inspected after scaling. |

Verified: native compiler accepts the layered icon; default, dark and clear-dark renders inspected; Icon Composer reopened and visibly shows the foreground mark; the running Settings preview shows the compact sidebar without clipping. Local app build, signature verification, plist validation and the Xcode Debug build all pass. Xcode compilation explicitly includes Beamlet.icon in CompileAssetCatalogVariant. The original empty Composer template stayed visible until its document was closed and reopened; it was never the completed icon asset.

Not verified: every Dock appearance and wallpaper combination, older macOS runtime appearance, and VoiceOver traversal. No custom animation was introduced. The system supplies icon effects.

Approve the inspected sidebar layout and layered icon integration. This does not certify untested system appearance combinations.
