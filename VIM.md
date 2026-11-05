# Held navigation for LibreOffice

Hold CapsLock to navigate; release it to resume ordinary typing. Tap CapsLock
for Escape. This extends SHK's existing muscle memory rather than running a Vim
emulator inside Writer, Calc or Impress. No mode can remain accidentally active.

| While holding CapsLock | Action |
| --- | --- |
| H / J / K / L | Left / down / up / right |
| Shift + H/J/K/L | Extend the native selection |
| W / E | Previous / next word, preserving SHK's established mapping |
| B | Previous word (additional Vim-style alias) |
| Shift + B | Select previous word |
| G / Shift + G | Beginning / end of document or native data range |
| F | Native Find and Replace dialog; use its Find Next/Previous controls |
| N | Repeat the last native search, using its current direction/options |
| Comma / M | Page up / down |
| Period / Slash | Existing SHK line-start / line-end route |

Shift+N repeats the same search, consistent with the adapter's explicit mapping.
It is **not** Vim's inverse-direction N. The existing SHK deletion, clipboard,
window and application shortcuts retain their meanings; for example CapsLock+U
is still Delete, not Vim Undo. Normal Ctrl/Command+Z remains Undo.

Writer moves through text. Calc moves/selects cells unless editing a cell.
Impress follows LibreOffice's native slide, object or text-editing focus; enter
text editing before using text motions. The new bindings are scoped to
LibreOffice, so VS Code, Neovim, terminals and other applications keep their keys.

The native search dialog works with the horizontal Find toolbar hidden. Ctrl+Alt+F13 (Command+Option+F13 on macOS)
routes to `.uno:RepeatSearch` and the corresponding F14 chord to `.uno:SearchDialog`; the platform adapters
produce those keys, so no physical F13/F14 keys are needed. These additions leave
the existing Office-style shortcuts in place.

## macOS

`Setup.command` installs `macos/vim-navigation.json` into the selected SHK
Karabiner profile, immediately before its general navigation rules. On a fresh
Karabiner profile it supplies a self-contained LibreOffice-only hold layer instead. Language
switching, the CapsLock activation rule and physical modifier mappings remain
in their original order. A private backup is made before the edit.

Remove just this application's additions with:

```sh
python3 scripts/install-vim-macos.py --remove
```

## Windows

`windows/vim-navigation.ahk` is the AutoHotkey **v1** companion. Setup integrates
it into SHK's application-hotkey section. A manual include, inside the hotkey
section and before other app-specific hotkeys, is:

```ahk
#Include *i C:\path\to\libreoffice-settings-portable\windows\vim-navigation.ahk
```

The shared SHK file uses the sibling-folder form. Reload SHK with CapsLock+F5.
Without SHK, run the included `windows/vim-standalone.ahk`; use only one keyboard
adapter at a time. The standalone adapter supplies the navigation keys too.

## Linux

The optional `linux/vim-navigation.yml` uses xremap's application-specific
multipurpose keys and a virtual F24 modifier. Only LibreOffice's CapsLock is
remapped. Choose a build/desktop integration that supports application detection,
then run:

```sh
xremap linux/vim-navigation.yml
```

Verify the active app class with `xremap --list-windows` or the desktop-specific
method in the [xremap documentation](https://github.com/xremap/xremap#application).
Adjust the LibreOffice application regex if your package uses a different class.
Stop that xremap instance to disable this optional layer. Desktop permissions,
Wayland integration and physical key behavior need testing on the Linux host.

Do not combine this file with another CapsLock remapper without reconciling the
existing mapping. Source details: [virtual modifiers](https://github.com/xremap/xremap/blob/master/doc/reference_config_options.md#virtual_modifiers).
