//
//  TranslationPopupView.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import SwiftUI

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let onCopy: (String) -> Void
    let engines: [TranslationEngine]
    @Binding var selectedEngineId: String
    #if os(macOS)
    @ObservedObject private var tts = TextToSpeechService.shared
    #endif

    var body: some View {
        VStack(spacing: 12) {
            header

            content

            footer
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .frame(width: 360)
        #if os(macOS)
        .onChange(of: viewModel.translatedText) { newValue in
            if newValue.isEmpty {
                TextToSpeechService.shared.stop()
            }
        }
        #endif
    }

	    private var header: some View {
	        HStack(spacing: 8) {
	            Image(systemName: "sparkles")
	                .font(.system(size: 14, weight: .semibold))
	            Text("Lexi")
	                .font(.system(size: 13, weight: .semibold))
	            Spacer()
	            #if os(macOS)
	            modelMenu
	            SettingsLink {
	                Image(systemName: "gearshape")
	            }
	            .buttonStyle(.plain)
	            #endif
	        }
	    }

	    #if os(macOS)
	    private var modelMenu: some View {
	        Menu {
	            let freeEngines = engines.filter { $0.kind == .free }
	            let aiEngines = engines.filter { $0.kind == .openAICompatible && !$0.isCustom }
	            let customEngines = engines.filter { $0.kind == .openAICompatible && $0.isCustom }

	            if !freeEngines.isEmpty {
	                Section("免费引擎") {
	                    ForEach(freeEngines) { engine in
	                        modelItem(title: engine.displayName, value: engine.id)
	                    }
	                }
	            }

	            if !aiEngines.isEmpty {
	                Divider()
	                Section("AI 模型") {
	                    ForEach(aiEngines) { engine in
	                        modelItem(title: engine.displayName, value: engine.id)
	                    }
	                }
	            }

	            if !customEngines.isEmpty {
	                Divider()
	                Section("自定义引擎") {
	                    ForEach(customEngines) { engine in
	                        modelItem(title: engine.displayName, value: engine.id)
	                    }
	                }
	            }
	        } label: {
	            Image(systemName: "square.stack.3d.up")
	                .font(.system(size: 13, weight: .semibold))
	                .padding(.horizontal, 4)
	        }
	        .menuStyle(.borderlessButton)
	        .help("Switch Model")
	    }

	    @ViewBuilder
	    private func modelItem(title: String, value: String) -> some View {
	        Button {
	            selectedEngineId = value
	        } label: {
	            if selectedEngineId == value {
	                Label(title, systemImage: "checkmark")
	            } else {
	                Text(title)
	            }
	        }
	    }
	    #endif

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.wordExplanation == nil, !viewModel.sourceText.isEmpty {
                Text(viewModel.sourceText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let banner = viewModel.errorBanner {
                ErrorBannerView(banner: banner)
            } else if let explanation = viewModel.wordExplanation {
                #if os(macOS)
                WordExplanationView(
                    explanation: explanation,
                    onSpeak: { TextToSpeechService.shared.toggleSpeak(text: explanation.word) }
                )
                #else
                WordExplanationView(explanation: explanation, onSpeak: {})
                #endif
            } else if !viewModel.translatedText.isEmpty {
                MarkdownText(viewModel.translatedText)
            } else {
                Text("Select text and press the hotkey to translate.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

	    private var footer: some View {
	        HStack {
	            Button {
	                onCopy(viewModel.copyText)
	            } label: {
	                Label("Copy", systemImage: "doc.on.doc")
	                    .font(.system(size: 12))
	            }
	            .buttonStyle(.borderless)
	            .disabled(viewModel.copyText.isEmpty)

	            #if os(macOS)
	            if viewModel.wordExplanation == nil {
	                Button {
	                    TextToSpeechService.shared.toggleSpeak(text: englishSpeakText)
	                } label: {
	                    Image(systemName: tts.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2")
	                        .font(.system(size: 12))
	                }
	                .buttonStyle(.borderless)
	                .disabled(englishSpeakText.isEmpty)
	                .help(tts.isSpeaking ? "Stop Speaking" : "Speak")
	            }
	            #endif

	            Spacer()
	            Text(selectedEngineName)
	                .font(.system(size: 12))
	                .foregroundStyle(.secondary)
	                .padding(.horizontal, 8)
	                .padding(.vertical, 4)
	                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
	        }
	    }

	    private var selectedEngineName: String {
	        engines.first(where: { $0.id == selectedEngineId })?.displayName ?? selectedEngineId
	    }

	    private var englishSpeakText: String {
	        if let explanation = viewModel.wordExplanation, !explanation.word.isEmpty {
	            return explanation.word
	        }
	        if looksLikeEnglish(viewModel.sourceText) {
	            return viewModel.sourceText
	        }
	        if looksLikeEnglish(viewModel.translatedText) {
	            return viewModel.translatedText
	        }
	        return ""
	    }

	    private func looksLikeEnglish(_ text: String) -> Bool {
	        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
	        guard !trimmed.isEmpty else { return false }

	        let allowedPunctuation = CharacterSet(charactersIn: "'-.,!?;:()\"/\\")
	        var hasAsciiLetter = false

	        for scalar in trimmed.unicodeScalars {
	            if (65...90).contains(scalar.value) || (97...122).contains(scalar.value) {
	                hasAsciiLetter = true
	                continue
	            }
	            if scalar.properties.isWhitespace {
	                continue
	            }
	            if allowedPunctuation.contains(scalar) {
	                continue
	            }
	            return false
	        }

	        return hasAsciiLetter
	    }
}

private struct MarkdownText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full)) {
            Text(attributed)
                .font(.system(size: 13))
                .textSelection(.enabled)
        } else {
            Text(markdown)
                .font(.system(size: 13))
                .textSelection(.enabled)
        }
    }
}

#Preview {
    TranslationPopupView(
        viewModel: TranslationViewModel(),
        onCopy: { _ in },
        engines: EngineStore.allEngines(),
        selectedEngineId: .constant("gpt-4o-mini")
    )
    .padding()
    .frame(width: 380)
}
