import SwiftUI

@main
struct IBCBrowserApp: App {
    @StateObject private var keyVault = KeyVaultManager()
    @StateObject private var ibcEngine = IBCEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(keyVault)
                .environmentObject(ibcEngine)
        }
    }
}
