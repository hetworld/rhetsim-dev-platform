#!/usr/bin/env python3
"""Minimal reader for env/versions.toml.

The file is a TOML subset that is also valid INI syntax, so the standard
library's configparser is enough and works on Python 3.8+ (no tomllib).
"""
import argparse
import configparser
import json
import sys
from pathlib import Path


def load(path: Path) -> dict:
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


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default=str(root / "env" / "versions.toml"))
    parser.add_argument("action", choices=["list", "get", "json"])
    parser.add_argument("args", nargs="*")
    ns = parser.parse_args()

    components = load(Path(ns.file))
    if ns.action == "list":
        for name, comp in components.items():
            print("\t".join([
                name,
                comp.get("type", ""),
                comp.get("url", ""),
                comp.get("ref", ""),
                comp.get("path", ""),
                comp.get("sha256", ""),
                comp.get("archive", ""),
                comp.get("strip_components", "1"),
            ]))
    elif ns.action == "get":
        if len(ns.args) != 2:
            parser.error("get <component> <key>")
        print(components.get(ns.args[0], {}).get(ns.args[1], ""))
    else:
        print(json.dumps(components, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
