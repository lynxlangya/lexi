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
        isLoading = false
        errorMessage = nil
    }

    func translate(using translator: @escaping (String) async throws -> String) {
        activeTask?.cancel()
        isLoading = true
        errorMessage = nil
        translatedText = ""

        activeTask = Task {
            do {
                let result = try await translator(sourceText)
                guard !Task.isCancelled else { return }
                translatedText = result
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

        activeTask = Task {
            do {
                let stream = try await translator(sourceText)
                for try await token in stream {
                    guard !Task.isCancelled else { return }
                    translatedText += token
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
