import Foundation

/// Configuration keys for Jamf managed preferences
/// Domain: eu.yaska.nasconnect
struct AppSettings {
    static let preferenceDomain = "eu.yaska.nasconnect"
    
    // Keys matching the Jamf configuration profile
    static let lanHostKey = "lanHost"
    static let ztnaHostKey = "ztnaHost"
    static let sharesKey = "shares"
    static let checkIntervalMinutesKey = "checkIntervalMinutes"
    static let lanProbeTimeoutKey = "lanProbeTimeoutSeconds"
    static let ztnaProbeTimeoutKey = "ztnaProbeTimeoutSeconds"
    
    /// Load settings from UserDefaults
    /// Jamf managed preferences are automatically available in UserDefaults.standard
    /// when a configuration profile with domain eu.yaska.nasconnect is deployed
    /// Falls back to manually saved configuration
    static func load() -> NASConfig {
        let defaults = UserDefaults.standard
        let lanHost = defaults.string(forKey: lanHostKey)
        let ztnaHost = defaults.string(forKey: ztnaHostKey)
        let shares = defaults.array(forKey: sharesKey) as? [String] ?? []
        
        return NASConfig(
            lanHost: lanHost,
            ztnaHost: ztnaHost,
            shares: shares,
            lanProbeTimeout: TimeInterval(defaults.integer(forKey: lanProbeTimeoutKey) != 0 
                ? defaults.integer(forKey: lanProbeTimeoutKey) 
                : 2),
            ztnaProbeTimeout: TimeInterval(defaults.integer(forKey: ztnaProbeTimeoutKey) != 0 
                ? defaults.integer(forKey: ztnaProbeTimeoutKey) 
                : 4)
        )
    }
    
    static func save(config: NASConfig) {
        let defaults = UserDefaults.standard
        if let lanHost = config.lanHost {
            defaults.set(lanHost, forKey: lanHostKey)
        }
        if let ztnaHost = config.ztnaHost {
            defaults.set(ztnaHost, forKey: ztnaHostKey)
        }
        defaults.set(config.shares, forKey: sharesKey)
        defaults.set(Int(config.lanProbeTimeout), forKey: lanProbeTimeoutKey)
        defaults.set(Int(config.ztnaProbeTimeout), forKey: ztnaProbeTimeoutKey)
    }
    
    static func isConfigured() -> Bool {
        let config = load()
        return config.lanHost != nil || config.ztnaHost != nil
    }
}

/// Application configuration
struct NASConfig {
    var lanHost: String?
    var ztnaHost: String?
    var shares: [String]
    var lanProbeTimeout: TimeInterval
    var ztnaProbeTimeout: TimeInterval
    
    var isValid: Bool {
        return lanHost != nil || ztnaHost != nil
    }
}
