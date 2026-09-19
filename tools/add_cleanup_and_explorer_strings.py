#!/usr/bin/env python3
"""Adds the user-facing strings of the new features (Auto Cleanup, IPA Explorer) to the
String Catalog so translators can pick them up.

They are already translated at runtime: `.localized()` is `NSLocalizedString`, which falls
back to the key itself. Adding them here only makes them visible in Xcode's String Catalog.

The catalog is hand-maintained and Xcode's own, non-alphabetical order, so entries are
inserted right after `"strings" : {` instead of rewriting the file — its 75k lines stay
byte-identical.

Run from the repository root:

    python3 tools/add_cleanup_and_explorer_strings.py            # dry run
    python3 tools/add_cleanup_and_explorer_strings.py --apply    # write
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / "VexSign/Resources/Localizable.xcstrings"

# Files that were added or edited for Auto Cleanup and the IPA Explorer. Keeping the list
# explicit means re-running this on a later change does not silently sweep in other strings.
SOURCES = [
    "VexSign/Backend/Observable/CleanupManager.swift",
    "VexSign/Utilities/IPAExplorer/IPAFileEntry.swift",
    "VexSign/Utilities/IPAExplorer/IPAWorkspace.swift",
    "VexSign/Backend/Observable/InstallCleanup.swift",
    "VexSign/Backend/Observable/StorageManager.swift",
    "VexSign/Views/Settings/Cleanup/CleanupView.swift",
    "VexSign/Views/IPAExplorer/IPAExplorerView.swift",
    "VexSign/Views/IPAExplorer/IPAFileViewerView.swift",
    "VexSign/Views/IPAExplorer/IPAExplorerHomeView.swift",
    "VexSign/Views/IPAExplorer/IPAExplorerActions.swift",
    # Existing screens that gained a cleanup or explorer entry point.
    "VexSign/Views/Settings/SettingsView.swift",
    "VexSign/Views/Settings/Storage/StorageView.swift",
    "VexSign/Views/Signing/Shared/SigningOptionsView.swift",
    "VexSign/Views/Library/LibraryView.swift",
    "VexSign/Views/Library/LibraryCellView.swift",
    "VexSign/Views/Library/Info/LibraryInfoView.swift",
]

# Matches `.localized("Key")` and `.localized("Key", arguments: …)` — the arguments form carries
# its own string, which also belongs in the catalog.
LOCALIZED = re.compile(r'\.localized\(\s*"([^"\\]+)"')


def _entry(key: str) -> str:
    """One catalog entry, indented the way Xcode writes them."""
    return (
        f'    {json.dumps(key, ensure_ascii=False)} : {{\n'
        f'      "extractionState" : "manual",\n'
        f'      "localizations" : {{\n'
        f'        "en" : {{\n'
        f'          "stringUnit" : {{\n'
        f'            "state" : "translated",\n'
        f'            "value" : {json.dumps(key, ensure_ascii=False)}\n'
        f'          }}\n'
        f'        }}\n'
        f'      }}\n'
        f'    }},\n'
    )


def new_keys() -> list[str]:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    known = set(catalog["strings"])

    keys: list[str] = []
    for relative in SOURCES:
        path = ROOT / relative
        if not path.exists():
            print(f"skipped (missing): {relative}", file=sys.stderr)
            continue
        for match in LOCALIZED.finditer(path.read_text(encoding="utf-8")):
            key = match.group(1)
            if key not in known and key not in keys:
                keys.append(key)
    return keys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write the catalog")
    args = parser.parse_args()

    keys = new_keys()
    if not keys:
        print("Catalog is already up to date.")
        return 0

    text = CATALOG.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as error:
        print(f"Catalog is not valid JSON: {error}", file=sys.stderr)
        return 1

    # Insertion point: the first entry sits directly after `"strings" : {`, so a block
    # inserted there keeps every existing line untouched.
    marker = '"strings" : {\n'
    index = text.index(marker) + len(marker)
    block = "".join(_entry(key) for key in keys)
    patched = text[:index] + block + text[index:]

    try:
        check = json.loads(patched)
    except json.JSONDecodeError as error:
        print(f"Refusing to write, result would not parse: {error}", file=sys.stderr)
        return 1

    if len(check["strings"]) != len(data["strings"]) + len(keys):
        print("Refusing to write, key count mismatch.", file=sys.stderr)
        return 1

    if not args.apply:
        print(f"Dry run: {len(keys)} new string(s) would be added.")
        for key in keys:
            print(f"  + {key}")
        return 0

    CATALOG.write_text(patched, encoding="utf-8")
    print(f"Added {len(keys)} string(s) to {CATALOG.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
