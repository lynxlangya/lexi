//
//  TextToSpeechService.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

#if os(macOS)
import AVFoundation
import Combine
import Foundation

@MainActor
final class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggleSpeak(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            stop()
            return
        }

        speak(trimmed)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            // Use a graceful stop to avoid occasional CoreAudio zero-buffer warnings.
            synthesizer.stopSpeaking(at: .word)
        }
        isSpeaking = false
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice(for: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = false
        synthesizer.speak(utterance)
    }

    private func preferredVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let language = Self.containsHanCharacters(text) ? "zh-CN" : "en-US"

        // Prefer compact system voices to avoid Siri/Assistant voice selection quirks.
        let preferredIdentifierByLanguage: [String: String] = [
            "en-US": "com.apple.voice.compact.en-US.Samantha",
            "zh-CN": "com.apple.voice.compact.zh-CN.Tingting",
        ]
        if let identifier = preferredIdentifierByLanguage[language],
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }

        return AVSpeechSynthesisVoice(language: language)
    }

    private static func containsHanCharacters(_ text: String) -> Bool {
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
}

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}
#endif
