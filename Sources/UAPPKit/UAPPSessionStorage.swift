import Foundation
import Security

protocol UAPPSessionStorage: Sendable {
    func read() throws -> Data?
    func save(_ data: Data) throws
    func remove() throws
}

/// Operações do Keychain usadas pelo armazenamento; substituíveis nos testes.
struct UAPPKeychain: Sendable {
    var copyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    var update: @Sendable (CFDictionary, CFDictionary) -> OSStatus = SecItemUpdate
    var add: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemAdd
    var delete: @Sendable (CFDictionary) -> OSStatus = SecItemDelete
}

struct UAPPKeychainSessionStorage: UAPPSessionStorage {
    let account: String
    var keychain = UAPPKeychain()
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "UAPPKit") + ".authentication",
            kSecAttrAccount as String: account
        ]
    }

    static func account(host: URL, projectId: String? = nil) -> String {
        // Componentes separados evitam colisões entre servidores/projetos.
        [host.absoluteString, projectId ?? ""].map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
    }

    func read() throws -> Data? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = keychain.copyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw StorageError(status: status) }
        return result as? Data
    }

    func save(_ data: Data) throws {
        let changes = [kSecValueData as String: data]
        let status = keychain.update(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = keychain.add(attributes as CFDictionary, nil)
            guard added == errSecSuccess else { throw StorageError(status: added) }
        } else if status != errSecSuccess {
            throw StorageError(status: status)
        }
    }

    func remove() throws {
        let status = keychain.delete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StorageError(status: status) }
    }

    struct StorageError: Error, Equatable { let status: OSStatus }
}

/// Sem persistência, para provedores temporários e testes determinísticos.
struct UAPPTransientSessionStorage: UAPPSessionStorage {
    func read() throws -> Data? {
        nil
    }

    func save(_: Data) throws {}
    func remove() throws {}
}
