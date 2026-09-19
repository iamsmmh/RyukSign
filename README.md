# VexSign

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B-black)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)]()

**VexSign** is a powerful, modern on-device iOS app signer and installer. No computer needed. Import your certificate, sign any IPA, and install directly on your iPhone or iPad.

<p align="center"><img alt="VexSign" src="Images/Image-light.png" width="800"></p>

### Why VexSign?

VexSign was built from scratch for power users who want full control over sideloading:

- Clean, native SwiftUI design with Liquid Glass support
- Fast on-device signing via Zsign
- No tracking, no analytics, 100% open source

### Features

- **Sign & Install** — Use `.p12` / `.mobileprovision` to sign and install any IPA on-device
- **Tweak Injection** — Import `.dylib`, `.deb`, `.framework`, `.bundle`, `.appex` with full dependency inspector and ElleKit support
- **IPA Explorer** — Browse, edit Info.plist, replace images, add/delete files, rebuild IPA
- **File Transfer Server** — Upload IPAs over HTTP drag-and-drop or WebDAV (Finder / Files app)
- **Smart Download Manager** — Background downloads, Live Activities & Dynamic Island progress
- **App Update Checker** — Detect updates from sources + one-tap Update All
- **Batch Signing** — Sign and queue multiple apps at once
- **Auto Cleanup** — One-tap pipeline: import → sign → install → clean. Auto-delete caches, temp files, leftover IPAs
- **Backup & Restore** — Encrypted `.vexbackup` archives for certs, sources, tweaks, settings
- **Logs & File Manager** — Live console + full Documents browser with plist/text editor
- **Anti-Revoke DNS Profile**, **Game Mode**, **Automation**, **Named Signing Profiles**, **Certificate Health**, **Storage Rules**, **Setup Wizard**

### Installation Methods

**Server Install (Recommended)**
- Fully local HTTPS server with backloop.dev SSL
- Uses `itms-services://` for installation
- Works without computer, supports iOS 18 entitlements

**Pairing Install**
- Direct AFC install via VPN + pairing file
- Similar to ideviceinstaller but 100% on-device

### Download

Get the latest IPA from [Releases](https://github.com/iamsmmh/VexSign/releases)

### Building from Source

Requirements: Xcode 16+, iOS 15+ SDK

```bash
git clone --recursive https://github.com/iamsmmh/VexSign.git
cd VexSign
make deps
open VexSign.xcworkspace
```

Set your own team in Signing & Capabilities, or build unsigned via `make`.

### Project Structure

```
VexSign/
├── Backend/       # Signing, downloads, storage, server
├── Extensions/    # Swift extensions
├── Resources/     # Assets, Info.plist, entitlements
├── Utilities/     # Helpers, crypto, file handling
├── Views/         # SwiftUI views
├── VexSign.xcodeproj
└── VexSign.xcworkspace
```

### Tech Stack

- **Zsign** — On-device IPA signing
- **Vapor** — Local HTTP server
- **idevice** — AFC installation backend
- **ElleKit** — Tweak injection
- **Nuke** — Image caching
- **ZIPFoundation / SWCompression** — Archive handling

### License

GPL-3.0 — See [LICENSE](./LICENSE)

This project includes code from open source projects. See Acknowledgements in Settings.bundle.

### Acknowledgements

- VexSign project for pioneering on-device signing concepts
- idevice, Vapor, Zsign, ElleKit, LiveContainer communities

### Disclaimer

Use at your own risk. Sideloading may violate Apple Developer Program terms. VexSign is not affiliated with Apple Inc.
