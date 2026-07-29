//
//  KeychainStore.swift
//  CalorieAI
//
//  API keys (Claude, OpenAI, Gemini) live only in the Keychain — never in
//  UserDefaults, SwiftData, or a plist. Entered once in onboarding /
//  Settings, read here by `ClaudeClient` and the image providers.
//

import Foundation
import Security

enum APIKeyKind: String {
    case anthropic = "com.calorieai.apikey.anthropic"
    case openAI = "com.calorieai.apikey.openai"
    case gemini = "com.calorieai.apikey.gemini"
}

enum KeychainStore {
    private static let service = "com.calorieai.apikeys"

    static func apiKey(for kind: APIKeyKind) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Pass `nil` to remove a stored key.
    static func setAPIKey(_ value: String?, for kind: APIKeyKind) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
        ]

        guard let value, !value.isEmpty else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        // Try update first; if nothing exists yet, add.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func hasKey(for kind: APIKeyKind) -> Bool {
        apiKey(for: kind)?.isEmpty == false
    }
}
