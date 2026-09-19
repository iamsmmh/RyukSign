# Feature Merge Audit

This is the record of merging the "merge features into your RyukSign fork" guide into this
repository: what the guide asks for, what was already here, what this branch changed, and how
each piece was checked. Modelled on `MYSIGN_MERGE_AUDIT.md` (MySignReincarnated), which does the
same job for a different signer.

Everything below is GPL-3.0 and keeps the upstream attribution (claration/Feather,
faroukbmiled/RyukSign, and the upstream projects each feature came from).

## 1. Summary

| # | Guide feature | Before this branch | This branch |
| --- | --- | --- | --- |
| 2A | Bulk / batch signing | **Already implemented** (`BatchJobRunner`, Library multi-select, per-app overrides) | Reviewed, unchanged |
| 2B | Dedicated Logs tab | Log store + console existed; no tab, no warning level, console was session-only | **Added** Logs tab, `warn` level, live + on-disk history |
| 2C | Backup / restore | **Already implemented**, richer (encrypted `.ryukbackup` archive) | Reviewed, unchanged |
| 2D | App name / icon / bundle ID editing | **Already implemented** (`SigningCustomizationView`, per-app overrides) | Reviewed, unchanged |
| 2E | DNS anti-revoke | **Already implemented** (`AntiRevokeManager`, DoH profile) | Reviewed, unchanged |
| 2F | Background downloads & signing | **Already implemented** (background `URLSession`, keep-alive, Live Activity phases) | Reviewed, unchanged |
| 2G | File manager | **Missing** | **Added** browser, editor, move picker, library-aware delete |
| 2H | Game Mode | Signing-side only (`Options.gameMode` → `GCSupportsGameMode`) | **Added** app-side pause: downloads, resume, automation |
| 2I | Self-hosted premium backend | **Already implemented** (`server/`, FastAPI + keygen + admin) | Verified end-to-end |

Two of the nine features were genuinely missing; the rest already existed. Rather than
re-scaffolding what was there (the guide's snippets are deliberately minimal — a `BulkSignQueue`
with no per-app options, a `Process`/`tar` backup that cannot run on iOS at all), this branch
implemented the gaps and left the working implementations alone.

## 2. What was added

### 2B — Logs tab

The app already had the pieces: `SigningLog` (batched, capped, mirrored to `FileLogger`) and
`LogConsoleView` (a `UITextView` renderer). What was missing was reachability and a level.

- `RyukSign/Views/Logs/LogsView.swift` — the tab: live console, level filter chips with counts,
  share/copy/reload/clear, pull-to-refresh, empty states.
- `RyukSign/Backend/Observable/SigningLog.swift` — now owns history. `entries` (newest first) is
  the session's entries followed by the tail of the on-disk log, loaded once via
  `loadHistory()`. Entries written this launch are filtered out of the history by timestamp, so
  nothing appears twice. `warn(_:)`, `clear()` and `exportText(_:)` added;
  `lines` still works for the existing signing-console sheet.
- `RyukSign/Utilities/LogPresentation.swift` — `LogKind.warn`, `WARNING:` classification that
  survives a round-trip through the log file, plus titles/system images for the filter UI.
- `RyukSign/Views/Common/LogConsoleView.swift` — amber warning colour in both palettes.
- `RyukSign/Utilities/FileLogger.swift` — `warn(_:category:)`.
- `RyukSign/Views/TabView/TabEnum.swift` — `.logs` tab (default order: Sources, Library, Logs,
  Tweaks, Settings); `TabBarPreferences.hideableTabs` includes it, so it can be hidden or
  reordered like any other tab.

Ordering note: the guide's snippet appends to the bottom of a `ScrollViewReader`. This console is
newest-first and pins to the top, which is what the existing signing console does — no
auto-scroll needed, and the user can scroll back through history without being yanked away.

### 2G — File Manager

- `RyukSign/Views/FileManager/FileManagerView.swift` — recursive browser of `Documents`:
  sort (name/date/size), hidden files, search, per-row swipe actions and context menu, "＋" menu
  (new folder, new file, import from Files), a summary header at the root, and an empty state.
- `RyukSign/Views/FileManager/FileManagerItemView.swift` — one file: preview (text, plist,
  image, hex), editors, share, duplicate, move, export, delete, and file attributes.
- `RyukSign/Views/FileManager/FileManagerActions.swift` — every write, in one place.
- `RyukSign/Views/FileManager/FileManagerMoveView.swift` — destination picker for "Move".
- Entry points: Settings → Misc → File Manager, and Files & Compression → File Manager.

Reuse instead of a second file engine: entries, type sniffing, text/plist reading and the
structured plist editors all come from `IPAFileLoader`/`IPAFileKind` and the IPA Explorer's
`PlistNodeView`/`PlistRawEditorView`/`IPAFileTextEditorView`. A `.plist` opens the same way in
both browsers. `IPAFileLoader.children(of:includesHidden:)` gained a `measuringDirectorySize`
flag so listing `Documents` does not re-walk every signed app bundle just to compute folder
sizes the File Manager never displays.

**Integration:** deleting `Signed/<uuid>`, `Unsigned/<uuid>` or `Certificates/<uuid>` deletes the
matching Core Data row too (`Storage.shared.deleteApps` / `deleteCertificate`) and refreshes
`StorageManager`, so the Library cannot end up pointing at a folder that is gone. Deleting
something *inside* one of those folders warns first, because that breaks the app without
removing the row. Folders that belong to the Library are marked with a seal in the list, the
Tweak Manager import shortcut is offered for `.dylib`/`.deb`/`.framework`/`.bundle`, and an
`.ipa` can be handed straight to the IPA Explorer.

### 2H — Game Mode (app side)

`Options.gameMode` already existed on the signing side (it writes `GCSupportsGameMode` into a
signed app's `Info.plist`). The guide's other half — RyukSign itself not spending data while you
play — was missing.

- `RyukSign/Backend/Observable/GameMode.swift` — the switch, what it pauses (read by Settings),
  `enable()` (pauses in-flight downloads), `disable()`, and two ways of reporting a blocked
  action: an alert that offers to turn the mode off, and a toast for flows that must not be
  interrupted.
- Blocked entry points: `DownloadManager.startDownload` (the single funnel every download uses),
  `DownloadManager.resumeDownload` + `resumeAllDownloads` (so becoming active or a background
  task cannot quietly undo the pause), `BackgroundAutomation.run` (the scheduled pass),
  `UpdateAllManager.run` (Update All) and `SelfUpdateManager.checkOnLaunch` (the one request the
  app makes without being asked).
- UI: an inline toggle in the main Settings list (`Settings → Game Mode`) for the one-tap case,
  and `Views/Settings/GameModeView.swift` for the detail — what stops, how many downloads are
  paused, and a resume button for when the mode is off.

Deliberately *not* blocked: source refreshes and update checks you start by hand, signing, tweak
injection and installing from disk. The mode stops the background network, not the app.

## 3. What was verified

There is no Swift toolchain in this environment (the app targets iOS 16 and builds on macOS), so
verification is split:

1. **Syntax** — `python3 tools/check-swift-syntax.py` parses every Swift file in the repo with
   tree-sitter and reports `ERROR`/`MISSING` nodes. Every file added or edited here parses
   cleanly; the twelve files it flags are pre-existing grammar noise (`try await` on its own
   line, `"\(a).\(b)"` interpolation) and are identical to the baseline before this branch.
2. **Compile** — `.github/workflows/build.yml` runs a full `make` (an `xcodebuild` of the app,
   the widget extension and the String Catalog, then a signed `.ipa`) on every pull request to
   `main`; that is the real check for these changes. It built this branch green: run
   [35436258383](https://github.com/iamsmmh/RyukSign/actions/runs/35436258383) — *Compile
   RyukSign ✓ 11m01s*, and `Get Version` read the version out of the staged `Payload/*.app`,
   so the bundle was complete rather than merely error-free.
3. **Premium backend** — run for real in this environment: `keygen.py create` minted a key,
   `uvicorn` served the app, and `/api/health`, `/api/validate` (401 for an unknown key, 200 +
   gated feed URL for a real one), `/api/urls` (device restore) and `/repo/premium.json`
   (401 unauthenticated, 200 with the device header) all behaved as `PremiumManager` expects.
4. **Strings** — `python3 tools/add_merge_feature_strings.py --apply` added the new user-facing
   strings to `Localizable.xcstrings` (82 keys), so translators can see them.

## 4. Test checklist

Mapped from the guide's checklist onto what each feature actually needs. Everything except the
server items needs a device (Zsign requires real hardware).

- [ ] **Bulk sign** — Library → Edit → select 3+ apps → *Sign & Install*; watch per-app status,
      cancel mid-run, and confirm a failed app does not stop the queue.
- [ ] **Logs tab** — sign an app with the Logs tab open: entries stream in newest first; filter
      to Warning/Error; share exports a `.txt`; Clear empties the console and the file; relaunch
      and confirm the previous run's lines are still there as history.
- [ ] **Backup** — Settings → Backup & Restore → export; delete the app; reinstall; import; confirm
      certificates, sources, settings and tweaks come back.
- [ ] **App editing** — Signing screen → Name/Identifier/Version + a new icon → sign → confirm the
      name, icon and bundle id on the Home Screen.
- [ ] **Anti-revoke** — Settings → Installation → Anti-Revoke → generate, share, install the
      profile in Settings, confirm the device's DNS shows the pinned DoH server.
- [ ] **Background** — start a download, lock the phone, confirm it completes and the Live
      Activity goes through Downloading → Importing → Signing.
- [ ] **File Manager** — Settings → Misc → File Manager; browse `Logs`; open `ryuksign.log`; create
      a file; rename it; edit a `.plist` (invalid XML must be refused); move it into a subfolder;
      delete a file from `Temporary`? (nothing there is protected) and confirm the app is
      unaffected.
- [ ] **File Manager ↔ Library** — sign an app, then delete `Signed/<uuid>` from the File Manager:
      the Library entry goes with it. Repeat, but delete a file *inside* the folder: the
      confirmation warns that the app may no longer open.
- [ ] **Game Mode** — Settings → Game Mode on: start a download (blocked with an alert that
      offers to turn it off), leave one running while you flip it on (it pauses), run
      Settings → Automation → Run Now (skipped), then turn it off and resume downloads.
- [ ] **Premium backend** — deploy `server/` (see `server/README.md`), point `RyukSignAPI.apiBaseURL`
      at it, redeem a key minted with `keygen.py create`.

## 5. Notes for future merges

- The app target is **iOS 16.0** (`SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`).
  Use the single-parameter `onChange(of:)` form, `NBContentUnavailable` instead of
  `ContentUnavailableView`, and `#available` guards for anything newer — the codebase has
  `View+compat*` helpers in NimbleKit for the common cases.
- New Swift files are picked up automatically: the app target uses
  `PBXFileSystemSynchronizedRootGroup`, so dropping a file into `RyukSign/` is enough.
- Keep user-facing strings going through `.localized()` and add them to the catalog with the
  `tools/add_*_strings.py` scripts, which are explicit about which files they read.
- Don't break the Tweak Manager: tweak injection paths (`TweakHandler`, `SigningHandler`) were not
  touched by this branch, but the File Manager can now import a `.deb`/`.dylib` from Documents into
  the Tweak Manager library, so it is worth re-testing injection after any change there.
