import SwiftUI

struct ContentView: View {
    @EnvironmentObject var keyVault: KeyVaultManager
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if keyVault.isOnboarded {
                TabView(selection: $selectedTab) {
                    BrowserView()
                        .tabItem {
                            Label("Browse", systemImage: "globe")
                        }
                        .tag(0)

                    SiteRegistrationView()
                        .tabItem {
                            Label("My Sites", systemImage: "plus.circle")
                        }
                        .tag(1)

                    DashboardView()
                        .tabItem {
                            Label("Security", systemImage: "lock.shield")
                        }
                        .tag(2)
                }
                .tint(.primary)
            } else {
                OnboardingView()
            }
        }
    }
}
