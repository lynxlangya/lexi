# Lexi

> A minimal macOS “selection translator” popover for language learners.

![snipaste](./snipaste.png)

## Features

- Floating, glass-like popup near the mouse cursor
- Global hotkey to translate the current selection (Accessibility / AXUIElement)
- OpenAI-compatible streaming (works with OpenAI / DeepSeek and many gateways)
- Free Google translate fallback (non-streaming)
- English word learning mode: single-word selections render a dictionary-style card (US IPA + POS senses) with Text-to-Speech
- Settings: source/target language, hotkey, launch at login, engine selection, custom OpenAI-compatible engines
- Click outside the popup to dismiss and clear content

## Requirements

- macOS 14+
- Xcode 15+ (for building from source)

## Quick Start

1. Select text in any app.
2. Press the global hotkey (default: `⌘⇧L`).
3. Lexi shows a floating popup near your mouse with the translation result.
4. Click anywhere outside the popup to close it.

## Permissions

Lexi needs Accessibility permission to read the selected text from other apps.

- System Settings → Privacy & Security → Accessibility → enable **Lexi**
- If you just enabled it, restart Lexi once.

## Engines & Configuration

Open **Settings…** from the menu bar icon or the popup’s gear button.

### Built-in engines

- **Google** (free, non-streaming; may be rate-limited)
- **gpt-4o** (OpenAI-compatible, streaming)
- **deepseek-chat** (OpenAI-compatible, streaming; set Base URL to DeepSeek)

### OpenAI-compatible Base URL examples

- OpenAI: `https://api.openai.com/v1`
- DeepSeek: `https://api.deepseek.com` (Lexi auto-completes `/v1/chat/completions`)

API Keys are stored in **macOS Keychain** (not in `UserDefaults`).

### Custom engines

In Settings, you can add custom OpenAI-compatible engines by providing:

- Engine name (optional)
- Base URL
- Model
- API Key (optional; falls back to the global key if empty)

## Development

- Open `Lexi.xcodeproj`, select the `Lexi` scheme, and run.
- CLI build:

```sh
xcodebuild -scheme Lexi -configuration Debug -destination 'platform=macOS' build
```

## Troubleshooting

- **Hotkey does nothing**: confirm Accessibility is enabled for Lexi; check if the hotkey conflicts with another app.
- **No popup appears**: Lexi won’t show the popup if the selection is empty.
- **HTTP 401/429 or network errors**: check the API Key, Base URL, and your quota/network.

## Architecture

See `Architecture.md`.

## Privacy & Security

- Selected text may be sent to the chosen translation provider (OpenAI/DeepSeek/Google). Avoid translating sensitive content if you don’t trust the provider.
- API Keys are stored in macOS Keychain.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
