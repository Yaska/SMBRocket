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
        // Use asyncAfter to ensure menu is dismissed before showing window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            // Close and clear existing settings window
            if let existing = self.settingsWindow {
                existing.close()
                self.settingsWindow = nil
            }
            
            // Create new window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "SMBRocket Settings"
            
            // Create the SwiftUI view with a copy of current config
            let currentConfig = self.appState.config
            let settingsView = SettingsView(
                config: currentConfig,
                onSave: { newConfig in
                    Task { @MainActor in
                        self.appState.saveConfig(newConfig)
                    }
                }
            )
            
            window.contentView = NSHostingView(rootView: settingsView)
            
            // Configure window behavior
            window.center()
            
            // Store strong reference
            self.settingsWindow = window
            
            // Bring to front and make key
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            // Handle window closure
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                // Clear the reference when window closes
                // We can't use weak self on a struct, so we just check by reference
                if self.settingsWindow === window {
                    self.settingsWindow = nil
                }
            }
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
