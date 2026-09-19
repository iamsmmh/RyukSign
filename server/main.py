#!/usr/bin/env python3
"""RyukSign Premium API — drop-in backend for the app's premium key flow.

Implements the exact contract `PremiumManager` (RyukSign/Backend/Observable)
expects:

    POST /api/validate    header: X-API-Key, JSON body: {"device_uuid": "..."}
        -> 200 {"urls": [{"url": "..."}]}      key consumed + bound to device
        -> 401 {"detail": "..."}               unknown / already-used key
        -> 403 {"detail": "..."}               disabled key

    GET  /api/urls        header: ryukSignUUID
        -> 200 {"urls": [{"url": "..."}]}      device has an activation
        -> 401 {"detail": "..."}               nothing registered for device

    GET  /api/health      -> {"status": "ok"}

Out of the box, a successful redemption returns this server's built-in demo
premium source (GET /repo/premium.json, gated by the same device/key headers),
so the whole flow can be tested with zero extra hosting. For real content,
either set PREMIUM_REPO_URLS (feeds hosted elsewhere) or drop your own
AltStore-v1 feed at premium.json / PREMIUM_FEED_FILE (served here).

Environment variables:
    PREMIUM_REPO_URLS   Comma-separated feed URLs returned on redemption.
    PREMIUM_FEED_FILE   Your feed JSON served at /repo/premium.json
                        (default: premium.json next to main.py, re-read per
                        request — content edits apply without a restart).
    SEED_KEYS           Comma-separated keys (re)created on boot, idempotent.
                        Lets hosts without shell access (Render free tier)
                        restore keys after a redeploy wiped the DB.
    PUBLIC_BASE_URL     Public base URL override for generated feed URLs.
    RYUKSIGN_DB         SQLite path (default: ryuksign.db next to main.py).

Run:
    pip install -r requirements.txt
    python keygen.py create -n 1
    uvicorn main:app --host 0.0.0.0 --port 8000
"""

import json
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse
from pydantic import BaseModel

import db

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

def _env_repo_urls() -> list[str]:
    raw = os.environ.get("PREMIUM_REPO_URLS", "")
    return [url.strip() for url in raw.split(",") if url.strip()]


INVALID_KEY_DETAIL = "Invalid API key. The key does not exist or has already been used."
DISABLED_KEY_DETAIL = "This API key has been disabled."
NO_ACTIVATION_DETAIL = "No premium access is registered for this device ID."


def _seed_keys() -> None:
    """Idempotently add SEED_KEYS on boot (comma-separated, upper-cased).

    Keys that already exist are left untouched (device bindings preserved),
    so this doubles as the recovery path after a redeploy wiped the DB on a
    host without persistent storage or shell access.
    """
    raw = os.environ.get("SEED_KEYS", "")
    added = 0
    for key in (k.strip().upper() for k in raw.split(",") if k.strip()):
        if db.get_key(key) is None:
            db.add_key(key)
            added += 1
    if added:
        print(f"[ryuksign] seeded {added} key(s) from SEED_KEYS", flush=True)


@asynccontextmanager
async def lifespan(_: FastAPI):
    _seed_keys()
    yield


app = FastAPI(
    title="RyukSign Premium API",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=lifespan,
)


class ValidateBody(BaseModel):
    device_uuid: str


def _base_url(request: Request) -> str:
    """Public base URL, respecting reverse-proxy forwarding headers.

    `PUBLIC_BASE_URL` (env) wins over header inference — set it when the
    proxy doesn't forward X-Forwarded-Host/X-Forwarded-Proto (e.g. e2b
    sandbox previews), so the URLs handed to the app are always the public
    ones it can actually reach.
    """
    override = os.environ.get("PUBLIC_BASE_URL")
    if override:
        return override.rstrip("/")

    proto = request.headers.get("x-forwarded-proto", request.url.scheme)
    host = request.headers.get("x-forwarded-host", request.headers.get("host", "localhost"))
    # e2b preview proxies terminate TLS; if they omit X-Forwarded-Proto we'd
    # otherwise hand the app a cleartext URL that iOS (ATS) rejects.
    if host.endswith(".e2b.app") and proto == "http":
        proto = "https"
    return f"{proto}://{host}".rstrip("/")


def _urls_payload(request: Request, count: int) -> dict:
    """Shape the app decodes into `RyukSignAPI.URLsResponse`. Must be non-empty."""
    urls = _env_repo_urls() or [f"{_base_url(request)}/repo/premium.json"]
    return {"urls": [{"url": url} for url in urls[:count]]}


# ---------------------------------------------------------------------------
# App-facing endpoints (the /api prefix must match apiBaseURL in the app)
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/validate")
def validate(
    body: ValidateBody,
    request: Request,
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
) -> dict:
    if not x_api_key:
        raise HTTPException(status_code=401, detail=INVALID_KEY_DETAIL)

    row = db.get_key(x_api_key)

    if row is None:
        raise HTTPException(status_code=401, detail=INVALID_KEY_DETAIL)

    if row["disabled"]:
        raise HTTPException(status_code=403, detail=DISABLED_KEY_DETAIL)

    # Keys are single-use and device-bound. Re-validating with the same device
    # is allowed (idempotent) so reinstall/restore flows stay smooth; a
    # different device gets the exact message the app shows for burned keys.
    if row["used"] and row["device_uuid"] != body.device_uuid:
        raise HTTPException(status_code=401, detail=INVALID_KEY_DETAIL)

    if not row["used"]:
        db.consume_key(x_api_key, body.device_uuid)

    return _urls_payload(request, count=25)


@app.get("/api/urls")
def urls(
    request: Request,
    ryuksign_uuid: str | None = Header(default=None, alias="ryukSignUUID"),
) -> dict:
    if not ryuksign_uuid or not db.device_has_activation(ryuksign_uuid):
        raise HTTPException(status_code=401, detail=NO_ACTIVATION_DETAIL)

    return _urls_payload(request, count=25)


# ---------------------------------------------------------------------------
# Gated premium source (your feed file, or the built-in demo as fallback)
# ---------------------------------------------------------------------------

def _require_premium_access(
    ryuksign_uuid: str | None,
    x_api_key: str | None,
) -> None:
    """The app attaches `ryukSignUUID` (always) and `X-API-Key` (once the key
    is persisted) when fetching URLs on premium hosts — mirror that here."""
    if ryuksign_uuid and db.device_has_activation(ryuksign_uuid):
        return
    if x_api_key and db.key_allows_downloads(x_api_key):
        return
    raise HTTPException(status_code=401, detail=NO_ACTIVATION_DETAIL)


def _local_feed() -> dict | None:
    """Your real feed, if present: PREMIUM_FEED_FILE (env) or a premium.json
    next to main.py. Read on every request so edits apply without a restart.
    Template: premium.example.json (exact shape ASRepository decodes)."""
    path = os.environ.get("PREMIUM_FEED_FILE") or os.path.join(
        os.path.dirname(__file__), "premium.json"
    )
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            feed = json.load(f)
    except (OSError, ValueError) as exc:
        raise HTTPException(status_code=500, detail=f"Premium feed file is invalid: {exc}")
    if not isinstance(feed, dict) or not feed.get("apps"):
        raise HTTPException(
            status_code=500,
            detail="Premium feed must be a JSON object with a non-empty 'apps' array.",
        )
    return feed


@app.get("/repo/premium.json")
def premium_repo(
    request: Request,
    ryuksign_uuid: str | None = Header(default=None, alias="ryukSignUUID"),
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
) -> dict:
    _require_premium_access(ryuksign_uuid, x_api_key)

    feed = _local_feed()
    if feed is not None:
        return feed

    base = _base_url(request)

    # Minimal AltStore v1 source (exact shape `ASRepository` decodes):
    # identifier + name + non-empty apps[]; every app needs name, bundleIdentifier
    # and iconURL. Replace the demo app with your real IPA entries (see README).
    return {
        "name": "RyukSign Premium",
        "identifier": "com.ryuksign.premium",
        "subtitle": "Your private premium source",
        "iconURL": f"{base}/static/icon.png",
        "sourceURL": f"{base}/repo/premium.json",
        "apps": [
            {
                "name": "Premium Demo",
                "bundleIdentifier": "com.ryuksign.premium.demo",
                "developerName": "RyukSign",
                "subtitle": "Premium works — replace me with your real apps",
                "version": "1.0",
                "versionDate": "2026-09-19T00:00:00Z",
                "versionDescription": "Demo entry served by your own RyukSign backend.",
                "iconURL": f"{base}/static/icon.png",
            }
        ],
    }


@app.get("/static/icon.png", include_in_schema=False)
def icon() -> FileResponse:
    return FileResponse(os.path.join(os.path.dirname(__file__), "static", "icon.png"))


@app.get("/")
def root(request: Request) -> dict:
    return {
        "service": "RyukSign Premium API",
        "endpoints": [
            "POST /api/validate",
            "GET /api/urls",
            "GET /api/health",
            "GET /repo/premium.json",
        ],
        "appSetting": f'static let apiBaseURL = "{_base_url(request)}/api"  // RyukSign/Utilities/RyukSignAPI.swift',
    }
