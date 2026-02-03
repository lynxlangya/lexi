//
//  ContentView.swift
//  Lexi
//
//  Created by 琅邪 on 12/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @ObservedObject private var apiKeyStore = APIKeyStore.shared
    @AppStorage("baseURL") private var baseURLString: String = "https://api.openai.com/v1"
    @AppStorage("selectedModel") private var selectedEngineId: String = ModelOptions.defaults.first ?? "gpt-4o"
    @AppStorage("sourceLanguage") private var sourceLanguage: String = "auto"
    @AppStorage("targetLanguage") private var targetLanguage: String = "zh-Hans"

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

        let engine = EngineStore.engine(for: engineId)
            ?? TranslationEngine(id: engineId, kind: .openAICompatible, displayName: engineId)
        viewModel.streamTranslate { source in
            await TranslationService.shared.streamTranslate(
                engine: engine,
                globalBaseURLString: baseURLString,
                globalAPIKey: apiKeyStore.apiKey,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
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
}

#Preview {
    ContentView()
}
