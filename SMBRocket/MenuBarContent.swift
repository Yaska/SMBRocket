import SwiftUI

/// Content for the menu bar extra
struct MenuBarContent: View {
    @ObservedObject var appState: AppState
    let openSettings: () -> Void
    
    var body: some View {
        VStack {
            // Connection status
            Section {
                HStack {
                    connectionStatusIcon
                    Text(connectionStatusText)
                        .font(.headline)
                }
                .foregroundColor(connectionStatusColor)
            }
            
            // Share statuses
            if !appState.config.shares.isEmpty {
                Section(header: Text("Shares")) {
                    ForEach(appState.mountManager.shareStatuses, id: \.name) { status in
                        ShareStatusRow(status: status)
                    }
                }
            }
            
            Divider()
            
            // Actions
            Section {
                Button(action: {
                    Task {
                        await appState.mountManager.probeAndMount()
                    }
                }) {
                    Label("Reconnect Now", systemImage: "arrow.clockwise")
                }
                .disabled(appState.mountManager.isProbing)
                
                if appState.mountManager.isProbing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            
            Divider()
            
            // Settings
            Section {
                Button(action: openSettings) {
                    Label("Settings...", systemImage: "gearshape")
                }
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .onAppear {
            Task {
                await appState.mountManager.probeAndMount()
            }
        }
    }
    
    // MARK: - Status Display
    
    @ViewBuilder
    private var connectionStatusIcon: some View {
        switch appState.mountManager.connectionPath {
        case .lan:
            Image(systemName: "hare")
                .foregroundColor(.green)
        case .ztna:
            Image(systemName: "cloud")
                .foregroundColor(.blue)
        case .offline:
            Image(systemName: "xmark.circle")
                .foregroundColor(.gray)
        }
    }
    
    private var connectionStatusText: String {
        switch appState.mountManager.connectionPath {
        case .lan:
            return "Connected (LAN)"
        case .ztna:
            return "Connected (ZTNA)"
        case .offline:
            return "Offline"
        }
    }
    
    private var connectionStatusColor: Color {
        switch appState.mountManager.connectionPath {
        case .lan:
            return .green
        case .ztna:
            return .blue
        case .offline:
            return .gray
        }
    }
}

/// Row for displaying share status
struct ShareStatusRow: View {
    let status: ShareStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(status.name)
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusIcon: String {
        switch status.status {
        case .notMounted:
            return "circle.dashed"
        case .mounted:
            return "checkmark.circle"
        case .mounting, .switching:
            return "arrow.clockwise"
        case .failed:
            return "xmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch status.status {
        case .notMounted:
            return .gray
        case .mounted:
            return .green
        case .mounting, .switching:
            return .blue
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch status.status {
        case .notMounted:
            return "Not mounted"
        case .mounted:
            return "Mounted"
        case .mounting:
            return "Mounting..."
        case .switching:
            return "Switching..."
        case .failed:
            return status.error ?? "Failed"
        }
    }
}

#Preview {
    let _ = NASConfig(
        lanHost: "192.168.1.100",
        ztnaHost: "smb.example.com",
        shares: ["Projects", "Archive"],
        lanProbeTimeout: 2,
        ztnaProbeTimeout: 4
    )
    let appState = AppState()
    // For preview, we'd need to inject config, but this is complex with @MainActor
    // Just show a basic preview
    return MenuBarContent(appState: appState, openSettings: {})
}
