# Notch Stash

A tiny shelf for your MacBook notch. Drop files on it, switch windows, Spaces or screens, then drag them out where you need them.

- **Notch shelf:** move the pointer onto the notch, or drag files onto it, and the shelf drops down. It folds back when the pointer leaves; your files stay.
- **Floating shelf:** double-tap **⌃ Control** to show a shelf next to the pointer, on any screen, including external displays without a notch.
- **Drag out:** drag a single file, or use **Drag All** to move everything at once. Files you drop somewhere leave the shelf; hold **⌥ Option** while dropping to keep them.
- **Quick Look:** click a file to preview it.
- **Lightweight:** lives in the menu bar, keeps references to your files instead of copying them.

## Requirements

- macOS 14 Sonoma or later
- A Mac with a notch for the notch shelf (the floating shelf works on any Mac)

## Install

1. Download `NotchStash-<version>.zip` from the [latest release](https://github.com/h1dr0nn/notch-stash/releases/latest) and unzip it.
2. Move **Notch Stash.app** to your **Applications** folder.
3. Open it. The app is not notarized, so macOS blocks the first launch: open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Notch Stash.

## Turn on the ⌃⌃ shortcut

The double-tap shortcut needs **Input Monitoring**. Notch Stash only listens for modifier keys to spot the double tap; it never records or sends keystrokes anywhere.

1. Open **System Settings → Privacy & Security → Input Monitoring**.
2. If an older **Notch Stash** entry is listed, select it and click **−**.
3. Click **+**, choose **Notch Stash** in Applications and switch it on.

The shortcut starts working within a few seconds, no restart needed. Settings shows whether access is granted.

## Settings

Open **Notch Stash** from Applications (or choose **Settings…** in the menu bar item) to:

- turn the notch shelf, opening on hover, or the floating shelf on and off
- pick the double-tap key: ⌃ Control, ⌥ Option, ⌘ Command or ⇧ Shift
- hide the menu bar icon (open the app again to get back to Settings)
- open Notch Stash at login
- check whether the shortcut has Input Monitoring access

## Use

| Action | How |
| --- | --- |
| Open the notch shelf | Move the pointer onto the notch, or drag files onto it |
| Show or hide the floating shelf | Double-tap ⌃ (or the key picked in Settings) |
| Move the floating shelf | Drag its title bar |
| Take files out | Drag a file, or drag **Drag All** |
| Keep a file after dropping it | Hold ⌥ while dropping |
| Preview | Click a file |
| Remove | Click the × on a file, or **Clear All** |

## Build from source

Requires Xcode 16 or later.

```bash
git clone https://github.com/h1dr0nn/notch-stash.git
cd notch-stash
swift test
./scripts/build-app.sh
open "build/Notch Stash.app"
```

## Releases

Pushing a tag builds the app on GitHub Actions and attaches a zip to a GitHub release:

- `develop-v1.2.3` creates a draft release for testing.
- `release-v1.2.3` publishes the release.

Release notes come from the matching section in [CHANGELOG.md](CHANGELOG.md).

## Credits

Notch measurement is based on [NotchDrop](https://github.com/Lakr233/NotchDrop) by Lakr233 (MIT).
