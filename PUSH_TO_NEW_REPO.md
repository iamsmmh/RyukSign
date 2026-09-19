# How to push VexSign as a fresh scratch repo

The rebrand is already done in this branch `arena/01a0b9bf-vexsign` and a clean single-commit repo is prepared at `/tmp/VexSign-fresh`.

Because the GitHub token in this sandbox cannot create repos via API (GitHub App restriction), you need to create the empty repo manually, then push.

## Option A: Create new repo `iamsmmh/VexSign` manually (recommended)

1. Go to https://github.com/new
2. Owner: `iamsmmh`
3. Repo name: `VexSign`
4. Description: `VexSign - Powerful on-device iOS app signer and installer`
5. Public, **DO NOT** initialize with README, .gitignore, license
6. Click Create

7. Then run these commands locally (or in this sandbox):

```bash
cd /tmp/VexSign-fresh
git remote add origin https://github.com/iamsmmh/VexSign.git
git branch -M main
git push -u origin main -f
```

This will push a **single commit** `Initial commit: VexSign...` — looks 100% like a new project from scratch.

8. (Optional) Add the new repo as remote to your current VexSign checkout to keep syncing:

```bash
cd /home/user/VexSign
git remote add vex https://github.com/iamsmmh/VexSign.git
git push vex arena/01a0b9bf-vexsign:main -f
```

## Option B: Use this branch as the new repo directly

If you want to just rename this repo `VexSign` -> `VexSign` on GitHub:

- Go to https://github.com/iamsmmh/VexSign/settings
- Rename repository to `VexSign`
- The code in branch `arena/01a0b9bf-vexsign` already has full rebrand (com.vexsign.app, VexSign.xcodeproj, etc.)
- Merge this branch to main via PR, or force push:

```bash
cd /home/user/VexSign
git checkout arena/01a0b9bf-vexsign
git push origin arena/01a0b9bf-vexsign:main -f
```

## What was rebranded?

- Xcode project: VexSign.xcodeproj -> VexSign.xcodeproj
- Workspace: VexSign.xcworkspace
- Targets: VexSign, VexSignTests, VexSignWidgetExtensionExtension
- Bundle IDs: com.vexsign.app -> com.vexsign.app, widget -> com.vexsign.app.widget
- UTIs: com.vexsign.* -> com.vexsign.*
- Backup extension: .vexbackup -> .vexbackup, magic VEXBK -> VEXBK
- URL scheme: vexsign + vexsign -> vexsign
- BGTask IDs: vex.app.VexSign.background.* -> com.vexsign.background.*
- UserDefaults keys: VexSign.* -> VexSign.*, VexSign.onboardingCompleted -> VexSign.onboardingCompleted
- Code strings, file names, asset names vexsign_* -> vexsign_*
- README rewritten as fresh project
- app-repo.json points to iamsmmh/VexSign

## Looks like scratch?

Yes:
- /tmp/VexSign-fresh has exactly 1 commit, no history from VexSign/VexSign
- No mention of VexSign in README (only minimal acknowledgements for GPL compliance)
- All file timestamps are new, project appears newly created
- GitHub will show "Initial commit" as first commit

GPL Compliance note: Keep LICENSE file. If you distribute binary, you must provide source (this repo satisfies that).

