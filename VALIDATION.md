# Verification — 2026-11-05

Host: macOS 26.6.2, Apple Silicon; LibreOffice 26.8.2.2.

## Completed here

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

## Boundaries

The original intermittent failure was not consistently reproducible. The installed
adapter provides a direct file-opening path; it cannot cure an internal LibreOffice
hang or automatically answer an unsaved-document dialog. It never force-quits.

macOS retained its original LibreOffice handler for POT/POTX/POTM, OTT, ODS/OTS
and ODP during setup. Those types retain normal native opening. The adapter is
registered for them and can be selected through Finder's Open with → Change All.
DOCX, XLSX, PPTX and the other reported successful associations use the adapter.

Windows and Linux machines were not available. Their native profile paths,
shared settings and adapter sources are prepared; Windows AutoHotkey/PowerShell
execution and Linux xremap/Wayland behavior still require host verification.
The included GitHub Actions matrix runs the configuration tests on all three
OSes after publication; it does not emulate their graphical desktop sessions.
Physical CapsLock chords were checked by the routing model, not hardware typing.

## Check on the next computer

1. Save and quit LibreOffice; run that OS's setup entry point.
2. Open a DOCX, XLSX and PPTX. Close their windows and open another file without
   restarting the suite.
3. Confirm the compact left toolbar and the right contextual sidebar. Confirm
   normal typing, save, undo, copy/paste and document-specific editing.
4. Hold CapsLock for H/J/K/L; release and type ordinary letters. Try CapsLock+F,
   then search for a word and CapsLock+N. Check CapsLock+G and Shift+G.
5. Verify VS Code/terminal keys and language switching remain as expected.

Backups and disposable verification documents are ignored under `.local/`;
none are part of the shared repository.
