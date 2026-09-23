# Native design contract

## Panel

Target 340 points wide, sized to content, anchored to the menu bar icon. Compact status header with original mark, Beamlet name, text state, and secondary explanatory sentence. One clear Start/Stop action. Selected folder displayed as `~/dev` rather than a huge absolute path. Below: Open session, Copy link, Show QR, then Settings and Quit Beamlet directly adjacent in the same options list. No separate footer buttons. The menu bar panel has no window traffic lights; developer preview windows are labeled separately.

Use a single panel, not nested popovers. QR expands the current content with a readable white-backed code and a close action. Hide no essential state behind hover. Disable unavailable session actions with an explanation. A stopped session must not retain a stale actionable link. Error states show concise next actions; diagnostics remain in Settings.

## Visual language

Use warm ivory in light appearance and deep graphite in dark appearance, with a restrained peach wash and vivid coral accent. The user's design correction explicitly rejects a flat grey utility aesthetic. Native Liquid Glass on the main capsule action (macOS 26+), solid native fallback on macOS 14–15 and under Reduce Transparency. Ordinary options remain plain rows. Rounded system typography emphasizes the current state; the original mark sits on a softly tinted tile. Do not layer glass on every row. Preserve contrast in active/inactive windows and both appearances. Respect Increase Contrast and Reduce Transparency by removing decorative gradients.

Original asymmetric sunburst plus a connection opening. Monochrome template image in the menu bar, with stable optical bounds and distinct offline/online state silhouettes. No colored status dot. Frequent actions and QR expansion are immediate. The primary action uses the native glassProminent button style; native controls own their feedback and accessibility behavior. No custom press animation is layered on top. Rows use immediate hover/press shading, with a 10-point radius nested in a 16-point surface at a 6-point inset. VoiceOver label always states exact status. Stable online must not animate endlessly.

Settings uses a 700×540-point native window with a fixed 170-point sidebar: General, Connection, and About. The sidebar cannot collapse. Use a compact, titleless native title bar with standard window controls, no toolbar, and no sidebar toggle. Extend both column backgrounds behind the transparent title bar using full-size content: native behind-window sidebar material on the left, the continuous Beamlet surface on the right. Only backgrounds ignore the top safe area; content remains below the window controls. Sidebar symbols occupy 18-point boxes with a consistent 10-point label gap; native list selection preserves arrow-key navigation. General contains startup, power, and notification controls; Connection contains folder/executable selection and collapsed Terminal setup; About contains version, updates, privacy, and expandable diagnostics. Remember the selected section. Review setup opens Connection directly. Notification permission is read from macOS and refreshed after a request and when the app becomes active: hide the request button after approval, and show a System Settings action after denial. Bundle the original coral Beamlet icon for system surfaces. Menu-bar-only operation until Settings opens; Settings uses regular Dock presence, native close/minimize controls, and Command-W. Closing Settings must leave the connection running. No custom Done button. Standard keyboard navigation, visible focus, Escape/outside-click dismissal, Command-comma Settings, and predictable Quit behavior.

## Accessibility and visual checks

Settings branding is confined to About. The sidebar starts with its navigation rows, with 12 points of top padding below the window safe area; General remains focused on controls. No repeated brand header or decorative app icon in General. This follows Apple's guidance to avoid redundant logos where people already know which app they are using.

The system app icon is authored in `Resources/Beamlet.icon`: one unshaded SVG foreground mark and a native background. Icon Composer/macOS own masking, highlights, shadows, and appearance variants. Both Xcode and `scripts/build-local.sh` compile this source with `actool` into `Assets.car` plus a legacy `.icns`; do not restore the earlier hand-painted bitmap rim or shadow. The menu bar mark remains a monochrome template appropriate to that surface.

Check light/dark backgrounds, Increase Contrast, Reduce Transparency, Reduce Motion, keyboard-only use, VoiceOver labels, long folder names, missing CLI, login required, offline and reconnecting. Keep controls comfortably clickable, aim for 28-point control dimensions, and provide accessible names for icon-only controls.

## Apple sources studied

- https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- https://developer.apple.com/design/human-interface-guidelines/popovers
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://developer.apple.com/design/human-interface-guidelines/accessibility

Apple prefers menus for simple extras; Beamlet intentionally uses the supported window style for status, controls, and QR content. Visual references: Dato and CleanShot. Their designs are references, not assets to copy.
