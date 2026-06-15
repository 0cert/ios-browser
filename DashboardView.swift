import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var keyVault: KeyVaultManager
    @State private var showingKeyDetails = false
    @State private var copiedField = ""

    var body: some View {
        NavigationStack {
            List {
                // ── Identity Section ──────────────────────────
                Section {
                    if let identity = keyVault.identity {
                        IdentityCard(identity: identity, copiedField: $copiedField)
                    }
                } header: {
                    Text("Your 0Cert identity")
                }

                // ── Key Status ────────────────────────────────
                Section {
                    if let identity = keyVault.identity {
                        KeyStatusRow(
                            label: "User Secret",
                            isPresent: true,
                            detail: "Stored in Keychain · Never leaves device",
                            icon: "key.fill",
                            color: .green
                        )
                        KeyStatusRow(
                            label: "Partial Key (from KGC)",
                            isPresent: identity.partialKey != nil,
                            detail: identity.partialKey != nil ? "Received from KGC" : "Not yet requested",
                            icon: "building.columns",
                            color: identity.partialKey != nil ? .blue : .secondary
                        )
                        KeyStatusRow(
                            label: "Full Private Key",
                            isPresent: identity.fullPrivKey != nil,
                            detail: identity.fullPrivKey != nil ? "Combined · Ready to decrypt" : "Combine partial + user secret",
                            icon: "lock.shield.fill",
                            color: identity.fullPrivKey != nil ? .green : .secondary
                        )
                    }
                } header: {
                    Text("Key Status")
                }

                // ── Verified Sites ────────────────────────────
                Section {
                    if keyVault.verifiedSites.isEmpty {
                        Text("No 0Cert sites visited yet")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    } else {
                        ForEach(keyVault.verifiedSites, id: \.self) { domain in
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 14))
                                Text(domain)
                                    .font(.system(size: 15))
                                Spacer()
                                Text("IBC")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.12))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } header: {
                    Text("0Cert Verified Sites")
                }

                // ── About ─────────────────────────────────────
                Section {
                    AboutRow(
                        icon: "shield.lefthalf.filled",
                        title: "How IBC protects you",
                        detail: "Your identity is your public key. No certificates. No renewals. Even the KGC can't read your messages."
                    )
                    AboutRow(
                        icon: "key.2.on.ring",
                        title: "Split key security",
                        detail: "Your full key = KGC partial key + your secret. Neither half alone can decrypt anything."
                    )
                    AboutRow(
                        icon: "globe.badge.chevron.backward",
                        title: "Works on all sites",
                        detail: "Non-0Cert sites use standard SSL. 0Cert sites get an extra verified encryption layer."
                    )
                } header: {
                    Text("About 0Cert")
                }

                // ── Danger Zone ───────────────────────────────
                Section {
                    Button(role: .destructive) {
                        keyVault.clearAll()
                    } label: {
                        Label("Reset 0Cert identity", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                }
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: — Identity Card

struct IdentityCard: View {
    let identity: IBCIdentity
    @Binding var copiedField: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: identity.isComplete ? "checkmark.shield.fill" : "shield")
                    .font(.system(size: 28))
                    .foregroundStyle(identity.isComplete ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.email)
                        .font(.system(size: 16, weight: .medium))
                    Text(identity.isComplete ? "0Cert identity active" : "Setup incomplete")
                        .font(.system(size: 13))
                        .foregroundStyle(identity.isComplete ? .green : .secondary)
                }
                Spacer()
            }

            Divider()

            // Public commitment — safe to share
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Public Key Commitment")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(identity.userPublicCommitment.prefix(24) + "...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = identity.userPublicCommitment
                        copiedField = "pubkey"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedField = ""
                        }
                    } label: {
                        Image(systemName: copiedField == "pubkey" ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(copiedField == "pubkey" ? .green : .secondary)
                    }
                }
            }

            Text("Connected to \(identity.kgcURL)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: — Key Status Row

struct KeyStatusRow: View {
    let label: String
    let isPresent: Bool
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isPresent ? .green : Color(.systemGray4))
                .font(.system(size: 18))
        }
        .padding(.vertical, 2)
    }
}

// MARK: — About Row

struct AboutRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
