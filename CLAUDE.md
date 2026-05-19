# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Lexi is a macOS 14+ SwiftUI menu-bar app that translates the current text selection in any app via a global hotkey, showing a borderless glass popup near the mouse. No third-party dependencies — system frameworks only.

## Build & Run

- Open `Lexi.xcodeproj`, select the `Lexi` scheme, run on macOS.
- CLI build:
  ```sh
  xcodebuild -scheme Lexi -configuration Debug -destination 'platform=macOS' build
  ```
- CLI tests:
  ```sh
  xcodebuild test -scheme Lexi -destination 'platform=macOS'
  ```
  Smoke-level coverage in `LexiTests/` (LanguageDetector, EngineStore migration, TranslationCacheKey, TranslationService cancel-cache behavior). Add tests here as you grow features — the target is already wired into the scheme.
- Built artifacts live in `dist/Lexi.app` (zipped + sha256). `site/` is the marketing site, unrelated to the app.

## Runtime requirements (must verify when debugging hotkey/selection issues)

- **Accessibility permission** is mandatory. `SelectionManager` reads selected text via AXUIElement; without it the hotkey appears to "do nothing." Toggle in System Settings → Privacy & Security → Accessibility and restart Lexi.
- App is intended to keep running with no windows — `applicationShouldTerminateAfterLastWindowClosed` returns `false` and `disableAutomaticTermination` is called at launch. Do not "fix" these without understanding the menu-bar-only lifecycle.

## Module layout

```
Lexi/
├── LexiApp.swift / AppDelegate.swift / ContentView.swift   ← entry + popup coordinator
├── Core/
│   ├── Translation/   ← TranslationService (actor, dispatcher), LLMService,
│   │                    FreeTranslateService, TranslationPromptStrategy,
│   │                    TranslationCache, LanguageDetector
│   ├── Engine/        ← EngineStore, TranslationEngine, ModelOptions,
│   │                    LanguageOptions, APIKeyStore
│   └── System/        ← SelectionManager, HotKeyManager, WindowManager,
│                        TextToSpeechService, LaunchAtLoginManager, HotKey
├── Popup/             ← TranslationPopupView, WordExplanationView,
│                        SettingsView, ErrorBannerView, HotKeyRecorderField,
│                        TranslationViewModel, WordExplanation
├── Reader/            ← (placeholder; EPUB reader work lands here)
└── Shared/Utilities/  ← KeychainHelper, Notifications, AppKitHelpers, WindowAccessor
```

Treat `Core/` as the reusable engine (translation + system + engine config) and `Popup/`, `Reader/` as feature surfaces that consume it. If `Reader/` grows substantially or an iOS target appears, `Core/` is the natural SPM split point — but don't pre-extract.

## Architecture (the parts you can't infer from a single file)

MVVM with a thin service layer. Full details in `Architecture.md`; the critical cross-file flow:

1. `AppDelegate.applicationDidFinishLaunching` registers the global hotkey via `HotKeyManager` (Carbon `RegisterEventHotKey`). The callback posts `.lexiHotKeyPressed` on `NotificationCenter` — **the hotkey never calls into views directly**.
2. `ContentView` observes `.lexiHotKeyPressed`, asks `SelectionManager.getSelectedText()` for the current selection, then `WindowManager.shared.showPopupNearMouse()` to display the floating window.
3. `ContentView.translateCurrent(engineId:)` calls a single entry point — `TranslationService.shared.streamTranslate(..., promptStrategy:, cache:)` (an `actor`). **That actor is the real strategy dispatcher**: it inspects `TranslationEngine.kind` and routes to either `FreeTranslateService` (REST; response wrapped into a single-token `AsyncThrowingStream` so the UI sees one consumption shape) or `LLMService` (OpenAI-compatible SSE). It normalizes every error to `TranslationError` via `TranslationError.from(_:)`, and (when a cache is supplied) reads/writes results keyed by `TranslationCacheKey`. New engine kinds belong in `TranslationService`, not `ContentView`. Only `google` remains as a free engine — old `microsoft` ids are silently migrated to `google` by `EngineStore.normalizedEngineId`.
4. `TranslationViewModel` aggregates streamed tokens; `TranslationPopupView` observes it and re-renders Markdown live.
5. `WindowManager` owns the borderless `NSWindow` (`.floating` level, transparent, glass via SwiftUI `Material`) and installs `NSEvent` monitors for click-outside dismissal, which fires `.lexiPopupDismissRequested` back to `ContentView` to clear state.

### Key abstractions to know before touching translation

- **`TranslationPromptStrategy`** ([Core/Translation/TranslationPromptStrategy.swift](Lexi/Core/Translation/TranslationPromptStrategy.swift)) — the system/user prompt is owned by a strategy, not hardcoded in `LLMService`. `promptVersion` is part of every strategy (used as cache key component). Implementations: `WordOrPhrasePromptStrategy` (handles single-word dictionary mode via `SourceAwareTranslationPromptStrategy` extension; preserves the JSON word-card output) and `ParagraphPromptStrategy` (placeholder used by `translateParagraph`; expect prompt iteration as the reader matures).
- **`TranslationCache`** ([Core/Translation/TranslationCache.swift](Lexi/Core/Translation/TranslationCache.swift)) — protocol with `get`/`set` over `TranslationCacheKey { textHash, sourceLanguage, targetLanguage, engineID, modelID, promptVersion }`. Key components are deliberate: change engine, model, or prompt version and old cache misses. Only `InMemoryTranslationCache` ships; reader work needs a SQLite-backed implementation.
- **`TranslationService.translateParagraph`** — non-streaming entry point that internally reuses `streamTranslate` with `ParagraphPromptStrategy` and collects the result. This is what the reader's per-paragraph translator should call (with cache injected). No active call sites yet.
- **`LanguageDetector`** ([Core/Translation/LanguageDetector.swift](Lexi/Core/Translation/LanguageDetector.swift)) — stateless static helpers: `resolve(...)` for zh/en auto-swap, `detectPrimaryLanguageCode(for:)` via `NLLanguageRecognizer`, and `isEnglishWordQuery(_:)` (the single-word detection used by both the popup view-model and `WordOrPhrasePromptStrategy` — **do not duplicate this logic elsewhere**).
- **Cancellation contract in `TranslationService.mapErrors`** — both `Task.isCancelled` (producer task cancelled) and `continuation.onTermination(.cancelled)` (downstream consumer dropped the stream) skip the cache write. Don't regress this: a partial cache write contaminates future reads. There's a regression test in `TranslationServiceCacheTests`.

### Key invariants

- **Selection fallback chain**: `SelectionManager` tries AX (`kAXSelectedTextAttribute`, then range + value), then simulates Cmd+C via `CGEvent` and polls `NSPasteboard.changeCount` (up to 400ms) and reads it, restoring the previous pasteboard snapshot. If you touch this, preserve both the fallback order and the pasteboard restore — apps differ wildly in AX support. `getSelectedTextResult()` exposes an `ExtractedTextSource` enum for instrumentation; the legacy `getSelectedText()` wrapper drops it.
- **API keys live in Keychain**, not `UserDefaults`. Use `Shared/Utilities/KeychainHelper.swift` / `Core/Engine/APIKeyStore.swift`. Legacy `UserDefaults("apiKey")` is migrated on first launch and removed. Do not regress to `@AppStorage` for secrets.
- **Base URL handling**: `LLMService` accepts either a host-only base URL (auto-appends `/v1/chat/completions`) or a full endpoint URL. Don't strip or normalize aggressively.
- **English single-word mode**: when the selection is a single English word, the popup renders a dictionary card (`WordExplanationView` + `WordExplanation` model) with TTS via `TextToSpeechService`, not raw translation Markdown. Branch is driven by `LanguageDetector.isEnglishWordQuery` in both the prompt strategy and the view-model's JSON parser.

### Adding a new translation engine

- **OpenAI-compatible**: add the model id to `Core/Engine/ModelOptions.swift` (`defaults`), optionally surface in `EngineStore.builtInEngines`. No service changes.
- **Non-compatible protocol**: add a case to `TranslationEngine.Kind`, create a new service in `Core/Translation/`, add a branch in `TranslationService.streamTranslate(...)` (wrap non-streaming responses into a single-token `AsyncThrowingStream`), extend `TranslationError.from(_:)` for any new error types, and register in `EngineStore`/`ModelOptions` so it appears in menus.
- **Custom prompting**: if the new engine needs a different prompt shape, add a new `TranslationPromptStrategy` implementation and pass it through — don't hardcode in `LLMService`.

## Conventions

- Swift 5, 4-space indent, `UpperCamelCase` types, `lowerCamelCase` members. Keep view bodies small via extracted subviews. Mark `private` narrowly.
- Assets referenced by name from `Lexi/Assets.xcassets`; don't hard-code colors/icons.
- Don't commit DerivedData or per-user Xcode settings.

## Reference docs in repo

- `Architecture.md` — authoritative architecture write-up (Chinese, detailed).
- `AGENTS.md` — repo guidelines (style, commits, PR expectations).
- `README.md` — user-facing feature/permission/engine notes.
