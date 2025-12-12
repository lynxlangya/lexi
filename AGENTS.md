# Repository Guidelines

## Project Structure & Module Organization
- macOS SwiftUI app; entry point is `Lexi/LexiApp.swift` which loads `Lexi/ContentView.swift`.
- Place code under `Lexi/` (add subfolders such as `Views`, `Models`, `Services` as the app grows) and keep assets in `Lexi/Assets.xcassets`.
- Add new colors/icons to the asset catalog and reference by asset names to avoid hard-coded resources.
- Tests are not yet set up; add an `LexiTests/` target and mirror the source layout when introducing tests.

## Build, Test, and Development Commands
- Xcode: open `Lexi.xcodeproj`, select the `Lexi` scheme, target macOS, and run.
- CLI debug build:
  ```sh
  xcodebuild -scheme Lexi -configuration Debug -destination 'platform=macOS' build
  ```
- CLI tests (after tests exist):
  ```sh
  xcodebuild test -scheme Lexi -destination 'platform=macOS'
  ```
- SwiftUI previews live next to views via `#Preview { ... }`; keep preview data lightweight to preserve build speed.

## Coding Style & Naming Conventions
- Swift 5 style; 4-space indentation, spaces over tabs.
- Types/enums/structs use UpperCamelCase; functions and variables use lowerCamelCase; assets use descriptive names (`PrimaryBlue`, `AppIcon`).
- Prefer `struct` and `let` defaults, mark access control (`private`) narrowly, and keep view bodies small by extracting reusable subviews.
- Avoid committing generated files (DerivedData) or per-user Xcode settings.

## Testing Guidelines
- Use XCTest; name suites `FeatureNameTests` and methods `test_whenCondition_expectResult`.
- Cover logic-heavy components first; add snapshot or behavior coverage for UI changes when practical.
- Run `xcodebuild test ...` locally before opening a PR and note results in the PR description.

## Commit & Pull Request Guidelines
- Commits: short, imperative summaries (e.g., `Add tap handler for main button`); group related changes.
- PRs: include intent, linked issues, manual/automated test results, and screenshots or gifs for visible UI updates.
- Keep diffs focused; avoid committing local configuration files or unrelated changes.
