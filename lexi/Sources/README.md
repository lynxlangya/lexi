# Lexi Sources

This directory is the home for Lexi v1 source code. The old `ContentView.swift`, `Persistence.swift`, and Core Data model template have been removed.

Module ownership:

- `App/` — reserved for application lifecycle code as the app grows. The current app entry is still `../lexiApp.swift`.
- `Data/` — GRDB-backed SQLite, migrations, record models, and Keychain API key storage.
- `EPUB/` — EPUB parsing, OPF/NAV resolution, cover extraction, and import payload construction.
- `Engines/` — OpenAI, Anthropic, DeepSeek, SSE parsing, and engine preferences.
- `MenuBar/` — MenuBarExtra, selection monitoring, NSPanel popup, global shortcuts, text replacement, toast, and speech.
- `Reader/` — Reader window, Shelf, import flow, translation controller, reading views, shortcuts, Vocab, and fixture seeding.
- `UI/` — shared colors, fonts, spacing tokens, Settings sheet, and reusable controls.

Verification entry points:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug -derivedDataPath /tmp/lexi-derived test
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Release build CODE_SIGNING_ALLOWED=NO
```

Design authority remains `DESIGN.md`; `PR-PLAN.md` is now a completed historical execution plan.
