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
        window.contentView = NSHostingView(rootView: SettingsView(
            config: appState.config,
            onSave: { newConfig in
                appState.saveConfig(newConfig)
            }
        ))
        
        // Configure window behavior
        window.center()
        
        // Bring to front and make key
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Focus the first text field (can't do this directly in SwiftUI, but we try)
        window.makeFirstResponder(window.contentView)
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
