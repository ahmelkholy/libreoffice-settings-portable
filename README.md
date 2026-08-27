# LibreOffice Portable Settings

This folder is a GitHub-ready, sanitized backup of a LibreOffice user profile.
It is designed to move UI, Writer formatting aids, keyboard shortcuts, and
text-direction settings between Windows, Linux, and macOS.

The repository contains one canonical, portable settings profile. Apply that
profile on every machine; do not copy an entire live LibreOffice profile
between operating systems.

## What Is Included

- `settings/registrymodifications.portable.xcu`
  - Minimal menu-first UI with every toolbar and the sidebar hidden
  - Writer formatting marks: spaces, tabs, paragraph marks, breaks, hidden text
  - Writer text/table/section boundaries
  - Writer opens new and loaded documents at 50% zoom
  - Zotero's Writer toolbar stays hidden
  - Complex text layout controls for LTR/RTL work
  - Microsoft Office-style Writer shortcuts layered over LibreOffice defaults
  - No saved screen coordinates or window dimensions, so different displays
    and operating systems choose safe native window placement
- `dist/portable-clean-libreoffice.oxt`
  - Configuration policy installed automatically by both restore scripts
  - Enforces the toolbar-free interface, hidden Zotero toolbar, hidden Writer
    rulers, and 50% Writer zoom
  - Covers Writer, Calc, Impress, Draw, Math, Base, and related LibreOffice views
- `extension/clean-ui`
  - Auditable source for the policy extension
- `settings/backup-summary.json`
  - JSON summary of what was exported and what was intentionally excluded
- `windows/file-associations.nologo.json`
  - Windows per-user LibreOffice file-association commands with `--nologo`
- `scripts/restore.ps1`
  - Cross-platform PowerShell restore script
- `scripts/restore.sh`
  - Linux/macOS restore script using Python 3
- `scripts/apply-windows-nologo-associations.ps1`
  - Windows registry restore for `--nologo`, without creating shortcuts
- `scripts/apply-windows-global-nologo.ps1`
  - Windows install-level `Logo=0` setting for app launches, without creating shortcuts

## What Is Not Included

This public/shareable backup intentionally excludes recent files, recovery
entries, thumbnails, local paths, and user profile data. A separate private raw
archive was created locally for full recovery. Do not publish the private raw
archive unless you have inspected it.

## Restore

Close LibreOffice first.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1 -WindowsNoLogo
```

Linux/macOS:

```bash
bash ./scripts/restore.sh
```

PowerShell on Linux/macOS also works if `pwsh` is installed:

```powershell
pwsh ./scripts/restore.ps1
```

By default, restore replaces `registrymodifications.xcu` with the repository's
single canonical profile. The old file is backed up first. Installed extensions
and documents are not removed. The script also force-updates the clean-interface
policy extension and verifies its registration.

Use merge mode only when you intentionally need to retain machine-specific or
older LibreOffice preferences:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1 -Merge
```

```bash
bash ./scripts/restore.sh --merge
```

The default replacement mode is what guarantees the same 50% zoom, hidden
sidebar, and toolbar-free interface on every OS. `--replace`/`-Replace` remains
available as an explicit spelling of the default. Merge mode is less strict and
can preserve stale UI state, so it is not recommended for the reference setup.

The Zotero integration extension itself is not included. Install it through
Zotero on each machine; this profile controls only its LibreOffice toolbar.

## Updates and Reliability

The policy extension is stored separately from LibreOffice's application files,
so normal LibreOffice and Zotero updates do not replace it. The restore scripts
also reinstall it with `--force`, making the Git checkout the canonical copy.

A LibreOffice factory reset, Safe Mode profile reset, or a newly installed OS
creates a new user profile and can remove user settings and extensions. In that
case, pull this repository and run the restore script again. This is the
recovery path; no full cross-platform profile copy is needed.

To synchronize another machine:

```bash
git pull --ff-only
bash ./scripts/restore.sh
```

On Windows:

```powershell
git pull --ff-only
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1 -WindowsNoLogo
```

## Windows No-Splash Behavior

The splash setting is not fully portable inside LibreOffice's user profile.
On Windows, this repo provides two no-shortcut options:

- Install-level app launch behavior through `soffice.ini` with `Logo=0`.
- Per-user file-association overrides that add `--nologo` when LibreOffice-owned documents are opened.

For app launches, run as administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-windows-global-nologo.ps1
```

For document file associations, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-windows-nologo-associations.ps1
```

## Rebuilding the Policy

The built `.oxt` is committed so Windows, Linux, and macOS machines can restore
without build tools. Maintainers can regenerate the window-state policy from an
installed LibreOffice registry and rebuild the package:

```bash
./scripts/generate-window-policy.py /path/to/libreoffice/share/registry
./scripts/build-policy.sh
./scripts/update-manifest.py
```
