import Foundation
import Security
import Testing
@testable import UAPPKit

/// Keychain em memória que registra as operações e permite forçar status de erro.
private final class KeychainDouble: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Data?
    var copyStatus: OSStatus?
    var updateStatus: OSStatus?
    var addStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus?
    /// Simula um app sem o direito de usar o Keychain moderno do Mac.
    var rejectsDataProtection = false
    private(set) var addedAttributes: [String: Any] = [:]

    private func rejects(_ query: CFDictionary) -> Bool {
        rejectsDataProtection && (query as NSDictionary)[kSecUseDataProtectionKeychain as String] != nil
    }

    var keychain: UAPPKeychain {
        UAPPKeychain(
            copyMatching: { [self] query, result in
                lock.withLock {
                    if rejects(query) {
                        return errSecMissingEntitlement
                    }
                    if let copyStatus {
                        return copyStatus
                    }
                    guard let stored else { return errSecItemNotFound }
                    result?.pointee = stored as CFData
                    return errSecSuccess
                }
            },
            update: { [self] query, changes in
                lock.withLock {
                    if rejects(query) {
                        return errSecMissingEntitlement
                    }
                    if let updateStatus {
                        return updateStatus
                    }
                    guard stored != nil else { return errSecItemNotFound }
                    stored = (changes as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                }
            },
            add: { [self] attributes, _ in
                lock.withLock {
                    if rejects(attributes) {
                        return errSecMissingEntitlement
                    }
                    addedAttributes = attributes as? [String: Any] ?? [:]
                    guard addStatus == errSecSuccess else { return addStatus }
                    stored = (attributes as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                }
            },
            delete: { [self] query in
                lock.withLock {
                    if rejects(query) {
                        return errSecMissingEntitlement
                    }
                    if let deleteStatus {
                        return deleteStatus
                    }
                    defer { stored = nil }
                    return stored == nil ? errSecItemNotFound : errSecSuccess
                }
            }
        )
    }
}

struct UAPPSessionStorageTests {
    @Test("Keychain cria, lê, atualiza e remove a sessão")
    func keychainRoundTrip() throws {
        let double = KeychainDouble()
        let storage = UAPPKeychainSessionStorage(account: "conta", keychain: double.keychain)
        #expect(try storage.read() == nil)
        try storage.save(Data("primeira".utf8))
        #expect(double.addedAttributes[kSecAttrAccount as String] as? String == "conta")
        #expect(try storage.read() == Data("primeira".utf8))
        try storage.save(Data("segunda".utf8))
        #expect(try storage.read() == Data("segunda".utf8))
        try storage.remove()
        #expect(try storage.read() == nil)
        try storage.remove()
    }

    @Test("Falhas do Keychain são propagadas com o status original")
    func keychainFailures() {
        let double = KeychainDouble()
        let storage = UAPPKeychainSessionStorage(account: "conta", keychain: double.keychain)
        double.copyStatus = errSecAuthFailed
        #expect(throws: UAPPKeychainSessionStorage.StorageError(status: errSecAuthFailed)) { try storage.read() }
        double.addStatus = errSecDuplicateItem
        #expect(throws: UAPPKeychainSessionStorage.StorageError(status: errSecDuplicateItem)) {
            try storage.save(Data("sessão".utf8))
        }
        double.updateStatus = errSecInteractionNotAllowed
        #expect(throws: UAPPKeychainSessionStorage.StorageError(status: errSecInteractionNotAllowed)) {
            try storage.save(Data("sessão".utf8))
        }
        double.deleteStatus = errSecParam
        #expect(throws: UAPPKeychainSessionStorage.StorageError(status: errSecParam)) { try storage.remove() }
    }

    #if os(macOS)
    @Test("No Mac, a sessão usa o Keychain moderno e volta ao clássico sem o direito de usá-lo")
    func macDataProtectionKeychain() throws {
        let modern = KeychainDouble()
        let storage = UAPPKeychainSessionStorage(account: "conta", keychain: modern.keychain)
        try storage.save(Data("sessão".utf8))
        #expect(modern.addedAttributes[kSecUseDataProtectionKeychain as String] as? Bool == true)

        let legacy = KeychainDouble()
        legacy.rejectsDataProtection = true
        let fallback = UAPPKeychainSessionStorage(account: "conta", keychain: legacy.keychain)
        #expect(try fallback.read() == nil)
        try fallback.save(Data("sessão".utf8))
        #expect(legacy.addedAttributes[kSecUseDataProtectionKeychain as String] == nil)
        #expect(try fallback.read() == Data("sessão".utf8))
        try fallback.remove()
        #expect(try fallback.read() == nil)
    }
    #endif

    @Test("Armazenamento transitório não guarda dados")
    func transientStorage() throws {
        let storage = UAPPTransientSessionStorage()
        try storage.save(Data("sessão".utf8))
        #expect(try storage.read() == nil)
        try storage.remove()
    }
}
