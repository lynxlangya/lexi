# AGENTS.md

```yaml
version: v0.2
author: langya
update: 2026-05-20
```

## Project Snapshot

- `lexi` is a macOS SwiftUI app for the locked Lexi v1 MVP described in `DESIGN.md`.
- PR 1-10 from `PR-PLAN.md` are complete and merged. Treat `PR-PLAN.md` as a historical execution plan plus acceptance index, not as an active backlog.
- Source code is organized under `lexi/Sources/` by module.
- The Xcode Core Data template has been removed. Do not reintroduce `NSPersistentContainer`, `.xcdatamodeld`, or template `Item` models.
- The v1 data layer uses GRDB-backed SQLite plus Keychain for API keys.
- This repository is an Xcode project, not a Swift Package. SwiftPM dependencies are managed through `lexi.xcodeproj`.
- Current product surfaces are Reader/Shelf, MenuBar selection popup, Settings, and Vocab.

## Tech Stack

- Platform: macOS app only.
- Project: `lexi.xcodeproj`.
- Scheme: `lexi`.
- Source root: `lexi/`.
- Deployment target: macOS `26.4`.
- Swift version: `5.0`.
- Bundle identifier: `com.langya.lexi`.
- Dependencies via Xcode SwiftPM integration: `GRDB.swift`, `ZIPFoundation`, `SwiftSoup`, `KeyboardShortcuts`.

## Build And Run

Use this command for a basic Debug build:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

Run the app from Xcode with the `lexi` scheme.

Use this command for the current unit test suite:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug -derivedDataPath /tmp/lexi-derived test
```

## Current Files

- `lexi/lexiApp.swift`: app entry point registering `ReaderWindow` and `LexiMenuBarExtra`.
- `lexi/Sources/UI/`: shared color, font, spacing tokens, and token preview.
- `lexi/Sources/Data/`: GRDB database actor, migrations, record models, and Keychain wrapper.
- `lexi/Sources/EPUB/`: EPUB parser, OPF/NAV helpers, and cover extraction.
- `lexi/Sources/Engines/`: OpenAI, Anthropic, DeepSeek, SSE parsing, and engine preferences.
- `lexi/Sources/Reader/`: Reader, Shelf, import flow, translation state controller, shortcuts, and Vocab.
- `lexi/Sources/MenuBar/`: MenuBarExtra, NSPanel popup, global shortcuts, AX selection/replacement, and speech.
- `lexiTests/`: Data, EPUB, Engine, and Reader translation controller tests.
- `CLAUDE.md`: companion guidance with current project facts.

## Coding Guidance

- Keep changes small and product-driven. Do not add abstractions before there is real app behavior to support.
- Prefer SwiftUI-native state and view composition before adding external dependencies.
- If adding dependencies, document why the built-in Apple framework is insufficient and how the dependency is integrated.
- Keep generated Xcode project edits narrow. Avoid unnecessary churn in `project.pbxproj`.
- Store business data in `AppDatabase`/SQLite and API keys in Keychain. API keys must not be persisted in SQLite.
- Runtime engine configuration must come from Settings → 引擎: API keys in Keychain, model/status in SQLite `EngineConfig`. Do not add `.env.local`, `DevSecrets`, or DEBUG-only key/model overrides.
- Reader window chrome uses native `.toolbar`, `.windowStyle(.titleBar)`, and `.windowToolbarStyle(.unified)`. Do not bring back Reader `fullSizeContentView`, `titlebarAppearsTransparent`, hidden title bars, or custom traffic lights.
- MenuBar translation popup is the exception that intentionally uses `NSPanel` with `.nonactivatingPanel`, `.borderless`, and `.fullSizeContentView` so it does not steal focus.
- Global shortcuts use `sindresorhus/KeyboardShortcuts`: `⌘⇧L` translate selection, `⌘⇧T` translate and replace selection, `⌘⇧K` show/hide Reader.

## Verification

- For compile-impacting changes, run the Debug build command above when feasible.
- For data-layer changes, run the unit test command above.
- For UI changes, build first, then use Xcode or the app UI for direct visual verification when needed.
- For MenuBar, AX selection/replacement, and global shortcut changes, physical keyboard/manual macOS permission smoke tests are required; synthetic automation is not reliable enough for final sign-off.
- If a command cannot be run because of local signing, SDK, or simulator constraints, report the exact blocker and any narrower validation completed.

## Safety

- Do not expose signing credentials, provisioning details, secrets, tokens, or local `.env` values in logs or responses.
- Do not add telemetry, analytics, network calls, or external services unless the user explicitly asks for them.
- Do not delete or reset user changes. This repository may contain uncommitted local work.
