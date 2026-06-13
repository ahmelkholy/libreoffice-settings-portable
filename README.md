# LibreOffice Portable Settings

This folder is a GitHub-ready, sanitized backup of a LibreOffice user profile.
It is designed to move UI, Writer formatting aids, keyboard shortcuts, and
text-direction settings between Windows, Linux, and macOS.

## What Is Included

- `settings/registrymodifications.portable.xcu`
  - Minimal menu-first UI settings
  - Hidden toolbars/sidebar-style compact settings
  - Writer formatting marks: spaces, tabs, paragraph marks, breaks, hidden text
  - Writer text/table/section boundaries
  - Complex text layout controls for LTR/RTL work
  - Microsoft Office-style Writer shortcuts layered over LibreOffice defaults
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
- `scripts/start-portable.ps1`
  - Starts the currently installed LibreOffice with a stable `portable-profile`
  - Converts Windows document paths to `file:///...` URIs before opening
- `scripts/start-portable.vbs`
  - Windows GUI launcher for file associations, so opening documents does not show a console window
- `scripts/apply-windows-portable-associations.ps1`
  - Per-user file-association override so LibreOffice-owned files use the portable profile launcher

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

By default, restore appends these portable settings to the current profile and
backs up the existing `registrymodifications.xcu` first. To fully replace that
file instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1 -Replace
```

```bash
bash ./scripts/restore.sh --replace
```

## Update-Resistant Windows Launcher

LibreOffice updates can change the default user profile under
`%APPDATA%\LibreOffice\4\user`. For a profile that survives updates, use the
portable launcher instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-portable.ps1
```

Open a document through the same profile:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-portable.ps1 "D:\PROJECT-PHD-Thesis\Presentation\transcript.docx"
```

The launcher finds the current LibreOffice installation each time, initializes
`portable-profile\user\registrymodifications.xcu` from the portable settings if
needed, and keeps that runtime profile outside git.

To make double-click/open commands use the portable profile for LibreOffice file
classes:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-windows-portable-associations.ps1
```

To remove those per-user overrides:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-windows-portable-associations.ps1 -Remove
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

## GitHub

Recommended as a private repo:

```bash
cd libreoffice-settings-portable
git init
git add .
git commit -m "Add portable LibreOffice settings"
gh repo create libreoffice-settings-portable --private --source=. --push
```

If you do not use GitHub CLI, create an empty private repo on GitHub and then:

```bash
git remote add origin https://github.com/YOURNAME/libreoffice-settings-portable.git
git branch -M main
git push -u origin main
```
