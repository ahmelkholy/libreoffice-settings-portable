; AutoHotkey v1 companion included by SHK. Do not run alongside another copy.
; Only unused SHK CapsLock chords are added. Existing HJKL/W/E remain in SHK.
; Ctrl+Alt+F13 repeats search; Ctrl+Alt+F14 opens the native search dialog.
#If (WinActive("ahk_exe soffice.bin") || WinActive("ahk_exe soffice.exe")) && !GetKeyState("Ctrl", "P") && !GetKeyState("Alt", "P") && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P")
    CapsLock & b::Send, % GetKeyState("Shift", "P") ? "^+{Left}" : "^{Left}"
    CapsLock & f::Send, ^!{F14}
    CapsLock & g::Send, % GetKeyState("Shift", "P") ? "^{End}" : "^{Home}"
    CapsLock & n::Send, ^!{F13}
#If
