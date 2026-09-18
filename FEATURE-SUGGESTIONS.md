# Feature Suggestions

You asked for automation that makes RyukSign feel like the App Store on your own device: install something and forget about it, keep everything up to date, and never manage files by hand. This is what already exists, what is worth building next, and what is deliberately not on the list.

---

## Where RyukSign already is

| App Store behaviour | RyukSign today |
| --- | --- |
| Install an app | Sign with Zsign → install via `itms-services` → queue in `InstallQueue` with Live Activities |
| Download progress | Background downloads with Live Activities / Dynamic Island |
| Update badges | `AppUpdateChecker` flags newer versions per source, with an ignore list |
| Library of installed apps | CoreData library with per-app info, icons, dylibs, descriptions |
| Storage management | `StorageManager` + Storage screen |
| Automatic cleanup | Auto Cleanup: delete installed apps, downloaded IPAs and caches after every sign and install |

The two gaps that matter for "feels automated" are **updating** (the checker knows about an update but you still do the work) and **sequencing** (each step needs its own tap).

---

## Priority 1 — the automation you asked for

### 1. Update All (one tap, then hands off)

**What:** A button in the Updates screen and in the Library toolbar that takes every app with an available update, re-signs it with the settings it originally used, and queues the installs in order.

**Why it matters:** `AppUpdateChecker` already computes the whole list — `precomputeAllUpdates()`, `hasUpdate(installedVersion:sourceVersion:)`, per-app ignore list — but each update still means: open source → download → pick options → sign → install → delete leftovers. Update All collapses that into one tap, and it is the single most "App Store" feature missing today.

**Hooks:** `AppUpdateChecker` (list of pending updates), `AutoSignManager` (batches signing already), `InstallQueue` (`_advance()` already serialises installs), `LibraryView` toolbar, `Views/Settings/Updates/` for the UI. Store the options used per app so an update re-uses the same tweaks/entitlements.

**Effort:** Medium — most logic exists, the work is batching and remembering per-app settings.

### 2. Scheduled background automation (the "Do Not Disturb" of signing)

**What:** An opt-in background task that periodically: checks sources for updates → optionally auto-signs and queues flagged apps → runs the Auto Cleanup sweep → posts one notification summarising what happened.

**Why it matters:** The App Store does its updates while you sleep. RyukSign already has the pieces (a `BGTask` registered in `RyukSignApp`, `AutoSignManager`, `CleanupManager`, `AppUpdateChecker`) but every step has to be started by hand.

**Hooks:** `RyukSignApp._registerBackgroundTasks()`, `AppUpdateChecker.refreshUpdateCount`, `AutoSignManager`, `CleanupManager`. Two policies: "notify only" and "sign + queue" — installing still needs the user in the loop, which is honest and safer.

**Effort:** Medium — the plumbing exists; the policy handling and notification text are the real work.

### 3. One-Tap Install anywhere (finish the pipeline)

**What:** Auto Cleanup already has a *One-Tap Install* switch that flips auto-sign → install-after-sign → delete-after-install → cache-clear. Surface it as a single button/affordance at the point of download ("Download, sign and install") instead of only inside Settings.

**Why it matters:** The switches exist but they are buried; a store-like app should never ask the user to visit Settings to install an app.

**Hooks:** `DownloadManager`, `SourceAppsView` / `DownloadButtonView`, `AutoSignManager`, `OptionsManager`, `CleanupManager.setOneTapInstall(_:)` (already written).

**Effort:** Low.

---

## Priority 2 — quality of life that compounds

### 4. Install queue with retry, pause and a real progress screen

**What:** Treat installs like App Store downloads: `InstallQueue` already serialises them, but one failure abandons the queue (`_abandon()`). Add retry, skip, pause and a dedicated queue list view.

**Why:** Batch-signing ten apps and having number four fail silently sends the user back to doing them one at a time — exactly what they are trying to escape.

**Effort:** Low–medium.

### 5. Per-app signing profiles ("sign it again exactly like that")

**What:** Remember the full `Options` snapshot (tweaks, entitlements, `infoPlistOverrides`, display-name overrides, keychain isolation, chosen certificate) per app, and offer "Re-sign with last settings".

**Why:** Store apps get updated with the same identity every time. RyukSign currently rebuilds the options each sign, so re-signing an app after an update means re-picking everything. This also makes #1 possible for real.

**Hooks:** `OptionsManager` (the `Options` struct already serialises to `signing_options`, including `tweakInjections` and `infoPlistOverrides`), `LibraryInfoView`, `SigningOptionsView`.

**Effort:** Low — it is a persisted snapshot keyed by bundle id.

### 6. Undo and history for IPA Explorer edits

**What:** Every edit in the IPA Explorer (plist value, replaced image, added dylib, deleted file) is recorded in a small manifest, with per-file revert, a "what changed" list before rebuild, and *Discard Changes*.

**Why:** Editing an app's bundle is destructive: one bad `Info.plist` value and the app crashes on launch, usually after the IPA is rebuilt and the workspace is cleaned. A diff plus one-tap revert is what turns the explorer from a power-user toy into something safe to use.

**Hooks:** `IPAWorkspace` (it already owns a private working copy — add a `History/` folder with the original bytes of touched files and a JSON manifest), `IPAFileViewerView`, rebuild screen.

**Effort:** Medium — self-contained in the explorer.

### 7. Preflight checks before signing

**What:** A single validation pass before `FR.signPackageFile` runs: bundle identifier and version sanity, missing required plist keys, architecture mismatch between the app and injected `.dylib`/`.framework` files (Mach-O inspection already exists via `MachOReader`), duplicate dylib names, and "certificate expired" for the selected `CertificatePair`.

**Why:** Most failed installs are boring data problems. Catching them before a two-minute sign-and-install cycle is worth more than any cosmetic feature, and it directly reduces the "delete and retry" churn the cleanup feature exists to handle.

**Hooks:** `MachOReader`, `InfoPlistPlan`, `CertificatePair`, `SigningView` before `FR.signPackageFile`, `BatchJobRunner` for batch warnings.

**Effort:** Low–medium, incremental — start with bundle id and certificate expiry.

### 8. Storage insights: history and rules

**What:** Keep a small history of what Auto Cleanup removed, show a trend on the Storage screen, and add rules like "keep only the newest signed copy of each app" and "warn when RyukSign's own storage passes N GB".

**Why:** Cleanup is invisible by design, but invisible tools get switched off the moment they delete something unexpected. A one-line history ("yesterday: 2 apps, 1.4 GB") plus an undo-friendly last-run summary makes it trustworthy.

**Hooks:** `CleanupManager.report()` already assembles a `CleanupSummary` — persist the last N summaries; `StorageView`, `StorageDetailView`.

**Effort:** Low.

### 9. Shortcuts and Home Screen actions

**What:** App Intents for "Sign latest download", "Update all", "Clean now", "Open IPA Explorer", surfaced in the Shortcuts app and as Home Screen quick actions.

**Why:** Free automation for power users, and it lets people build their own pipelines (for example: Wi-Fi at home → auto-check updates → install everything queued).

**Hooks:** the existing managers are already callable from a single entry point each (`AutoSignManager`, `CleanupManager`, `AppUpdateChecker`).

**Effort:** Low — mostly boilerplate intents over existing calls.

---

## Deliberately not suggested

- **Silent background installs without a prompt.** iOS gives a signature-based install flow no way to prove the user wanted it; auto-queuing installs and notifying is the honest ceiling.
- **Accounts, telemetry or a hosted service.** RyukSign is local-first and advertises no tracking; nothing above needs a server.
- **A full UI redesign.** The tab bar is already configurable and the Library/Sources/Updates screens map cleanly onto the store metaphor; the missing part is automation, not chrome.
- **More archive formats in the explorer.** IPA/TIPA plus the existing tweak formats cover what the app installs.

## Suggested order

1. **Update All** (#1) and its prerequisite **per-app signing profiles** (#5) — the biggest visible jump toward "App Store behaviour".
2. **One-Tap Install at the point of download** (#3), since the switches already exist.
3. **Scheduled background automation** (#2) — meaningful once #1 and #3 are reliable.
4. **Queue retry** (#4), **preflight checks** (#7), **cleanup history** (#8) and **explorer undo** (#6) as follow-ups.
5. **Shortcuts** (#9) last — cheap, but it multiplies whatever is already there.
