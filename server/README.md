# RyukSign Premium Server

A self-hosted backend for the RyukSign app's **Premium RyukSign** feature. It replaces
`https://ryuksign.com/api`, so **your** app validates keys against **your** server — you
create and issue keys yourself, and no key paid to someone else is required.

## What it implements

| Endpoint | Auth | Purpose |
| --- | --- | --- |
| `POST /api/validate` | `X-API-Key: RYK-…` header + `{"device_uuid": "…"}` body | Redeems a key: consumes it, binds it to the device, returns its premium repo URLs |
| `GET /api/urls` | `ryukSignUUID: <device>` header | "Restore Repositories" — re-lists a device's premium URLs without consuming anything |
| `GET /api/health` | – | Liveness check |
| `GET /repo/premium.json` | `ryukSignUUID` / `X-API-Key` | Built-in **gated** demo premium source (works out of the box) |

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

One line in `RyukSign/Utilities/RyukSignAPI.swift`:

```swift
static let apiBaseURL = "https://YOUR-SERVER-DOMAIN/api"
```

Rebuild the app, open **Sources → Premium** (the crown), redeem one of your keys, done.
This build has `NSAllowsArbitraryLoads`, so `http://` works for LAN testing — still use
HTTPS in production.

## 3. Manage keys

```bash
python keygen.py create -n 10        # generate a batch
python keygen.py add RYK-VIP-0001    # add a specific key (RYK- prefix, 16+ chars)
python keygen.py list                # status of every key (FRESH / USED / DISABLED)
python keygen.py disable RYK-…       # app reports "key has been disabled"
python keygen.py reset RYK-…         # unbind device, make it redeemable again
python keygen.py revoke RYK-…        # delete it
```

Keys live in `ryuksign.db` (SQLite, override with `RYUKSIGN_DB=/path/file.db`).

## 4. Serve your own premium content

Out of the box, redeeming a key returns this server's gated `/repo/premium.json` demo
source. To give your users real repos, either:

- **Option A — use existing feeds:** set `PREMIUM_REPO_URLS` to comma-separated
  AltStore-style JSON URLs, e.g.
  `PREMIUM_REPO_URLS="https://you.com/premium1.json,https://you.com/premium2.json"`
- **Option B — host them here:** edit the dict returned by `premium_repo()` in
  `main.py` (add your apps' `downloadURL`s — must be real IPA URLs, HTTPS).

## 5. Deploy (free options)

The server must be reachable from your iPhone 24/7, so local-only won't cut it past
testing. Easiest paths:

**Render (free tier)**

1. Push this repo to GitHub (already done — it's your repo).
2. Render → New → Web Service → pick the repo.
3. Root directory: `server`. Build: `pip install -r requirements.txt`.
   Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`.
4. Add env var `PREMIUM_REPO_URLS` if you use Option A, and a persistent disk mounted
   at `/data` so keys survive restarts (set `RYUKSIGN_DB=/data/ryuksign.db`).
5. Render gives you `https://your-app.onrender.com` → set `apiBaseURL` to `…/api`.

**Docker (any VPS / Railway / Fly.io)**

```bash
cd server && docker build -t ryuksign-premium .
docker run -p 8000:8000 -e PREMIUM_REPO_URLS="https://you.com/premium.json" ryuksign-premium
```

**Any VPS with Python:**

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000   # put Caddy/nginx + TLS in front
```

After deploying, don't forget to create keys on the server (`python keygen.py create`)
and update `apiBaseURL` in the app.
