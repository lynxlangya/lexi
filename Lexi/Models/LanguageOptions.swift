//
//  LanguageOptions.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let displayName: String
}

enum LanguageOptions {
    static let all: [LanguageOption] = [
        LanguageOption(id: "auto", displayName: "自动检测"),
        LanguageOption(id: "en", displayName: "英文"),
        LanguageOption(id: "zh-Hans", displayName: "中文（简体）"),
        LanguageOption(id: "zh-Hant", displayName: "中文（繁体）"),
        LanguageOption(id: "ja", displayName: "日文"),
        LanguageOption(id: "ko", displayName: "韩文"),
        LanguageOption(id: "fr", displayName: "法文"),
        LanguageOption(id: "de", displayName: "德文"),
        LanguageOption(id: "es", displayName: "西班牙文"),
        LanguageOption(id: "ru", displayName: "俄文"),
    ]

    static let targets: [LanguageOption] = all.filter { $0.id != "auto" }

    static func name(for code: String) -> String {
        all.first(where: { $0.id == code })?.displayName ?? code
    }
}

