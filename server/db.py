#!/usr/bin/env python3
"""Tiny SQLite-backed storage for VexSign premium API keys.

A key row looks like:

    api_key      TEXT PRIMARY KEY  -- e.g. RYK-ABCD-EFGH-IJKL
    used         INTEGER           -- 0 = fresh, 1 = consumed by a device
    device_uuid  TEXT              -- the VexSign device that consumed it
    disabled     INTEGER           -- 1 = administratively disabled (403)
    created_at   REAL              -- unix timestamp
"""

import os
import sqlite3
import time

DB_PATH = os.environ.get("RYUKSIGN_DB", os.path.join(os.path.dirname(__file__), "vexsign.db"))

# Shared with keygen.py and the admin API: keep O/0 and I/1 out of keys so a
# key read off a phone screen and typed back is never ambiguous.
KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS keys (
    api_key     TEXT PRIMARY KEY,
    used        INTEGER NOT NULL DEFAULT 0,
    device_uuid TEXT,
    disabled    INTEGER NOT NULL DEFAULT 0,
    created_at  REAL NOT NULL
);
"""


def connect() -> sqlite3.Connection:
    """Open the database (creating the schema on first use)."""
    parent = os.path.dirname(DB_PATH)
    if parent:
        os.makedirs(parent, exist_ok=True)  # e.g. /data before a volume exists
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(_SCHEMA)
    return conn


def add_key(api_key: str) -> None:
    with connect() as conn:
        conn.execute(
            "INSERT INTO keys (api_key, used, device_uuid, disabled, created_at) VALUES (?, 0, NULL, 0, ?)",
            (api_key, time.time()),
        )


def get_key(api_key: str) -> sqlite3.Row | None:
    with connect() as conn:
        return conn.execute("SELECT * FROM keys WHERE api_key = ?", (api_key,)).fetchone()


def consume_key(api_key: str, device_uuid: str) -> None:
    """Mark a fresh key as used and bind it to a device (idempotently)."""
    with connect() as conn:
        conn.execute(
            "UPDATE keys SET used = 1, device_uuid = ? WHERE api_key = ?",
            (device_uuid, api_key),
        )


def device_has_activation(device_uuid: str) -> bool:
    with connect() as conn:
        row = conn.execute(
            "SELECT 1 FROM keys WHERE device_uuid = ? AND used = 1 AND disabled = 0 LIMIT 1",
            (device_uuid,),
        ).fetchone()
        return row is not None


def key_allows_downloads(api_key: str) -> bool:
    """A consumed, non-disabled key may download premium content."""
    row = get_key(api_key)
    return bool(row and row["used"] and not row["disabled"])


def set_key_disabled(api_key: str, disabled: bool) -> None:
    """Administratively disable (or re-enable) a key."""
    with connect() as conn:
        conn.execute(
            "UPDATE keys SET disabled = ? WHERE api_key = ?",
            (int(disabled), api_key),
        )


def reset_key(api_key: str) -> None:
    """Make a consumed key fresh again (unbind its device)."""
    with connect() as conn:
        conn.execute(
            "UPDATE keys SET used = 0, device_uuid = NULL WHERE api_key = ?",
            (api_key,),
        )


def delete_key(api_key: str) -> None:
    """Permanently remove a key."""
    with connect() as conn:
        conn.execute("DELETE FROM keys WHERE api_key = ?", (api_key,))
