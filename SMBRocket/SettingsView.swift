import SwiftUI

/// Settings view for manual configuration
struct SettingsView: View {
    let config: NASConfig
    let onSave: (NASConfig) -> Void
    
    @State private var lanHost: String
    @State private var ztnaHost: String
    @State private var sharesText: String
    @State private var lanTimeout: String
    @State private var ztnaTimeout: String
    
    init(config: NASConfig, onSave: @escaping (NASConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        
        // Initialize state from config
        _lanHost = State(initialValue: config.lanHost ?? "")
        _ztnaHost = State(initialValue: config.ztnaHost ?? "")
        _sharesText = State(initialValue: config.shares.joined(separator: ", "))
        _lanTimeout = State(initialValue: String(Int(config.lanProbeTimeout)))
        _ztnaTimeout = State(initialValue: String(Int(config.ztnaProbeTimeout)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SMB Connection Settings")
                .font(.headline)
                .padding(.bottom, 10)
            
            Form {
                Section(header: Text("Server Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAN Server IP/Host")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., 192.168.1.100", text: $lanHost)
                            .textFieldStyle(.roundedBorder)
                            .help("Direct LAN IP address of your NAS (not in ZTNA policy)")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ZTNA Hostname")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., smb.yourcompany.com", text: $ztnaHost)
                            .textFieldStyle(.roundedBorder)
                            .help("Hostname for Jamf ZTNA connection")
                    }
                }
                
                Section(header: Text("Shares")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share Names")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Projects, Archive, Marketing", text: $sharesText)
                            .textFieldStyle(.roundedBorder)
                            .help("Comma-separated list of SMB share names")
                    }
                }
                
                Section(header: Text("Advanced")) {
                    HStack {
                        Text("LAN Probe Timeout (seconds)")
                        Spacer()
                        TextField("", text: $lanTimeout)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("ZTNA Probe Timeout (seconds)")
                        Spacer()
                        TextField("", text: $ztnaTimeout)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    NSApplication.shared.keyWindow?.close()
                }
                
                Button("Save") {
                    saveSettings()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .onAppear {
            // Ensure we have valid state
            if !isValid {
                // If config is empty, use defaults
                if lanHost.isEmpty && ztnaHost.isEmpty {
                    // No-op, user needs to enter values
                }
            }
        }
    }
    
    private var isValid: Bool {
        return !lanHost.isEmpty || !ztnaHost.isEmpty
    }
    
    private func saveSettings() {
        let shares = sharesText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let newConfig = NASConfig(
            lanHost: lanHost.isEmpty ? nil : lanHost,
            ztnaHost: ztnaHost.isEmpty ? nil : ztnaHost,
            shares: shares,
            lanProbeTimeout: TimeInterval(Int(lanTimeout) ?? 2),
            ztnaProbeTimeout: TimeInterval(Int(ztnaTimeout) ?? 4)
        )
        
        onSave(newConfig)
    }
}

#Preview {
    let config = NASConfig(
        lanHost: "192.168.1.100",
        ztnaHost: "smb.example.com",
        shares: ["Projects", "Archive"],
        lanProbeTimeout: 2,
        ztnaProbeTimeout: 4
    )
    return SettingsView(config: config, onSave: { _ in })
}
