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

nonisolated struct KeychainStore: Sendable {
    let servicePrefix: String

    func setApiKey(_ key: String, for engine: EngineID) throws {
        let data = Data(key.utf8)
        let query = baseQuery(for: engine)

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

    func apiKey(for engine: EngineID) throws -> String? {
        var query = baseQuery(for: engine)
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

    func delete(_ engine: EngineID) throws {
        let status = SecItemDelete(baseQuery(for: engine) as CFDictionary)
        if status != errSecItemNotFound {
            try check(status)
        }
    }

    private func baseQuery(for engine: EngineID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(servicePrefix).\(engine.rawValue)",
            kSecAttrAccount as String: "apiKey",
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: Error, Equatable {
    var status: OSStatus
}
