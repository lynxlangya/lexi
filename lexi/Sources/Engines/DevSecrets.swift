import Foundation

#if DEBUG
nonisolated enum DevSecrets {
    static func apiKey(for engine: EngineID) -> String? {
        let values = load()
        let key: String?
        switch engine {
        case .openai:
            key = values["OPENAI_API_KEY"]
        case .anthropic:
            key = values["ANTHROPIC_API_KEY"]
        case .deepseek:
            key = values["DEEPSEEK_API_KEY"]
        }
        return nonEmpty(key)
    }

    static func defaultEngineConfig() -> EngineConfig? {
        let values = load()
        let candidates: [(EngineID, String, String)] = [
            (.deepseek, "DEEPSEEK_API_KEY", "DEEPSEEK_MODEL"),
            (.openai, "OPENAI_API_KEY", "OPENAI_MODEL"),
            (.anthropic, "ANTHROPIC_API_KEY", "ANTHROPIC_MODEL"),
        ]

        for (engine, keyName, modelName) in candidates {
            guard nonEmpty(values[keyName]) != nil else {
                continue
            }
            let model = resolvedModel(nonEmpty(values[modelName]), for: engine)
            return EngineConfig(
                id: engine,
                model: model,
                lastTestedOK: false,
                lastTestedAt: nil
            )
        }

        return nil
    }

    private static func load() -> [String: String] {
        guard let data = try? String(contentsOf: envURL(), encoding: .utf8) else {
            return [:]
        }

        return data.split(whereSeparator: \.isNewline).reduce(into: [:]) { values, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty,
                  !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=") else {
                return
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
    }

    private static func envURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".env.local")
    }

    private static func resolvedModel(_ model: String?, for engine: EngineID) -> String {
        guard let model = nonEmpty(model) else {
            return ReaderFixtureStore.defaultModel(for: engine)
        }

        if engine == .deepseek, model == "deepseek-v4-flash" {
            print("[Lexi] DEBUG: DEEPSEEK_MODEL=deepseek-v4-flash is not publicly available; falling back to deepseek-chat.")
            return "deepseek-chat"
        }

        return model
    }
}

nonisolated private func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else {
        return nil
    }
    return value
}
#endif
