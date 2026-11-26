#!/usr/bin/env python3
"""Write workspace/instances/<name>/bin/runtime.manifest.json."""
import argparse
import datetime
import hashlib
import json
import os
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--instance", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--shared-root", default="")
    ap.add_argument("--reused-from", default="")
    ap.add_argument("--build-id", action="append", default=[], metavar="NAME=ID")
    ap.add_argument("artifacts", nargs="+", help="name=path")
    ns = ap.parse_args()

    shared = Path(ns.shared_root).resolve() if ns.shared_root else None
    output = Path(ns.output).resolve()
    base = output.parent
    overrides = {}
    for item in ns.build_id:
        if "=" in item:
            name, value = item.split("=", 1)
            overrides[name] = value

    artifacts = {}
    for item in ns.artifacts:
        if "=" not in item:
            print(f"bad artifact spec (expected name=path): {item}", file=sys.stderr)
            return 2
        name, path = item.split("=", 1)
        given = Path(path)
        p = given.resolve()
        data = p.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        build_id = overrides.get(name)
        if build_id is None and shared is not None and shared in p.parents:
            build_id = p.parent.name
        artifacts[name] = {
            # Keep the instance path (possibly a symlink), not the cache path.
            "path": os.path.relpath(given.absolute(), base),
            "sha256": digest,
            "size": len(data),
            "build_id": build_id or f"sha256:{digest[:16]}",
        }

    payload = {
        "instance": ns.instance,
        "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "artifacts": artifacts,
    }
    if ns.reused_from:
        payload["reused_from"] = ns.reused_from

    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
