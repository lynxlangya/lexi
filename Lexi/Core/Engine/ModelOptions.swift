//
//  ModelOptions.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

enum ModelOptions {
    static let freeEngines: [String] = [
        "google",
    ]

    static let openAIModels: [String] = [
        "gpt-4o",
    ]

    static let deepSeekModels: [String] = [
        "deepseek-chat",
    ]

    // Keep GPT as the default choice while still exposing free engines.
    static let defaults: [String] = openAIModels + deepSeekModels + freeEngines
}
