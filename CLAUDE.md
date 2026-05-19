# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Lexi v1 MVP has been initiated. Source code is organized by module under `lexi/Sources/`; see [DESIGN.md](DESIGN.md) and [PR-PLAN.md](PR-PLAN.md) for the locked product decisions and staged PR plan.

There are no business Swift modules yet beyond the minimal app entry placeholder. There are no tests, no CI, no package manager, and no lint config.

## Build & run

This is an Xcode project (`lexi.xcodeproj`), not a Swift Package — there is no `Package.swift` and no SwiftPM dependencies. Build from the command line with:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

To launch the app, open `lexi.xcodeproj` in Xcode and Run (⌘R). Target is **macOS 26.4**, Swift 5.0, `SDKROOT=macosx`. There is no iOS / iPadOS target.

There is no test target yet, so `xcodebuild test` will fail until one is added.

## Architecture

`lexiApp.swift` is the `@main` entry point and currently displays a placeholder `WindowGroup("Lexi")` scene. Real windows and app lifecycle code will land in later PRs.

`lexi/Sources/` is the v1 source root:

- `App/` — application entry and lifecycle
- `Reader/` — Reader main window, Shelf, and Settings sheet
- `MenuBar/` — status-bar agent and panel UI
- `Engines/` — translation engine integrations
- `Data/` — local persistence and secure configuration storage
- `EPUB/` — EPUB parsing
- `UI/` — shared UI tokens, fonts, and controls
