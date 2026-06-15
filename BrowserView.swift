import SwiftUI
import WebKit
import Combine

struct BrowserView: View {
    @EnvironmentObject var ibcEngine: IBCEngine
    @EnvironmentObject var keyVault: KeyVaultManager

    @State private var urlString = "https://example.com"
    @State private var displayURL = ""
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isEditingURL = false
    @State private var pageTitle = ""

    @StateObject private var coordinator = WebViewCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            // ── IBC Status Banner ──────────────────────────────
            if let status = ibcEngine.currentStatus {
                IBCStatusBanner(status: status)
            }

            // ── Address Bar ────────────────────────────────────
            AddressBar(
                urlString: $urlString,
                displayURL: $displayURL,
                isLoading: $isLoading,
                isEditing: $isEditingURL,
                trustLevel: ibcEngine.currentStatus?.trustLevel ?? .unknown,
                onSubmit: { loadURL() }
            )

            // ── Web Content ────────────────────────────────────
            WebView(
                urlString: $urlString,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                displayURL: $displayURL,
                pageTitle: $pageTitle,
                coordinator: coordinator,
                onNavigate: { url in
                    Task { await ibcEngine.checkSite(url: url) }
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // ── Navigation Bar ─────────────────────────────────
            NavigationBar(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                isLoading: isLoading,
                onBack:    { coordinator.webView?.goBack() },
                onForward: { coordinator.webView?.goForward() },
                onReload:  { coordinator.webView?.reload() },
                onHome:    { loadURL("https://example.com") }
            )
        }
        .background(Color(.systemBackground))
    }

    private func loadURL(_ override: String? = nil) {
        var raw = override ?? urlString
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            // Treat as search if no dots, URL otherwise
            if raw.contains(".") && !raw.contains(" ") {
                raw = "https://" + raw
            } else {
                raw = "https://www.google.com/search?q=" + raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        urlString = raw
        isEditingURL = false
    }
}

// MARK: — IBC Status Banner

struct IBCStatusBanner: View {
    let status: IBCSiteStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.trustLevel.icon)
                .font(.system(size: 13, weight: .medium))
            Text(status.trustLevel.label)
                .font(.system(size: 12, weight: .medium))
            if !status.message.isEmpty {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(status.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(bannerBackground)
        .foregroundStyle(bannerForeground)
    }

    private var bannerBackground: Color {
        switch status.trustLevel {
        case .ibcVerified:  return Color.green.opacity(0.12)
        case .ibcDetected:  return Color.blue.opacity(0.10)
        case .standardSSL:  return Color(.systemGray6)
        case .failed:       return Color.red.opacity(0.10)
        case .unknown:      return Color(.systemGray6)
        }
    }

    private var bannerForeground: Color {
        switch status.trustLevel {
        case .ibcVerified:  return .green
        case .ibcDetected:  return .blue
        case .standardSSL:  return .secondary
        case .failed:       return .red
        case .unknown:      return .secondary
        }
    }
}

// MARK: — Address Bar

struct AddressBar: View {
    @Binding var urlString: String
    @Binding var displayURL: String
    @Binding var isLoading: Bool
    @Binding var isEditing: Bool
    let trustLevel: IBCTrustLevel
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Lock icon
            Image(systemName: trustLevel.icon)
                .font(.system(size: 14))
                .foregroundStyle(lockColor)
                .frame(width: 20)

            // URL field
            TextField("Search or enter URL", text: isEditing ? $urlString : .constant(displayURL))
                .font(.system(size: 15))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($focused)
                .onTapGesture {
                    isEditing = true
                    focused = true
                }
                .onSubmit { onSubmit() }

            // Loading indicator or clear
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if isEditing {
                Button {
                    urlString = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: focused) { _, newVal in
            if !newVal { isEditing = false }
        }
    }

    private var lockColor: Color {
        switch trustLevel {
        case .ibcVerified: return .green
        case .ibcDetected: return .blue
        case .standardSSL: return .secondary
        case .failed:      return .red
        case .unknown:     return .secondary
        }
    }
}

// MARK: — Navigation Bar

struct NavigationBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onHome: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
            }
            .disabled(!canGoBack)

            Spacer()

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
            }
            .disabled(!canGoForward)

            Spacer()

            Button(action: onHome) {
                Image(systemName: "house")
                    .font(.system(size: 18, weight: .medium))
            }

            Spacer()

            Button(action: onReload) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
        .foregroundStyle(.primary)
    }
}

// MARK: — WKWebView Coordinator

class WebViewCoordinator: ObservableObject {
    weak var webView: WKWebView?
}

// MARK: — WebView UIViewRepresentable

struct WebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var displayURL: String
    @Binding var pageTitle: String
    let coordinator: WebViewCoordinator
    let onNavigate: (URL) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString),
              webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading   = false
                self.parent.canGoBack   = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.pageTitle   = webView.title ?? ""
                if let url = webView.url {
                    self.parent.displayURL = url.host ?? url.absoluteString
                    self.parent.onNavigate(url)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
