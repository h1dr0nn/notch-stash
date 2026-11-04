# Notch Stash

A tiny shelf for your MacBook notch. Drop files on it, switch windows, Spaces or screens, then drag them out where you need them. Send them to your phone or another computer over Wi-Fi, too. Also available for Windows.

## Features

- **Notch shelf:** move the pointer onto the notch, or drag files onto it, and the shelf drops down. It folds back when the pointer leaves; your files stay.
- **Floating shelf:** a shortcut (double-tap **⌃ Control** by default) shows a shelf next to the pointer on any screen, including external displays without a notch.
- **Drag out:** drag a single file, or **Drag All** to move everything at once. Files you drop somewhere leave the shelf; hold **⌥ Option** while dropping to keep them.
- **Nearby sharing:** send shelf files to phones and computers running [LocalSend](https://localsend.org) on the same network, and receive files from them straight into the shelf.
- **Quick Look and right-click:** click a file to preview it; right-click for Show in Finder, Send to Device… and Remove.
- **Updates in the app:** Notch Stash tells you when a new version is out and installs it with one click.
- **Lightweight:** lives in the menu bar and keeps references to your files instead of copying them.

## Install

### Mac

1. Download `NotchStash-<version>.dmg` from the [latest release](https://github.com/h1dr0nn/notch-stash/releases/latest) and open it.
2. Drag **Notch Stash** onto the **Applications** shortcut in the window.
3. Open Notch Stash from Applications. The app is not notarized, so macOS blocks the first launch: open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Notch Stash.

Requires macOS 14 Sonoma or later. The notch shelf needs a Mac with a notch; the floating shelf works on any Mac.

### Windows

1. Download `NotchStash-Setup-<version>.exe` from the [latest release](https://github.com/h1dr0nn/notch-stash/releases/latest) and run it. No administrator rights are needed.
2. If Windows warns about an unknown publisher, choose **More info → Run anyway**.
3. When the firewall asks, allow Notch Stash on private networks so nearby devices can reach it.

Requires Windows 10 or 11. Windows has no notch, so the shelf floats next to the pointer: press **Ctrl+Alt+Space** (change it in Settings) or click the tray icon. A portable `NotchStash-Windows-<version>.zip` is attached to every release as well.

## Use

| Action | How |
| --- | --- |
| Open the notch shelf | Move the pointer onto the notch, or drag files onto it |
| Show or hide the floating shelf | Double-tap ⌃, or the shortcut picked in Settings |
| Move the floating shelf | Drag its title bar |
| Take files out | Drag a file, or drag **Drag All** |
| Keep a file after dropping it | Hold ⌥ while dropping |
| Preview | Click a file |
| More actions | Right-click a file: Quick Look, Show in Finder, Send to Device…, Remove |
| Send files to a phone or computer | Right-click → **Send to Device…**, or **Send All…** for the whole shelf |
| Remove | Click the × on a file, or **Clear All** |

## Nearby sharing

Notch Stash speaks the LocalSend protocol, so it swaps files with any device running the free LocalSend app (iPhone, Android, Windows, Linux, Mac) and with Notch Stash on other computers.

- **Send:** choose **Send to Device…**, pick a device from the list, and it gets a prompt to accept. Each device shows its progress and result.
- **Receive:** when a device sends you files, the notch shelf drops down with the offered files and **Accept** / **Decline** (a small window asks instead on screens without a notch). Accepted files are saved to Downloads, or the folder picked in Settings, and appear on the shelf. An unanswered request is declined after a minute.
- Turn receiving off, or nearby sharing altogether, in **Settings → Sharing**.

## Permissions

| Permission | Why | Where |
| --- | --- | --- |
| **Input Monitoring** | Only for the double-tap shortcut: Notch Stash watches modifier keys to spot the double tap and never records or sends keystrokes. A key combination such as ⌃⌥Space needs no permission. | System Settings → Privacy & Security → Input Monitoring |
| **Local Network** | Finding nearby devices for sharing. macOS asks the first time. | System Settings → Privacy & Security → Local Network |

If the shortcut does not react after an update, remove the old **Notch Stash** entry in Input Monitoring with **−**, add the app again with **+** and switch it on. It starts working within a few seconds; Settings shows whether access is granted.

## Settings

Open Notch Stash from Applications, or choose **Settings…** in the menu bar item.

- **General:** notch shelf, opening on hover, floating shelf, menu bar icon, open at login.
- **Shortcut:** double-tap ⌃ Control, ⌥ Option, ⌘ Command or ⇧ Shift, or record a key combination; Input Monitoring status.
- **Sharing:** nearby sharing, receiving files, device name, save folder; Local Network status.
- **Updates:** automatic checks, current version, Check Now and Update and Relaunch.

With the menu bar icon hidden, open the app again to get back to Settings.

## Updates

Notch Stash checks GitHub once a day. When a new version is out, the menu bar item shows **Update to …**; choose it, or **Update and Relaunch** in Settings. The app downloads the release, checks it against the checksum GitHub publishes, replaces itself and relaunches.

## Build from source

### Mac

Requires Xcode 16 or later.

```bash
git clone https://github.com/h1dr0nn/notch-stash.git
cd notch-stash
swift test
./scripts/build-app.sh
open "build/Notch Stash.app"
```

`./scripts/make-dmg.sh` packs the built app into a DMG installer.

### Windows

The Windows app is a Flutter project in [windows-app](windows-app/README.md).

## Releases

Pushing a tag builds both apps on GitHub Actions and attaches them to a GitHub release: a DMG and a zip for the Mac, an installer and a portable zip for Windows.

- `develop-v1.2.3` creates a draft release for testing.
- `release-v1.2.3` publishes the release.

Release notes come from the matching section in [CHANGELOG.md](CHANGELOG.md).

## Credits

Notch measurement is based on [NotchDrop](https://github.com/Lakr233/NotchDrop) by Lakr233 (MIT). Nearby sharing follows the [LocalSend protocol](https://github.com/localsend/protocol).
