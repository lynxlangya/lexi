//
//  LanguageDetector.swift
//  Lexi
//
//  Created by Codex on 05/19/26.
//

import Foundation
#if os(macOS)
import NaturalLanguage
#endif

enum LanguageDetector {
    static func resolve(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        autoSwapZhEn: Bool
    ) -> (source: String, target: String) {
        guard autoSwapZhEn, let detected = detectPrimaryLanguageCode(for: text) else {
            return (sourceLanguage, targetLanguage)
        }

        switch detected {
        case "zh-Hans", "zh-Hant":
            return (detected, "en")
        case "en":
            return ("en", "zh-Hans")
        default:
            return (sourceLanguage, targetLanguage)
        }
    }

    static func detectPrimaryLanguageCode(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        #if os(macOS)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            switch lang {
            case .simplifiedChinese:
                return "zh-Hans"
            case .traditionalChinese:
                return "zh-Hant"
            case .english:
                return "en"
            default:
                break
            }
        }
        #endif

        if containsHanCharacters(trimmed) {
            return "zh-Hans"
        }
        if containsASCIILetters(trimmed) {
            return "en"
        }
        return nil
    }

    static func containsHanCharacters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                continue
            }
        }
        return false
    }

    static func containsASCIILetters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 65...90, 97...122:
                return true
            default:
                continue
            }
        }
        return false
    }
}
