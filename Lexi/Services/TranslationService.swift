//
//  TranslationService.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

import Foundation

enum TranslationErrorSeverity: Hashable {
    case warning
    case error
}

enum TranslationError: LocalizedError, Hashable {
    case httpStatus(Int)
    case noInternet
    case missingAPIKey
    case invalidResponse
    case unsupportedEngine
    case unknown

    var severity: TranslationErrorSeverity {
        switch self {
        case .noInternet, .httpStatus(429):
            return .warning
        default:
            return .error
        }
    }

    var errorDescription: String? {
        switch self {
        case .httpStatus(401):
            return "API Key is invalid or expired."
        case .httpStatus(429):
            return "Usage limit exceeded. Please check your quota."
        case .noInternet:
            return "Please check your network connection."
        case let .httpStatus(code):
            return "Translation failed (Error code: \(code))."
        case .missingAPIKey:
            return "API Key is missing."
        case .invalidResponse:
            return "Translation failed. Please try again."
        case .unsupportedEngine:
            return "Unsupported engine."
        case .unknown:
            return "Translation failed. Please try again."
        }
    }

    static func from(_ error: Error) -> TranslationError {
        if let error = error as? TranslationError {
            return error
        }

        if let urlError = error as? URLError, isNoInternet(urlError) {
            return .noInternet
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let urlCode = URLError.Code(rawValue: nsError.code)
            if isNoInternet(URLError(urlCode)) {
                return .noInternet
            }
        }

        if let llmError = error as? LLMServiceError {
            switch llmError {
            case let .httpError(code, _):
                return .httpStatus(code)
            case .missingAPIKey:
                return .missingAPIKey
            case .invalidResponse:
                return .invalidResponse
            }
        }

        if let freeError = error as? FreeTranslateError {
            switch freeError {
            case let .httpError(code, _):
                return .httpStatus(code)
            case .unsupportedEngine:
                return .unsupportedEngine
            case .invalidResponse:
                return .invalidResponse
            }
        }

        return .unknown
    }

    private static func isNoInternet(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

actor TranslationService {
    static let shared = TranslationService()

    func streamTranslate(
        engine: TranslationEngine,
        globalBaseURLString: String,
        globalAPIKey: String,
        sourceLanguage: String,
        targetLanguage: String,
        text: String
    ) async -> AsyncThrowingStream<String, Error> {
        if engine.kind == .free {
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let translated = try await FreeTranslateService.shared.translate(
                            engineId: engine.id,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage,
                            text: text
                        )
                        continuation.yield(translated)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: TranslationError.from(error))
                    }
                }
            }
        }

        let engineBaseURLString = engine.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseURLString = engineBaseURLString.isEmpty ? globalBaseURLString : engineBaseURLString
        let baseURL = URL(string: baseURLString)
            ?? URL(string: globalBaseURLString)
            ?? URL(string: "https://api.openai.com/v1")!

        let engineKey = engine.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = engineKey.isEmpty ? globalAPIKey : engineKey

        let config = LLMService.Configuration(
            baseURL: baseURL,
            apiKey: apiKey,
            model: engine.resolvedModel,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        let stream = await LLMService.shared.streamTranslate(configuration: config, sourceText: text)
        return mapErrors(from: stream)
    }

    private func mapErrors(from stream: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await token in stream {
                        if Task.isCancelled { break }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TranslationError.from(error))
                }
            }
        }
    }
}
