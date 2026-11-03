import SwiftUI
import Combine

@main
struct SMBRocketApp: App {
    @StateObject private var appState = AppState()
    @State private var settingsWindow: NSWindow?
    
    var body: some Scene {
        MenuBarExtra("SMBRocket") {
            MenuBarContent(appState: appState, openSettings: {
                openSettingsWindow()
            })
        }
        .menuBarExtraStyle(.menu)
    }
    
    private func openSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentView = NSHostingView(rootView: SettingsView(
                config: appState.config,
                onSave: { newConfig in
                    appState.saveConfig(newConfig)
                }
            ))
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
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
    }
}
