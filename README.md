# BlinkBar

BlinkBar is a native macOS menu-bar app that reminds you to blink at a configurable interval.

It is designed to stay out of the way: it lives in the menu bar, shows a lightweight reminder, and closes the reminder automatically after 20 seconds.

## Features

- Menu-bar only app with an eye icon
- Configurable reminder interval
- Preset intervals: 5, 10, 20, 30, and 60 minutes
- Custom interval input
- Three reminder styles:
  - Full-screen overlay
  - Small center popup
  - macOS notification
- `Done` button for overlay and popup reminders
- 20-second auto-dismiss
- Start-at-login toggle
- Best-effort pause during fullscreen apps
- Best-effort pause while common video/call apps are frontmost
- Local-only settings using `UserDefaults`

## Tech Stack

- **Language:** Swift
- **UI framework:** AppKit
- **App type:** macOS menu-bar utility
- **Menu bar:** `NSStatusItem`
- **Overlay and popup reminders:** `NSWindow` + custom `NSView`
- **Notifications:** `UserNotifications`
- **Login item support:** `ServiceManagement`
- **Settings storage:** `UserDefaults`
- **Build system:** Swift Package Manager
- **Packaging:** Shell scripts, `iconutil`, `sips`, `ditto`, and ad-hoc `codesign`

## Requirements

- macOS 13 or newer
- Apple Silicon Mac recommended
- Xcode command line tools

Check tools:

```sh
swift --version
xcodebuild -version
```

## Project Structure

```text
.
├── Assets/
│   └── AppIcon.png
├── Sources/
│   └── BlinkReminder/
│       └── main.swift
├── INSTALL.md
├── Package.swift
├── README.md
├── build_app.sh
└── distribute.sh
```

## Architecture

`main.swift` contains the app entry point, menu-bar controller, reminder scheduling, reminder views, notification handling, and login-item toggle.

The app starts as an accessory application, so it does not show a Dock icon. `ReminderController` owns the menu-bar item, timers, settings, and reminder display logic.

Reminder flow:

1. The app schedules a repeating timer using the selected interval.
2. When the timer fires, BlinkBar checks whether it should pause because a fullscreen window or known call/video app is active.
3. If not paused, it shows the selected reminder style.
4. The reminder auto-dismisses after 20 seconds.

Overlay and popup windows are reused instead of repeatedly destroyed. This avoids AppKit lifecycle crashes during auto-dismiss.

## Build

```sh
chmod +x build_app.sh
./build_app.sh
```

The app bundle is created at:

```text
.build/release/BlinkBar.app
```

Run locally:

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

The package script:

- Builds the release binary
- Creates a macOS `.app` bundle
- Generates `AppIcon.icns`
- Adds `Info.plist`
- Ad-hoc signs the app
- Creates a clean zip for sharing

See [INSTALL.md](INSTALL.md) for install notes.

## Usage

Open BlinkBar and use the eye icon in the macOS menu bar.

Available menu actions:

- Turn reminders on or off
- Pick a preset interval
- Set a custom interval
- Choose reminder style
- Enable or disable start at login
- Show a reminder immediately
- Quit BlinkBar

The default interval is 20 minutes.

## Notification Mode

macOS notification mode requires notification permission:

```text
System Settings > Notifications > BlinkBar > Allow Notifications
```

If notifications are denied or unavailable, BlinkBar falls back to the small popup reminder.

Focus/DND behavior is controlled by macOS Notification Center. Overlay and popup reminders are app-controlled and do not have reliable public access to Focus/DND state.

## Pause Behavior

BlinkBar pauses reminders when:

- The frontmost window appears to be fullscreen
- A known call/video app is frontmost

This is best-effort because macOS does not expose a single reliable public API for detecting all video playback, meetings, or Focus/DND state.

Currently checked app bundle IDs include Zoom, Microsoft Teams, FaceTime, Webex, Chrome, Safari, and Arc.

## Distribution Notes

The current build is ad-hoc signed and not notarized by Apple. That is enough for local sharing and testing, but macOS may warn on first launch.

For wider distribution, the next production steps are:

- Use an Apple Developer ID certificate
- Harden the runtime
- Notarize the app with Apple
- Staple the notarization ticket
- Optionally create a DMG installer

## Repository

GitHub:

```text
https://github.com/RubenManoj/BlinkBar
```

Common commands:

```sh
git status
git pull
./distribute.sh
git add .
git commit -m "Describe your change"
git push
```

## Known Limitations

- The notification style depends on macOS notification permission.
- The app is currently ad-hoc signed, not notarized.
- Video/call detection is heuristic-based.
- Focus/DND detection is reliable only for macOS notification behavior, not custom overlays.
