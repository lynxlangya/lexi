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
    @AppStorage("apiKey") private var apiKey: String = ""
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
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func translateCurrent(engineId: String) async {
        let text = viewModel.sourceText
        guard !text.isEmpty else { return }

        if ModelOptions.freeEngines.contains(engineId) {
            viewModel.translate { source in
                try await FreeTranslateService.shared.translate(
                    engineId: engineId,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    text: source
                )
            }
            return
        }

        if let customEngine = EngineStore.loadCustomEngines().first(where: { $0.id == engineId }),
           let baseURLString = customEngine.baseURL,
           let baseURL = URL(string: baseURLString),
           !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = (customEngine.apiKey?.isEmpty == false) ? (customEngine.apiKey ?? "") : apiKey
            let config = LLMService.Configuration(
                baseURL: baseURL,
                apiKey: key,
                model: customEngine.resolvedModel,
                systemPrompt: systemPrompt()
            )
            viewModel.streamTranslate { source in
                await LLMService.shared.streamTranslate(configuration: config, sourceText: source)
            }
            return
        }

        let baseURL = URL(string: baseURLString) ?? URL(string: "https://api.openai.com/v1")!
        let config = LLMService.Configuration(
            baseURL: baseURL,
            apiKey: apiKey,
            model: engineId,
            systemPrompt: systemPrompt()
        )
        viewModel.streamTranslate { source in
            await LLMService.shared.streamTranslate(configuration: config, sourceText: source)
        }
    }

    private func systemPrompt() -> String {
        let targetName = LanguageOptions.name(for: targetLanguage)
        if sourceLanguage == "auto" {
            return "You are a translation assistant. Detect the source language and translate the user's text into \(targetName). Preserve markdown formatting."
        }
        let sourceName = LanguageOptions.name(for: sourceLanguage)
        return "You are a translation assistant. Translate the user's text from \(sourceName) into \(targetName). Preserve markdown formatting."
    }
}

#Preview {
    ContentView()
}
