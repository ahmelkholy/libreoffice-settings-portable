#!/usr/bin/env python3
"""Manage portable preferences without sharing a live LibreOffice profile. Python 3.9+."""
from __future__ import annotations

import argparse
import copy
import csv
import datetime as dt
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "settings/registrymodifications.portable.xcu"
POLICY = ROOT / "dist/portable-clean-libreoffice.oxt"
OOR = "http://openoffice.org/2001/registry"
XS = "http://www.w3.org/2001/XMLSchema"
XSI = "http://www.w3.org/2001/XMLSchema-instance"
for prefix, uri in (("oor", OOR), ("xs", XS), ("xsi", XSI)):
    ET.register_namespace(prefix, uri)


def profile_path(system=None, env=None, home=None):
    system, env, home = system or platform.system(), os.environ if env is None else env, home or Path.home()
    if system == "Darwin":
        return home / "Library/Application Support/LibreOffice/4/user"
    if system == "Windows":
        if not env.get("APPDATA"):
            raise RuntimeError("APPDATA is missing; supply --profile with the LibreOffice user directory.")
        return Path(env["APPDATA"]) / "LibreOffice/4/user"
    if system == "Linux":
        return Path(env.get("XDG_CONFIG_HOME", str(home / ".config"))) / "libreoffice/4/user"
    raise RuntimeError("Unsupported OS; supply --profile explicitly.")


def find_program(name="soffice"):
    override = os.environ.get("LIBREOFFICE_PROGRAM" if name == "soffice" else "LIBREOFFICE_UNOPKG")
    if override:
        p = Path(override).expanduser()
        if p.is_file():
            return p.resolve()
        raise RuntimeError(f"Configured {name} does not exist: {p}")
    candidates = []
    system = platform.system()
    if system == "Darwin":
        candidates += [p / f"LibreOffice.app/Contents/MacOS/{name}" for p in (Path("/Applications"), Path.home() / "Applications")]
    elif system == "Windows":
        exe = "unopkg.com" if name == "unopkg" else "soffice.exe"
        candidates += [Path(os.environ[key]) / "LibreOffice/program" / exe for key in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA") if os.environ.get(key)]
        candidates += [Path(p) for p in (shutil.which(exe),) if p]
    else:
        candidates += [Path(p) for p in (shutil.which(name), shutil.which("libreoffice") if name == "soffice" else None) if p]
        candidates += [Path(base) / name for base in ("/usr/lib/libreoffice/program", "/usr/lib64/libreoffice/program", "/opt/libreoffice/program")]
    for p in candidates:
        if p.is_file():
            return p.resolve()
    raise RuntimeError(f"LibreOffice {name} not found. Set LIBREOFFICE_{'PROGRAM' if name == 'soffice' else 'UNOPKG'} to its full path.")


def process_names():
    if platform.system() == "Windows":
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, check=True, timeout=15).stdout
        return [row[0] for row in csv.reader(io.StringIO(out)) if row]
    return subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True, text=True, check=True, timeout=15).stdout.splitlines()


def office_processes(names=None):
    return [s.strip() for s in (process_names() if names is None else names)
            if s.strip().replace("\\", "/").rsplit("/", 1)[-1].lower()
            in {"soffice", "soffice.bin", "soffice.exe", "libreoffice", "libreoffice.exe", "unopkg", "unopkg.bin", "unopkg.exe", "unopkg.com"}]


def require_closed():
    if office_processes():
        raise RuntimeError("Save your documents and quit LibreOffice first. No processes were stopped and no settings were changed.")


def read_xcu(path):
    root = ET.parse(path).getroot()
    if root.tag != f"{{{OOR}}}items":
        raise ValueError(f"Not a LibreOffice user settings file: {path}")
    return root


def item_key(item):
    return (item.get(f"{{{OOR}}}path", ""), tuple((c.tag, c.get(f"{{{OOR}}}name", "")) for c in item))


def portable_check(root):
    forbidden = ("Histories", "UserProfile", "Password", "Credential", "SelectedOpenCLDeviceIdentifier", "ooSetupFactoryWindowAttributes", "LastTipOfTheDay")
    for item in root:
        path = item_key(item)[0]
        if "Recovery" in path and path != "/org.openoffice.Office.Recovery/AutoSave":
            raise ValueError("Recovery sessions cannot be synchronized.")
        text = ET.tostring(item, encoding="unicode")
        if any(word in text for word in forbidden):
            raise ValueError("Portable settings contain private, hardware, or session state: " + item_key(item)[0])
        for value in item.iter("value"):
            value_text = "".join(value.itertext()).strip()
            if re.search(r"file:/|(?:^|\s)[A-Za-z]:[\\/]|/Users/|/home/|\\\\[^\\]+\\", value_text, re.I):
                raise ValueError("Portable settings contain a machine-specific path: " + item_key(item)[0])
        if ".Accelerators/" in item_key(item)[0]:
            if any((v.text or "").strip() and not (v.text or "").startswith(".uno:") for v in item.iter("value")):
                raise ValueError("Only built-in .uno: keyboard commands can be exported.")


def merge_xcu(live, portable):
    result = copy.deepcopy(live)
    keys = {item_key(i) for i in portable}
    for item in list(result):
        path = item_key(item)[0]
        # Retire the former hidden-sidebar policy so native contextual panels return.
        obsolete_sidebar = (path.startswith("/org.openoffice.Office.UI.Sidebar/Content/")
                            or (path.startswith("/org.openoffice.Office.Views/Windows/") and "10336" in path))
        obsolete_search_key = (path == "/org.openoffice.Office.Accelerators/PrimaryKeys/Global"
                               and any(c.get(f"{{{OOR}}}name") in ("F13", "F14") for c in item)
                               and all(v.text in (".uno:RepeatSearch", ".uno:SearchDialog") for v in item.iter("value")))
        if item_key(item) in keys or obsolete_sidebar or obsolete_search_key:
            result.remove(item)
        # Remove this obsolete Windows GPU selection, never any recovery data.
        elif any(p.get(f"{{{OOR}}}name") == "SelectedOpenCLDeviceIdentifier" for p in item):
            result.remove(item)
    result.extend(copy.deepcopy(list(portable)))
    return result


def xml_bytes(root):
    root = copy.deepcopy(root)
    # QName values (e.g. oor:type="xs:string") do not retain their namespace in ElementTree.
    root.set("xmlns:xs", XS)
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".lo-settings-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def backup_file(path):
    folder = ROOT / ".local/backups" / dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    folder.mkdir(parents=True, mode=0o700)
    if path.exists():
        shutil.copy2(path, folder / path.name)
    atomic_write(folder / "backup.json", (json.dumps({"target": str(path.resolve()), "existed": path.exists()}, indent=2) + "\n").encode())
    return folder


def export_settings(profile):
    require_closed()
    live, portable = read_xcu(profile / "registrymodifications.xcu"), read_xcu(SOURCE)
    portable_check(portable)
    live_by_key = {item_key(i): i for i in live}
    result = ET.Element(f"{{{OOR}}}items")
    # Explicitly managed items only. New private settings never enter the shared copy.
    for item in portable:
        result.append(copy.deepcopy(live_by_key.get(item_key(item), item)))
    portable_check(result)
    backup = backup_file(SOURCE)
    atomic_write(SOURCE, xml_bytes(result))
    print(f"Exported {len(result)} managed settings. Previous source: {backup}")


def apply_settings(profile, replace=False):
    require_closed()
    portable = read_xcu(SOURCE)
    portable_check(portable)
    if not POLICY.is_file():
        raise RuntimeError("Missing policy extension. Run scripts/build-policy.sh.")
    toolbar = ROOT / "settings/side-essentials.xml"
    ET.parse(toolbar)
    unopkg = find_program("unopkg")
    target = profile / "registrymodifications.xcu"
    live = read_xcu(target) if target.exists() else ET.Element(f"{{{OOR}}}items")
    output = portable if replace else merge_xcu(live, portable)
    backup = backup_file(target)
    profile.mkdir(parents=True, exist_ok=True)
    profile_arg = "-env:UserInstallation=" + profile.parent.resolve().as_uri()
    for args in (("add", "--force", "--suppress-license", str(POLICY)), ("validate", "org.ahmelkholy.libreoffice.cleanui")):
        try:
            subprocess.run([str(unopkg), profile_arg, *args], check=True, timeout=60)
        except (subprocess.SubprocessError, OSError) as exc:
            # unopkg may rewrite the registry even on a failed installation.
            if not office_processes():
                if (backup / target.name).exists():
                    atomic_write(target, (backup / target.name).read_bytes())
                elif target.is_file():
                    target.unlink()
            raise RuntimeError(f"Policy installation failed. Settings backup: {backup}. {exc}") from exc
    require_closed()
    for module in ("swriter", "scalc", "simpress", "sdraw"):
        destination = profile / "config/soffice.cfg/modules" / module / "toolbar/custom_sideessentials.xml"
        if destination.exists():
            saved = backup / "toolbars" / module / destination.name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, saved)
        atomic_write(destination, toolbar.read_bytes())
    atomic_write(target, xml_bytes(output))
    print(f"Applied {len(portable)} managed settings to {target}\nBackup: {backup}")


def rollback(folder):
    require_closed()
    folder = folder.resolve()
    backup_root = (ROOT / ".local/backups").resolve()
    if backup_root not in folder.parents:
        raise ValueError("Choose a backup inside this repository's .local/backups directory.")
    data = json.loads((folder / "backup.json").read_text())
    target = Path(data["target"])
    if target.name not in ("registrymodifications.xcu", SOURCE.name):
        raise ValueError("This is not a settings backup.")
    if not data["existed"]:
        raise RuntimeError("There was no previous settings file; use the native LibreOffice profile reset if needed.")
    old = folder / target.name
    read_xcu(old)
    backup_file(target)
    atomic_write(target, old.read_bytes())
    print(f"Restored settings: {target}. Installed extensions are unchanged.")


def open_files(files):
    program = find_program()
    paths = [Path(f).expanduser().resolve(strict=True) for f in files]
    if any(not p.is_file() for p in paths):
        raise ValueError("Select files, not directories.")
    # File URIs preserve spaces, Unicode, quotes and leading '-' on every OS.
    subprocess.Popen([str(program), "--nologo", *[p.as_uri() for p in paths]],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def doctor(profile):
    portable = read_xcu(SOURCE)
    portable_check(portable)
    print(f"Portable XML: valid ({len(portable)} managed items)")
    print(f"Profile: {profile}")
    print(f"LibreOffice: {find_program()}")
    print(f"Extension manager: {find_program('unopkg')}")
    print("Running: " + (", ".join(office_processes()) or "no"))
    target = profile / "registrymodifications.xcu"
    if target.exists():
        live = {item_key(i): i for i in read_xcu(target)}
        def signature(item):
            return (item.tag, tuple(sorted((k, v) for k, v in item.attrib.items() if k not in (f"{{{OOR}}}op", f"{{{OOR}}}type"))),
                    (item.text or "").strip(), tuple(signature(c) for c in item))
        def matches(expected, actual):
            if expected.tag == "value":
                return signature(expected) == signature(actual)
            for child in expected:
                candidates = [c for c in actual if c.tag == child.tag and c.get(f"{{{OOR}}}name") == child.get(f"{{{OOR}}}name")]
                if not any(matches(child, candidate) for candidate in candidates):
                    return False
            return True
        drift = sum(item_key(i) not in live or not matches(i, live[item_key(i)]) for i in portable)
        print(f"Managed preference differences: {drift} (extra local window metadata is ignored)")
    else:
        print("Profile not initialized; apply will create it.")
    if platform.system() == "Darwin":
        import macos_opener
        macos_opener.status()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, help="Explicit .../4/user directory (also for Flatpak/custom profiles)")
    subs = parser.add_subparsers(dest="action", required=True)
    subs.add_parser("doctor", help="Read-only configuration and opening diagnostics")
    apply = subs.add_parser("apply", help="Merge managed settings, preserving local extensions and recovery")
    apply.add_argument("--replace", action="store_true", help="Explicitly replace the settings file after backing it up")
    subs.add_parser("export", help="Capture changes to the managed settings only")
    undo = subs.add_parser("rollback", help="Restore a saved settings file")
    undo.add_argument("backup", type=Path)
    opening = subs.add_parser("open", help="Open documents directly through LibreOffice")
    opening.add_argument("files", nargs="*")
    subs.add_parser("repair-macos", help="Install/reinstall the native file opener and repair its registrations")
    subs.add_parser("uninstall-macos-opener", help="Restore the previous file associations")
    args = parser.parse_args(argv)
    if args.action in ("repair-macos", "uninstall-macos-opener"):
        import macos_opener
        if args.action == "repair-macos":
            macos_opener.install(find_program())
        else:
            macos_opener.uninstall()
        return
    if args.action == "open":
        open_files(args.files)
        return
    if args.action == "rollback":
        rollback(args.backup)
        return
    profile = args.profile.expanduser().resolve() if args.profile else profile_path()
    if profile.name != "user":
        raise ValueError("--profile must end in /user, not /4 or the settings filename.")
    if args.action == "apply":
        apply_settings(profile, args.replace)
    elif args.action == "export":
        export_settings(profile)
    else:
        doctor(profile)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, RuntimeError, ET.ParseError, subprocess.SubprocessError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
