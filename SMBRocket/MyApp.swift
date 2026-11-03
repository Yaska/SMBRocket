import SwiftUI
import Combine

@main
struct SMBRocketApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("SMBRocket") {
            MenuBarContent(appState: appState, openSettings: {
                openSettingsWindow()
            })
        }
        .menuBarExtraStyle(.menu)
    }
    
    private func openSettingsWindow() {
        // Use asyncAfter to ensure menu is dismissed before showing window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Close any existing settings windows
            NSApplication.shared.windows
                .filter { $0.title == "SMBRocket Settings" }
                .forEach { $0.close() }
            
            // Create new window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "SMBRocket Settings"
            
            // Create the SwiftUI view with a copy of current config
            let currentConfig = appState.config
            let settingsView = SettingsView(
                config: currentConfig,
                onSave: { newConfig in
                    Task { @MainActor in
                        appState.saveConfig(newConfig)
                    }
                }
            )
            
            window.contentView = NSHostingView(rootView: settingsView)
            
            // Configure window behavior
            window.center()
            
            // Bring to front and make key
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// App-wide state
@MainActor
class AppState: ObservableObject {
    @Published var config: NASConfig
    @Published var mountManager: NASMountManager
    
    init() {
        let loadedConfig = AppSettings.load()
        self.config = loadedConfig
        self.mountManager = NASMountManager(config: loadedConfig)
    }
    
    func saveConfig(_ newConfig: NASConfig) {
        AppSettings.save(config: newConfig)
        self.config = newConfig
        self.mountManager = NASMountManager(config: newConfig)
        // Don't auto-probe after config change - let user click Reconnect
    }
}
