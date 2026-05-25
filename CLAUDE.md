# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Lexi MVP PR 1-10 have all been merged, and v2.0.1 is the current technical preview release line. Source code is organized by module under `lexi/Sources/`; see [DESIGN.md](DESIGN.md) for historical product decisions and [PR-PLAN.md](PR-PLAN.md) for the completed historical PR breakdown.

The Core Data template has been removed. The app now has the main Reader/Shelf surface, EPUB import, streaming translation, right-side AI read-aloud, MenuBar selection popup, Settings sheet, and Vocab list. Persistence is GRDB-backed SQLite plus Keychain for API keys. The unit test target covers Data, EPUB parsing, translation engines, read-aloud planning/audio cache behavior, and Reader translation controller behavior. There is no CI or lint config yet.

## Build & run

This is an Xcode project (`lexi.xcodeproj`), not a Swift Package — there is no `Package.swift`. SwiftPM dependencies are managed through the Xcode project. Build from the command line with:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

To launch the app, open `lexi.xcodeproj` in Xcode and Run (⌘R). Target is **macOS 26.4**, Swift 5.0, `SDKROOT=macosx`. There is no iOS / iPadOS target.

Run the current unit tests with:

```sh
./scripts/test.sh
```

The test script creates a temporary DerivedData directory and deletes it on exit. Avoid adding new long-lived `/tmp/lexi-*` DerivedData paths.

## Architecture

`lexiApp.swift` is the `@main` entry point. It registers the Reader window scene and the MenuBarExtra scene, wires both through `LexiMenuBarCoordinator`, and keeps Lexi resident after the main window closes by switching to accessory activation policy.

`lexi/Sources/` is the source root:

- `App/` — application entry and lifecycle
- `Reader/` — Reader main window, Shelf, EPUB import flow, translation state UI, read-aloud drawer, and Vocab sheet
- `MenuBar/` — status-bar agent, selection monitoring, NSPanel popup, replacement, speech, and global shortcuts
- `Engines/` — translation engine integrations, SSE parsing, and engine preferences
- `Audio/` — Doubao TTS provider, narration profile service, audio cache, and read-aloud request models
- `Data/` — local persistence and secure configuration storage
- `EPUB/` — EPUB parsing
- `UI/` — shared UI tokens, fonts, Settings sheet, and reusable controls

Current data-layer files:

- `Sources/Data/Models.swift` — v1 record types and `EngineID`
- `Sources/Data/Migrations.swift` — GRDB schema migrations, including vocab and audio cache tables
- `Sources/Data/Database.swift` — `AppDatabase` actor backed by `DatabasePool`
- `Sources/Data/Keychain.swift` — API key storage, service `com.lexi.engine.<id>`

API keys must stay in Keychain, not SQLite.

Current app surfaces:

- Reader/Shelf: `Sources/Reader/ReaderWindow.swift`, `ShelfView.swift`, `ReadingColumn.swift`, `ChapterTranslationController.swift`
- Read aloud: `Sources/Reader/ReaderReadAloudController.swift`, `ReaderReadAloudPanel.swift`, `Sources/Audio/{TTSProvider,DoubaoTTSProvider,NarrationProfileService,AudioCache}.swift`
- MenuBar popup: `Sources/MenuBar/LexiMenuBarExtra.swift`, `PopupPanel.swift`, `PopupContent.swift`
- Settings/Vocab: `Sources/UI/SettingsSheet.swift`, `Sources/Reader/VocabView.swift`
- Translation engines: `Sources/Engines/{OpenAIEngine,AnthropicEngine,DeepSeekEngine,EngineRegistry}.swift`

## Engine configuration

API keys for OpenAI / Anthropic / DeepSeek are configured in the app through Settings → 引擎. Doubao TTS keys are configured through Settings → 朗读. Runtime code must use the persisted configuration path:

- API keys live in Keychain via `Sources/Data/Keychain.swift`.
- Engine model / last test status live in SQLite `EngineConfig`.
- TTS provider/resource/speaker/speech-rate live in `LexiDefaultsKey`; the TTS API key uses Keychain service prefix `com.lexi.tts`.
- `EngineRegistry.shared` reads Keychain only. Do not add `.env.local`, `DevSecrets`, build-time secrets, or DEBUG-only key overrides.
- If a key is ever exposed in logs, screenshots, PRs, or issue comments, rotate it immediately at the provider's dashboard.
