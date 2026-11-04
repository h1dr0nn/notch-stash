# Notch Stash for Windows

A temporary file shelf for Windows, built with Flutter. Windows has no notch, so the shelf lives in the notification area: press **Ctrl+Alt+Space** (or click the tray icon) and a small shelf appears next to the pointer. Drop files on it, switch windows or screens, then drag them out where you need them.

- **Shelf:** drop files to keep references to them (nothing is copied). Drag a file out, or use **Drag All**; files you drop somewhere leave the shelf, and the shelf hides when it is empty. Right-click a file to open it, show it in Explorer, send it or remove it.
- **Nearby sharing:** speaks the [LocalSend](https://localsend.org) v2 protocol, so it swaps files with the LocalSend apps and with Notch Stash on the Mac. Use **Send All…** or **Send to Device…**; incoming files ask for approval and are saved to Downloads (change it in Settings), then appear on the shelf.
- **Settings:** open from the tray menu, or launch Notch Stash again. Change the shortcut, start with Windows, and turn nearby sharing on or off.

The first time nearby sharing starts, Windows Firewall may ask whether Notch Stash can use the network. Allow it on private networks, or other devices cannot find this PC.

## Build

Requires Flutter 3.47.9 (stable) and, for the Windows build, Visual Studio 2022 with the **Desktop development with C++** workload.

```powershell
cd windows-app
flutter pub get
flutter analyze
flutter test
flutter build windows --release --build-name=0.6.0
```

The app is in `build\windows\x64\runner\Release` (`NotchStash.exe` plus its DLLs and `data` folder). `flutter analyze` and `flutter test` also run on macOS and Linux; only the build needs Windows.

### Installer

Install [Inno Setup 6](https://jrsoftware.org/isinfo.php), build the app, then:

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=0.6.0 installer\NotchStash.iss
```

This writes `build\installer\NotchStash-Setup-0.6.0.exe`: a per-user install (no admin rights) with a Start Menu shortcut and an optional "start when I sign in" task. For the portable build, zip the contents of the `Release` folder.

### Releases

The `windows` job in `.github/workflows/release.yml` runs after the macOS release job for `develop-v*` and `release-v*` tags. It tests, builds with the version from the tag, and uploads `NotchStash-Setup-<version>.exe` and `NotchStash-Windows-<version>.zip` to the same GitHub release.

## Layout

| Path | What |
| --- | --- |
| `lib/main.dart` | Start-up: single instance, settings, window |
| `lib/src/app_controller.dart` | Shelf, window modes, tray, hotkey and sharing wired together |
| `lib/src/core/` | Shelf store, file naming, shortcut model, placement, versions (no plugins, unit tested) |
| `lib/src/localsend/` | LocalSend v2: models, multicast discovery, HTTP server and client, receive logic |
| `lib/src/platform/` | Tray, global hotkey, window, startup entry, Explorer, single instance |
| `lib/src/ui/` | Shelf, Send to Device, Incoming Files and Settings views |
| `installer/NotchStash.iss` | Inno Setup script |
