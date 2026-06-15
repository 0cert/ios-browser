import Foundation
import CryptoKit
import Combine

// Trust level for a site
enum IBCTrustLevel {
    case ibcVerified      // Site has IBC, our keys match, fully verified
    case ibcDetected      // Site has IBC DNS record but not yet verified
    case standardSSL      // Normal HTTPS, no IBC
    case unknown          // Still checking
    case failed           // Something went wrong

    var icon: String {
        switch self {
        case .ibcVerified:  return "lock.shield.fill"
        case .ibcDetected:  return "lock.shield"
        case .standardSSL:  return "lock.fill"
        case .unknown:      return "lock"
        case .failed:       return "exclamationmark.shield"
        }
    }

    var color: String {
        switch self {
        case .ibcVerified:  return "ibcGreen"
        case .ibcDetected:  return "ibcBlue"
        case .standardSSL:  return "ibcGray"
        case .unknown:      return "ibcGray"
        case .failed:       return "ibcRed"
        }
    }

    var label: String {
        switch self {
        case .ibcVerified:  return "IBC Verified"
        case .ibcDetected:  return "IBC Detected"
        case .standardSSL:  return "Standard SSL"
        case .unknown:      return "Checking..."
        case .failed:       return "Check Failed"
        }
    }
}

// Result of checking a site
struct IBCSiteStatus {
    let domain: String
    let trustLevel: IBCTrustLevel
    let kgcURL: String?
    let checkedAt: Date
    var message: String = ""
}

@MainActor
class IBCEngine: ObservableObject {
    @Published var currentStatus: IBCSiteStatus?
    @Published var isChecking = false

    // Cache to avoid re-checking same domain repeatedly
    private var cache: [String: IBCSiteStatus] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // Check a URL when user navigates to it
    func checkSite(url: URL) async {
        guard let host = url.host else { return }

        // Return cached result if fresh
        if let cached = cache[host],
           Date().timeIntervalSince(cached.checkedAt) < cacheTimeout {
            currentStatus = cached
            return
        }

        isChecking = true
        currentStatus = IBCSiteStatus(
            domain: host,
            trustLevel: .unknown,
            kgcURL: nil,
            checkedAt: Date()
        )

        let status = await performCheck(domain: host)
        cache[host] = status
        currentStatus = status
        isChecking = false
    }

    private func performCheck(domain: String) async -> IBCSiteStatus {
        // Step 1: Check DNS TXT record for ibc-kgc entry
        // In production: use real DNS-over-HTTPS (Cloudflare/Google DoH)
        // For now: check our KGC API if the domain is registered
        let kgcURL = await lookupIBCRecord(domain: domain)

        guard let kgcURL = kgcURL else {
            return IBCSiteStatus(
                domain: domain,
                trustLevel: .standardSSL,
                kgcURL: nil,
                checkedAt: Date(),
                message: "No IBC record found in DNS"
            )
        }

        // Step 2: Verify the KGC is reachable and the domain has a key
        let verified = await verifyWithKGC(domain: domain, kgcURL: kgcURL)

        return IBCSiteStatus(
            domain: domain,
            trustLevel: verified ? .ibcVerified : .ibcDetected,
            kgcURL: kgcURL,
            checkedAt: Date(),
            message: verified
                ? "Identity-bound encryption active"
                : "IBC configured but verification pending"
        )
    }

    // DNS-over-HTTPS lookup for IBC TXT record
    // Format: ibc-kgc=https://kgc.example.com
    private func lookupIBCRecord(domain: String) async -> String? {
        // Use Cloudflare DoH to look up TXT records
        let dohURL = "https://cloudflare-dns.com/dns-query?name=\(domain)&type=TXT"

        guard let url = URL(string: dohURL) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let answers = json?["Answer"] as? [[String: Any]] ?? []

            for answer in answers {
                if let data = answer["data"] as? String,
                   data.hasPrefix("\"ibc-kgc=") || data.hasPrefix("ibc-kgc=") {
                    let cleaned = data
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "ibc-kgc=", with: "")
                    return cleaned
                }
            }
        } catch {
            // DNS lookup failed — treat as no IBC
        }

        // For demo/dev: hardcode our own KGC server
        // Remove this when DNS records are live
        let devDomains = ["localhost", "demo.ibctrust.io"]
        if devDomains.contains(domain) {
            return "https://kgc.ibctrust.io"
        }

        return nil
    }

    // Verify domain has an active key with the KGC
    private func verifyWithKGC(domain: String, kgcURL: String) async -> Bool {
        let endpoint = "\(kgcURL)/key/\(domain)"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = json?["status"] as? String
            return status == "active"
        } catch {
            return false
        }
    }

    // Encrypt data to a domain (for sending sensitive form data)
    func encrypt(message: String, toDomain domain: String, userPublicCommitment: String, kgcURL: String) async -> [String: Any]? {
        let endpoint = "\(kgcURL)/encrypt"
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "identity": domain,
            "userPublicCommitment": userPublicCommitment,
            "message": message
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}
