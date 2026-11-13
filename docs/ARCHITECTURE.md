# Architecture

Mullion is a small macOS agent. The design goal is that each part can be
understood and changed on its own: a window source, a state machine, a view, and
an activator. There is no framework, no dependency injection container, and no
global mutable state beyond the process itself.

## Layers

```
                    ┌───────────────────┐
   ⌘⇥ key           │     EventTap      │  session-level CGEventTap, always on
                    └─────────┬─────────┘
                              │ swallows ⌘⇥, so the native switcher never opens
                    ┌─────────▼─────────┐
                    │ SwitcherController│  state machine + selection
                    └──┬───────┬──────┬─┘
        windows()      │       │      │  renders / handles keys
              ┌────────▼──────┐│   ┌──▼─────────────┐
              │WindowInventory││   │  SwitcherPanel  │
              │  (protocol)   ││   │  SwitcherView   │
              └────────┬──────┘│   │  WindowCellView │
                       │       │   └─────────────────┘
                       │       │ capture()
              ┌────────▼───────▼──┐
              │  ThumbnailProvider│  SCScreenshotManager
              │     (protocol)    │
              └────────┬──────────┘
                       │
              ┌────────▼──────────┐
              │ Accessibility API │  titles, frames, raise
              │   CGWindowList    │  z-order, on-screen set
              │  ScreenCaptureKit │  window content
              └────────┬──────────┘
                       │ commit()
              ┌────────▼──────────┐
              │  WindowActivator  │  NSRunningApplication + AX
              └───────────────────┘
```

## Responsibilities

| Type | Owns | Does not |
|---|---|---|
| `AppDelegate` | process lifetime, menu bar, wiring | window logic |
| `HotkeyMonitor` | ⌥⇥ fallback only (used when the tap is refused) | knowing what it opens |
| `EventTap` | session-level key/modifier interception for the whole run | selection policy |
| `WindowInventory` (protocol) | where the window list comes from | UI, selection |
| `AccessibilityWindowInventory` | CG + AX correlation | ordering policy, activation |
| `AXWindowLookup` | resolving a `WindowItem` to an `AXUIElement` | what to do with it |
| `WindowActivator` | raising and focusing a window | when to raise |
| `WindowCloser` | closing, minimizing, zooming via AX controls | when to apply them |
| `ThumbnailProvider` (protocol) | where window images come from | when to capture |
| `ScreenCaptureThumbnailProvider` | ScreenCaptureKit capture and batching | UI state, permissions decisions |
| `SwitcherController` | visible/idle state, selected index, key mapping, capture lifetime | drawing, API calls |
| `SwitcherView` | grid layout, cell selection styling | data source |
| `WindowCellView` | one cell's appearance | any behaviour |
| `WindowActivator` | raising a specific window | when to raise |
| `Permissions` | Accessibility check + prompt | anything else |
| `Theme` | layout and colour constants | logic |

Dependencies point downward only. `WindowInventory` is a protocol specifically so a
future ScreenCaptureKit or private-CGS backend can replace the AX implementation
without touching the controller or the view.

## Data flow

1. **Hotkey.** A session-level `CGEventTap` sees ⌘⇥ before the Dock does and
   swallows it, so the macOS switcher never opens. This is what "replacing ⌘⇥"
   means in practice: no system setting, no conflict. `Carbon` registration of ⌘⇥
   remains only as a fallback when the tap cannot be created (no Accessibility).
2. **Snapshot.** `SwitcherController.show()` asks the inventory for windows. The
   inventory builds the list once per presentation; nothing is cached between
   shows, so the list can never go stale.
3. **Render.** `SwitcherView` rebuilds its grid and the controller computes the
   panel size from the item count *before* showing, so there is no visible resize.
4. **Capture.** Cached frames are painted before any capture starts, so a re-open
   within 3 s is instant and free. Otherwise the controller asks for thumbnails in
   two waves (visible rows first) and applies them as they arrive. Each presentation
   gets a token, so a capture that finishes after dismissal is dropped.
5. **Select.** Repeated ⌘⇥ cycles. While visible, a session-level `CGEventTap`
   swallows Tab/arrows/Return/Escape and watches for the Command release, so the
   overlay works without making Mullion the active application.
6. **Commit.** Releasing ⌥ or pressing Return re-resolves the target window through
   Accessibility (the snapshot may be a few hundred milliseconds old), un-minimizes
   it if needed, raises it, and activates the owning app.

## Key decisions

**CoreGraphics for order, Accessibility for titles.** `CGWindowListCopyWindowInfo`
is the only public source of true front-to-back ordering. Its `kCGWindowName` field
is withheld unless the app has Screen Recording permission, while the Accessibility
API exposes titles with only Accessibility permission. So the two are joined on
(pid, window frame) with a 2 pt tolerance, which keeps titles working even when
Screen Recording is denied.

**Per-presentation stills, not live streams.** `SCScreenshotManager.captureImage`
is one-shot: the overlay is transient, so there is no reason to keep `SCStream`
objects and their buffers alive while it is hidden.

**Event-driven caching, not background refresh.** Speed comes from doing less work,
not from doing it earlier. Three rules:

- idle means idle: no timers, no polling, no streams;
- paint cache first, capture second, and only for entries older than 3 s;
- bound everything: 32 cached images at ≤402 px, and the `SCShareableContent`
  enumeration (100–300 ms) reused for 2 s.

**One Accessibility IPC call per window.** A snapshot used to ask each window five
separate questions (title, document path, position, size, minimized), and every
question is a round-trip to the AX server. `AXUIElementCopyMultipleAttributeValues`
returns all five in a single call. Combined with the per-app parallel query, a warm
snapshot costs ~10 ms, measured in the log as `show windows=… inventory=… ms`.

**Warm the AX pipeline at launch.** The first snapshot after launch pays ~200 ms of
framework setup; later ones are an order of magnitude cheaper. The app takes one
throwaway snapshot on a background queue at startup so the first ⌘⇥ is already warm.
The result is discarded — it is a warm-up, not a cache.

**Tiles are a uniform grid.** Every tile is the same size: a header row (app icon
immediately left of the title) above a 268×168 pt preview box. Windows are
aspect-fit inside that box, so nothing is ever cropped; a portrait window (Mail) or
an ultrawide window shows glass at the sides or above and below. That empty space is
the deliberate trade: sizing each tile to its window's aspect ratio avoids the
letterboxing but makes one tile twice as tall as its neighbours. Uniform tiles also
let `SwitcherView.size(for:)` be a plain rows × columns calculation.

**A session event tap instead of key-window focus.** `NSEvent` monitors only see
events delivered to this app, which made dismissal and arrow keys depend on
Mullion being frontmost — the overlay would stay up if it was not. While visible,
a `CGEventTap` at `.cgSessionEventTap` handles the keys and the Command release and
swallows what it uses, so focus never moves. The panel-key path remains as a fallback
when Accessibility is unavailable and the tap cannot be created.

**Window-server image capture is gone.** `CGWindowListCreateImage` is
`unavailable` from macOS 15 (`obsoleted in macOS 15.0`), so ScreenCaptureKit is the
only option; the code must not be written against the old API.

**An event tap for suppression; Carbon only as a fallback.** A global `NSEvent`
monitor cannot suppress a key combination. A `CGEventTap` can, which is what makes
replacing ⌘⇥ possible. Carbon's `RegisterEventHotKey` can also consume a key and
needs no Accessibility by itself, so it remains as the ⌥⇥ fallback for the case
where the tap is refused.

**A nonactivating panel that still becomes key.** `.nonactivatingPanel` avoids
reordering the target app's windows when the overlay appears; `canBecomeKey = true`
lets the panel receive Tab/arrows/Return/Escape. The trade-off is that the app has
to be activated to receive those events (`NSApp.activate` in `show()`), which is
acceptable for an overlay that covers the screen and disappears on commit.

**Commit on modifier release.** ⌘⇥ shows, ⌘ stays held, ⇥ cycles, releasing ⌘ picks.
This is the behaviour a switcher is expected to have.

**The tap runs for the whole session, not only while visible.** ⌘⇥ must be
intercepted before the Dock to suppress the native switcher, so the tap is installed
at launch and never torn down. Its cost when idle is one comparison per key event;
there is no polling or timer. State changes are dispatched asynchronously because
invalidating an event tap from inside its own callback is not safe.

**Close, minimize, and zoom through Accessibility, not ⌘W.** Sending ⌘W to an app
closes whatever *it* considers focused, which may not be the tile the user clicked.
`WindowCloser` resolves the exact `AXUIElement` (same title+frame matching as
activation) and presses its `kAXCloseButton`, sets `kAXMinimized`, or presses
`kAXZoomButton`. Close and minimize remove the tile locally and keep the panel open,
so several windows can be cleared in a row; zoom commits and switches to the window,
because the result is only visible once the panel is gone. Mouse clicks work without
activating Mullion: the panel is a `.nonactivatingPanel` and `TrafficLightsView`
returns `true` from `acceptsFirstMouse`, so the first click lands.

The three controls are drawn as one 24 pt view that occupies the app-icon slot, with
6 pt dots and 3 pt gaps. Hovering fades the icon out and the controls in without
moving the title; the same slot means no layout shift. ⌘W and ⌘M reach the same code
paths from the keyboard.

**One blur, many translucent tiles.** The glass look is a single
`NSVisualEffectView` (`.hudWindow`, `.behindWindow`) behind the whole panel, plus a
light scrim, a top sheen gradient and a bottom foot gradient. Cells are dark
translucent gradients (32% → 14% black) rather than white ones: over a light desktop
a white fill reads as opaque grey, while a dark fill lets the blurred backdrop show
through. There is one blur total — per-cell backdrop blur would composite 15+ live
filters on every open for no visual gain.

**Re-resolve on commit rather than caching `AXUIElement`s.** Elements can be
invalidated between snapshot and commit if a window closes. Matching again by
title and frame, with a fallback to the closest frame match, is more robust than
holding a stale reference.

## Known limitations (0.2)

- Only on-screen windows: minimized/hidden windows and other Spaces are not listed.
- No MRU ordering yet; the list is front-to-back as reported by the window server.
- Replaces ⌘⇥ outright; there is no mode where the native switcher and Mullion
  share the shortcut. Quit Mullion to get stock behaviour back.
- No reverse (⇧⌘⇥) *registration* is needed — the tap sees it — but the native
  behaviour for ⇧⌘⇥ (reverse app switch) is also swallowed while running.
- No search, no style switching.
- Thumbnails are stills captured at presentation time. A video playing in a window
  shows the frame captured when ⌘⇥ was pressed, not live motion — that is the price
  of zero idle cost.
- First open after launch has no cache, so its thumbnails arrive in ~200–500 ms
  depending on how many apps answer Accessibility slowly.
- Window content that macOS protects (DRM video, some secure input) captures as
  blank; that is enforced by the system, not by Mullion.
- `AXUIElementSetAttributeValue(kAXMainAttribute)` is a no-op for some apps (e.g.
  apps with a single window); activation still works through
  `NSRunningApplication`.

## Testing seams

- `WindowInventory` is a protocol, so the controller can be driven by a fake list.
- `ThumbnailProvider` is a protocol, so a fake can return solid-colour images
  without Screen Recording permission.
- `SwitcherView.size(forCount:)` is pure and can be checked without AppKit windows.
- `SwitcherController` takes both providers via `init`, so no singletons are needed.
- The AX/CG/SCK layer is the only part that requires a running WindowServer; keep
  logic out of it and test logic elsewhere.
