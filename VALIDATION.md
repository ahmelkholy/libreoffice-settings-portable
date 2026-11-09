# Verification — latest layout update 2026-11-09

Host: macOS 26.6.2, Apple Silicon; LibreOffice 26.8.2.2.

## 2026-11-09: style-list contrast in the dark theme

- Added `/org.openoffice.Office.Common/StylesAndFormatting/Preview=false` to
  the shared settings. This is the native **Show previews** switch, verified
  against the installed configuration schema and LibreOffice's Styles help.
  Plain style names use the UI theme instead of previewing document text colors.
- The local change targets only this preference, with a registry backup first.
  The dark-theme settings, document formatting, side toolbar definitions and
  keyboard configuration are preserved. The setting is shared across OSes.
- Verification of this change uses configuration readback; visual contrast
  cannot be certified while screen capture remains unavailable on this host.

## 2026-11-09: useful status bar and expanded left controls

- Restored the native status bar in Writer, Calc, Impress and Draw. Their native
  View menus each reported Status Bar, Sidebar and Essentials enabled during
  document-window checks. Native status definitions retain language in Writer,
  Calc and Impress, plus the usual document information and zoom controls.
- Expanded the single left toolbar from nine to 17 actions per app: 14 common
  actions, including Save As, Print, Clone Formatting, Spelling and Navigator,
  plus three useful commands for that document type. Writer gets Table, Image
  and Comment; Calc gets Sum, AutoFilter and Chart; Impress gets New Slide, Image
  and Start Slideshow; Draw gets Text Box, Image and Basic Shapes.
  All command IDs exist in the installed LibreOffice registry. The four installed
  toolbar files exactly match the shared common XML plus `module-tools.json`;
  their recorded docking area remains left (`2`). Horizontal toolbars stay hidden.
- All 20 Python tests passed, including packaged extension integrity, safe
  merging, keyboard isolation, correct app-specific tools and rejection of
  non-native toolbar commands before installation. The extension is version 2.1.0.
  VS Code settings/keybindings and Karabiner configuration retained their hashes.
- The previous repository state is recorded at
  `refs/backups/pre-statusbar-update-20261109`; the native apply operation saved
  the prior registry and toolbar files in the ignored local backups directory.
- Verification used native menu states, installed configuration and native
  command definitions. Screen capture was unavailable on this host, so this is
  not a screenshot-based assessment of every control at different window sizes.

## 2026-11-05: original setup verification

- Native DOCX, XLSX and PPTX fixtures were opened through the macOS default file
  association into one LibreOffice session. Their window titles and document
  locks were observed. Cold startup and opening additional documents passed.
- After closing every document window, another document opened in the **same
  process**, without quitting LibreOffice. The document lock and window appeared.
- A filename containing spaces, an apostrophe, Greek and Arabic text opened
  through the same adapter.
- Writer, Calc and Impress each showed the Essentials toolbar and Sidebar checked
  in their native View menus, with Status Bar unchecked. Live toolbar state
  recorded `Docked=true`, `DockingArea=2` (left), `Visible=true` in the four main
  modules. All nine toolbar command IDs exist in the installed native registry.
- The search bridge using Command+Option+F14 opened the native Find and Replace
  dialog in Writer. Ordinary F13/F14 were deliberately left unassigned to avoid
  macOS hardware-function conflicts.
- 17 Python tests cover safe merging, rejection while running, backups on failed
  extension installation, privacy filtering, path handling, side-layout assets,
  namespace preservation, shortcut scope and a fresh Mac keyboard profile.
- The OXT archive matches its source files, passes its ZIP integrity check, and
  contains no finalized configuration properties that lock the native controls.
- Karabiner's existing checks passed: 1,696 first-match/schema cases, 280 writing
  direction cases, language/input-source checks, and 14 window shortcut routes.
  Removing the one added LibreOffice group produces exactly the original parsed
  Karabiner configuration. VS Code settings and keybindings are byte-for-byte
  unchanged. Reinstalling the keyboard group is idempotent.
- Shell syntax, Python parsing, XML parsing, Linux YAML syntax (24 bindings), and
  Git whitespace checks passed. The GitHub remote was fetched; the starting
  checkout matched `origin/main`.
- [GitHub Actions run 42050183364](https://github.com/ahmelkholy/libreoffice-settings-portable/actions/runs/42050183364)
  passed all 17 configuration tests on macOS, Windows and Linux. The Windows
  PowerShell scripts parsed successfully, and the Swift opener compiled on macOS.
  The workflow also validates the standalone Windows keyboard adapter and its
  included companion with AutoHotkey v1's parse-only `/iLib` mode, using the
  checksum-pinned official 1.1.37.02 archive. See the
  [AutoHotkey command-line documentation](https://github.com/AutoHotkey/AutoHotkeyDocs/blob/v1/docs/Scripts.htm#cmd).

## Boundaries

The original intermittent failure was not consistently reproducible. The installed
adapter provides a direct file-opening path; it cannot cure an internal LibreOffice
hang or automatically answer an unsaved-document dialog. It never force-quits.

macOS retained its original LibreOffice handler for POT/POTX/POTM, OTT, ODS/OTS
and ODP during setup. Those types retain normal native opening. The adapter is
registered for them and can be selected through Finder's Open with → Change All.
DOCX, XLSX, PPTX and the other reported successful associations use the adapter.

Windows and Linux graphical desktop sessions were not available. Their native
profile paths and shared settings passed the hosted configuration tests; actual
AutoHotkey input, full SHK integration, Windows setup execution and Linux
xremap/Wayland behavior still require host verification. The GitHub Actions
matrix does not emulate those graphical desktop sessions.
Physical CapsLock chords were checked by the routing model, not hardware typing.

## Check on the next computer

1. Save and quit LibreOffice; run that OS's setup entry point.
2. Open a DOCX, XLSX and PPTX. Close their windows and open another file without
   restarting the suite.
3. Confirm the compact left toolbar, right contextual sidebar and bottom status
   bar. In Writer, click the language and word-count fields. Confirm normal
   typing, save, undo, copy/paste and document-specific editing.
4. Hold CapsLock for H/J/K/L; release and type ordinary letters. Try CapsLock+F,
   then search for a word and CapsLock+N. Check CapsLock+G and Shift+G.
5. Verify VS Code/terminal keys and language switching remain as expected.

Backups and disposable verification documents are ignored under `.local/`;
none are part of the shared repository.
