//
//  TranslationViewModel.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Combine
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var wordExplanation: WordExplanation?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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
        errorMessage = nil
    }

    var copyText: String {
        if let wordExplanation {
            return wordExplanation.copyText
        }
        return translatedText
    }

    func translate(using translator: @escaping (String) async throws -> String) {
        activeTask?.cancel()
        isLoading = true
        errorMessage = nil
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
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func streamTranslate(using translator: @escaping (String) async throws -> AsyncThrowingStream<String, Error>) {
        activeTask?.cancel()
        isLoading = true
        errorMessage = nil
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
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func parseWordExplanationIfPossible() {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return }
        guard let data = trimmed.data(using: .utf8) else { return }
        if let decoded = try? JSONDecoder().decode(WordExplanation.self, from: data),
           !decoded.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            wordExplanation = decoded
        }
    }
}
