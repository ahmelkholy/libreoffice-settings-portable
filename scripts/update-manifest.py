#!/usr/bin/env python3
"""Regenerate the repository integrity manifest."""

from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "manifest.json"


def repository_files() -> list[Path]:
    result = subprocess.run(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
        ],
        cwd=REPO_ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
    relative_paths = [
        Path(raw.decode("utf-8", errors="surrogateescape"))
        for raw in result.stdout.split(b"\0")
        if raw
    ]
    return sorted(
        path
        for path in relative_paths
        if path.as_posix() != MANIFEST.name and (REPO_ROOT / path).is_file()
    )


def file_record(relative_path: Path) -> dict[str, object]:
    data = (REPO_ROOT / relative_path).read_bytes()
    return {
        "path": relative_path.as_posix(),
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def main() -> None:
    payload = {
        "schema": "libreoffice-settings-portable-manifest-v1",
        "generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
        "sourceProfile": "redacted local LibreOffice user profile",
        "portableFolder": "repository root",
        "noShortcuts": True,
        "windowsGlobalNoSplash": "Logo=0",
        "privateArchive": {
            "createdOnThisMachine": True,
            "trackedInGit": False,
            "pathRedacted": True,
            "note": (
                "A private full-profile archive was created outside this repository. "
                "Do not publish raw profile archives without review."
            ),
        },
        "note": (
            "No desktop or Start Menu shortcuts are required or created. The canonical "
            "LibreOffice registry and clean-interface policy are restored together. "
            "Windows no-splash is handled by install-level Logo=0 and optional per-user "
            "file-association overrides."
        ),
        "files": [file_record(path) for path in repository_files()],
    }
    MANIFEST.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated: {MANIFEST}")


if __name__ == "__main__":
    main()
