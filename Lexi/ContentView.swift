//
//  ContentView.swift
//  Lexi
//
//  Created by 琅邪 on 12/11/25.
//

import SwiftUI
#if os(macOS)
import NaturalLanguage
#endif

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @ObservedObject private var apiKeyStore = APIKeyStore.shared
    @AppStorage("baseURL") private var baseURLString: String = "https://api.openai.com/v1"
    @AppStorage("selectedModel") private var selectedEngineId: String = ModelOptions.defaults.first ?? "gpt-4o"
    @AppStorage("sourceLanguage") private var sourceLanguage: String = "auto"
    @AppStorage("targetLanguage") private var targetLanguage: String = "zh-Hans"
    @AppStorage("autoSwapZhEn") private var autoSwapZhEn: Bool = true

    var body: some View {
        let engines = EngineStore.allEngines()
        TranslationPopupView(
            viewModel: viewModel,
            engines: engines,
            selectedEngineId: $selectedEngineId
        )
        .fixedSize()
        #if os(macOS)
        .ignoresSafeArea(.container, edges: .top)
        #endif
        #if os(macOS)
        .background(WindowAccessor { window in
            WindowManager.shared.attach(window: window)
        })
        .onAppear {
            normalizeSelectedEngineIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiHotKeyPressed)) { _ in
            Task { await handleHotKey() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiPopupDismissRequested)) { _ in
            #if os(macOS)
            TextToSpeechService.shared.stop()
            #endif
            viewModel.clear()
        }
        .onChange(of: selectedEngineId) { newEngineId in
            guard !viewModel.sourceText.isEmpty else { return }
            Task { await translateCurrent(engineId: newEngineId) }
        }
        .onChange(of: viewModel.translatedText) { _ in
            WindowManager.shared.refreshLayout()
        }
        .onChange(of: viewModel.wordExplanation) { _ in
            WindowManager.shared.refreshLayout()
        }
        .onChange(of: viewModel.errorBanner) { _ in
            WindowManager.shared.refreshLayout()
        }
        .onChange(of: viewModel.isLoading) { _ in
            WindowManager.shared.refreshLayout()
        }
        .onExitCommand {
            TextToSpeechService.shared.stop()
            WindowManager.shared.hidePopup()
            viewModel.clear()
        }
        #endif
    }

    @MainActor
    private func handleHotKey() async {
        do {
            let selected = try await SelectionManager.shared.getSelectedText()
            guard let selected,
                  !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return
            }

            WindowManager.shared.showPopupNearMouse()
            viewModel.setSourceText(selected)
            await translateCurrent(engineId: selectedEngineId)
        } catch {
            WindowManager.shared.showPopupNearMouse()
            viewModel.presentError(error)
        }
    }

    private func translateCurrent(engineId: String) async {
        let text = viewModel.sourceText
        guard !text.isEmpty else { return }

        let resolved = resolveLanguages(for: text)
        let engine = EngineStore.engine(for: engineId)
            ?? TranslationEngine(id: engineId, kind: .openAICompatible, displayName: engineId)
        viewModel.streamTranslate { source in
            await TranslationService.shared.streamTranslate(
                engine: engine,
                globalBaseURLString: baseURLString,
                globalAPIKey: apiKeyStore.apiKey,
                sourceLanguage: resolved.source,
                targetLanguage: resolved.target,
                text: source
            )
        }
    }

    @MainActor
    private func normalizeSelectedEngineIfNeeded() {
        if selectedEngineId == "microsoft" {
            selectedEngineId = "google"
            return
        }
        guard EngineStore.engine(for: selectedEngineId) == nil else { return }
        selectedEngineId = ModelOptions.defaults.first ?? "gpt-4o"
    }

    private func resolveLanguages(for text: String) -> (source: String, target: String) {
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

    private func detectPrimaryLanguageCode(for text: String) -> String? {
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

    private func containsHanCharacters(_ text: String) -> Bool {
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

    private func containsASCIILetters(_ text: String) -> Bool {
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

#Preview {
    ContentView()
}
