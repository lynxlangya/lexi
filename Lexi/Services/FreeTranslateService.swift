//
//  FreeTranslateService.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

enum FreeTranslateError: LocalizedError {
    case unsupportedEngine
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedEngine:
            return "Unsupported free engine."
        case .invalidResponse:
            return "Invalid response from translation service."
        case let .httpError(code, message):
            return "HTTP \(code): \(message)"
        }
    }
}

actor FreeTranslateService {
    static let shared = FreeTranslateService()

    func translate(
        engineId: String,
        sourceLanguage: String,
        targetLanguage: String,
        text: String
    ) async throws -> String {
        switch engineId {
        case "google":
            return try await translateWithGoogle(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, text: text)
        case "microsoft":
            return try await translateWithMicrosoft(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, text: text)
        default:
            throw FreeTranslateError.unsupportedEngine
        }
    }

    private func translateWithGoogle(sourceLanguage: String, targetLanguage: String, text: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: googleCode(from: sourceLanguage)),
            URLQueryItem(name: "tl", value: googleCode(from: targetLanguage)),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        let url = components.url!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw FreeTranslateError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FreeTranslateError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [Any]
        if let first = json?.first as? [[Any]] {
            let translated = first.compactMap { $0.first as? String }.joined()
            return translated
        }
        throw FreeTranslateError.invalidResponse
    }

    private func translateWithMicrosoft(sourceLanguage: String, targetLanguage: String, text: String) async throws -> String {
        var components = URLComponents(string: "https://api-edge.cognitive.microsofttranslator.com/translate")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: microsoftCode(from: targetLanguage)),
        ]
        let fromCode = microsoftCode(from: sourceLanguage)
        if fromCode != "auto" {
            items.append(URLQueryItem(name: "from", value: fromCode))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([["Text": text]])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FreeTranslateError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FreeTranslateError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        struct MicrosoftResponse: Decodable {
            struct Translation: Decodable { let text: String }
            let translations: [Translation]
        }

        let decoded = try JSONDecoder().decode([MicrosoftResponse].self, from: data)
        return decoded.first?.translations.first?.text ?? ""
    }

    private func googleCode(from code: String) -> String {
        switch code {
        case "zh-Hans":
            return "zh-CN"
        case "zh-Hant":
            return "zh-TW"
        default:
            return code
        }
    }

    private func microsoftCode(from code: String) -> String {
        switch code {
        case "zh-Hans":
            return "zh-Hans"
        case "zh-Hant":
            return "zh-Hant"
        default:
            return code
        }
    }
}

