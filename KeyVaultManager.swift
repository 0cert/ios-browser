import Foundation
import Security
import CryptoKit
import Combine

// User's complete IBC identity
struct IBCIdentity: Codable {
    let email: String
    let userSecret: String           // ECDH private key — never leaves device
    let userPublicCommitment: String // ECDH public key — safe to share
    let partialKey: String?          // From KGC — stored after issuance
    let fullPrivKey: String?         // Combined key — after setup complete
    let kgcURL: String
    let createdAt: Date
    var isComplete: Bool { fullPrivKey != nil }
}

class KeyVaultManager: ObservableObject {
    @Published var identity: IBCIdentity?
    @Published var isOnboarded: Bool = false
    @Published var verifiedSites: [String] = []  // domains we've verified

    private let identityKey = "ibc.user.identity"
    private let sitesKey    = "ibc.verified.sites"

    init() {
        loadFromKeychain()
    }

    // MARK: — Onboarding

    // Step 1: Generate user's ECDH keypair locally
    // This runs entirely on device — nothing sent to server
    func generateLocalKeys(email: String, kgcURL: String) -> IBCIdentity {
        // Generate P-256 ECDH keypair using CryptoKit
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey  = privateKey.publicKey

        let userSecret           = privateKey.rawRepresentation.hexString
        let userPublicCommitment = publicKey.compressedRepresentation.hexString

        let identity = IBCIdentity(
            email: email,
            userSecret: userSecret,
            userPublicCommitment: userPublicCommitment,
            partialKey: nil,
            fullPrivKey: nil,
            kgcURL: kgcURL,
            createdAt: Date()
        )

        return identity
    }

    // Step 2: After receiving partialKey from KGC, combine into full key
    func completeSetup(identity: IBCIdentity, partialKey: String) async -> IBCIdentity? {
        // Call KGC /user/combine-keys endpoint
        guard let url = URL(string: "\(identity.kgcURL)/user/combine-keys") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "identity": identity.email,
            "partialKey": partialKey,
            "userSecret": identity.userSecret
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let fullPrivKey = json?["fullPrivKey"] as? String else { return nil }

            let completed = IBCIdentity(
                email: identity.email,
                userSecret: identity.userSecret,
                userPublicCommitment: identity.userPublicCommitment,
                partialKey: partialKey,
                fullPrivKey: fullPrivKey,
                kgcURL: identity.kgcURL,
                createdAt: identity.createdAt
            )

            await MainActor.run {
                self.identity = completed
                self.isOnboarded = true
            }

            saveToKeychain(completed)
            return completed
        } catch {
            return nil
        }
    }

    // Save identity (without onboarding complete flag)
    func saveIdentity(_ identity: IBCIdentity) {
        self.identity = identity
        if identity.isComplete {
            isOnboarded = true
        }
        saveToKeychain(identity)
    }

    func addVerifiedSite(_ domain: String) {
        if !verifiedSites.contains(domain) {
            verifiedSites.append(domain)
            saveVerifiedSites()
        }
    }

    // MARK: — Keychain

    private func saveToKeychain(_ identity: IBCIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      identityKey,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: identityKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let identity = try? JSONDecoder().decode(IBCIdentity.self, from: data) {
            self.identity = identity
            self.isOnboarded = identity.isComplete
        }

        // Load verified sites
        if let sites = UserDefaults.standard.stringArray(forKey: sitesKey) {
            self.verifiedSites = sites
        }
    }

    private func saveVerifiedSites() {
        UserDefaults.standard.set(verifiedSites, forKey: sitesKey)
    }

    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: identityKey
        ]
        SecItemDelete(query as CFDictionary)
        identity = nil
        isOnboarded = false
        verifiedSites = []
    }
}

// MARK: — Helpers

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
