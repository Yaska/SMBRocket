# SMBRocket

A lightweight macOS menu bar application for mounting SMB shares with intelligent LAN/ZTNA path selection.

## Overview

SMBRocket replaces shell script-based NAS mounting solutions with a native macOS app that provides:
- Automatic detection of the fastest connection path (LAN or ZTNA)
- One-click reconnection from the menu bar
- Clean, native user interface
- Support for both Jamf-managed and manual configuration

## Features

| Feature | Description |
|---------|-------------|
| **Menu Bar Icon** | Shows current connection status (LAN, ZTNA, or Offline) |
| **Automatic Path Selection** | Probes LAN first, falls back to ZTNA automatically |
| **Manual Reconnect** | Click "Reconnect Now" to force a probe and remount |
| **Status Messages** | Clear feedback on what the app is doing |
| **Cancel Support** | Abort ongoing connection attempts |
| **Settings Window** | Configure server details manually |
| **Share Status** | See which shares are mounted/not mounted |

## Requirements

- **macOS**: 27 Sequoia or later
- **Xcode**: 27.0 or later (for building)
- **Deployment**: Jamf Pro (optional, for managed configuration)

## Installation

### For Development

```bash
# Clone the repository
git clone <repository-url>

# Open in Xcode
open SMBRocket.xcodeproj

# Build and run
xcodebuild -project SMBRocket.xcodeproj -target SMBRocket -configuration Release
```

The built app will be at: `build/Release/SMBRocket.app`

### For Production Deployment

1. **Build the app** (see above)
2. **Sign and notarize** (see Distribution section below)
3. **Package as .pkg** for Jamf deployment
4. **Deploy via Jamf Pro** with configuration profile

## Configuration

SMBRocket supports two configuration methods:

### Method 1: Jamf Managed Preferences (Recommended)

Deploy a Configuration Profile with the following settings:

- **Preference Domain**: `eu.yaska.nasconnect`
- **Configuration**:

```xml
<key>lanHost</key>
<string>192.168.1.100</string>
<key>ztnaHost</key>
<string>smb.yourcompany.com</string>
<key>shares</key>
<array>
    <string>Projects</string>
    <string>Archive</string>
</array>
<key>lanProbeTimeoutSeconds</key>
<integer>2</integer>
<key>ztnaProbeTimeoutSeconds</key>
<integer>4</integer>
```

### Method 2: Manual Configuration

1. Click the menu bar icon
2. Select **Settings...**
3. Enter your server details:
   - **LAN Server IP/Host**: Your NAS's local IP address
   - **ZTNA Hostname**: Your Jamf ZTNA hostname
   - **Share Names**: Comma-separated list of SMB shares
   - **Timeouts**: Connection probe timeouts (optional)
4. Click **Save**
5. Click **Reconnect Now** to test the connection

## Usage

### Menu Bar Icon

The icon shows the current connection status:

- **Green hare (🐇)**: Connected via LAN (fastest)
- **Blue cloud (☁️)**: Connected via ZTNA
- **Gray X (⊘)**: Offline / No connection

### Menu Options

| Option | Description |
|--------|-------------|
| **Connection Status** | Shows current path and status message |
| **Shares** | Lists all configured shares with their mount status |
| **Reconnect Now** | Manually trigger probe and mount |
| **Cancel** | (Appears during probing) Abort the connection attempt |
| **Settings...** | Open configuration window |
| **Quit** | Exit the application |

### Share Status Icons

| Icon | Meaning |
|------|---------|
| ✓ | Mounted successfully |
| 🔄 | Mounting in progress |
| ⚪ | Not mounted |
| ✗ | Mount failed |

## Connection Logic

SMBRocket uses the following logic to determine the best connection path:

1. **Probe LAN IP** (port 445, timeout: 2 seconds by default)
   - If reachable → Use LAN path
   - If not → Proceed to step 2

2. **Probe ZTNA Hostname** (port 445, timeout: 4 seconds by default)
   - If reachable → Use ZTNA path
   - If not → Go offline

3. **Mount Shares**
   - Mount all configured shares from the best available path
   - Use macOS native SMB mounting (`osascript -e "mount volume smb://..."`)
   - If already mounted from correct host → Do nothing
   - If mounted from wrong host → Unmount and remount from correct host

4. **Offline Behavior**
   - Show "Offline" status
   - Do not show error dialogs
   - Auto-retry on next "Reconnect Now" or network change

## Building for Distribution

### 1. Configure Project

- Update `SMBRocket/Info.plist`:
  - `CFBundleIdentifier`: Your organization's bundle ID
  - `CFBundleName`: Your app name
  - `CFBundleVersion`: Version number

### 2. Code Signing

```bash
# Set your development team in project.xcproj
# Or in Xcode: Targets > SMBRocket > Signing & Capabilities
```

### 3. Archive and Export

```bash
# Archive
xcodebuild archive -project SMBRocket.xcodeproj -scheme SMBRocket -archivePath SMBRocket.xcarchive

# Export as .pkg
xcodebuild -exportArchive -archivePath SMBRocket.xcarchive -exportPath . -exportOptionsPlist ExportOptions.plist
```

### 4. Notarization

```bash
# Submit for notarization
xcrun altool --notarize-app --primary-bundle-id eu.yaska.nasconnect \
  --username your-email@apple.com --password @keychain:AC_PASSWORD \
  --file SMBRocket.pkg

# Staple the notary ticket
xcrun stapler staple SMBRocket.pkg
```

## Jamf Deployment

### Package

Upload `SMBRocket.pkg` to Jamf Pro:
- **Category**: Applications
- **Display Name**: SMBRocket
- **Priority**: After

### Configuration Profile

Create a Configuration Profile:
- **Payload Type**: Custom Settings
- **Preference Domain**: `eu.yaska.nasconnect`
- **Payload**: See Configuration section above

### Policy

Create a policy to:
1. Install the .pkg
2. Deploy the configuration profile
3. **Trigger**: Recurring check-in or enrollment
4. **Scope**: Target computers/machines

## Troubleshooting

### App Doesn't Launch

1. Check if the app is in Applications folder
2. Verify code signing: `codesign -dv --verbose=4 /Applications/SMBRocket.app`
3. Check Gatekeeper: `spctl -a -v /Applications/SMBRocket.app`

### Connection Fails

1. **Verify configuration**: Open Settings and check server details
2. **Test connectivity**: 
   ```bash
   # Test LAN connection
   nc -z -G 2 192.168.1.100 445
   
   # Test ZTNA connection
   nc -z -G 4 smb.yourcompany.com 445
   ```
3. **Check network**: Ensure you're on the correct network for LAN access
4. **Verify ZTNA**: Ensure Jamf Trust client is connected

### Mounting Fails

1. **Check credentials**: First mount will prompt for SMB credentials
2. **Keychain**: Credentials are stored in login keychain as "Internet password" entries
3. **Manual test**: 
   ```bash
   open smb://192.168.1.100/Projects
   ```
4. **Unmount first**: If files are open, unmount may fail

### Settings Window Issues

1. **Window doesn't appear**: Check if it's behind other windows
2. **Window freezes**: This has been fixed in recent versions
3. **Crash on close**: This has been fixed in recent versions

### Logs

For debugging, you can check:

```bash
# System log for SMBRocket
log show --predicate 'process == "SMBRocket"' --last 1h

# General system logs
log show --last 1h | grep -i smb
```

## Architecture

### Components

```
SMBRocketApp (App)
├── AppState (ObservableObject)
│   ├── config: NASConfig
│   └── mountManager: NASMountManager
├── MenuBarContent (View)
│   └── Displays status, shares, actions
├── SettingsView (View)
│   └── Configuration UI
└── NASMountManager (ObservableObject)
    ├── probe() -> ConnectionPath
    ├── mountShares()
    └── testConnection() -> Bool
```

### Data Flow

```
User Action (Reconnect)
    ↓
MenuBarContent.onAppear / Button Action
    ↓
NASMountManager.probeAndMount()
    ↓
  ├─► determineConnectionPath()
  │     ├─► testConnection(LAN)
  │     └─► testConnection(ZTNA)
  │
  └─► mountShares()
        └─► mountShare() for each share
              ├─► Check if already mounted
              └─► Mount via osascript
    ↓
Update AppState
    ↓
Update MenuBarContent UI
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-11-03 | Initial release |

## License

Copyright © 2026 Yaska. All rights reserved.

## Support

For issues or questions, please refer to the project documentation or contact your system administrator.

## References

- [Jamf Documentation](https://docs.jamf.com)
- [Apple Developer Documentation](https://developer.apple.com/documentation)
- [Network Framework](https://developer.apple.com/documentation/network)
