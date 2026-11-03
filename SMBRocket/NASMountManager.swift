import Foundation
import Network
import Combine

/// Manages SMB share mounting and connection state
enum ConnectionPath {
    case lan
    case ztna
    case offline
}

/// Mount status for a share
enum ShareMountStatus {
    case notMounted
    case mounted
    case mounting
    case failed
    case switching
}

struct ShareStatus {
    let name: String
    let status: ShareMountStatus
    let mountedPath: String?
    let error: String?
}

/// Manages probing and mounting NAS shares
@MainActor
class NASMountManager: ObservableObject {
    @Published var connectionPath: ConnectionPath = .offline
    @Published var isProbing: Bool = false
    @Published var shareStatuses: [ShareStatus] = []
    @Published var lastError: String?
    
    private let config: NASConfig
    private var probeTask: Task<Void, Never>?
    
    init(config: NASConfig) {
        self.config = config
        updateShareStatuses()
    }
    
    /// Probe network to determine best connection path
    func probe() async {
        await MainActor.run {
            isProbing = true
            lastError = nil
        }
        
        let result = await determineConnectionPath()
        
        await MainActor.run {
            connectionPath = result
            isProbing = false
        }
    }
    
    /// Probe and then mount shares
    func probeAndMount() async {
        await probe()
        
        // Small delay to let UI update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await mountShares()
    }
    
    /// Determine which connection path to use
    private func determineConnectionPath() async -> ConnectionPath {
        // If we have a LAN host, try it first
        if let lanHost = config.lanHost {
            if await testConnection(host: lanHost, port: 445, timeout: config.lanProbeTimeout) {
                return .lan
            }
        }
        
        // Then try ZTNA host
        if let ztnaHost = config.ztnaHost {
            if await testConnection(host: ztnaHost, port: 445, timeout: config.ztnaProbeTimeout) {
                return .ztna
            }
        }
        
        return .offline
    }
    
    /// Test TCP connection to a host
    private func testConnection(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            let options = NWProtocolTCP.Options()
            options.enableKeepalive = true
            options.keepaliveIdle = 60
            
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            
            let queue = DispatchQueue(label: "eu.yaska.nasconnect.probe")
            connection.start(queue: queue)
            
            let timeoutWorkItem = DispatchWorkItem {
                connection.cancel()
                continuation.resume(returning: false)
            }
            
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutWorkItem.cancel()
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    timeoutWorkItem.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
        }
    }
    
    /// Mount all configured shares using the current connection path
    func mountShares() async {
        guard config.isValid else {
            await MainActor.run {
                lastError = "No server configuration"
            }
            return
        }
        
        // Get the target host based on current connection path
        let targetHost: String?
        switch connectionPath {
        case .lan:
            targetHost = config.lanHost
        case .ztna:
            targetHost = config.ztnaHost
        case .offline:
            await MainActor.run {
                lastError = "Network unreachable"
            }
            return
        }
        
        guard let targetHost = targetHost else {
            await MainActor.run {
                lastError = "No valid host for current path"
            }
            return
        }
        
        await MainActor.run {
            shareStatuses = config.shares.map { share in
                ShareStatus(name: share, status: .mounting, mountedPath: nil, error: nil)
            }
        }
        
        // Mount each share
        for share in config.shares {
            await mountShare(name: share, host: targetHost)
        }
        
        updateShareStatuses()
    }
    
    /// Mount a single share
    private func mountShare(name: String, host: String) async {
        let shareNameEncoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let urlString = "smb://\(host)/\(shareNameEncoded)"
        
        // Check if already mounted from the correct host
        if let currentMount = getMountInfo(for: name) {
            let currentHost = currentMount.host.lowercased()
            let targetHost = host.lowercased()
            
            if currentHost == targetHost {
                // Already mounted from correct host
                await MainActor.run {
                    updateStatus(for: name, status: .mounted, mountedPath: currentMount.path)
                }
                return
            } else {
                // Need to unmount from old host first
                if await unmountShare(name: name) {
                    // Try mounting again after unmount
                    await mountShare(name: name, host: host)
                } else {
                    await MainActor.run {
                        updateStatus(for: name, status: .failed, error: "Cannot unmount: files may be in use")
                    }
                }
                return
            }
        }
        
        // Try to mount
        let result = await mountSMB(url: urlString)
        
        await MainActor.run {
            if result.success {
                updateStatus(for: name, status: .mounted, mountedPath: result.path)
            } else {
                updateStatus(for: name, status: .failed, error: result.error)
            }
        }
    }
    
    /// Get mount information for a share
    private func getMountInfo(for shareName: String) -> (host: String, path: String)? {
        let shareLower = shareName.lowercased()
        
        // Use mount command to get smbfs mounts
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        process.arguments = ["-t", "smbfs"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                // Parse: //user@host/share on /Volumes/share (smbfs, ...)
                let parts = line.components(separatedBy: " on ")
                guard parts.count >= 2 else { continue }
                
                let source = parts[0]
                let mountPoint = parts[1].components(separatedBy: " ").first ?? ""
                
                // Extract host and share from source
                let sourceCleaned = source.replacingOccurrences(of: "//", with: "")
                let sourceParts = sourceCleaned.components(separatedBy: "/")
                guard sourceParts.count >= 2 else { continue }
                
                let hostWithUser = sourceParts[0]
                let shareFromSource = sourceParts[1].removingPercentEncoding ?? sourceParts[1]
                
                // Extract just the host (remove user@ if present)
                let host = hostWithUser.components(separatedBy: "@").last ?? hostWithUser
                
                if shareFromSource.lowercased() == shareLower {
                    return (host: host, path: mountPoint)
                }
            }
        } catch {
            print("Error checking mounts: \(error)")
        }
        
        return nil
    }
    
    /// Mount SMB share
    private func mountSMB(url: String) async -> (success: Bool, path: String?, error: String?) {
        // Use AppleScript to mount, which will prompt for credentials if needed
        let script = "mount volume \"\(url)\""
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let _ = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus == 0 {
                // Extract mount point from output or check mounted volumes
                let mountPoint = getMountPoint(for: url)
                return (success: true, path: mountPoint, error: nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Mount failed"
                return (success: false, path: nil, error: errorOutput)
            }
        } catch {
            return (success: false, path: nil, error: error.localizedDescription)
        }
    }
    
    /// Unmount a share
    private func unmountShare(name: String) async -> Bool {
        guard let mountInfo = getMountInfo(for: name) else {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", mountInfo.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Get mount point for a URL
    private func getMountPoint(for url: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        process.arguments = ["-t", "smbfs"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains(url) {
                    let parts = line.components(separatedBy: " on ")
                    if parts.count >= 2 {
                        return parts[1].components(separatedBy: " ").first
                    }
                }
            }
        } catch {
            print("Error getting mount point: \(error)")
        }
        
        return nil
    }
    
    /// Update status for a specific share
    private func updateStatus(for shareName: String, status: ShareMountStatus, mountedPath: String? = nil, error: String? = nil) {
        if let index = shareStatuses.firstIndex(where: { $0.name == shareName }) {
            shareStatuses[index] = ShareStatus(
                name: shareName,
                status: status,
                mountedPath: mountedPath,
                error: error
            )
        }
    }
    
    /// Update all share statuses based on current mounts
    func updateShareStatuses() {
        var newStatuses: [ShareStatus] = []
        
        for share in config.shares {
            if let mountInfo = getMountInfo(for: share) {
                newStatuses.append(ShareStatus(
                    name: share,
                    status: .mounted,
                    mountedPath: mountInfo.path,
                    error: nil
                ))
            } else {
                newStatuses.append(ShareStatus(
                    name: share,
                    status: .notMounted,
                    mountedPath: nil,
                    error: nil
                ))
            }
        }
        
        shareStatuses = newStatuses
    }
}
