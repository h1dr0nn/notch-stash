# Changelog

## 0.6.0 — 2026-11-04

### Added
- Nearby sharing with LocalSend: send shelf files to phones and computers running LocalSend on the same network, and receive files from them straight into the shelf.
- Right-click a file on the shelf for Quick Look, Show in Finder, Send to Device… and Remove; Send All… sends the whole shelf.
- Send to Device window that finds nearby devices and shows approval, progress and result for each.
- Incoming files prompt with Accept and Decline; accepted files are saved to a folder you choose (Downloads by default).
- Settings: Nearby Sharing, Receive Files, Device Name, Save To, and the Local Network permission status with a shortcut to System Settings.

## 0.5.2 — 2026-11-04

### Fixed
- Switching Spaces (for example with a three-finger swipe) while the notch shelf was open left it behind on the old Space, and the notch stopped responding on the new one. The shelf now moves to the new Space: it stays open without flickering while the pointer is on it, and folds away with its animation otherwise.

## 0.5.1 — 2026-11-03

### Added
- Release builds on GitHub Actions: `develop-v*` tags create a draft release, `release-v*` tags publish one. Each release has a DMG installer and a zip.
- New app icon following the macOS icon grid.
- Settings window, shown when you open the app: turn the notch shelf, hover opening and the floating shelf on or off, pick the double-tap key (⌃, ⌥, ⌘ or ⇧), hide the menu bar icon, open at login, and check the Input Monitoring status.
- Light haptic feedback when the notch shelf closes.
- Shortcut can be a regular key combination (for example ⌃⌥Space) recorded in Settings; it needs no Input Monitoring permission.
- Notch Stash shows in the Dock while Settings is open.

### Fixed
- Dragging files onto the notch opens the shelf: file drags are detected anywhere on screen and the shelf drops down as the pointer nears the notch.
- Nothing is left at the notch while the shelf is closed.
- Dropping files works in both shelves.
- Haptic feedback is a single light tap while dragging files.
- The notch shelf works again after the floating shelf has been closed.
- The notch shelf no longer slides in from the left; its window stays exactly over the notch while closed.
- ⌃⌃ could work once and then stop: a key listener created before Input Monitoring was granted only sees keys typed into Notch Stash itself. It is now recreated as soon as the permission appears, and the menu shows the real shortcut state.

## 0.4.0 — 2026-11-03

### Added
- Floating shelf can be moved by dragging its header or edges.
- Shelf header shows a "Notch Shelf" title; on the notch shelf the title and buttons sit beside the notch, without a close button (it folds away on its own).

### Changed
- The notch shelf scales up from nothing at the notch when it opens and scales back down when it closes; no notch-shaped block any more.
- While the floating shelf is open, the notch shelf stays closed (no hover or drag opening).

### Fixed
- ⌃⌃ shortcut did not start after granting Input Monitoring until the app was relaunched; the event tap is now retried directly.

## 0.3.1 — 2026-11-03

### Fixed
- The notch shelf could slide in from the left: the window now resizes only after the animation has fully finished, and is laid out before the next one starts.

## 0.3.0 — 2026-11-03

### Changed
- ⌃⌃ always shows or hides the floating shelf next to the cursor and closes the notch shelf.

### Fixed
- Nothing is drawn around the notch while the shelf is closed.
- Shelf content no longer shows outside the black background while it opens; moving back to the notch during the close animation reverses it smoothly.
- Input Monitoring permission survives rebuilds (fixed code signing requirement).

## 0.2.0 — 2026-11-03

### Added
- Spring animation when the notch shelf opens and closes; fade for the floating shelf.

### Changed
- The notch shelf folds back into the notch when the mouse leaves it, even with files on it. Opening with ⌃⌃ keeps it pinned.

## 0.1.0 — 2026-11-03

### Added
- Notch shelf: opens on hover or when files are dragged onto the notch, stays open across windows and Spaces while it holds files.
- Floating shelf next to the cursor on screens without a notch.
- Double-tap ⌃ to show or hide the shelf (Input Monitoring permission).
- Drop files in; drag them out one by one or all at once as real files; delivered files leave the shelf (hold ⌥ to keep).
- Quick Look on click, remove per file, Clear All.
- Menu bar item with file count.
- App icon.
