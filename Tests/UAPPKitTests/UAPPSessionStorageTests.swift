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
    private(set) var addedAttributes: [String: Any] = [:]

    var keychain: UAPPKeychain {
        UAPPKeychain(
            copyMatching: { [self] _, result in
                lock.withLock {
                    if let copyStatus { return copyStatus }
                    guard let stored else { return errSecItemNotFound }
                    result?.pointee = stored as CFData
                    return errSecSuccess
                }
            },
            update: { [self] _, changes in
                lock.withLock {
                    if let updateStatus { return updateStatus }
                    guard stored != nil else { return errSecItemNotFound }
                    stored = (changes as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                }
            },
            add: { [self] attributes, _ in
                lock.withLock {
                    addedAttributes = attributes as? [String: Any] ?? [:]
                    guard addStatus == errSecSuccess else { return addStatus }
                    stored = (attributes as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                }
            },
            delete: { [self] _ in
                lock.withLock {
                    if let deleteStatus { return deleteStatus }
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

    @Test("Armazenamento transitório não guarda dados")
    func transientStorage() throws {
        let storage = UAPPTransientSessionStorage()
        try storage.save(Data("sessão".utf8))
        #expect(try storage.read() == nil)
        try storage.remove()
    }
}
