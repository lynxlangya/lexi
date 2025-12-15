//
//  SettingsView.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("sourceLanguage") private var sourceLanguage: String = "auto"
    @AppStorage("targetLanguage") private var targetLanguage: String = "zh-Hans"
    @AppStorage("hotKeyCode") private var hotKeyCode: Int = Int(HotKey.default.keyCode)
    @AppStorage("hotKeyModifiers") private var hotKeyModifiers: Int = Int(HotKey.default.modifiers)

    // Selected engine/model id (kept for backward compatibility).
    @AppStorage("selectedModel") private var selectedEngineId: String = ModelOptions.defaults.first ?? "gpt-4o-mini"

    // Global OpenAI-compatible config used by built-in AI models.
    @ObservedObject private var apiKeyStore = APIKeyStore.shared
    @AppStorage("baseURL") private var globalBaseURL: String = "https://api.openai.com/v1"

    #if os(macOS)
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    #endif

    @State private var customEngines: [TranslationEngine] = EngineStore.loadCustomEngines()
    @State private var showingAddEngine = false

    var body: some View {
        Form {
            Section("基本设置") {
                HStack(alignment: .top, spacing: 16) {
                    LanguagePickerColumn(
                        title: "源语种",
                        options: LanguageOptions.all,
                        selection: $sourceLanguage
                    )
                    LanguagePickerColumn(
                        title: "翻译语种",
                        options: LanguageOptions.targets,
                        selection: $targetLanguage
                    )
                }

#if os(macOS)
                HStack {
                    Text("快捷键")
                    Spacer()
                    HotKeyRecorderField(hotKey: hotKeyBinding)
                        .frame(width: 120, height: 22)
                        .fixedSize()
                }
                Text("点击后按下新的快捷键，Esc 取消。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("开机自启动", isOn: launchAtLoginBinding)
#endif
            }

            Divider()

            Section("翻译引擎") {
                Picker("引擎/模型", selection: $selectedEngineId) {
                    Section("免费引擎") {
                        ForEach(freeEngines) { engine in
                            Text(engine.displayName).tag(engine.id)
                        }
                    }
                    Section("AI 引擎") {
                        ForEach(aiEngines) { engine in
                            Text(engine.displayName).tag(engine.id)
                        }
                    }
                    if !customEngines.isEmpty {
                        Section("自定义引擎") {
                            ForEach(customEngines) { engine in
                                Text(engine.displayName).tag(engine.id)
                            }
                        }
                    }
                }

                engineConfigurationSection

                Button("添加自定义 AI 引擎…") {
                    showingAddEngine = true
                }
            }
        }
        .padding(12)
        .frame(width: 460)
        .sheet(isPresented: $showingAddEngine) {
            AddCustomEngineSheet(customEngines: $customEngines, selectedEngineId: $selectedEngineId)
        }
        .onChange(of: customEngines) { engines in
            EngineStore.saveCustomEngines(engines)
        }
        #if os(macOS)
        .onAppear {
            LaunchAtLoginManager.shared.refresh()
        }
        #endif
    }

    private var hotKeyBinding: Binding<HotKey> {
        Binding(
            get: {
                HotKey(keyCode: UInt32(hotKeyCode), modifiers: UInt32(hotKeyModifiers))
            },
            set: { newValue in
                hotKeyCode = Int(newValue.keyCode)
                hotKeyModifiers = Int(newValue.modifiers)
                HotKeyManager.shared.updateHotKey(newValue)
            }
        )
    }

    #if os(macOS)
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { newValue in
                launchAtLogin.setEnabled(newValue)
            }
        )
    }
    #endif

    private var freeEngines: [TranslationEngine] {
        EngineStore.builtInEngines.filter { $0.kind == .free }
    }

    private var aiEngines: [TranslationEngine] {
        EngineStore.builtInEngines.filter { $0.kind == .openAICompatible }
    }

    private var selectedCustomEngineIndex: Int? {
        customEngines.firstIndex(where: { $0.id == selectedEngineId })
    }

    @ViewBuilder
    private var engineConfigurationSection: some View {
        if let index = selectedCustomEngineIndex {
            VStack(alignment: .leading, spacing: 8) {
                TextField("引擎名称", text: $customEngines[index].displayName)
                    .textFieldStyle(.roundedBorder)

                TextField(
                    "API Base URL",
                    text: Binding(
                        get: { customEngines[index].baseURL ?? "" },
                        set: { customEngines[index].baseURL = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "模型",
                    text: Binding(
                        get: { customEngines[index].model ?? "" },
                        set: { customEngines[index].model = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                SecureField(
                    "API Key（可选）",
                    text: Binding(
                        get: { customEngines[index].apiKey ?? "" },
                        set: { customEngines[index].apiKey = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button("删除该引擎", role: .destructive) {
                    let removedId = customEngines[index].id
                    customEngines.remove(at: index)
                    if selectedEngineId == removedId {
                        selectedEngineId = ModelOptions.defaults.first ?? "gpt-4o-mini"
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 6)
        } else if ModelOptions.freeEngines.contains(selectedEngineId) {
            Text("免费引擎无需 API 配置。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SecureField("API Key", text: $apiKeyStore.apiKey)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                TextField("Base URL", text: $globalBaseURL)
                    .textFieldStyle(.roundedBorder)

                Text("OpenAI 兼容接口，例如 https://api.openai.com/v1 或 https://api.deepseek.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }
}

private struct LanguagePickerColumn: View {
    let title: String
    let options: [LanguageOption]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AddCustomEngineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var customEngines: [TranslationEngine]
    @Binding var selectedEngineId: String

    @State private var displayName: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var apiKey: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("引擎名称") {
                        TextField("可选，用于展示", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("API Base URL") {
                        TextField("https://api.openai.com/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("模型") {
                        TextField("gpt-4o-mini", text: $model)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("API Key") {
                        SecureField("可选，留空使用全局 Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("自定义 AI 引擎")
                }

                Text("支持任意 OpenAI 兼容接口，可直接粘贴完整的 endpoint。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("添加自定义引擎")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let engine = TranslationEngine(
                            id: UUID().uuidString,
                            kind: .openAICompatible,
                            displayName: displayName.isEmpty ? model : displayName,
                            baseURL: baseURL,
                            apiKey: apiKey,
                            model: model,
                            isCustom: true
                        )
                        customEngines.append(engine)
                        selectedEngineId = engine.id
                        dismiss()
                    }
                    .disabled(baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 420, height: 320)
    }
}

#Preview {
    SettingsView()
}
