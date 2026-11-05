"""Build/install a local native opener; preserve other applications' associations."""
from pathlib import Path
import datetime as dt
import json
import platform
import plistlib
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
APP = Path.home() / "Applications/LibreOffice Open.app"
BUNDLE_ID = "org.ahmelkholy.libreoffice.open"
NATIVE_ID = "org.libreoffice.script"
STATE = ROOT / ".local/macos/associations.json"
LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
EXTENSIONS = "doc docx docm dot dotx dotm xls xlsx xlsm xlt xltx xltm ppt pptx pptm pot potx potm pps ppsx odt ott ods ots odp otp odg otg odf odm odb rtf".split()


def run(args, **kwargs):
    try:
        return subprocess.run([str(a) for a in args], check=True, text=True, capture_output=True, timeout=60, **kwargs).stdout.strip()
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"{args[0]} failed: {exc.stderr.strip() or exc.stdout.strip()}") from exc


def binary(app=APP):
    return app / "Contents/MacOS/LibreOfficeOpen"


def require_macos():
    if platform.system() != "Darwin":
        raise RuntimeError("The native opener is macOS-only. Windows/Linux use their normal LibreOffice file associations.")


def handler(executable, ext):
    fields = run([executable, "--handler", ext]).split("\t", 1)
    return fields[0], fields[1] if len(fields) > 1 else ""


def save_state(state):
    from importlib import import_module
    # Atomic file replacement; this module is also callable from the CLI with a hyphenated filename.
    manager = import_module("lo-settings")
    manager.atomic_write(STATE, (json.dumps(state, indent=2) + "\n").encode())


def install(soffice):
    require_macos()
    native = next((p for p in soffice.parents if p.suffix == ".app"), None)
    if native is None:
        raise ValueError("LIBREOFFICE_PROGRAM must point inside an installed LibreOffice.app.")
    if not shutil.which("swiftc"):
        raise RuntimeError("Building the opener requires Apple's Command Line Tools (xcode-select --install).")
    native_info = plistlib.loads((native / "Contents/Info.plist").read_bytes())
    if native_info.get("CFBundleIdentifier") != NATIVE_ID:
        raise ValueError("The selected application is not LibreOffice.")
    if APP.exists():
        if plistlib.loads((APP / "Contents/Info.plist").read_bytes()).get("CFBundleIdentifier") != BUNDLE_ID:
            raise RuntimeError(f"Refusing to replace an unrelated application at {APP}")
        if not STATE.exists():
            raise RuntimeError("The opener exists but its original association backup is missing. Restore .local/macos/associations.json before reinstalling.")
    run([LSREGISTER, "-f", native])
    build_dir = ROOT / ".local/build"
    build_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="opener-", dir=build_dir) as temp:
        stage = Path(temp) / APP.name
        binary(stage).parent.mkdir(parents=True)
        resources = stage / "Contents/Resources"
        resources.mkdir()
        run(["swiftc", "-O", "-swift-version", "5", "-target", platform.machine() + "-apple-macosx11.0",
             ROOT / "macos/LibreOfficeOpen.swift", "-o", binary(stage)])
        associations = {ext: dict(zip(("uti", "previous"), handler(binary(stage), ext))) for ext in EXTENSIONS}
        types = {record["uti"] for record in associations.values()}
        info = {
            "CFBundleIdentifier": BUNDLE_ID, "CFBundleName": "LibreOffice Open",
            "CFBundleDisplayName": "LibreOffice Open", "CFBundleExecutable": "LibreOfficeOpen",
            "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1", "LSMinimumSystemVersion": "11.0", "LSUIElement": True,
            "NSHighResolutionCapable": True, "CFBundleIconFile": "main.icns",
            "LibreOfficeApplicationPath": str(native),
            "CFBundleDocumentTypes": [{"CFBundleTypeName": "Office documents", "CFBundleTypeRole": "Editor",
                                       "LSHandlerRank": "Alternate", "LSItemContentTypes": sorted(types)}],
            "UTImportedTypeDeclarations": [t for t in native_info.get("UTImportedTypeDeclarations", []) + native_info.get("UTExportedTypeDeclarations", []) if t.get("UTTypeIdentifier") in types],
        }
        (stage / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        shutil.copy2(native / "Contents/Resources/main.icns", resources / "main.icns")
        run(["codesign", "--force", "--sign", "-", stage])
        APP.parent.mkdir(parents=True, exist_ok=True)
        if APP.exists():
            run([LSREGISTER, "-u", APP])
            old = ROOT / ".local/macos" / ("opener-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".disabled")
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(APP), old)
        shutil.move(str(stage), APP)
    run([LSREGISTER, "-f", APP])
    # Registration is asynchronous. Give LaunchServices time to index a new bundle.
    time.sleep(1)
    state = json.loads(STATE.read_text()) if STATE.exists() else {"schema": 1, "associations": {}}
    changed, preserved, native_fallback = [], [], []
    for ext, record in associations.items():
        if record["previous"] in (NATIVE_ID, BUNDLE_ID, ""):
            if ext not in state["associations"]:
                state["associations"][ext] = record
            # Save the original owner before changing even one association.
            save_state(state)
            run([binary(), "--set-handler", record["uti"], BUNDLE_ID])
            for attempt in range(4):
                if handler(binary(), ext)[1] == BUNDLE_ID:
                    break
                time.sleep(0.25)
                run([binary(), "--set-handler", record["uti"], BUNDLE_ID])
            if handler(binary(), ext)[1] != BUNDLE_ID:
                native_fallback.append(ext)
            else:
                changed.append(ext)
        else:
            preserved.append(ext)
    print(f"Installed: {APP}\nDirect opening enabled for: {', '.join(changed)}")
    if preserved:
        print("Kept existing non-LibreOffice defaults for: " + ", ".join(preserved))
    if native_fallback:
        print("macOS retained the native handler for: " + ", ".join(native_fallback)
              + ". These files still open with LibreOffice; Finder > Get Info > Open with > LibreOffice Open > Change All can select the adapter.")


def uninstall():
    require_macos()
    if not APP.exists() or not STATE.exists():
        raise RuntimeError("The installed opener or its association backup is missing.")
    state = json.loads(STATE.read_text())
    for ext, record in state["associations"].items():
        _, owner = handler(binary(), ext)
        if owner == BUNDLE_ID:
            run([binary(), "--set-handler", record["uti"], record["previous"] or NATIVE_ID])
    run([LSREGISTER, "-u", APP])
    disabled = ROOT / ".local/macos" / ("uninstalled-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".disabled")
    shutil.move(str(APP), disabled)
    STATE.rename(STATE.with_name("associations-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".json"))
    print("Restored previous file associations. LibreOffice and its settings remain installed.")


def status():
    if not binary().is_file():
        print("macOS direct opener: not installed")
        return
    print(f"macOS direct opener: {APP}")
    for ext in ("docx", "xlsx", "pptx", "odt"):
        _, owner = handler(binary(), ext)
        print(f"  .{ext}: {owner}")
