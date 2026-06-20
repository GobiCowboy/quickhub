# Menu Bar Agent Behavior

This doc captures the lifecycle rules for a macOS menu-bar utility that should stay out of the Dock but still be reachable from the app icon.

## What We Want

- Show a single status item in the menu bar.
- Hide the Dock icon for normal operation.
- Let the user click the app from `/Applications` and bring the settings window forward.
- Keep the status item toggleable from Settings.

## Canonical Behavior

1. `LSUIElement = true` makes the app an agent app, so it does not live in the Dock by default.
2. `NSApp.setActivationPolicy(.accessory)` keeps the app in menu-bar mode after launch.
3. `NSStatusItem` must be held by a strong property on `AppDelegate`.
4. The menu bar image should use a template-capable asset and a fixed icon size.
5. `applicationShouldHandleReopen(_:hasVisibleWindows:)` should call `openSettings()` when the app is clicked again from Finder or the Dock-less app launcher.
6. A Settings toggle should control `statusItem.isVisible` so the icon can be hidden without killing the app.

## Implementation Notes

- Status item setup lives in `App/AppDelegate.swift`.
- The visibility toggle is persisted in `App/Models/Models.swift` under `AppSettings`.
- The General settings page owns the toggle UI and pushes changes back to `AppDelegate`.
- Icon loading should go through one shared helper so the menu bar icon, settings preview, and command chips do not diverge.

## Troubleshooting

- If the app opens but the menu bar icon is missing, check the asset name, template setting, and `statusItem.isVisible`.
- If the app is running but clicking the app icon does nothing, check `applicationShouldHandleReopen`.
- If the Dock icon appears, re-check `LSUIElement` and the activation policy path.

