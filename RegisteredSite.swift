//
//  RegisteredSite.swift
//  0 Browser
//
//  Created by Dmitry Ulyanov on 15.06.2026.
//


import SwiftUI
import Combine

// MARK: — Registered Site Model

struct RegisteredSite: Codable, Identifiable {
    var id: String { domain }
    let domain: String
    let email: String
    let userSecret: String
    let userPublicCommitment: String
    let partialKey: String
    let fullPrivKey: String
    let keyId: String
    let registeredAt: Date
    var status: String = "active"

    // DNS TXT record the site owner needs to add
    var dnsTxtRecord: String {
        "ibc-kgc=https://kgc.0cert.io"
    }

    // npm snippet the site owner needs to install
    var npmSnippet: String {
        "npm install 0cert-middleware"
    }

    // Express middleware snippet
    var middlewareSnippet: String {
        """
const zerocert = require('0cert-middleware')

app.use(zerocert({
  identity: '\(domain)',
  fullPrivKey: '\(fullPrivKey)',
  userSecret: '\(userSecret)',
  kgc: 'https://kgc.0cert.io'
}))
"""
    }
}

// MARK: — Site Store

class SiteStore: ObservableObject {
    @Published var sites: [RegisteredSite] = []
    private let key = "0cert.registered.sites"

    init() { load() }

    func add(_ site: RegisteredSite) {
        sites.removeAll { $0.domain == site.domain }
        sites.append(site)
        save()
    }

    func remove(_ domain: String) {
        sites.removeAll { $0.domain == domain }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([RegisteredSite].self, from: data) {
            sites = saved
        }
    }
}

// MARK: — Main Site Registration View

struct SiteRegistrationView: View {
    @StateObject private var siteStore = SiteStore()
    @State private var showingRegister = false

    var body: some View {
        NavigationStack {
            Group {
                if siteStore.sites.isEmpty {
                    EmptyStateView(showingRegister: $showingRegister)
                } else {
                    SiteListView(
                        siteStore: siteStore,
                        showingRegister: $showingRegister
                    )
                }
            }
            .navigationTitle("My Sites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingRegister = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingRegister) {
                RegisterSiteSheet(siteStore: siteStore)
            }
        }
    }
}

// MARK: — Empty State

struct EmptyStateView: View {
    @Binding var showingRegister: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Register your site")
                    .font(.system(size: 24, weight: .bold))
                Text("Add 0Cert protection to any website you own. Users visiting with 0Cert Browser will see the verified badge.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(3)
            }

            Button {
                showingRegister = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Register a Site")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: — Site List

struct SiteListView: View {
    @ObservedObject var siteStore: SiteStore
    @Binding var showingRegister: Bool
    @State private var selectedSite: RegisteredSite?

    var body: some View {
        List {
            Section {
                ForEach(siteStore.sites) { site in
                    SiteRow(site: site)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedSite = site }
                }
                .onDelete { indexSet in
                    indexSet.forEach { siteStore.remove(siteStore.sites[$0].domain) }
                }
            } header: {
                Text("\(siteStore.sites.count) registered site\(siteStore.sites.count == 1 ? "" : "s")")
            }

            Section {
                HowItWorksRow(
                    step: "1",
                    text: "Register your domain here"
                )
                HowItWorksRow(
                    step: "2",
                    text: "Add DNS TXT record to your domain"
                )
                HowItWorksRow(
                    step: "3",
                    text: "Install npm middleware on your server"
                )
                HowItWorksRow(
                    step: "4",
                    text: "0Cert users see verified badge on your site"
                )
            } header: {
                Text("How it works")
            }
        }
        .sheet(item: $selectedSite) { site in
            SiteDetailSheet(site: site, siteStore: siteStore)
        }
    }
}

// MARK: — Site Row

struct SiteRow: View {
    let site: RegisteredSite

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(site.domain)
                    .font(.system(size: 15, weight: .medium))
                Text(site.email)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("0Cert")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                Text(site.registeredAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: — How It Works Row

struct HowItWorksRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 26, height: 26)
                Text(step)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: — Register Site Sheet

struct RegisterSiteSheet: View {
    @ObservedObject var siteStore: SiteStore
    @Environment(\.dismiss) var dismiss

    @State private var domain = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var error = ""
    @State private var registeredSite: RegisteredSite?

    let kgcURL = "https://kgc.0cert.io"

    var body: some View {
        NavigationStack {
            Group {
                if let site = registeredSite {
                    SuccessView(site: site, onDone: {
                        siteStore.add(site)
                        dismiss()
                    })
                } else {
                    FormView(
                        domain: $domain,
                        email: $email,
                        isLoading: $isLoading,
                        error: $error,
                        onRegister: register
                    )
                }
            }
            .navigationTitle(registeredSite == nil ? "Register Site" : "Site Registered!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if registeredSite == nil {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private func register() {
        error = ""
        let cleanDomain = domain
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        guard cleanDomain.contains(".") else {
            error = "Please enter a valid domain like mysite.com"
            return
        }
        guard email.contains("@") else {
            error = "Please enter a valid email address"
            return
        }

        isLoading = true

        Task {
            do {
                // Step 1: Generate user secret via KGC
                let secretResult = try await callKGC(
                    endpoint: "/user/generate-secret",
                    body: [:]
                )
                guard let userSecret = secretResult["userSecret"] as? String,
                      let userPublicCommitment = secretResult["userPublicCommitment"] as? String
                else { throw KGCError.invalidResponse }

                // Step 2: Request partial key from KGC
                let (partialKey, keyId) = try await requestPartialKey(
                    domain: cleanDomain,
                    email: email,
                    userPublicCommitment: userPublicCommitment
                )

                // Step 3: Combine into full private key
                let fullPrivKey = try await combineKeys(
                    domain: cleanDomain,
                    partialKey: partialKey,
                    userSecret: userSecret
                )

                let site = RegisteredSite(
                    domain: cleanDomain,
                    email: email,
                    userSecret: userSecret,
                    userPublicCommitment: userPublicCommitment,
                    partialKey: partialKey,
                    fullPrivKey: fullPrivKey,
                    keyId: keyId,
                    registeredAt: Date()
                )

                await MainActor.run {
                    registeredSite = site
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }


    private func requestPartialKey(
        domain: String,
        email: String,
        userPublicCommitment: String
    ) async throws -> (partialKey: String, keyId: String) {
        let result = try await callKGC(
            endpoint: "/issue-partial-key",
            body: [
                "identity": domain,
                "metadata": [
                    "email": email,
                    "userPub": userPublicCommitment,
                    "source": "0cert-browser-ios"
                ]
            ]
        )
        guard let partialKey = result["partialKey"] as? String,
              let keyId = result["keyId"] as? String else {
            throw KGCError.invalidResponse
        }
        return (partialKey, keyId)
    }

    private func combineKeys(
        domain: String,
        partialKey: String,
        userSecret: String
    ) async throws -> String {
        let result = try await callKGC(
            endpoint: "/user/combine-keys",
            body: [
                "identity": domain,
                "partialKey": partialKey,
                "userSecret": userSecret
            ]
        )
        guard let fullPrivKey = result["fullPrivKey"] as? String else {
            throw KGCError.invalidResponse
        }
        return fullPrivKey
    }

    private func callKGC(
        endpoint: String,
        body: [String: Any]
    ) async throws -> [String: Any] {
        guard let url = URL(string: kgcURL + endpoint) else {
            throw KGCError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errMsg = json["error"] as? String {
                throw KGCError.serverError(errMsg)
            }
            throw KGCError.serverError("Server error")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KGCError.invalidResponse
        }
        return json
    }
}

enum KGCError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid KGC URL"
        case .invalidResponse:      return "Invalid response from KGC"
        case .serverError(let msg): return msg
        }
    }
}

// MARK: — Form View

struct FormView: View {
    @Binding var domain: String
    @Binding var email: String
    @Binding var isLoading: Bool
    @Binding var error: String
    let onRegister: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.primary)
                    Text("Protect your website with 0Cert — no certificates, no renewals, identity-bound encryption.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                // Domain field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your domain")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("mysite.com", text: $domain)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Without https:// or www")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your email")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("you@mysite.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("For key recovery and notifications")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // What happens
                VStack(alignment: .leading, spacing: 10) {
                    Text("What happens when you register:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    StepNote(icon: "iphone", text: "Your private key is generated on this device")
                    StepNote(icon: "building.columns", text: "KGC issues a partial key for your domain")
                    StepNote(icon: "lock.shield", text: "Keys are combined — even 0Cert can't decrypt your traffic")
                    StepNote(icon: "checkmark.circle", text: "Your site shows verified badge to 0Cert users")
                }
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Error
                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Register button
                Button(action: onRegister) {
                    Group {
                        if isLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(.white)
                                Text("Registering...").fontWeight(.semibold)
                            }
                        } else {
                            Text("Register with 0Cert")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading || domain.isEmpty || email.isEmpty)
            }
            .padding(20)
        }
    }
}

struct StepNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: — Success View

struct SuccessView: View {
    let site: RegisteredSite
    let onDone: () -> Void
    @State private var copiedSnippet = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Success header
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("\(site.domain) is registered!")
                        .font(.system(size: 24, weight: .bold))
                    Text("Now add these two things to your server to activate 0Cert protection.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                // Step 1 — DNS
                VStack(alignment: .leading, spacing: 10) {
                    Label("Step 1 — Add DNS TXT record", systemImage: "1.circle.fill")
                        .font(.system(size: 15, weight: .semibold))

                    Text("In your domain registrar, add this TXT record:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    CodeBlock(
                        code: "TXT  @  \(site.dnsTxtRecord)",
                        copyLabel: "Copy DNS Record",
                        copiedLabel: "Copied!",
                        snippetId: "dns",
                        copiedSnippet: $copiedSnippet
                    )
                }

                // Step 2 — npm
                VStack(alignment: .leading, spacing: 10) {
                    Label("Step 2 — Install middleware", systemImage: "2.circle.fill")
                        .font(.system(size: 15, weight: .semibold))

                    Text("In your Node.js project:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    CodeBlock(
                        code: site.npmSnippet,
                        copyLabel: "Copy npm command",
                        copiedLabel: "Copied!",
                        snippetId: "npm",
                        copiedSnippet: $copiedSnippet
                    )
                }

                // Step 3 — middleware config
                VStack(alignment: .leading, spacing: 10) {
                    Label("Step 3 — Add to your server", systemImage: "3.circle.fill")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Add this to your Express app:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    CodeBlock(
                        code: site.middlewareSnippet,
                        copyLabel: "Copy Code",
                        copiedLabel: "Copied!",
                        snippetId: "middleware",
                        copiedSnippet: $copiedSnippet
                    )
                }

                // Security note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .padding(.top, 1)
                    Text("Your private keys are stored securely in your device Keychain. The middleware snippet above contains your keys — only add it to your own server.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Done button
                Button(action: onDone) {
                    Text("Done — View My Sites")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(20)
        }
    }
}

// MARK: — Code Block

struct CodeBlock: View {
    let code: String
    let copyLabel: String
    let copiedLabel: String
    let snippetId: String
    @Binding var copiedSnippet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(12)
            }
            Divider()
            Button {
                UIPasteboard.general.string = code
                copiedSnippet = snippetId
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedSnippet = ""
                }
            } label: {
                HStack {
                    Image(systemName: copiedSnippet == snippetId ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                    Text(copiedSnippet == snippetId ? copiedLabel : copyLabel)
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(copiedSnippet == snippetId ? .green : .primary)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: — Site Detail Sheet

struct SiteDetailSheet: View {
    let site: RegisteredSite
    @ObservedObject var siteStore: SiteStore
    @Environment(\.dismiss) var dismiss
    @State private var copiedSnippet = ""
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.domain)
                                .font(.system(size: 17, weight: .semibold))
                            Text("0Cert Protected")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DNS TXT Record")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        CodeBlock(
                            code: "TXT  @  \(site.dnsTxtRecord)",
                            copyLabel: "Copy",
                            copiedLabel: "Copied!",
                            snippetId: "dns2",
                            copiedSnippet: $copiedSnippet
                        )
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Server Middleware")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        CodeBlock(
                            code: site.middlewareSnippet,
                            copyLabel: "Copy Code",
                            copiedLabel: "Copied!",
                            snippetId: "mid2",
                            copiedSnippet: $copiedSnippet
                        )
                    }
                    .padding(.vertical, 4)
                }

                Section("Key Info") {
                    KeyInfoRow(label: "Key ID", value: site.keyId)
                    KeyInfoRow(label: "Registered", value: site.registeredAt.formatted(date: .abbreviated, time: .shortened))
                    KeyInfoRow(label: "Public Commitment", value: site.userPublicCommitment.prefix(20) + "...")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Remove Site", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(site.domain)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Remove \(site.domain)?", isPresented: $showingDeleteAlert) {
                Button("Remove", role: .destructive) {
                    siteStore.remove(site.domain)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the site from your app. Your KGC key remains active — contact support to revoke it.")
            }
        }
    }
}

struct KeyInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}
