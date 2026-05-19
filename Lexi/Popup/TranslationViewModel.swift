//
//  TranslationViewModel.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Combine
import Foundation

struct ErrorBanner: Hashable, Identifiable {
    enum Style: Hashable {
        case warning
        case error
    }

    enum Action: Hashable {
        case openAccessibilitySettings
    }

    let id = UUID()
    let message: String
    let style: Style
    let action: Action?
}

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var wordExplanation: WordExplanation?
    @Published var isLoading: Bool = false
    @Published var errorBanner: ErrorBanner?

    private var activeTask: Task<Void, Never>?

    func setSourceText(_ text: String) {
        sourceText = text
    }

    func clear() {
        activeTask?.cancel()
        activeTask = nil
        sourceText = ""
        translatedText = ""
        wordExplanation = nil
        isLoading = false
        errorBanner = nil
    }

    func translate(using translator: @escaping (String) async throws -> String) {
        activeTask?.cancel()
        isLoading = true
        errorBanner = nil
        translatedText = ""
        wordExplanation = nil

        activeTask = Task {
            do {
                let result = try await translator(sourceText)
                guard !Task.isCancelled else { return }
                translatedText = result
                parseWordExplanationIfPossible()
            } catch {
                guard !Task.isCancelled else { return }
                presentError(error)
            }
            isLoading = false
        }
    }

    func streamTranslate(using translator: @escaping (String) async throws -> AsyncThrowingStream<String, Error>) {
        activeTask?.cancel()
        isLoading = true
        errorBanner = nil
        translatedText = ""
        wordExplanation = nil

        activeTask = Task {
            do {
                let stream = try await translator(sourceText)
                for try await token in stream {
                    guard !Task.isCancelled else { return }
                    translatedText += token
                }
                parseWordExplanationIfPossible()
            } catch {
                guard !Task.isCancelled else { return }
                presentError(error)
            }
            isLoading = false
        }
    }

    func presentError(_ error: Error) {
        if error is SelectionError {
            errorBanner = ErrorBanner(
                message: error.localizedDescription,
                style: .warning,
                action: .openAccessibilitySettings
            )
            return
        }

        if let translationError = error as? TranslationError {
            errorBanner = ErrorBanner(
                message: translationError.localizedDescription,
                style: translationError.severity == .warning ? .warning : .error,
                action: nil
            )
            return
        }

        errorBanner = ErrorBanner(message: error.localizedDescription, style: .error, action: nil)
    }

    private func parseWordExplanationIfPossible() {
        guard LanguageDetector.isEnglishWordQuery(sourceText) else { return }
        guard let jsonString = extractJSONFragment(from: translatedText),
              let data = jsonString.data(using: .utf8)
        else { return }

        if let decoded = try? JSONDecoder().decode(WordExplanation.self, from: data),
           !decoded.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            wordExplanation = decoded
        }
    }

    private func extractJSONFragment(from text: String) -> String? {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let cleanedLines = lines.filter { line in
            !line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }
        let cleaned = cleanedLines.joined(separator: "\n")
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end
        else { return nil }
        return String(cleaned[start...end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
