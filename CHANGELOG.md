# Changelog

## 0.5.0 — 2026-11-03

### Added
- Release builds on GitHub Actions: `develop-v*` tags create a draft release, `release-v*` tags publish one.
- A prompt on launch explains how to turn on Input Monitoring when the ⌃⌃ shortcut is not allowed yet.
- New app icon following the macOS icon grid.

### Fixed
- Dragging files onto the notch opens the shelf again.
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
