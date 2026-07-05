import Foundation
import Security

protocol CredentialStore {
    func value(for account: String) throws -> String?
    func setValue(_ value: String?, for account: String) throws
}

enum DefaultCredentialStore {
    static let disableKeychainEnvironmentKey = "RUNNING_OVERLAY_DISABLE_KEYCHAIN"

    static func make(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any CredentialStore {
        if environment[disableKeychainEnvironmentKey] == "1" || bundleIdentifier == nil {
            return InMemoryCredentialStore()
        }
        return KeychainCredentialStore()
    }
}

final class InMemoryCredentialStore: CredentialStore {
    private var values: [String: String] = [:]

    func value(for account: String) throws -> String? {
        values[account]
    }

    func setValue(_ value: String?, for account: String) throws {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalized.isEmpty {
            values[account] = nil
        } else {
            values[account] = normalized
        }
    }
}

enum CredentialStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidStoredData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "\(message) (\(status))."
        case .invalidStoredData:
            return "The stored credential is not valid UTF-8 text."
        }
    }
}

struct KeychainCredentialStore: CredentialStore {
    static let serviceIdentifier = "io.github.zijianwang90.runningoverlay.credentials"
    static let openWeatherAccount = "openweather-api-key"

    private let service: String

    init(service: String = serviceIdentifier) {
        self.service = service
    }

    func value(for account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidStoredData
        }
        return value
    }

    func setValue(_ value: String?, for account: String) throws {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if normalized.isEmpty {
            let status = SecItemDelete(lookup as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CredentialStoreError.unexpectedStatus(status)
            }
            return
        }

        let data = Data(normalized.utf8)
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }

        var insert = lookup
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(insertStatus)
        }
    }
}
