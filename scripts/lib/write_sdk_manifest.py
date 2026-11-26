#!/usr/bin/env python3
"""Write manifest.json for a packaged SDK directory."""
import argparse
import configparser
import datetime
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_components(path: Path) -> dict:
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(path, encoding="utf-8")
    components = {}
    for section in cp.sections():
        if not section.startswith("components."):
            continue
        name = section.split(".", 1)[1]
        components[name] = {
            key: value.strip().strip('"').strip("'")
            for key, value in cp.items(section)
        }
    return components


def glibc_version() -> str:
    try:
        out = subprocess.check_output(["ldd", "--version"], text=True, stderr=subprocess.STDOUT)
        return out.splitlines()[0].strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--instance", required=True)
    ns = ap.parse_args()

    root = Path(ns.root).resolve()
    repo_root = Path(ns.repo_root).resolve()
    manifest_path = root / "manifest.json"

    artifacts = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == manifest_path:
            continue
        artifacts.append({
            "path": path.relative_to(root).as_posix(),
            "sha256": sha256(path),
            "size": path.stat().st_size,
        })

    payload = {
        "schema_version": 1,
        "name": "rhetsim-sdk",
        "version": ns.version,
        "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "instance": ns.instance,
        "host": {
            "arch": platform.machine(),
            "glibc": glibc_version(),
        },
        "components": load_components(repo_root / "env" / "versions.toml"),
        "artifacts": artifacts,
        "licenses": {
            "rhetsim": "Apache-2.0",
            "linux": "GPL-2.0-only",
            "opensbi": "BSD-2-Clause",
            "busybox": "GPL-2.0-only",
            "musl": "MIT",
        },
        "source_availability": "Component source URLs and exact refs are in the components section. "
                               "GPL/LGPL binaries are distributed with corresponding source access "
                               "through the rhetsim-dev-platform repository.",
    }
    manifest_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(manifest_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
