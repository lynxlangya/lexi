//
//  WordExplanationView.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

import SwiftUI
import Foundation

struct WordExplanationView: View {
    let explanation: WordExplanation
    #if os(macOS)
    @ObservedObject private var tts = TextToSpeechService.shared
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(explanation.word)
                .font(.system(size: 30, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let phonetic = normalizedPhonetic, !phonetic.isEmpty {
                HStack(spacing: 8) {
                    Text("US")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(phonetic)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)

                    #if os(macOS)
                    Button {
                        TextToSpeechService.shared.toggleSpeak(text: explanation.word)
                    } label: {
                        Image(systemName: tts.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help(tts.isSpeaking ? "停止朗读" : "朗读")
                    #endif

                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(explanation.senses) { sense in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(sense.pos)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .fixedSize()

                        Text(sense.meaning)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let webMeaning = normalizedWebMeaning, !hasWebSense {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("web.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .fixedSize()

                        Text(webMeaning)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var normalizedPhonetic: String? {
        let raw = explanation.phoneticUS?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private var normalizedWebMeaning: String? {
        let raw = explanation.web?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private var hasWebSense: Bool {
        explanation.senses.contains { sense in
            let normalized = sense.pos
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return normalized == "web"
        }
    }
}

#Preview {
    WordExplanationView(
        explanation: WordExplanation(
            word: "Which",
            phoneticUS: "/wɪtʃ/",
            web: "哪一个；哪些；哪一类",
            senses: [
                .init(pos: "pron.", meaning: "哪个；那；哪一个"),
            ]
        )
    )
    .padding()
    .frame(width: 360)
}
