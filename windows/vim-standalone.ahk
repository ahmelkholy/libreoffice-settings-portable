; AutoHotkey v1 fallback for a Windows machine WITHOUT SHK running.
#NoEnv
#SingleInstance Force
SendMode Input
#If WinActive("ahk_exe soffice.bin") || WinActive("ahk_exe soffice.exe")
CapsLock::Send, {Esc}
CapsLock & h::Send, % GetKeyState("Shift", "P") ? "+{Left}" : "{Left}"
CapsLock & j::Send, % GetKeyState("Shift", "P") ? "+{Down}" : "{Down}"
CapsLock & k::Send, % GetKeyState("Shift", "P") ? "+{Up}" : "{Up}"
CapsLock & l::Send, % GetKeyState("Shift", "P") ? "+{Right}" : "{Right}"
CapsLock & w::Send, % GetKeyState("Shift", "P") ? "^+{Left}" : "^{Left}"
CapsLock & e::Send, % GetKeyState("Shift", "P") ? "^+{Right}" : "^{Right}"
CapsLock & .::Send, {Home}
CapsLock & /::Send, {End}
CapsLock & ,::Send, {PgUp}
CapsLock & m::Send, {PgDn}
#If
#Include %A_ScriptDir%\vim-navigation.ahk
