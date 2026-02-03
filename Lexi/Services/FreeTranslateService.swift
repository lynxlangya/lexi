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
            return "不支持的免费引擎。"
        case .invalidResponse:
            return "翻译服务返回异常。"
        case let .httpError(code, message):
            return "HTTP \(code)：\(message)"
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
}
