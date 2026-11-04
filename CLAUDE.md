# goodthoughts-mac

A macOS menu bar app that shows one quote a day from goodthoughts (<https://goodthoughts.page>) and sets it as the desktop wallpaper with one click.

The site renders the wallpapers; the app doesn't. The site publishes wallpaper-sized PNGs and a JSON feed, and the app reads the feed, picks today's quote, shows it and applies its image. Never redraw quotes in Swift: the design lives in one place, the site's `site/src/lib/og.ts` (Satori and resvg).

The site's source is next door at `../goodthoughts` (its own repo, STACK-42/goodthoughts). The two repos talk only through the public feed URL. Read it for reference, but don't edit it unless the user adds it with `/add-dir` and asks; its own CLAUDE.md, branches and pull requests apply there.

## Stack

- Swift 6 language mode, SwiftUI, macOS 13+. `MenuBarExtra` with `.menuBarExtraStyle(.window)`, no Dock icon (`LSUIElement = YES`).
- XcodeGen: `project.yml` is the source of truth. `GoodThoughts.xcodeproj` is generated and gitignored, so never hand-edit it; change `project.yml` and regenerate.
- Targets: `GoodThoughts` (the app, sources in `GoodThoughts/`) and `GoodThoughtsTests` (XCTest unit tests hosted in the app, in `GoodThoughtsTests/`).
- App Sandbox on, with outgoing network only, plus the two mach-lookup exceptions Sparkle's installer needs.
- No Apple Developer account, by the user's choice: builds are ad-hoc signed (`CODE_SIGN_IDENTITY = -`) and not notarised, and users approve the app once in Privacy & Security. The hardened runtime is off, because it only matters for notarisation and its library validation can reject the ad-hoc-signed Sparkle framework.
- One dependency: Sparkle 2 (Swift package, pinned in `project.yml`) for automatic updates from GitHub Releases. `GoodThoughts/Updates/Updater.swift` wraps it in `#if canImport(Sparkle)`. Ask before adding any other.

## Commands

```sh
xcodegen generate                         # writes GoodThoughts.xcodeproj
xcodebuild build -project GoodThoughts.xcodeproj -scheme GoodThoughts -destination 'platform=macOS'
xcodebuild test  -project GoodThoughts.xcodeproj -scheme GoodThoughts -destination 'platform=macOS'
open GoodThoughts.xcodeproj               # then Cmd-R to run
```

The user's Mac has only the Command Line Tools, not Xcode, so `xcodebuild` doesn't work locally and CI is where the app is built and tested. Locally:

```sh
scripts/run.sh                            # swiftc build of build/local/GoodThoughts.app, ad-hoc signed, then opens it
scripts/run.sh --no-open                  # build only; CI runs this too so it keeps working
swift scripts/make-menubar-icon.swift     # regenerate GoodThoughts/Resources/MenuBarIcon.pdf
swift scripts/make-app-icon.swift         # regenerate GoodThoughts/Resources/AppIcon.icns
swift scripts/make-sample-wallpapers.swift  # regenerate the placeholder PNGs in GoodThoughts/Sample
scripts/make-dmg.sh <app> <out.dmg>       # pack an app into a drag-to-install disk image
```

Releases: pushing a `v*` tag runs `.github/workflows/release.yml`, which builds the app, packs the `.dmg`, signs it with the Sparkle EdDSA key (secret `SPARKLE_ED_PRIVATE_KEY`) and publishes it with `appcast.xml`. Details are in `docs/RELEASING.md`. Tagging and releasing are the user's call: never push a tag yourself. Never change `SUPublicEDKey` either; installed copies would stop accepting updates.

`run.sh` reads its build settings from `project.yml` and copies every non-Swift file under `GoodThoughts/` into `Contents/Resources`, flattened as Xcode does. It can't compile asset catalogs or expand macros, so don't add either; keep resources as plain files. That rules out `#Preview` and, in the macOS 27 SDK, SwiftUI's `@State` (now a macro): keep view state in an `ObservableObject` held by `@StateObject`, or in `AppModel`. `@StateObject`, `@ObservedObject`, `@Published` and `@Environment` are fine. The agent can't see the screen (no Screen Recording permission), so the user checks the UI by hand.

## Feed contract

`https://goodthoughts.page/wallpapers.json`. It's proposed as v1 and isn't live yet. Until it is, code against the local fixture (in the test bundle, and as a debug-build fallback).

```json
{
  "version": "1.0",
  "generated": "2026-11-04T00:00:00Z",
  "quotes": [
    {
      "id": "allen-calmness",
      "number": "No. 001",
      "text": "…",
      "author": "James Allen",
      "source": "As a Man Thinketh",
      "lang": "en",
      "url": "https://goodthoughts.page/q/allen-calmness/",
      "wallpapers": {
        "16x10": "https://goodthoughts.page/wallpaper/q/allen-calmness/16x10.png",
        "16x9": "https://goodthoughts.page/wallpaper/q/allen-calmness/16x9.png"
      }
    }
  ]
}
```

- `author` and `source` can be empty strings. `lang` is `"en"` or `"ar"`.
- `version` is semver: the minor number goes up for additions, the major for breaking changes. Ignore unknown fields. If the major version is one the app doesn't know, show "Update the app" instead of failing.
- Cache the last good feed on disk and fall back to it when offline.

## Behaviour

- Daily pick: days since a fixed epoch, counted on the local calendar date, mod the number of quotes, in feed order. Every Mac shows the same quote on the same local day, and there's no server logic.
- Apply: for each `NSScreen`, download the PNG whose aspect ratio (`16x10` or `16x9`) is closest to the screen's, cache it in Application Support, and call `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` on the main thread, scaled to fill.
- Spaces limit: there's no public API to set the wallpaper on every Space, so Apply changes the current Space only. The UI says so ("Applies to the current desktop"). Don't edit the wallpaper plist or script Mission Control to get around it.

## Brand

Copy values from `../goodthoughts/docs/brand/HybridA.dc.html`, not its markup. They're in code in `GoodThoughts/Brand/Palette.swift`.

- Paper `#FAFAF7`, ink `#2B2B2B`, card `#FFFFFF`, greys `#3D3D3D #5C5C5C #8A8A85 #E2E2DC #EFEFEA`.
- Highlighter `#F2D649` is the only colour.
- Fonts (all OFL, bundled): EB Garamond for quote text, Instrument Serif for headings, JetBrains Mono for metadata and UI, Amiri for Arabic. Metadata labels are uppercase mono with wide tracking (about 0.1em).
- Arabic: right-to-left layout, no letter-spacing (letters join), more line spacing than Latin.
- Respect Reduce Motion. Support light and dark appearance.
- Icon: No. 07 "Underlined" in `../goodthoughts/docs/brand/icon/IconsCropped.dc.html`, a serif "g" (Instrument Serif) over a highlighter bar rotated -5°. The menu bar uses a monochrome template version.

## Work plan

The app is built in rounds: setup, menu bar shell, feed and daily pick, apply, the real popover, daily automation (ask first), distribution (ask first). Do one round at a time. At the end of a round, build, run the tests, push and merge, then report what changed, what was tested, and exactly what the user should click and see, because the agent can't see the menu bar. Wait for the go-ahead before the next round.

If something in the plan turns out to be wrong or impossible on macOS, stop and say so rather than working around it.

## Git (overrides the global "don't push unless I ask")

The repo is public, so following the global rule for public repos, work directly on `main`: no feature branches unless the user asks for one.

Push ordinary work without asking: when a change is done and committed, push `main` and check that CI passes; if it fails, fix it straight away. Ordinary work covers features, fixes, tests, docs, refactors and CI tweaks.

Ask first for anything hard to undo or outside the code: force-pushes or history rewrites, tags and releases, changing repo settings or secrets (including the Sparkle key), and adding a dependency.

All other global git rules still apply: small commits by the seven rules, run through the humanizer, and open issues for out-of-scope work instead of leaving TODO comments.
