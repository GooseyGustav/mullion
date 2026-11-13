# Mullion

A personal, minimal, glassmorphic ⌘⇥ window switcher for macOS that replaces the native app switcher.

Mullion is an independent implementation. It shares no code with any other
switcher; it exists so the behaviour can be owned, read, and changed locally.

Status: **0.2** — overlay with live window thumbnails, titles, keyboard navigation,
and window activation. See [Roadmap](#roadmap).

## Requirements

- macOS 14 or later (thumbnails use `SCScreenshotManager`; developed on macOS 26)
- Xcode 26 (Swift 5 language mode)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build and run

```bash
xcodegen generate                       # writes Mullion.xcodeproj
xcodebuild -project Mullion.xcodeproj \
           -scheme Mullion -configuration Debug \
           -derivedDataPath build build

open build/Build/Products/Debug/Mullion.app
```

Or open `Mullion.xcodeproj` in Xcode and press ⌘R.

The app is a menu-bar agent (`LSUIElement`), so there is no Dock icon and no main
window. Look for the ▭▭ icon in the menu bar.

## First run

1. macOS asks for **Accessibility** permission. Grant it in
   System Settings ▸ Privacy & Security ▸ Accessibility. Without it, window
   titles cannot be read and windows cannot be raised.
2. macOS asks for **Screen Recording** permission. Grant it in
   System Settings ▸ Privacy & Security ▸ Screen Recording. This is used only to
   capture the thumbnails; without it the switcher still works with app icons.
   **macOS requires a restart of Mullion after this permission is granted.**
3. Use **⌘⇥** to open the switcher.
   - keep holding ⌘ and press ⇥ again to move forward
   - ⇠ ⇢ ⇡ ⇣ also move the selection; ⇧⌘⇥ moves backwards
   - **release ⌘** or press **Return** to switch
   - **Esc** cancels
   - hover a tile for its titlebar controls: **close** (red), **minimize**
     (yellow), **zoom** (green). Close and minimize remove the tile and keep the
     panel open; zoom switches to the window.
   - **⌘W** closes the selected window and **⌘M** minimizes it without leaving the
     switcher

## Replacing ⌘⇥

Mullion swallows ⌘⇥ at the session level, so the macOS app switcher never
appears — there is no system setting to disable and the two never conflict. Quit
Mullion (menu bar ▸ Quit) and ⌘⇥ returns to stock macOS behaviour. There is no
way to run both at once; that is deliberate, because two switchers competing for one
shortcut is why the previous ⌥⇥ build felt unreliable.

## Permission note

Mullion is signed with the Apple Development identity
`Apple Development: Ky Anh Pham (W99V9DN93Y)` (team `NZJ6XP9B66`). TCC grants are
keyed to that identity plus the bundle ID, so **rebuilding does not invalidate the
Accessibility or Screen Recording permissions**. (An ad-hoc signature does, because
its hash changes on every build.)

That identity lives in `project.yml` so the maintainer's local builds keep their
permissions. If you build your own copy, replace `CODE_SIGN_IDENTITY` and
`DEVELOPMENT_TEAM` with your own certificate; do not change the bundle ID.

## Distribution

Mullion is sold outside the Mac App Store: Developer ID signing, notarization, a
signed DMG, Sparkle updates, and a hosted checkout. The bundle ID
`com.kyanhpham.mullion` is final — changing it resets every user's Accessibility and
Screen Recording grants.

- [docs/LAUNCH.md](docs/LAUNCH.md) — certificates, signing, notarization, DMG,
  Sparkle, trial and licensing, store setup, release checklist.
- [docs/WEBSITE.md](docs/WEBSITE.md) — website concept and build brief for the
  marketing site, VPS deployment, checkout, legal pages.

## Performance

There is no background work: no timers, no polling, no `SCStream`. Idle CPU is zero.

Opening the switcher costs:

1. **Window snapshot** — `CGWindowListCopyWindowInfo` plus one Accessibility query
   per app, run in parallel; each window's five attributes come back in one IPC
   call. Measured at ~10–20 ms warm. The first snapshot after launch is ~200 ms of
   framework setup, so one is taken on a background queue at startup.
2. **Cached thumbnails** — painted on the same run-loop turn as the keypress.
3. **Capture** — only for windows whose thumbnail is missing or older than 3 s,
   first wave (the visible two rows) then the rest. `SCShareableContent` is reused
   for 2 s, so quick re-opens skip enumeration entirely.

Re-opening within 3 s performs **no capture at all**. The image cache is capped at
32 entries of ≤402 px wide, so memory stays bounded.

## Tests

None yet. The architecture keeps the window list, the state machine, and the view
separate so that each can be tested without a live window server; see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#testing-seams).

## Roadmap

| Version | Scope |
|---|---|
| 0.1 | Overlay, app icons, titles, keyboard selection, activation, menu bar |
| 0.2 | Live thumbnails via ScreenCaptureKit |
| 0.3 | MRU ordering, minimized/hidden windows, multi-display, excluded apps |
| 0.4 | Search field over titles and app names |
| 0.5 | App Icons / Titles / Thumbnails styles, auto-sizing cells |
| 0.6 | Multiple configurable shortcuts, preferences window, settings persistence |

## Layout

```
Mullion/
├── App/            entry point, menu bar, composition root
├── Core/           window model, inventory, activation, permissions
├── Input/          global hotkey registration
├── UI/             panel, grid view, cells, state machine, theme
└── Resources/      Info.plist
docs/               architecture notes
project.yml         XcodeGen spec (the .xcodeproj is generated, not committed)
```
