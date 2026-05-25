<p align="center">
  <img src="https://img.wangyun.fan/lexi_board.png" alt="Lexi — bilingual macOS reader" width="900">
</p>

# Lexi

**English** · [简体中文](README.zh-CN.md)

A native macOS reader for English books, with streaming Chinese translation rendered next to the original text, AI read-aloud in a right-side player drawer, and a global selection-translation popup that follows you into any app.

> **Status — v2.1.0 MVP release line.** Reader, EPUB import, streaming translation, AI read-aloud, MenuBar popup, vocabulary list, and side-by-side dual-column layout have all shipped. Technical preview builds are distributed through GitHub Releases and Homebrew Cask.

---

## Why Lexi

Most "AI translation" tools treat the translation as the final artifact. Lexi treats the translation as scaffolding: the English original is the thing you're reading, and the Chinese is meant to live at the edge of your vision — ready when you need it, easy to ignore when you don't. That single decision shapes every choice below.

- **Quiet typography.** Warm paper background, single serif column, no skeuomorphism. Optimized for 1–2 hours of continuous reading.
- **Translation is on-demand and cached.** Paragraphs are translated lazily as you read, streamed sentence by sentence, and stored locally — so re-opening a book costs nothing.
- **Side-by-side or stacked.** Toggle between the classic stacked layout (English paragraph above its Chinese translation) and the new dual-column layout (English left, Chinese right, top-aligned).
- **Read aloud without losing your place.** Open the right-side read-aloud drawer, choose original or translation, and keep playback going chapter to chapter while the current chunk stays highlighted.
- **Works outside the reader.** Select English text in Safari, Mail, Notes, or any other app and trigger a popup with single-word definitions or full-sentence translations — same engines, same vocabulary list.
- **Bring your own keys.** No accounts, no backend, no subscription. API keys live in Keychain and are sent only to the provider you configure.

---

## Highlights

### A reader designed for bilingual reading, not just translation viewing

- **Paragraph-level streaming translation.** Each paragraph is a separate LLM call, streamed as it arrives, with previous EN/ZH paragraph used as few-shot context for literary continuity.
- **Two layouts.** **Dual column** (default) places English and Chinese side by side with equal font size and top-aligned rows — short translations naturally leave whitespace below. **Stacked** keeps the classic "English above, demoted Chinese below" pattern. Toggle from the toolbar or Settings.
- **Three display modes.** EN-only, ZH-only, or both — switchable inline with `⌘B`.
- **Chapter prefetching.** While you read chapter N, Lexi quietly translates chapter N+1 in the background.
- **Per-paragraph retry.** If a single paragraph fails (rate-limit, network blip), only that paragraph shows an inline error and later paragraphs keep translating. Partial or truncated output is rejected instead of cached.

### AI read-aloud that feels like a player, not a modal

- **Right-side drawer.** The reader can become a compact playback surface: cover, chapter, progress, play/pause, previous/next chunk, previous/next chapter, and a scrollable read-aloud transcript.
- **Original or translation.** Narration is intentionally single-language at a time. The drawer can read the English original or the cached Chinese translation, and the transcript follows the same choice.
- **Book-aware style profile.** Before narration, Lexi samples the book and current chapter through the configured translation engine to build a compact tone/pace/pronunciation profile for TTS.
- **Doubao-first TTS.** The current AI voice provider is Doubao TTS (`seed-tts-2.0` by default), with API key stored in Keychain and audio cached locally. The system voice is used only as a fallback when the TTS key or speaker is missing.

### A MenuBar surface that follows you everywhere

- **Global selection translation.** Highlight English text in any macOS app, hit `⌘⇧L`, and a non-activating panel appears near the selection with a Lexi-style word card or sentence card.
- **Word vs. phrase vs. sentence routing.** The popup picks the right card based on the selection's shape — single word gets a dictionary entry with multiple senses and IPA, phrase gets idiom-aware lookup, sentence gets a clean translation.
- **One click into the vocabulary list.** Star a word from the popup; it lands in your shared vocab list (and is scoped to the book you saved it from, if you saved it inside the reader).

### Vocabulary that remembers context

- **Snapshot definitions.** When you save a word, Lexi stores not just the headword but the LLM's full lookup payload at that moment (senses, IPA, example) — so subsequent provider updates can't quietly rewrite your saved meanings.
- **Per-book and global scopes.** Saved-while-reading words remember their source book; saved-from-popup words live in a global pool. Filter the vocab list by either.
- **Local-first.** All entries live in SQLite. No sync, no telemetry.

### Engine flexibility without engine sprawl

- **Three presets:** OpenAI, Anthropic, DeepSeek. Each accepts a free-form model name (so you can run `gpt-4-turbo` today and `gpt-5` tomorrow without an app update).
- **Separate engines for paragraph and popup.** Use a cheap fast model for chapter translation and a smarter model for selection lookups — or vice versa.
- **Mid-chapter engine switching is non-destructive.** Already-cached paragraphs keep their original translation; only future paragraphs use the new engine.

---

## Requirements

- **macOS 26.4 or later**
- **Xcode 26 or later** (Swift 5.0 toolchain)
- API key for at least one of: OpenAI · Anthropic · DeepSeek
- Optional Doubao TTS API key and speaker ID for AI read-aloud

---

## Install

Install with Homebrew:

```sh
brew tap lynxlangya/tap
brew install --cask lexi
```

Or download the latest zip from [GitHub Releases](https://github.com/lynxlangya/lexi/releases).

Current preview builds are ad-hoc signed and not Apple-notarized. If macOS blocks the first launch, allow Lexi from System Settings → Privacy & Security, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Lexi.app
open /Applications/Lexi.app
```

## Build from source

```sh
git clone https://github.com/lynxlangya/lexi.git
cd lexi
open lexi.xcodeproj
```

Then ⌘R in Xcode to build and run. Or from the command line:

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

First-run setup:

1. Launch the app. The shelf opens empty.
2. **Settings → Engines.** Paste an API key for OpenAI, Anthropic, or DeepSeek and enter the model name (defaults are suggested). Click **Test** to verify.
3. Optional: **Settings → Read Aloud.** Paste the Doubao TTS key, resource ID, and speaker ID if you want AI narration.
4. **Drag an EPUB onto the shelf** (or use `⌘O`). Lexi parses the file, extracts the cover, and adds it to your shelf.
5. Click the book to open the reader. Translation starts streaming for the visible chapter immediately.

---

## Configuration

| Setting | Where | Notes |
|---|---|---|
| API keys | Settings → Engines | Stored in macOS Keychain (service `com.lexi.engine.<id>`). Never written to SQLite, logs, or source. |
| Paragraph layout | Toolbar button · Settings → Reader → Translation Display | Stacked or dual-column. Default is dual. |
| Display mode | Toolbar button · `⌘B` | English-only / Chinese-only / both. |
| Font, line height, theme, accent | Settings → Reader | Independent of OS appearance; supports system-follow, day, night. |
| Chapter prefetch | Settings → Reader → Translation Display | 0–2 chapters ahead. |
| AI read-aloud | Settings → Read Aloud | Doubao TTS provider, resource ID, speaker ID, speech rate, local audio cache. |
| Keyboard shortcuts | Settings → Shortcuts | Most are remappable; conflict detection optional. |

### Key shortcuts

- `⌘⇧L` — Global selection translation popup (works in any app)
- `⌘⇧K` — Show/hide reader window from anywhere
- `⌘B` — Cycle display mode (both / EN-only / ZH-only) inside reader
- `⌘+` / `⌘-` — Adjust font size while reading

---

## Architecture

Lexi is an Xcode project (`lexi.xcodeproj`) — **not** a Swift package — with SwiftPM dependencies managed through the project file. Source is organized under `lexi/Sources/`:

| Module | Responsibility |
|---|---|
| `App/` | `@main` entry, MenuBarExtra wiring, lifecycle, scenes |
| `Reader/` | Reader window, Shelf, EPUB import flow, paragraph rendering, translation state UI, vocab sheet |
| `MenuBar/` | Status-bar agent, selection monitoring (Accessibility API), `NSPanel` popup, speech, global shortcuts |
| `Engines/` | OpenAI / Anthropic / DeepSeek integrations, SSE parsing, structured lookup schema, prompts |
| `Audio/` | Doubao TTS provider, narration profile generation, audio cache, read-aloud request models |
| `Data/` | GRDB-backed `AppDatabase` actor, migrations, models, Keychain wrapper |
| `EPUB/` | Archive extraction, OPF/Nav parsing, cover extraction |
| `UI/` | Design tokens, fonts, Settings sheet, reusable controls |

See [`DESIGN.md`](DESIGN.md) for v1 product decisions and [`PR-PLAN.md`](PR-PLAN.md) for the historical breakdown of how the MVP was built.

---

## Tech stack

- **Swift 5 / SwiftUI** with AppKit hybridization (`NSPanel`, `NSEvent` monitors, custom window chrome)
- **[GRDB.swift](https://github.com/groue/GRDB.swift)** — SQLite access via an actor-backed `DatabasePool`
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)** — EPUB archive extraction
- **[SwiftSoup](https://github.com/scinfu/SwiftSoup)** — XHTML chapter parsing
- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** — User-rebindable global shortcuts
- **macOS Keychain** — API key storage
- **Doubao TTS + AVFoundation** — AI narration via Doubao SSE audio, local playback/cache via `AVPlayer`, system speech fallback via `AVSpeechSynthesizer`

No iOS / iPadOS target. Targets macOS 26.4, `SDKROOT=macosx`.

---

## Development

Run the unit tests:

```sh
./scripts/test.sh
```

Coverage spans Data (GRDB migrations, vocab/audio CRUD), EPUB parsing, translation engines (request shaping, SSE parsing, retry behavior), Reader translation controller state machine, read-aloud planning/audio cache behavior, selection context resolution, and paragraph layout modes.

The test script uses a temporary DerivedData directory and removes it on exit, so repeated CLI verification does not accumulate `/tmp/lexi-*` build artifacts. There is no CI or lint config in the repo yet.

### Security

- API keys must stay in Keychain. This includes translation engine keys and Doubao TTS keys. There is no `.env`, no DEBUG-only override, no build-time secret path.
- If a key is exposed in logs, screenshots, PRs, or issues, rotate it at the provider's dashboard immediately.

---

## Project status

v2.1.0 is the current MVP technical preview release line: PR 1–10 have landed, follow-up fixes and read-aloud iteration are merged, and installable builds are available through GitHub Releases and `lynxlangya/tap`.

For roadmap and product decisions, see [`DESIGN.md`](DESIGN.md).

---

## License

No open-source license has been granted yet. Treat the source as visible but not reusable until a license file is added.
