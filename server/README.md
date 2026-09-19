# VexSign Premium Server

A self-hosted backend for the VexSign app's **Premium VexSign** feature. It replaces
`https://vexsign.com/api`, so **your** app validates keys against **your** server — you
create and issue keys yourself, and no key paid to someone else is required.

## What it implements

| Endpoint | Auth | Purpose |
| --- | --- | --- |
| `POST /api/validate` | `X-API-Key: RYK-…` header + `{"device_uuid": "…"}` body | Redeems a key: consumes it, binds it to the device, returns its premium repo URLs |
| `GET /api/urls` | `vexSignUUID: <device>` header | "Restore Repositories" — re-lists a device's premium URLs without consuming anything |
| `GET /api/health` | – | Liveness check |
| `GET /repo/premium.json` | `vexSignUUID` / `X-API-Key` | Built-in **gated** demo premium source (works out of the box) |
| `GET /api/admin/health` | – | Whether the admin API is enabled (no token needed) |
| `POST /api/admin/keys` | `X-Admin-Token` | Mint fresh keys (distributor) |
| `GET /api/admin/keys` | `X-Admin-Token` | List every key + its status |
| `POST /api/admin/keys/{disable\|enable\|reset\|revoke}` | `X-Admin-Token` | Manage a single key |

Keys are **single-use and device-bound**, exactly like the app expects:

- Unknown or already-used key → `401 {"detail": "Invalid API key. The key does not exist or has already been used."}`
- Disabled key → `403 {"detail": "This API key has been disabled."}`
- Re-validating from the *same* device is allowed (smooth reinstall/restore)

## 1. Run it locally

```bash
cd server
python3 -m pip install -r requirements.txt
python keygen.py create          # prints your first key, e.g. RYK-ABCD-EFGH-IJKL
uvicorn main:app --host 0.0.0.0 --port 8000
```

Test it:

```bash
curl http://localhost:8000/api/health
curl -X POST http://localhost:8000/api/validate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: RYK-ABCD-EFGH-IJKL" \
  -d '{"device_uuid": "test-device"}'
# -> {"urls":[{"url":"http://localhost:8000/repo/premium.json"}]}
```

## 2. Point the app at your server

One line in `VexSign/Utilities/VexSignAPI.swift`:

```swift
static let apiBaseURL = "https://YOUR-SERVER-DOMAIN/api"
```

Rebuild the app, open **Sources → Premium** (the crown), redeem one of your keys, done.
This build has `NSAllowsArbitraryLoads`, so `http://` works for LAN testing — still use
HTTPS in production.

If your proxy doesn't forward `X-Forwarded-Host`/`X-Forwarded-Proto` (e.g. e2b sandbox
previews), the URLs the server hands back may be the proxy's internal address instead of
the public one. Pin the public base with the `PUBLIC_BASE_URL` env var:

```bash
PUBLIC_BASE_URL=https://your-public-host uvicorn main:app --host 0.0.0.0 --port 8000
```

(Hosts ending in `.e2b.app` additionally get `https` by default, since iOS rejects
cleartext URLs.)

## 3. Manage keys

```bash
python keygen.py create -n 10        # generate a batch
python keygen.py add RYK-VIP-0001    # add a specific key (RYK- prefix, 16+ chars)
python keygen.py list                # status of every key (FRESH / USED / DISABLED)
python keygen.py disable RYK-…       # app reports "key has been disabled"
python keygen.py reset RYK-…         # unbind device, make it redeemable again
python keygen.py revoke RYK-…        # delete it
```

Keys live in `vexsign.db` (SQLite, override with `RYUKSIGN_DB=/path/file.db`).

### 3b. Distributor admin API (manage keys without SSH)

Keys can also be managed over HTTP — handy when you're selling keys from a
phone/laptop and can't (or don't want to) SSH into the box. It's the same
operations as §3, gated by a single shared secret set as the `ADMIN_TOKEN`
environment variable:

- `ADMIN_TOKEN` **unset** → the whole admin surface is off (`403` for every
  `/api/admin/*` route). This is the default, so nothing to ship unauthenticated.
- `ADMIN_TOKEN` **set** → every management call must send
  `X-Admin-Token: <your secret>`, or it gets `403`.

First, set the secret once (Render dashboard → Environment, or your VPS shell):

```bash
# Render dashboard: add env var  ADMIN_TOKEN=<paste output>  then redeploy
# VPS:
export ADMIN_TOKEN="$(openssl rand -hex 24)"   # e.g. 32 random hex chars
```

Then manage keys over HTTPS:

```bash
S=https://your-server.onrender.com
T="your-admin-token"

# See if admin is live (no token required):
curl -s "$S/api/admin/health"
# -> {"enabled": true}

# Mint a batch of fresh keys:
curl -s -X POST "$S/api/admin/keys" \
  -H "X-Admin-Token: $T" -H "Content-Type: application/json" \
  -d '{"count": 5}'
# -> {"count": 5, "keys": ["RYK-…", …]}

# List every key and its status:
curl -s "$S/api/admin/keys" -H "X-Admin-Token: $T"

# Manage a single key (body: the key to act on):
curl -s -X POST "$S/api/admin/keys/disable" -H "X-Admin-Token: $T" \
  -H "Content-Type: application/json" -d '{"key": "RYK-…"}'
curl -s -X POST "$S/api/admin/keys/enable"  -H "X-Admin-Token: $T" \
  -H "Content-Type: application/json" -d '{"key": "RYK-…"}'
curl -s -X POST "$S/api/admin/keys/reset"   -H "X-Admin-Token: $T" \
  -H "Content-Type: application/json" -d '{"key": "RYK-…"}'
curl -s -X POST "$S/api/admin/keys/revoke"  -H "X-Admin-Token: $T" \
  -H "Content-Type: application/json" -d '{"key": "RYK-…"}'
```

> **Selling flow:** buyer contacts you → you run the `mint` curl (count 1) →
> paste the fresh `RYK-…` key back → they redeem it in-app. Because the free
> tier has no persistent disk, **also append each issued key to `SEED_KEYS`**
> in the dashboard so a redeploy doesn't strand your buyers.

## 4. Serve your own premium content

Out of the box, redeeming a key returns this server's gated `/repo/premium.json` demo
source. To give your users real repos, pick one:

- **Option A — host your own feed file here (recommended):** copy
  `premium.example.json` to `server/premium.json` (gitignored), fill in your app
  entries, done. The server serves it at `/repo/premium.json` behind the same
  key gating and re-reads the file on every request, so content edits apply
  without a restart. Point `PREMIUM_FEED_FILE` at another path if you prefer.
  (On Render the file must be **tracked** — it's gitignored by default, so run
  `git add -f server/premium.json` to ship it in the deploy; safe when your
  `downloadURL`s are already public. On a VPS the local file is enough.)
- **Option B — use existing feeds:** set `PREMIUM_REPO_URLS` to comma-separated
  AltStore-style JSON URLs, e.g.
  `PREMIUM_REPO_URLS="https://you.com/premium1.json,https://you.com/premium2.json"`
- **Option C — in code:** edit the dict returned by `premium_repo()` in `main.py`.

Field reference (what the app's `ASRepository` decoder needs):

| Level | Field | Notes |
| --- | --- | --- |
| repo | `name`, `identifier` | shown in the source list |
| repo | `apps` | **required, non-empty** — the source won't load otherwise |
| app | `iconURL` | **required** (decode hard-fails without it) |
| app | `name`, `bundleIdentifier`, `developerName`, `subtitle` | display |
| app | `downloadURL` | direct HTTPS `.ipa` URL — required to actually install |
| app | `version`, `versionDate`, `size`, `category` | optional |

## 5. Deploy (free options)

The server must be reachable from your iPhone 24/7, so local-only won't cut it past
testing. Easiest paths:

**Render free tier (one-click blueprint)**

1. Push the branch you want to deploy to GitHub.
2. Render → **New → Blueprint** → pick the repo. The `render.yaml` at the repo
   root configures everything (rootDir `server`, build/start, health check).
3. After the first deploy, add private env vars to the service:
   - `SEED_KEYS=RYK-AAAA-BBBB-CCCC,RYK-…` — keys are (re)created idempotently
     on every boot. This is how keys survive free-tier redeploys (no
     persistent disk): the key text is in your dashboard, not on the box.
   - `ADMIN_TOKEN=<openssl rand -hex 24>` — optional: enables the §3b
     distributor admin API. Leave unset to keep remote key management off.
   - `PREMIUM_REPO_URLS` — only if you use Option B content.
4. Render gives you `https://your-app.onrender.com` → set `apiBaseURL` to `…/api`.

Free-tier gotchas: the instance sleeps after 15 min idle — a cold start can
take ~30–60 s, so the app's 30 s request timeout may need one retry after
silence. No persistent disk on free instances, and after a redeploy a device
must re-redeem its (still valid) key once to re-bind. A paid instance can
attach a disk at `/data` instead, keeping bindings forever
(`RYUKSIGN_DB=/data/vexsign.db` is already the default in `render.yaml`).

**Docker (any VPS / Railway / Fly.io)**

```bash
cd server && docker build -t vexsign-premium .
docker run -p 8000:8000 -e PREMIUM_REPO_URLS="https://you.com/premium.json" vexsign-premium
```

**Any VPS with Python:**

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000   # put Caddy/nginx + TLS in front
```

After deploying, don't forget to create keys on the server (`python keygen.py create`)
and update `apiBaseURL` in the app.
