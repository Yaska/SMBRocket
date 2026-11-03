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
    @State private var validationError: String?
    
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("SMB Connection Settings")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Configure your NAS server connections")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // Server Configuration Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Server Configuration")
                    .font(.headline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 12) {
                    LabeledTextField(
                        label: "LAN Server IP/Host",
                        placeholder: "192.168.1.100",
                        text: $lanHost,
                        help: "Direct LAN IP address of your NAS (not in ZTNA policy)"
                    )
                    
                    LabeledTextField(
                        label: "ZTNA Hostname",
                        placeholder: "smb.yourcompany.com",
                        text: $ztnaHost,
                        help: "Hostname for Jamf ZTNA connection"
                    )
                }
            }
            .padding(.bottom, 20)
            
            Divider()
            .padding(.vertical, 10)
            
            // Shares Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Shares")
                    .font(.headline)
                    .fontWeight(.medium)
                
                LabeledTextField(
                    label: "Share Names",
                    placeholder: "Projects, Archive, Marketing",
                    text: $sharesText,
                    help: "Comma-separated list of SMB share names to mount"
                )
            }
            .padding(.bottom, 20)
            
            Divider()
            .padding(.vertical, 10)
            
            // Advanced Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced")
                    .font(.headline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("LAN Probe Timeout")
                            .frame(width: 150, alignment: .leading)
                        TextField("", text: $lanTimeout)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("seconds")
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("ZTNA Probe Timeout")
                            .frame(width: 150, alignment: .leading)
                        TextField("", text: $ztnaTimeout)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("seconds")
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
            }
            .padding(.bottom, 20)
            
            // Error message
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 10)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveSettings()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 400, idealHeight: 500)
        .onAppear {
            // Focus first field if empty
            if lanHost.isEmpty {
                // Can't set focus programmatically in SwiftUI without NSView
            }
        }
    }
    
    private var isValid: Bool {
        return !lanHost.isEmpty || !ztnaHost.isEmpty
    }
    
    private func saveSettings() {
        // Validate inputs
        let timeoutValid = lanTimeout.isNumeric && ztnaTimeout.isNumeric
        
        if !timeoutValid {
            validationError = "Timeout values must be numbers"
            return
        }
        
        let shares = sharesText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if shares.isEmpty && !sharesText.isEmpty {
            validationError = "Please enter valid share names"
            return
        }
        
        validationError = nil
        
        let newConfig = NASConfig(
            lanHost: lanHost.isEmpty ? nil : lanHost,
            ztnaHost: ztnaHost.isEmpty ? nil : ztnaHost,
            shares: shares,
            lanProbeTimeout: TimeInterval(max(Int(lanTimeout) ?? 2, 1)),
            ztnaProbeTimeout: TimeInterval(max(Int(ztnaTimeout) ?? 4, 1))
        )
        
        onSave(newConfig)
    }
}

/// Labeled text field component
struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let help: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .help(help ?? "")
        }
    }
}

/// Extension to check if string is numeric
extension String {
    var isNumeric: Bool {
        !isEmpty && allSatisfy { $0.isNumber }
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
