//
//  APIKeyStore.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

import Combine
import Foundation
import os

private let keychainLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Lexi",
    category: "Keychain"
)

@MainActor
final class APIKeyStore: ObservableObject {
    static let shared = APIKeyStore()

    @Published var apiKey: String {
        didSet { persist(apiKey) }
    }

    private let service: String
    private let account = "global_api_key"

    private init() {
        service = Bundle.main.bundleIdentifier ?? "Lexi"

        let keychainValue = (try? KeychainHelper.loadString(service: service, account: account)) ?? nil
        if let keychainValue, !keychainValue.isEmpty {
            apiKey = keychainValue
        } else if let legacy = UserDefaults.standard.string(forKey: "apiKey"),
                  !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apiKey = legacy
            persist(legacy)
            UserDefaults.standard.removeObject(forKey: "apiKey")
        } else {
            apiKey = ""
            UserDefaults.standard.removeObject(forKey: "apiKey")
        }
    }

    private func persist(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try KeychainHelper.delete(service: service, account: account)
            } else {
                try KeychainHelper.saveString(trimmed, service: service, account: account)
            }
        } catch {
            // Keychain errors should not crash the UI; log for debugging.
            keychainLogger.error("Keychain error: \(String(describing: error), privacy: .public)")
        }

        // Ensure legacy value isn't kept around.
        UserDefaults.standard.removeObject(forKey: "apiKey")
    }
}
