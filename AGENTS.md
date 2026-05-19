# AGENTS.md

```yaml
version: v0.1
author: langya
update: 2026-05-19
```

## Project Snapshot

- `lexi` is a macOS SwiftUI app for the locked Lexi v1 MVP described in `DESIGN.md`.
- Source code is organized under `lexi/Sources/` by module.
- The Xcode Core Data template has been removed. Do not reintroduce `NSPersistentContainer`, `.xcdatamodeld`, or template `Item` models.
- The v1 data layer uses GRDB-backed SQLite plus Keychain for API keys.
- This repository is an Xcode project, not a Swift Package. SwiftPM dependencies are managed through `lexi.xcodeproj`.

## Tech Stack

- Platform: macOS app only.
- Project: `lexi.xcodeproj`.
- Scheme: `lexi`.
- Source root: `lexi/`.
- Deployment target: macOS `26.4`.
- Swift version: `5.0`.
- Bundle identifier: `com.langya.lexi`.
- Data dependency: `GRDB.swift` via Xcode SwiftPM integration.

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

- `lexi/lexiApp.swift`: app entry point with a placeholder `WindowGroup("Lexi")`.
- `lexi/Sources/UI/`: shared color, font, spacing tokens, and token preview.
- `lexi/Sources/Data/`: GRDB database actor, migrations, record models, and Keychain wrapper.
- `lexiTests/DataTests.swift`: migration, CRUD, and Keychain smoke tests.
- `CLAUDE.md`: companion guidance with current project facts.

## Coding Guidance

- Keep changes small and product-driven. Do not add abstractions before there is real app behavior to support.
- Prefer SwiftUI-native state and view composition before adding external dependencies.
- If adding dependencies, document why the built-in Apple framework is insufficient and how the dependency is integrated.
- Keep generated Xcode project edits narrow. Avoid unnecessary churn in `project.pbxproj`.
- Store business data in `AppDatabase`/SQLite and API keys in Keychain. API keys must not be persisted in SQLite.

## Verification

- For compile-impacting changes, run the Debug build command above when feasible.
- For data-layer changes, run the unit test command above.
- For UI changes, build first, then use Xcode or the app UI for direct visual verification when needed.
- If a command cannot be run because of local signing, SDK, or simulator constraints, report the exact blocker and any narrower validation completed.

## Safety

- Do not expose signing credentials, provisioning details, secrets, tokens, or local `.env` values in logs or responses.
- Do not add telemetry, analytics, network calls, or external services unless the user explicitly asks for them.
- Do not delete or reset user changes. This repository may contain uncommitted local work.
