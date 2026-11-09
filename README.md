# LibreOffice: one shared settings folder

Canonical repository: https://github.com/ahmelkholy/libreoffice-settings-portable

Use this same checkout on macOS, Windows and Linux. It contains the shared
preferences, native side toolbar, interface policy, keyboard adapters, setup,
backup and diagnostic tools. `Keys.code-workspace` points to this folder. The
standalone `LibreOffice.code-workspace` opens with relative paths on every OS.

## Everyday use

Open documents normally. On macOS the installed **LibreOffice Open** adapter
forwards files directly to the current LibreOffice executable and activates the
application. It uses the normal profile, keeps save/recovery prompts, and never
force-quits LibreOffice. It does not rewrite settings on each launch.

The layout is designed around vertical document space:

- **Left:** one compact toolbar with 14 common actions, grouped by purpose:
  Open, Save, Save As, Print, Export PDF; Undo, Redo; Cut, Copy, Paste, Clone
  Formatting; Find and Replace, Spelling, Navigator. Print opens the native
  dialog so you can choose the printer and pages. Hover an icon for its name.
  Three extra buttons match the document you are editing: **Writer** has Table,
  Image and Comment; **Calc** has Sum, AutoFilter and Chart; **Impress** has New
  Slide, Image and Start Slideshow; **Draw** has Text Box, Image and Basic Shapes.
  Each app shows 17 actions in one vertical toolbar.
- **Right:** LibreOffice's contextual sidebar: properties, formatting, styles,
  navigation and application-specific tools.
  The Styles list uses readable theme-colored names with **Show previews** off.
  This avoids black document-style text on the dark sidebar; the actual styles
  in your documents keep their formatting. You can re-enable Show previews at
  the bottom of the Styles panel if you want formatted samples again.
- **Bottom:** the native status bar stays visible. Writer provides page and
  word counts, page style, text language, selection mode, save state and zoom.
  Click the language to change the selected text or paragraph's language;
  click the word count for details. Calc provides sheet/selection information
  and calculation summaries; Impress and Draw show slide/page and object
  information. Each app keeps its own native controls in this single row.
- Horizontal toolbars start hidden. Native menus remain
  available, including View → User Interface to choose another native layout. These
  are defaults, not permanent locks on the interface.
- The existing Writer formatting marks, hidden rulers and 50% initial zoom
  remain. Default save formats are DOCX, XLSX and PPTX. Recovery is enabled
  every five minutes and backup copies are enabled.

Hold **CapsLock** for navigation; release it to type normally. See [VIM.md](VIM.md)
for the exact keys and per-OS keyboard setup. There are no document macros,
Normal/Insert mode switches, or unmodified letter-key overrides.

## Setup on each computer

Install LibreOffice and Python **3.9 or newer**, then save your work and quit
LibreOffice. The scripts refuse to apply settings while any LibreOffice or
extension-manager process is running.

| Platform | Run from this folder | Keyboard adapter |
| --- | --- | --- |
| macOS | Double-click `Setup.command`, or `bash setup.sh` | Karabiner-Elements (existing SHK supported) |
| Windows | `powershell -ExecutionPolicy Bypass -File .\Setup.ps1` | Existing AutoHotkey v1 SHK, or the included standalone script |
| Linux | `bash setup.sh` | Optional xremap config in `linux/vim-navigation.yml` |

macOS builds its opener using Apple's Command Line Tools (`xcode-select --install`
if missing). The keyboard installer reuses SHK if present; otherwise it creates a LibreOffice-only
held layer in the selected Karabiner profile. No separate SHK checkout is required.
The installed app lives in `~/Applications`; all its source lives
in this repository. It only takes over Office document types already assigned
to LibreOffice, preserving defaults owned by other apps. Some types can retain
their native handler; setup reports these explicitly. Finder → Get Info → Open
with → LibreOffice Open → Change All can select the adapter for them. Re-run setup after
moving the repository or reinstalling LibreOffice.

Windows setup looks for `../SHK/shk.ahk` and inserts one include pointing to this
folder. Set `SHK_SCRIPT` to use another SHK location. Reload SHK afterward. On a
machine without SHK, use `windows/vim-standalone.ahk` with AutoHotkey v1; do not
run it alongside SHK. Normal Windows LibreOffice associations continue to work.

Linux setup applies the profile; start xremap separately after configuring its
required desktop integration/device access. Its application filter must identify
LibreOffice correctly. Flatpak/custom installations must supply the actual
`--profile` directory and matching `LIBREOFFICE_UNOPKG`; the native default is
`${XDG_CONFIG_HOME:-~/.config}/libreoffice/4/user`.

## Sync through GitHub

The checkout is the shared source; each OS keeps its own native runtime profile.
Do not point multiple OSes at one live profile. Exclude `.local/`, `.git/`,
`portable-profile/`, locks and caches from cloud-folder synchronization.
Git already ignores the private runtime and backup directories.

On the computer where you changed a managed preference:

```sh
# Quit LibreOffice first; Windows uses `py -3` instead of `python3`.
python3 scripts/lo-settings.py export
python3 scripts/update-manifest.py
git diff
# Review, then commit and push your intended changes.
```

On another computer:

```sh
git pull --ff-only
bash setup.sh
# Windows: powershell -ExecutionPolicy Bypass -File .\Setup.ps1
```

Export captures only the managed preferences already in the shared XML. New
private settings, identities, recent documents, recovery sessions, credentials,
local paths and hardware identifiers are never automatically imported. Custom
fonts, Zotero and dictionaries/extensions must be installed on each OS; existing
local installations, templates, dictionaries and documents are preserved.

## Useful commands

```sh
python3 scripts/lo-settings.py doctor
python3 scripts/lo-settings.py apply
python3 scripts/lo-settings.py open "/path with spaces/document.docx"
python3 scripts/lo-settings.py repair-macos
python3 scripts/install-vim-macos.py --remove
python3 scripts/lo-settings.py uninstall-macos-opener
python3 scripts/lo-settings.py rollback .local/backups/<backup-name>
```

`apply` merges shared settings into the local registry, backs up the previous
file, updates the UI extension and installs the essential toolbar in the four
main modules. `--replace` is an explicit full registry replacement; normal setup
never uses it. `--profile /path/to/4/user` precedes the subcommand when needed.
The original `restore.sh` and `restore.ps1` now use this safe merge by default.

`rollback` restores the saved registry file. The UI extension and toolbar files
are separate assets; for a complete return to the prior UI use the private
full-profile archive, with LibreOffice closed. Local backups are in `.local/backups`.
The full archive made during the 2026-11-05 work predates the side-layout changes.

If an opening problem recurs, double-click `Repair LibreOffice.command` or run
Doctor from the VS Code tasks. The repair reinstalls the opener/associations; it
does not kill the application or discard unsaved work. A busy modal dialog or
an internal LibreOffice hang still needs to be resolved in LibreOffice itself.

The old Windows `start-portable.ps1` entry point now opens the **native** profile
without resetting it. Its old `portable-profile` folder is preserved. Legacy
Windows no-splash scripts remain optional; they are not needed for profile sync.

## Source and verification

- `settings/`: shared XML, common essentials toolbar, app-specific tools in
  `module-tools.json`, and shortcut descriptions.
- `extension/clean-ui/`: native configuration extension source, version 2.1.0.
  The historical extension ID is retained so it upgrades the existing policy.
- `macos/`, `windows/`, `linux/`: adapters within this one repository.
- `scripts/`: one cross-platform settings engine and host-specific installers.
- `.local/`: ignored machine data, builds, verification fixtures and backups.

```sh
python3 -m unittest discover -s tests -v
bash scripts/build-policy.sh
python3 scripts/update-manifest.py
```

See [VALIDATION.md](VALIDATION.md) for what was actually checked. Windows and
Linux desktop behavior must be verified on those machines; this Mac cannot
certify their input hooks, desktop detection or installed fonts/extensions.

Implementation references: [LibreOffice command-line parameters](https://help.libreoffice.org/latest/en-US/text/shared/guide/start_parameters.html),
[native keyboard customization](https://help.libreoffice.org/latest/en-US/text/shared/01/06140200.html),
[Writer's native status bar](https://help.libreoffice.org/latest/en-US/text/swriter/main0208.html),
and [Styles panel previews](https://help.libreoffice.org/latest/en-US/text/shared/01/styles.html).
