# Feature Merge Audit

Audit of the nine features from the "Merging Features into RyukSign" guide, against
**this fork** (`iamsmmh/RyukSign`). Each entry records the final state, where the code
lives, and how the feature is wired into the rest of the app.

Legend: ✅ already implemented here before this pass · ✚ implemented in this pass · 🔧 verified + hooked up in this pass

---

## 2A — Bulk / Batch Signing (from KSign) — ✅ 🔧

**Status:** fully implemented; logging added this pass.

- `RyukSign/Backend/Observable/BatchJobRunner.swift` — `@MainActor` queue runner with
  per-item states (`queued / working / signed / alreadySigned / installed / failed / skipped`),
  sign / install / sign-and-install modes, per-app option overrides, a single
  `BackgroundTaskManager` keep-alive for the whole queue, cancel/skip, and a final
  `Batch finished: N/M succeeded` line in the activity log.
- `RyukSign/Views/Library/Batch/BatchSignView.swift` — mode + options + per-app
  overrides + icon + certificate selection.
- `RyukSign/Views/Library/Batch/BatchProgressView.swift` — live per-item status list.
- `RyukSign/Views/Library/Batch/BatchAppOptionsView.swift` — per-app option editor.
- Entry point: `LibraryView` selection mode → `BatchRequest` → full-screen
  `BatchSignView` (`LibraryView.swift`).

**This pass:** `FileLogger` hooks for batch start, per-app sign/install success and
failure, and the final summary — all visible in the Logs tab under the `[BATCH]` tag.

**KSign mapping:** "Select Multiple mode" = Library edit mode; `beginBackgroundTask`
keep-alive = `BackgroundTaskManager` (silent-audio + re-armed `UIBackgroundTask`
cycles, `RyukSign/Utilities/BackgroundTaskManager.swift`), which outlives the plain
30 s `beginBackgroundTask` window KSign uses.

## 2B — Dedicated Logs Tab (from KSign) — ✚

**Status:** implemented this pass. The fork already had the substrate —
`FileLogger` (disk, `Documents/Logs/ryuksign.log`, 2 MB rotation, OSLog mirror),
`SigningLog` (live signing console), `LogParser`/`LogEntry`/`LogKind`
(`Utilities/LogPresentation.swift`) and `LogsHistoryView` (Settings → Activity Logs) —
but no real-time tab.

New:

- `RyukSign/Backend/Observable/ActivityLogStore.swift` — in-memory newest-first ring
  (cap 500) that mirrors every `FileLogger` line in real time. Same serial-queue +
  batched-main-flush pattern as `SigningLog`, so it is thread-safe and cheap. Seeded
  from disk on launch; `clear()` wipes memory + disk; `reloadFromDisk()` re-reads the
  rotated history.
- `RyukSign/Views/Logs/LogsTabView.swift` — the tab: level filter (All / Success /
  Errors), live console (`LogConsoleView`, pull-to-refresh re-reads disk), Share
  (exports the log file), Clear (with destructive confirm).
- `RyukSign/Utilities/FileLogger.swift` — `log/success/error` now route through
  `ActivityLogStore`; the disk writer (`writeDisk`) is unchanged in format
  (`ISO8601 [category] message` with `ERROR:` / `>>>` markers), so history, the
  Web Manager log export, and the in-app console all keep reading the same file.
- `RyukSign/Views/TabView/TabEnum.swift` — new `.logs` tab (default, between Tweaks
  and Settings, `list.bullet.rectangle`).
- `RyukSign/Backend/Observable/TabBarPreferences.swift` — `.logs` is hideable in
  Settings → Tab Bar, with a migration that slots it before Settings for users with a
  saved tab order instead of appending after it.

**Real-time hooks added this pass** (category → `[TAG]` in the console):

| Pipeline point | Category |
| --- | --- |
| `DownloadManager.startDownload` / `startArchive` (start, blocked-by-Game-Mode) | `download` |
| `DownloadManager+Delegates` — finished, paused (network), failed (all three error branches) | `download` |
| `InstallQueue.enqueue` / install success / install failure | `install` |
| `BatchJobRunner` — start, per-app sign/install, summary | `batch` |
| `AutoSignManager` — auto sign start/result, Game-Mode pause | `auto` |
| signing itself (existing) — `SigningHandler` / `ZsignHandler` / `TweakHandler` | `sign` / `inject` |
| server install + TLS (existing) | `install` / `server` |

**KSign mapping:** "Share logs export" = Share (file) on both the tab and the
Activity Logs screen; "filter by level" = the segmented picker; "cap at 500" = the
store cap (disk history is unbounded up to rotation).

## 2C — Backup / Restore (from FeatherPlus) — ✅

**Status:** fully implemented, more complete than the guide's proposal (which zips
whole folders with a `Process` tar call — impossible on iOS; this fork zips in-app).

- `RyukSign/Backend/Observable/BackupManager.swift` — password-protected zip archives
  (via the `Zip` package) of certificates (`.p12` + `.mobileprovision` + password +
  PPQ state), sources, whitelisted settings, and tweaks; a `BackupManifest` records
  versions, counts, and the selected certificate (restored by UUID remap).
- `RyukSign/Views/Settings/Backup/BackupView.swift` + `BackupComponentsView.swift` —
  component picker, export/share, document-picker import, per-item restore summary,
  "restart to apply" prompt when settings/certs change.
- Entry: Settings → **Backup & Restore**.

**FeatherPlus mapping:** the "copy the whole Documents folder" idea is covered by the
per-component design plus the in-app Files browser (2G) and Web Manager for pulling
anything else.

## 2D — App Name / Icon / Bundle ID Editing (from KSign + FeatherPlus) — ✅

**Status:** fully implemented.

- `RyukSign/Views/Signing/Shared/SigningCustomizationView.swift` — display name,
  identifier (with "Match Certificate Identifier" one-tap fill from the selected
  provisioning profile's `application-identifier`, the KSign "fill from cert" touch),
  version, description, and icon override from the in-app icon set, Files, or Photos
  (`resizeToSquare`).
- Applied at sign time by `RyukSign/Utilities/InfoPlistPlan.swift` (plist overrides)
  and the icon pipeline in `SigningHandler`/`AppFileHandler`.
- Deeper edits: IPA Explorer (`Views/IPAExplorer/`) — per-key `Info.plist` editing,
  raw XML editor, image replace, file add/rename/replace/delete, rebuild.

## 2E — DNS Anti-Revoke (from KSign + FlareStore) — ✚

**Status:** implemented this pass.

- `RyukSign/Utilities/AntiRevokeManager.swift` — generates the `.mobileconfig`
  (`com.apple.dns.settings` payload, servers `1.1.1.1` / `8.8.8.8`, fixed payload
  identifier so re-install replaces in place), writes it to
  `Documents/AntiRevoke/RyukSign-AntiRevoke.mobileconfig` (kept for re-install /
  AirDrop), and presents it via `UIActivityViewController` — iOS shows a built-in
  **Install Profile** action for `.mobileconfig` items, which is the flow
  KSign/FlareStore use, because iOS 16+ allows no programmatic install or removal.
  Installed state is a best-effort flag (`Feather.antiRevokeInstalled`), set on the
  install action and cleared when the user confirms the manual removal
  (Settings → Profiles & Device Management). Every action is logged (`antirevoke`).
- `RyukSign/Views/Settings/AntiRevoke/AntiRevokeView.swift` — status row, Install,
  guided Remove, and Share Profile File.
- Entry: Settings → Features → **Anti-Revoke**.

**Honesty notes (documented in-app):** the profile changes the device-wide DNS
servers only; the status cannot be verified by the app on modern iOS; removal is a
guided manual step.

## 2F — Background Downloads & Signing (from KSign) — ✅ 🔧

**Status:** fully implemented; activity-log coverage added this pass.

- `RyukSign/Backend/Observable/DownloadManager.swift` — background `URLSession`
  (`ryuk2.anoxclan.com.background`, `isDiscretionary = false`), resume-data
  persistence, foreground/background session switch on scene phase.
- `RyukSign/RyukSignApp.swift` (AppDelegate) — `BGContinuedProcessingTask` (iOS 19+),
  `BGProcessingTask` (scheduled background downloads), `BGAppRefreshTask`
  (rescheduling), all now guarded by Game Mode.
- `RyukSign/Utilities/BackgroundTaskManager.swift` — silent-audio keep-alive with
  re-armed `UIBackgroundTask` cycles and expiration notifications; used by
  `DownloadManager`, `AppInstaller`, `BatchJobRunner`, `ServerInstaller`,
  `ArchiveHandler`, `SelfUpdateManager`, `WebManager`, `SourcesViewModel`, and
  `FR.signPackageFile` — i.e. **downloads, signing, and installs all keep running
  backgrounded**, which is the guide's goal.
- Live Activities / Dynamic Island: `DownloadProgressAttributes` +
  `DownloadManager+LiveActivity` (downloads), `InstallQueue` +
  `InstallQueueWindow`/`InstallProgressView` (installs), batch progress in
  `BatchProgressView`.

## 2G — File Manager (from KSign) — ✚

**Status:** implemented this pass (Settings row, as the guide allows: "a tab or a row
in Settings → Files").

- `RyukSign/Views/FileManager/FileManagerModel.swift` — `@MainActor` browser model:
  sorted listing (folders first), `goUp`, create file/folder, delete, rename. Every
  mutation is confined to `URL.documentsDirectory` (standardized-path prefix check),
  rejects empty/dotfile/path-traversal names, and logs its actions (`files`).
  `isTextFile(_:)` = known text extension + bplist sniff for binary `.plist`.
- `RyukSign/Views/FileManager/FileManagerView.swift` — `NavigationStack`-driven
  browser (path of `URL`s, so Up pops correctly), type-specific row icons, size +
  relative date, tap = open (text editor for text files, share sheet otherwise),
  context menu (Share / Edit / Rename / Delete with `DestructiveConfirm`), toolbar
  New File / New Folder / Share folder, pull-to-refresh.
- `RyukSign/Views/FileManager/TextFileEditorView.swift` — monospaced `TextEditor`,
  loads off-main, refuses files over 2 MB or non-UTF-8, Save (atomic) + Share.
- Entry: Settings → Features → **Files**. It browses the same container as
  Files → RyukSign, Web Manager, and Backups, so "edit a `.plist` / create a file"
  from the guide's checklist is covered, and it doubles as the way to reach the
  generated anti-revoke profile and the activity log.

## 2H — Game Mode (from FeatherPlus) — ✚

**Status:** implemented this pass. Deliberately **not** the per-app
`Options.gameMode` (that one sets the `GCSupportsGameMode` Info.plist key on signed
games — unchanged).

- `RyukSign/Backend/Observable/GameMode.swift` — `Feather.gameMode` flag with a
  single write path, `setEnabled(_:)`: persists, logs, and pauses/resumes in-flight
  downloads (they hold resume data, so nothing is lost).
- UI: Settings → **Downloads** → "Pause Background Activity" toggle with a plain-
  language footer.
- Guards, all checked at the decision point:
  - `DownloadManager.startDownload` — new network downloads are refused with a
    "Game Mode is on — downloads are paused" toast; the entry is kept in a paused
    state so an explicit resume tap still starts it.
  - `AutoSignManager._perform` — auto sign is skipped with a specific
    `AutoSignError.gameMode` message; the import is kept so the app can be signed
    by hand.
  - `AppUpdateChecker.performUpdateCheck` — update checks are skipped (badge
    refreshes on the next run).
  - AppDelegate `BGProcessingTask` / `BGAppRefreshTask` / `BGContinuedProcessingTask`
    handlers — complete immediately without doing work.
  - Explicit foreground actions (signing from the Library, importing a local IPA,
    resuming a specific download) are **not** blocked, matching the guide's intent
    ("disables background downloads and auto-updates").

## 2I — Self-Hosted Premium Backend (from this fork's PR #8) — ✅

**Status:** implemented (already merged in this fork).

- `server/` — FastAPI app: `main.py` (`/api/validate`, `/api/urls`, `/api/health`),
  `keygen.py` (RIYK-/RYK- style key CLI), `db.py` (SQLite via `RYUKSIGN_DB`),
  `premium.json` demo feed, `Dockerfile`, `requirements.txt`, `static/`.
- `render.yaml` — one-click Render deploy; `RyukSign/Utilities/RyukSignAPI.swift`
  points the client at the deployment (`https://ryuksign-premium.onrender.com/api`)
  with keychain-persisted keys (`IdentityVault`) and local-mode fallbacks.
- To self-host: deploy `server/` (Render/Fly/VPS), then
  `python server/keygen.py create` and redeem the key in-app (Settings → Premium).

---

## Integration notes

- **One logging spine.** Every feature reports through `FileLogger` →
  `ActivityLogStore` → Logs tab + on-disk file. No feature writes logs anywhere
  else, so the tab is a faithful stream of the whole app.
- **One tab system.** The Logs tab goes through `TabEnum` + `TabBarPreferences` like
  every other tab: reorderable, hideable, respects the launch-tab setting, and works
  in both the iOS 17 `TabbarView` and the iOS 18 `ExtendedTabbarView` (sidebar).
- **Game Mode is orthogonal to signing options** — it only gates *automatic* work,
  and every guard is a single `if GameMode.isOn` at the decision point, so it cannot
  change what a deliberate sign does.
- **No Tweak Manager impact** — no tweak path was touched; injection still flows
  `TweakManager` → `TweakHandler`/`TweakAnalyzer` → `FR.signPackageFile`, with its
  existing `[INJECT]`/`[ANALYZE]` log categories now visible in the tab.
- **New files only** for the new features (synchronized Xcode groups,
  objectVersion 77 — no `project.pbxproj` edits needed); modifications to existing
  files are additive (hooks, one guard, one new tab case).

## Test checklist (per the guide)

- [ ] **Logs:** sign + install an app with the Logs tab open — lines appear live under
      `[SIGN]` / `[INSTALL]`; pause a download (network off) — a paused line appears;
      filter Errors; Share produces the `.log` file; Clear empties tab + disk
      (`Documents/Logs/`).
- [ ] **Backup:** export → uninstall → reinstall → import → verify certificates,
      sources, settings, tweaks restored (Settings → Backup & Restore).
- [ ] **App editing:** change name/icon/bundle ID → sign → verify in Springboard;
      "Match Certificate Identifier" fills the provisioning profile's App ID.
- [ ] **Bulk sign:** select 3+ apps in the Library → sign + install → all install;
      Logs tab shows `[BATCH]` lines and the summary.
- [ ] **Game Mode:** enable → new download attempt shows the toast and stays paused;
      in-flight download pauses; auto sign on import is skipped with an explanation;
      lock the device (BGTask fires) → no work; disable → paused download resumes.
- [ ] **Files:** browse Documents → edit `Logs/ryuksign.log` or an entitlements file →
      save; create a folder + file; rename; delete (confirm). Verify nothing outside
      Documents is reachable.
- [ ] **Anti-Revoke:** Install → share sheet → "Install Profile" → Settings completes
      the install; status shows Installed; Remove instructions → remove in Settings →
      status clears.
- [ ] **Background:** start a download, lock the phone (and enable Game Mode, then
      disable it) → download completes; Live Activity shows progress.
- [ ] **Tweak Manager (regression):** import a tweak → inject into an app → sign →
      install → tweak loads; verify `[INJECT]` lines in the Logs tab.
