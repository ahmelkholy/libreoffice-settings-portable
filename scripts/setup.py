#!/usr/bin/env python3
"""One setup entry point for the single repository, on each operating system."""
import datetime as dt
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import re

ROOT = Path(__file__).resolve().parents[1]


def run(script, *args):
    subprocess.run([sys.executable, str(ROOT / "scripts" / script), *args], check=True)


def main():
    run("lo-settings.py", "apply")
    system = platform.system()
    if system == "Darwin":
        run("lo-settings.py", "repair-macos")
        if (Path.home() / ".config/karabiner/karabiner.json").exists():
            run("install-vim-macos.py")
        else:
            print("For held navigation, install/start Karabiner-Elements once, then rerun setup. SHK is optional.")
    elif system == "Windows":
        shk = Path(os.environ.get("SHK_SCRIPT", str(ROOT.parent / "SHK/shk.ahk")))
        if shk.is_file():
            source = shk.read_text(encoding="utf-8-sig")
            try:
                relative = os.path.relpath(ROOT / "windows/vim-navigation.ahk", shk.parent)
            except ValueError as exc:
                raise RuntimeError("Keep SHK and the settings checkout on the same drive, or use the standalone adapter.") from exc
            include = "#Include *i %A_ScriptDir%\\" + relative.replace("/", "\\")
            pattern = r"(?m)^[ \t]*#Include[^\r\n]*[\\/]windows[\\/]vim-navigation\.ahk[ \t]*$"
            if re.search(pattern, source):
                updated = re.sub(pattern, lambda _: include, source)
            else:
                anchor = "; --- Application-Specific Hotkeys ---"
                if anchor not in source:
                    raise RuntimeError("SHK's application-hotkey section was not found. Use the include instruction in VIM.md.")
                updated = source.replace(anchor, anchor + "\n" + include, 1)
            if updated != source:
                backup = ROOT / ".local/backups" / ("shk-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
                backup.mkdir(parents=True)
                shutil.copy2(shk, backup / shk.name)
                import importlib
                importlib.import_module("lo-settings").atomic_write(shk, updated.encode("utf-8-sig"))
            print("SHK integration is ready. Reload SHK (CapsLock+F5) to activate the additions.")
        else:
            print("SHK was not found. With AutoHotkey v1 installed, run windows/vim-standalone.ahk, or set SHK_SCRIPT and rerun setup.")
    elif system == "Linux":
        print("Settings applied. To enable held navigation with xremap, run: xremap " + str(ROOT / "linux/vim-navigation.yml"))
        print("Use the xremap build/integration for your desktop; see VIM.md.")
    run("lo-settings.py", "doctor")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"Setup stopped: {exc}", file=sys.stderr)
        sys.exit(1)
