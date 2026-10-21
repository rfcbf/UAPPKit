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

    /// No Mac, o Keychain moderno (o mesmo do iPhone), que não pede a senha das chaves "login" a
    /// cada nova assinatura do aplicativo. Sem o direito de usá-lo (app sem equipe ou binário de
    /// testes), o Keychain responde `errSecMissingEntitlement` e o kit volta ao Keychain clássico.
    private func query(dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "UAPPKit") + ".authentication",
            kSecAttrAccount as String: account
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    /// Executa no Keychain moderno do Mac e, se faltar o direito, no clássico.
    private func perform(_ operation: ([String: Any]) -> OSStatus) -> OSStatus {
        #if os(macOS)
        let status = operation(query(dataProtection: true))
        guard status == errSecMissingEntitlement else { return status }
        #endif
        return operation(query(dataProtection: false))
    }

    static func account(host: URL, projectId: String? = nil) -> String {
        // Componentes separados evitam colisões entre servidores/projetos.
        [host.absoluteString, projectId ?? ""].map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
    }

    func read() throws -> Data? {
        var result: CFTypeRef?
        let status = perform { query in
            var attributes = query
            attributes[kSecReturnData as String] = true
            attributes[kSecMatchLimit as String] = kSecMatchLimitOne
            result = nil
            return keychain.copyMatching(attributes as CFDictionary, &result)
        }
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw StorageError(status: status) }
        return result as? Data
    }

    func save(_ data: Data) throws {
        let changes = [kSecValueData as String: data]
        let status = perform { query in
            let status = keychain.update(query as CFDictionary, changes as CFDictionary)
            guard status == errSecItemNotFound else { return status }
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return keychain.add(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageError(status: status) }
    }

    func remove() throws {
        let status = perform { keychain.delete($0 as CFDictionary) }
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
