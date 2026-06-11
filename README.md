# BlinkBar

A native macOS menu-bar app that reminds you to blink at a configurable interval.

## Requirements

- Apple Silicon Mac recommended
- macOS 13 or newer
- Xcode command line tools

## Build

```sh
chmod +x build_app.sh
./build_app.sh
```

The app bundle is created at:

```text
.build/release/BlinkBar.app
```

## Run

```sh
open ".build/release/BlinkBar.app"
```

## Package for Sharing

```sh
chmod +x distribute.sh
./distribute.sh
```

The shareable zip is created at:

```text
dist/BlinkBar-1.0.zip
```

See [INSTALL.md](INSTALL.md) for install notes.

Use the BlinkBar eye icon in the menu bar to:

- Turn reminders on or off
- Pick a preset interval
- Set a custom interval
- Choose full-screen overlay, small popup, or macOS notification
- Enable or disable start at login
- Show a reminder immediately

The default interval is 20 minutes. Reminders close automatically after 20 seconds.

## Pause Behavior

The app pauses reminders when the current foreground window appears to be full screen, and while common call/video apps are frontmost. macOS notification mode also respects system Focus/DND behavior through Notification Center.
