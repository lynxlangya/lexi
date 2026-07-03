import Foundation
import Security

nonisolated enum Keychain {
    private static let store = KeychainStore(servicePrefix: "com.lexi.engine")

    static func setApiKey(_ key: String, for engine: EngineID) {
        try? setApiKeyThrowing(key, for: engine)
    }

    static func apiKey(for engine: EngineID) -> String? {
        try? apiKeyThrowing(for: engine)
    }

    static func delete(_ engine: EngineID) {
        try? deleteThrowing(engine)
    }

    static func setApiKeyThrowing(_ key: String, for engine: EngineID) throws {
        try store.setApiKey(key, for: engine)
    }

    static func apiKeyThrowing(for engine: EngineID) throws -> String? {
        try store.apiKey(for: engine)
    }

    static func deleteThrowing(_ engine: EngineID) throws {
        try store.delete(engine)
    }
}

nonisolated enum TTSKeychain {
    private static let store = GenericKeychainStore(servicePrefix: "com.lexi.tts")

    static func setApiKey(_ key: String, for provider: TTSProviderID) {
        try? setApiKeyThrowing(key, for: provider)
    }

    static func apiKey(for provider: TTSProviderID) -> String? {
        try? apiKeyThrowing(for: provider)
    }

    static func delete(_ provider: TTSProviderID) {
        try? deleteThrowing(provider)
    }

    static func setApiKeyThrowing(_ key: String, for provider: TTSProviderID) throws {
        try store.setApiKey(key, account: provider.rawValue)
    }

    static func apiKeyThrowing(for provider: TTSProviderID) throws -> String? {
        try store.apiKey(account: provider.rawValue)
    }

    static func deleteThrowing(_ provider: TTSProviderID) throws {
        try store.delete(account: provider.rawValue)
    }
}

nonisolated struct KeychainStore: Sendable {
    let servicePrefix: String

    func setApiKey(_ key: String, for engine: EngineID) throws {
        try generic.setApiKey(key, account: engine.rawValue)
    }

    func apiKey(for engine: EngineID) throws -> String? {
        try generic.apiKey(account: engine.rawValue)
    }

    func delete(_ engine: EngineID) throws {
        try generic.delete(account: engine.rawValue)
    }

    private var generic: GenericKeychainStore {
        GenericKeychainStore(servicePrefix: servicePrefix)
    }
}

nonisolated struct GenericKeychainStore: Sendable {
    let servicePrefix: String

    func setApiKey(_ key: String, account: String) throws {
        let data = Data(key.utf8)
        let query = baseQuery(account: account)

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            try check(updateStatus)
        case errSecItemNotFound:
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            try check(addStatus)
        default:
            try check(status)
        }
    }

    func apiKey(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            try check(status)
            return nil
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status != errSecItemNotFound {
            try check(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(servicePrefix).\(account)",
            kSecAttrAccount as String: "apiKey",
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            LexiLog.dbError("Keychain operation failed status=\(status)")
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: Error, Equatable {
    var status: OSStatus
}
