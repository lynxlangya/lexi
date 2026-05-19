# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Lexi v1 MVP has been initiated. Source code is organized by module under `lexi/Sources/`; see [DESIGN.md](DESIGN.md) and [PR-PLAN.md](PR-PLAN.md) for the locked product decisions and staged PR plan.

The Core Data template has been removed. The project now has shared UI tokens and the initial GRDB + Keychain data layer. There is a unit test target for data-layer coverage. There is no CI or lint config yet.

## Build & run

This is an Xcode project (`lexi.xcodeproj`), not a Swift Package — there is no `Package.swift`. SwiftPM dependencies are managed through the Xcode project. Build from the command line with:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

To launch the app, open `lexi.xcodeproj` in Xcode and Run (⌘R). Target is **macOS 26.4**, Swift 5.0, `SDKROOT=macosx`. There is no iOS / iPadOS target.

Run the current unit tests with:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug -derivedDataPath /tmp/lexi-derived test
```

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

Current data-layer files:

- `Sources/Data/Models.swift` — v1 record types and `EngineID`
- `Sources/Data/Migrations.swift` — GRDB v1 schema migration
- `Sources/Data/Database.swift` — `AppDatabase` actor backed by `DatabasePool`
- `Sources/Data/Keychain.swift` — API key storage, service `com.lexi.engine.<id>`

API keys must stay in Keychain, not SQLite.

## Local secrets (`.env.local`)

API keys for OpenAI / Anthropic / DeepSeek used during development live in `.env.local` at the repo root. This file is **gitignored** — do not commit it, do not paste its contents into PR descriptions / issue comments / chat logs.

- `.env.example` (tracked) is the template. After cloning: `cp .env.example .env.local && chmod 600 .env.local`, then fill in your own keys.
- Format: `KEY=VALUE` per line, no quotes, no spaces around `=`. Empty value means "engine not configured" — runtime will skip that engine.
- Used **only in DEBUG builds** by the dev-time engine loader (lands in PR 5). Release builds always read keys from Keychain via Settings → 引擎.
- If a key is ever exposed (committed by accident, shared in a screenshot, etc.), rotate it immediately at the provider's dashboard. Git history is the part that bites.
