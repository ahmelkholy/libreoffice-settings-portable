#!/usr/bin/env python3
"""Add/remove only the LibreOffice group in the existing SHK Karabiner profile."""
import argparse
import datetime as dt
import json
from pathlib import Path
import shutil
import sys
import copy

ROOT = Path(__file__).resolve().parents[1]
NAME = "LibreOffice: safe held CapsLock navigation additions"


def standalone_rule(additions):
    """A fresh Karabiner profile can use this repository without the separate SHK repo."""
    rule = copy.deepcopy(additions)
    app = {"type": "frontmost_application_if", "bundle_identifiers": [r"^org\.libreoffice\.script$"]}
    held = {"type": "variable_if", "name": "lo_caps", "value": 1}
    for mapping in rule["manipulators"]:
        mapping["conditions"] = [app, held]
    activation = {"description": "LibreOffice only: hold CapsLock to navigate, tap for Escape", "type": "basic",
                  "from": {"key_code": "caps_lock", "modifiers": {"optional": ["any"]}},
                  "conditions": [app], "to": [{"set_variable": {"name": "lo_caps", "value": 1}}],
                  "to_after_key_up": [{"set_variable": {"name": "lo_caps", "value": 0}}],
                  "to_if_alone": [{"key_code": "escape"}]}
    rule["manipulators"].insert(0, activation)
    mappings = [("h", "left_arrow", []), ("j", "down_arrow", []), ("k", "up_arrow", []),
                ("l", "right_arrow", []), ("w", "left_arrow", ["left_option"]),
                ("e", "right_arrow", ["left_option"]), ("period", "home", []),
                ("slash", "end", []), ("comma", "page_up", []), ("m", "page_down", [])]
    for key, output, modifiers in mappings:
        for shifted in (True, False):
            rule["manipulators"].append({"type": "basic",
                "from": {"key_code": key, "modifiers": {"mandatory": ["shift"] if shifted else [], "optional": ["caps_lock"]}},
                "conditions": [app, held],
                "to": [{"key_code": output, "modifiers": modifiers + (["left_shift"] if shifted else [])}]})
    return rule


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--config", type=Path, default=Path.home() / ".config/karabiner/karabiner.json")
    args = parser.parse_args()
    config = args.config.expanduser()
    data = json.loads(config.read_text())
    selected = [p for p in data["profiles"] if p.get("selected")]
    if len(selected) != 1:
        raise ValueError("Select exactly one Karabiner profile first.")
    rules = selected[0]["complex_modifications"]["rules"]
    has_shk = any(
        t.get("set_variable") == {"name": "shk_caps", "value": 1}
        for r in rules for m in r["manipulators"] for t in m.get("to", [])
    )
    replacement = [r for r in rules if r["description"] != NAME]
    if not args.remove:
        new = json.loads((ROOT / "macos/vim-navigation.json").read_text())["rules"][0]
        # Precede the generic CapsLock rules. Every addition is LibreOffice-only.
        if has_shk:
            index = next((i for i, rule in enumerate(replacement) if rule["description"] == "SHK macOS: CapsLock navigation layer"), None)
            if index is None:
                raise ValueError("The SHK navigation anchor was not found; no settings were changed.")
        else:
            new, index = standalone_rule(new), 0
        replacement.insert(index, new)
    if replacement == rules:
        print("LibreOffice navigation is already in the requested state.")
        return
    backup = ROOT / ".local/backups" / ("karabiner-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    backup.mkdir(parents=True, mode=0o700)
    shutil.copy2(config, backup / "karabiner.json")
    selected[0]["complex_modifications"]["rules"] = replacement
    import importlib
    manager = importlib.import_module("lo-settings")
    manager.atomic_write(config, (json.dumps(data, indent=4, ensure_ascii=False) + "\n").encode())
    print(("Removed" if args.remove else "Installed") + f" LibreOffice-only navigation. Backup: {backup}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
