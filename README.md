# goodthoughts for Mac

[![CI](https://img.shields.io/github/actions/workflow/status/STACK-42/goodthoughts-mac/ci.yml?branch=main&label=CI)](https://github.com/STACK-42/goodthoughts-mac/actions/workflows/ci.yml)

A menu bar app that shows one quote a day from [goodthoughts](https://goodthoughts.page) and sets it as your desktop wallpaper with one click.

The wallpapers are drawn by the goodthoughts site, which publishes them with a JSON feed at `https://goodthoughts.page/wallpapers.json`. The app reads the feed, works out today's quote from the date, and applies its image to each screen. Every Mac gets the same quote on the same day.

> [!NOTE]
> macOS has no public way to set the wallpaper on every Space, so Apply changes the current desktop only.

## Install

1. Download `goodthoughts-<version>.dmg` from [Releases](https://github.com/STACK-42/goodthoughts-mac/releases/latest), open it, and drag **GoodThoughts** to **Applications**.
2. Open it from Applications. The app isn't notarised by Apple (there's no paid developer account behind it), so macOS stops it the first time:
   - **macOS 15 Sequoia and later:** macOS says it couldn't verify the app. Click **Done**, then open **System Settings → Privacy & Security**, scroll to *Security*, click **Open Anyway** next to "GoodThoughts was blocked", and confirm with your password.
   - **macOS 13 Ventura and 14 Sonoma:** Control-click GoodThoughts in Applications, choose **Open**, then **Open** again.
3. Click the **g** in the menu bar. Turn on *Open at login* and *Set each morning* there if you want a new wallpaper every day.

You only do this once. After that the app updates itself: it checks once a day and asks before installing, or click **Updates** in the popover.

> [!NOTE]
> On privacy: the app runs in the macOS App Sandbox with no access beyond outgoing network connections. It contacts goodthoughts.page for the quotes and wallpapers, and github.com to check for updates, and sends nothing about you or your Mac. Every update is checked against the project's signing key before it's installed. You can read all of the code here.

## Requirements

- macOS 13 Ventura or later
- To build: Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

The Xcode project is generated from `project.yml` and isn't committed.

```sh
xcodegen generate
open GoodThoughts.xcodeproj
```

Or from the command line:

```sh
xcodebuild build -project GoodThoughts.xcodeproj -scheme GoodThoughts -destination 'platform=macOS'
xcodebuild test  -project GoodThoughts.xcodeproj -scheme GoodThoughts -destination 'platform=macOS'
```

> [!TIP]
> Run `xcodegen generate` again after pulling changes to `project.yml` or adding files.

Without Xcode, `scripts/run.sh` builds the app with the Command Line Tools and opens it. It needs XcodeGen too. That build leaves out Sparkle, which comes in as a Swift package only Xcode can link.

The menu bar icon is generated from the brand mark by `swift scripts/make-menubar-icon.swift`. Rerun it and commit `MenuBarIcon.pdf` when the mark changes.

## Layout

- `project.yml`: the XcodeGen spec for the app and test targets
- `GoodThoughts/`: the app, with bundled fonts and the icon in `Resources/`
- `scripts/`: the local run script, the icon and placeholder-wallpaper generators, the `.dmg` packer and the appcast writer
- `docs/RELEASING.md`: cutting a release and looking after the update key
- `GoodThoughtsTests/`: unit tests
- `.github/workflows/ci.yml`: builds (Debug and Release) and tests on a macOS runner for pull requests and `main`
- `.github/workflows/release.yml`: publishes a `.dmg` and the Sparkle appcast when a `v*` tag is pushed

## Status

Feature complete for a first release. The feed isn't live yet, so debug builds use a bundled sample feed with placeholder wallpapers until it is.
