Option Explicit

Dim fso, shell, scriptDir, launcher, powershell, command, arg
Dim printCommand

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcher = fso.BuildPath(scriptDir, "start-portable.ps1")
powershell = shell.ExpandEnvironmentStrings( _
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")

If Not fso.FileExists(launcher) Then
    Fail "Portable PowerShell launcher not found: " & launcher
End If
If Not fso.FileExists(powershell) Then
    Fail "Windows PowerShell was not found: " & powershell
End If

command = Quote(powershell) & _
    " -NoProfile -ExecutionPolicy Bypass -File " & Quote(launcher)

printCommand = False
For Each arg In WScript.Arguments
    If LCase(CStr(arg)) = "--print-command" Then
        printCommand = True
    Else
        command = command & " " & Quote(CStr(arg))
    End If
Next

If printCommand Then
    WScript.Echo command
    WScript.Quit 0
End If

' Window style 0 keeps file-association launches free of a console window.
shell.Run command, 0, False

Function Quote(ByVal value)
    Quote = """" & Replace(value, """", "\""") & """"
End Function

Sub Fail(ByVal message)
    WScript.Echo message
    WScript.Quit 1
End Sub
