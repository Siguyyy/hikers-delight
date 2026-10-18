#!/usr/bin/env python3
"""Validate bundle identifiers in an iOS IPA before it is published."""

from __future__ import annotations

import pathlib
import plistlib
import sys
import zipfile


MAIN_ID = "com.siguyyy.hikersdelight"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate_ipa.py <ipa>")

    ipa = pathlib.Path(sys.argv[1])
    if not ipa.is_file():
        raise SystemExit(f"IPA does not exist: {ipa}")

    bundles: list[tuple[str, str]] = []
    with zipfile.ZipFile(ipa) as archive:
        for name in archive.namelist():
            if not name.endswith("/Info.plist"):
                continue
            if not any(
                marker in name
                for marker in (".app/", ".appex/", ".framework/")
            ):
                continue
            info = plistlib.loads(archive.read(name))
            identifier = info.get("CFBundleIdentifier")
            if identifier:
                bundles.append((name, identifier))

    main_bundles = [item for item in bundles if item[0].endswith(".app/Info.plist")]
    if len(main_bundles) != 1 or main_bundles[0][1] != MAIN_ID:
        raise SystemExit(f"Invalid main app bundle: {main_bundles}")

    seen: dict[str, str] = {}
    for path, identifier in bundles:
        previous = seen.get(identifier)
        if previous:
            raise SystemExit(
                f"Duplicate bundle identifier {identifier}: {previous} and {path}"
            )
        seen[identifier] = path

        if ".appex/" in path and not identifier.startswith(f"{MAIN_ID}."):
            raise SystemExit(f"Extension is not nested under {MAIN_ID}: {path} -> {identifier}")

    print("Validated IPA bundles:")
    for path, identifier in bundles:
        print(f"  {identifier}  {path}")


if __name__ == "__main__":
    main()
