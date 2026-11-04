# goodthoughts for Mac

[![CI](https://github.com/STACK-42/goodthoughts-mac/actions/workflows/ci.yml/badge.svg)](https://github.com/STACK-42/goodthoughts-mac/actions/workflows/ci.yml)

A menu bar app that shows one quote a day from [goodthoughts](https://goodthoughts.page) and sets it as your desktop wallpaper with one click.

The wallpapers are drawn by the goodthoughts site, which publishes them with a JSON feed at `https://goodthoughts.page/wallpapers.json`. The app reads the feed, works out today's quote from the date, and applies its image to each screen. Every Mac gets the same quote on the same day.

> [!NOTE]
> macOS has no public way to set the wallpaper on every Space, so Apply changes the current desktop only.

## Install

Download the `.dmg` from [Releases](https://github.com/STACK-42/goodthoughts-mac/releases), open it, and drag goodthoughts to Applications. Then click the **g** in the menu bar. Turn on *Open at login* and *Set each morning* there if you want a new wallpaper every day.

> [!NOTE]
> There are no releases yet. [docs/RELEASING.md](docs/RELEASING.md) lists the Apple Developer setup needed first.

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

Without Xcode, `scripts/run.sh` builds the app with the Command Line Tools and opens it. It needs XcodeGen too.

The menu bar icon is generated from the brand mark by `swift scripts/make-menubar-icon.swift`. Rerun it and commit `MenuBarIcon.pdf` when the mark changes.

## Layout

- `project.yml`: the XcodeGen spec for the app and test targets
- `GoodThoughts/`: the app, with bundled fonts and the icon in `Resources/`
- `scripts/`: the local run script, the icon and placeholder-wallpaper generators, and the `.dmg` packer
- `docs/RELEASING.md`: signing, notarisation and releases
- `GoodThoughtsTests/`: unit tests
- `.github/workflows/ci.yml`: builds (Debug and Release) and tests on a macOS runner for pull requests and `main`
- `.github/workflows/release.yml`: signs, notarises and publishes a `.dmg` when a `v*` tag is pushed

## Status

Feature complete for a first release. The feed isn't live yet, so debug builds use a bundled sample feed with placeholder wallpapers until it is.
