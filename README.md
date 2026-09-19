# VexSign

[![Release](https://img.shields.io/github/v/release/iamsmmh/VexSign?color=C96FAD&label=Release)](https://github.com/iamsmmh/VexSign/releases)
[![Downloads](https://img.shields.io/github/downloads/iamsmmh/VexSign/total?color=black&label=Downloads)](https://github.com/iamsmmh/VexSign/releases)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B-black)]()
[![Author](https://img.shields.io/badge/Author-@iamsmmh-purple)]()

**The most powerful on-device iOS signer. No PC. No revoke fear. Just sign and install.**

Built and maintained by **[@iamsmmh](https://github.com/iamsmmh)** — Crafted for power users who want full control.

<p align="center">
  <img src="repo-icon.png" width="160" alt="VexSign Icon" />
</p>

<p align="center">
  <img src="Images/Image-light.png" width="800" alt="VexSign Screenshot" />
</p>

---

### 👨‍💻 Author

**VexSign** is designed, developed and maintained by **[@iamsmmh](https://github.com/iamsmmh)**

- GitHub: [@iamsmmh](https://github.com/iamsmmh)
- Repository: [iamsmmh/VexSign](https://github.com/iamsmmh/VexSign)

If you like VexSign, please ⭐ star the repo!

---

### 🚀 Why VexSign? Why not Feather, ESign, KSign, Scarlet?

Most signers do one thing: sign an IPA. **VexSign does everything after that too.**

| Feature | Feather | ESign / KSign | Scarlet | **VexSign by @iamsmmh** |
| :--- | :---: | :---: | :---: | :---: |
| On-device signing | ✅ | ✅ | ✅ | ✅ |
| Tweak injection | ✅ | ❌ | ✅ | ✅ **Advanced** |
| IPA Explorer (edit inside IPA) | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| File Transfer (HTTP/WebDAV) | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Live Activities & Dynamic Island | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Auto Cleanup Pipeline | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Batch Signing | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Update All (one-tap) | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Backup & Restore (.vexbackup) | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| Logs & File Manager | ❌ | ❌ | ❌ | ✅ **Exclusive** |
| No Ads, No Tracking | ✅ | ❌ | ❌ | ✅ |

**VexSign is the only signer that feels like the real App Store.**

---

### ✨ Features

#### 🔹 Base Features — Powered by Feather

VexSign is built on top of **Feather** by **@claration** — the original open source on-device signer that pioneered the concept. All base features come from Feather's solid foundation:

- Clean native SwiftUI UI with Liquid Glass support (iOS 19+)
- Sign & Install with `.p12` / `.mobileprovision` via Zsign
- AltStore repository support
- Certificate manager with health check (valid / expiring / revoked)
- Custom signing options (display name, bundle ID, Files app, compatibility patches)
- No tracking, no analytics, 100% open source (GPL-3.0)
- View detailed app & certificate info
- Configurable tab bar

> **Credit:** Base signing engine, UI architecture and CoreData model originally from **[Feather](https://github.com/claration/Feather) by [claration](https://github.com/claration)** — Thank you for open sourcing this!

#### 🔥 Exclusive Features — Added by [@iamsmmh](https://github.com/iamsmmh)

These features **do not exist** in Feather or any other signer. Built from scratch for VexSign by @iamsmmh:

**1. 🧹 Auto Cleanup — The App Store Experience**
> One screen in Settings → Auto Cleanup. VexSign automatically deletes downloaded IPAs, signed copies, caches, temp files and leftovers after every install. Includes **One-Tap Install**: import → sign → install → clean, zero manual work.

**2. 📂 IPA Explorer — Edit IPAs Like a Pro**
> Open any IPA and browse every file inside. Edit `Info.plist` key-by-key or raw XML, edit text files, preview and replace images, add/rename/replace/delete files, then rebuild IPA or sign & install directly. No other signer has this.

**3. 🔧 Tweak Manager — Advanced Injection**
> Import, organize and inject `.dylib`, `.deb`, `.framework`, `.bundle`, `.appex`. Multi-file tweaks, per-file config, dependency inspector, ElleKit / CydiaSubstrate detection. More powerful than Feather's original.

**4. 📡 File Transfer Server — No Cable Needed**
> Upload IPAs and tweaks over HTTP (drag-and-drop browser page) or WebDAV (mount in Finder / Files app). Optional password protection. Transfer from PC without cable.

**5. ⬇️ Smart Download Manager**
> Fast background downloads that keep running when you switch apps. With **Live Activities & Dynamic Island** — watch progress live from Lock Screen.

**6. 🔄 App Update Checker + Update All**
> Flags installed apps that have newer versions in your sources. Per-app ignore/skip. **Update All** button re-signs and queues every update in one tap — like real App Store.

**7. 📦 Batch Signing**
> Select any number of apps in Library and sign (and install) them in one queue, with per-app properties, icons and certificates.

**8. 📝 Logs Tab — See Everything**
> Live console of everything VexSign does (signing, injection, installs, downloads). Level filters, on-disk history, share/copy/clear.

**9. 🗂️ File Manager**
> Browse all VexSign documents, edit text and `.plist` files, create, import, move, share and delete. Library and Certificates stay in sync.

**10. 💾 Backup & Restore**
> Export certificates, sources, tweaks and settings to encrypted `.vexbackup` archive and restore on another device. One file to rule them all.

**11. 🛡️ Anti-Revoke**
> Generate DNS-over-HTTPS configuration profile that pins resolver for Apple verification hosts.

**12. 🎮 Game Mode**
> Stops downloads and background updates while you play — zero data, zero battery drain. Also stamps `GCSupportsGameMode` into signed apps.

**13. 🤖 Automation**
> Opt-in scheduled pass that checks sources for updates, optionally signs and queues them, runs cleanup sweep and posts one summary notification.

**14. 🎨 And More QoL by @iamsmmh**
> Named signing profiles, install queue summary (retry/skip/stop), source pinning, Wi-Fi only downloads, parallel cap, speed/ETA, Library sort (name/date/size), storage rules, setup wizard, fully configurable tab bar, curated repositories.

---

### 📲 Download

Get the latest `.ipa` from **[Releases](https://github.com/iamsmmh/VexSign/releases)**

Or add this repo to your current signer:
```
https://raw.githubusercontent.com/iamsmmh/VexSign/main/app-repo.json
```

---

### 🛠️ How It Works

**Server Install (Recommended, No PC):**
- Fully local HTTPS server with backloop.dev SSL
- Uses `itms-services://?action=download-manifest&url=<PLIST_URL>` 
- Works on iOS 18+ with new entitlements

**Pairing Install (Direct):**
- AFC install via VPN + pairing file (like ideviceinstaller but on-device)
- Uploads IPA to `/PublicStaging/` and installs directly

---

### 🔨 Building from Source

**Requirements:** Xcode 16+, iOS 15+ SDK, Swift 6.0

```bash
git clone --recursive https://github.com/iamsmmh/VexSign.git
cd VexSign
make deps          # fetches SSL certs for local server
open VexSign.xcworkspace
```

Set your own team in Signing & Capabilities, or build unsigned via `make`.

---

### 🧰 Tech Stack & Credits

**Base by Feather — Special Thanks:**

- **[Feather](https://github.com/claration/Feather) by @claration (Samara)** — The original on-device signer, base for VexSign. Without Feather, VexSign wouldn't exist. GPL-3.0.

**Other Open Source Projects:**

- **[idevice](https://github.com/jkcoxson/idevice)** by jkcoxson — Backend for AFC communication with `installd`
- **[Vapor](https://github.com/vapor/vapor)** — Server-side Swift HTTP framework for local install server
- **[Zsign](https://github.com/zhlynn/zsign)** by zhlynn — On-device IPA signing, reimplemented for iOS
- **[ElleKit](https://github.com/tealbathingsuit/ellekit)** by tealbathingsuit — Tweak injection
- **[LiveContainer](https://github.com/LiveContainer/LiveContainer)** — Fixes and compatibility help
- **[Nuke](https://github.com/kean/Nuke)** by kean — Image caching
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation) / [SWCompression](https://github.com/tsolomko/SWCompression)** — Archive handling
- **[AltSourceKit](https://github.com/claration/AltSourceKit)** — AltStore source parsing
- **[NimbleKit](https://github.com/claration/NimbleKit)** — UI components and extensions
- **[*.backloop.dev](https://backloop.dev/)** — localhost with public-CA-signed SSL certificate
- **[Asspp](https://github.com/Lakr233/Asspp)** — HTTP server setup reference
- **[plistserver](https://github.com/nekohaxx/plistserver)** — Hosted on api.palera.in

All dependencies retain their original licenses (MIT, BSD-3-Clause, GPL-3.0). See `license_plist.yml` and `LICENSE`.

---

### 📄 License

**GPL-3.0** — See [LICENSE](./LICENSE)

VexSign is licensed under GPL-3.0, same as Feather. As a derivative of Feather (GPL-3.0), we preserve that license and give full credit to upstream.

Copyright (c) 2026 [@iamsmmh](https://github.com/iamsmmh) & VexSign Team. Base (c) 2024 Samara / @claration.

By contributing, you agree to license your code under GPL-3.0, ensuring it remains free and open.

---

### 🙏 Acknowledgements

**Special Thanks to Feather:**

> **VexSign is built on top of [Feather](https://github.com/claration/Feather) by [@claration](https://github.com/claration).** Feather pioneered on-device signing on stock iOS without jailbreak. We are deeply grateful for the open source foundation. All upstream work and attribution is preserved — see Credits in app and below.

**Additional Thanks:**

- **@iamsmmh** — Lead Developer, all exclusive features (IPA Explorer, File Transfer, Live Activities, Auto Cleanup, Batch Signing, etc.)
- **@jkcoxson** — idevice backend
- **@zhlynn** — Zsign
- **@tealbathingsuit** — ElleKit
- **@kean** — Nuke
- **@Lakr233** — Asspp reference
- **@nekohaxx** — plistserver
- All contributors and translators

---

### ⚠️ Disclaimer

VexSign is maintained by [@iamsmmh](https://github.com/iamsmmh) on GitHub. Releases only on GitHub. Avoid other sites — they may be malicious.

Use at your own risk. Sideloading may violate Apple Developer Program terms. Not affiliated with Apple Inc.

---

<p align="center">
  <b>Made with ❤️ by <a href="https://github.com/iamsmmh">@iamsmmh</a> — VexSign</b><br>
  Built on <a href="https://github.com/claration/Feather">Feather by @claration</a><br>
  If VexSign saves your time, please ⭐ star the repo!
</p>
