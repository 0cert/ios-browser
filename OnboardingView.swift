import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var keyVault: KeyVaultManager
    @State private var step = 0
    @State private var email = ""
    @State private var kgcURL = "https://kgc.0cert.io"
    @State private var isLoading = false
    @State private var error = ""
    @State private var pendingIdentity: IBCIdentity?

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i <= step ? Color.primary : Color(.systemGray4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 60)
            .padding(.bottom, 40)

            // Step content
            Group {
                switch step {
                case 0: WelcomeStep()
                case 1: IdentityStep(email: $email, kgcURL: $kgcURL)
                case 2: KeygenStep(identity: pendingIdentity)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Error
            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            // Action button
            Button(action: handleNext) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonLabel)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading || (step == 1 && email.isEmpty))
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var buttonLabel: String {
        switch step {
        case 0: return "Get Started"
        case 1: return "Generate My Keys"
        case 2: return "Start Browsing Securely"
        default: return "Continue"
        }
    }

    private func handleNext() {
        error = ""

        switch step {
        case 0:
            step = 1

        case 1:
            guard email.contains("@") else {
                error = "Please enter a valid email address"
                return
            }
            isLoading = true
            Task {
                // Generate keys locally — nothing sent to server yet
                let identity = keyVault.generateLocalKeys(email: email, kgcURL: kgcURL)
                pendingIdentity = identity

                // Request partial key from KGC
                if let completed = await requestPartialKeyAndComplete(identity: identity) {
                    keyVault.saveIdentity(completed)
                    await MainActor.run {
                        isLoading = false
                        step = 2
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        error = "Could not reach KGC. Check your connection."
                    }
                }
            }

        case 2:
            // Already saved — just mark as done
            if let identity = pendingIdentity {
                keyVault.saveIdentity(identity)
            }

        default: break
        }
    }

    private func requestPartialKeyAndComplete(identity: IBCIdentity) async -> IBCIdentity? {
        guard let url = URL(string: "\(identity.kgcURL)/issue-partial-key") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "identity": identity.email,
            "metadata": ["source": "ibc-browser-ios", "userPub": identity.userPublicCommitment]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let partialKey = json?["partialKey"] as? String else { return nil }

            return await keyVault.completeSetup(identity: identity, partialKey: partialKey)
        } catch {
            return nil
        }
    }
}

// MARK: — Step Views

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                Text("A browser that\nactually trusts you")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("0 Browser uses next-generation identity-based cryptography. Your email is your key. No certificates. No renewals. Even we can't read your data.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

struct IdentityStep: View {
    @Binding var email: String
    @Binding var kgcURL: String
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your\n0Cert identity")
                    .font(.system(size: 32, weight: .bold))
                Text("Your email becomes your cryptographic identity. We'll generate your keys right here on your device.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email address")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Advanced — KGC URL
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text("Advanced settings")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    Text("KGC Server URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("https://kgc.ibctrust.io", text: $kgcURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Use your own private KGC for enterprise deployments")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Privacy note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                    .padding(.top, 1)
                Text("Your private key is generated on this device and never leaves it. We only receive your email to issue a partial key.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct KeygenStep: View {
    let identity: IBCIdentity?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("You're protected")
                    .font(.system(size: 32, weight: .bold))

                if let identity = identity {
                    Text("0Cert identity created for\n**\(identity.email)**")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 12) {
                FeatureRow(icon: "key.fill", text: "Your private key lives in your Keychain")
                FeatureRow(icon: "lock.shield", text: "0Cert sites get verified encryption")
                FeatureRow(icon: "globe", text: "All other sites work normally")
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
