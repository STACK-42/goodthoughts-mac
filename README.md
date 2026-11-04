# goodthoughts for Mac

A menu bar app that shows one quote a day from [goodthoughts](https://goodthoughts.page) and sets it as your desktop wallpaper with one click.

The wallpapers are drawn by the goodthoughts site, which publishes them with a JSON feed at `https://goodthoughts.page/wallpapers.json`. The app reads the feed, works out today's quote from the date, and applies its image to each screen. Every Mac gets the same quote on the same day.

> [!NOTE]
> macOS has no public way to set the wallpaper on every Space, so Apply changes the current desktop only.

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

## Layout

- `project.yml`: the XcodeGen spec for the app and test targets
- `GoodThoughts/`: the app
- `GoodThoughtsTests/`: unit tests
- `.github/workflows/ci.yml`: builds and tests on a macOS runner for pull requests and `main`

## Status

Early development. The feed isn't live yet, so the app works from a bundled sample feed until it is.
