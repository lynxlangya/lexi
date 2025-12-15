//
//  ContentView.swift
//  Lexi
//
//  Created by 琅邪 on 12/11/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @ObservedObject private var apiKeyStore = APIKeyStore.shared
    @AppStorage("baseURL") private var baseURLString: String = "https://api.openai.com/v1"
    @AppStorage("selectedModel") private var selectedEngineId: String = ModelOptions.defaults.first ?? "gpt-4o-mini"
    @AppStorage("sourceLanguage") private var sourceLanguage: String = "auto"
    @AppStorage("targetLanguage") private var targetLanguage: String = "zh-Hans"

    var body: some View {
        let engines = EngineStore.allEngines()
        TranslationPopupView(
            viewModel: viewModel,
            onCopy: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
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
        .onReceive(NotificationCenter.default.publisher(for: .lexiHotKeyPressed)) { _ in
            Task { await handleHotKey() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexiPopupDismissRequested)) { _ in
            viewModel.clear()
        }
        .onChange(of: selectedEngineId) { newEngineId in
            guard !viewModel.sourceText.isEmpty else { return }
            Task { await translateCurrent(engineId: newEngineId) }
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
}

#Preview {
    ContentView()
}
