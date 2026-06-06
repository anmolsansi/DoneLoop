import CryptoKit
import Foundation
import Security

enum DLAuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case accountExists
    case accountMissing
    case invalidCredentials
    case keychainFailure

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Enter a valid email address."
        case .weakPassword:
            "Use at least 8 characters."
        case .accountExists:
            "An account already exists on this device."
        case .accountMissing:
            "No local account exists yet."
        case .invalidCredentials:
            "Email or password is incorrect."
        case .keychainFailure:
            "Secure storage failed."
        }
    }
}

struct DLAccountSession: Equatable {
    var email: String
    var signedInAt: Date
}

struct DLSecureToken: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var scope: String?
}

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.openclaw.DoneLoop"

    private init() {}

    func save(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw DLAuthError.keychainFailure }
    }

    func load(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw DLAuthError.keychainFailure }
        return data
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: DLAccountSession?
    @Published private(set) var lastErrorMessage: String?

    private let keychain: KeychainStore
    private let accountKey = "local-account"
    private let sessionKey = "local-session"

    init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
        restoreSession()
    }

    var isSignedIn: Bool {
        session != nil
    }

    func signUp(email: String, password: String) {
        do {
            let normalizedEmail = try normalize(email: email)
            guard password.count >= 8 else { throw DLAuthError.weakPassword }
            if try keychain.load(account: accountKey) != nil { throw DLAuthError.accountExists }

            let record = DLSecureAccountRecord(
                email: normalizedEmail,
                passwordHash: passwordHash(email: normalizedEmail, password: password)
            )
            try save(record, key: accountKey)
            try save(DLAccountSession(email: normalizedEmail, signedInAt: Date()), key: sessionKey)
            session = DLAccountSession(email: normalizedEmail, signedInAt: Date())
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func logIn(email: String, password: String) {
        do {
            let normalizedEmail = try normalize(email: email)
            guard let record: DLSecureAccountRecord = try load(key: accountKey) else {
                throw DLAuthError.accountMissing
            }
            guard record.email == normalizedEmail,
                  record.passwordHash == passwordHash(email: normalizedEmail, password: password)
            else {
                throw DLAuthError.invalidCredentials
            }

            let newSession = DLAccountSession(email: normalizedEmail, signedInAt: Date())
            try save(newSession, key: sessionKey)
            session = newSession
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func logOut() {
        keychain.delete(account: sessionKey)
        session = nil
        lastErrorMessage = nil
    }

    func deleteLocalAccount() {
        keychain.delete(account: accountKey)
        keychain.delete(account: sessionKey)
        session = nil
        lastErrorMessage = nil
    }

    private func restoreSession() {
        session = try? load(key: sessionKey)
    }

    private func normalize(email: String) throws -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), normalized.contains(".") else { throw DLAuthError.invalidEmail }
        return normalized
    }

    private func passwordHash(email: String, password: String) -> String {
        let input = "\(email):\(password):DoneLoopLocalAccount"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func save<T: Codable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        try keychain.save(data, account: key)
    }

    private func load<T: Codable>(key: String) throws -> T? {
        guard let data = try keychain.load(account: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct DLSecureAccountRecord: Codable, Equatable {
    var email: String
    var passwordHash: String
}

extension DLAccountSession: Codable {}
