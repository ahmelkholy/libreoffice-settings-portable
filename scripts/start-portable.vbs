Option Explicit

Dim fso, shell, scriptDir, repo, profileRoot, userDir, source, target
Dim soffice, profileUri, command, arg, printCommand

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
repo = fso.GetParentFolderName(scriptDir)
profileRoot = fso.BuildPath(repo, "portable-profile")
userDir = fso.BuildPath(profileRoot, "user")
source = fso.BuildPath(repo, "settings\registrymodifications.portable.xcu")
target = fso.BuildPath(userDir, "registrymodifications.xcu")

InitializePortableProfile userDir, source, target

soffice = GetLibreOfficeProgram()
profileUri = PathToUri(profileRoot)
command = Quote(soffice) & _
    " " & Quote("-env:UserInstallation=" & profileUri) & _
    " --nologo --nolockcheck --nofirststartwizard"

printCommand = False
For Each arg In WScript.Arguments
    If LCase(CStr(arg)) = "--print-command" Then
        printCommand = True
    Else
        command = command & " " & Quote(ConvertPathArgument(CStr(arg)))
    End If
Next

If printCommand Then
    WScript.Echo command
    WScript.Quit 0
End If

shell.Run command, 1, False

Sub InitializePortableProfile(ByVal userDirPath, ByVal sourcePath, ByVal targetPath)
    If Not fso.FileExists(sourcePath) Then
        Fail "Portable settings file not found: " & sourcePath
    End If

    CreateFolderRecursive userDirPath

    If Not fso.FileExists(targetPath) Then
        fso.CopyFile sourcePath, targetPath, True
    End If
End Sub

Sub CreateFolderRecursive(ByVal folderPath)
    Dim parentPath

    If fso.FolderExists(folderPath) Then
        Exit Sub
    End If

    parentPath = fso.GetParentFolderName(folderPath)
    If Len(parentPath) > 0 And Not fso.FolderExists(parentPath) Then
        CreateFolderRecursive parentPath
    End If

    fso.CreateFolder folderPath
End Sub

Function GetLibreOfficeProgram()
    Dim candidate

    candidate = shell.ExpandEnvironmentStrings("%LIBREOFFICE_PROGRAM%")
    If Len(candidate) > 0 And Left(candidate, 1) <> "%" Then
        If fso.FileExists(candidate) Then
            GetLibreOfficeProgram = candidate
            Exit Function
        End If
    End If

    candidate = shell.ExpandEnvironmentStrings("%ProgramFiles%") & "\LibreOffice\program\soffice.exe"
    If fso.FileExists(candidate) Then
        GetLibreOfficeProgram = candidate
        Exit Function
    End If

    candidate = shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\LibreOffice\program\soffice.exe"
    If fso.FileExists(candidate) Then
        GetLibreOfficeProgram = candidate
        Exit Function
    End If

    Fail "LibreOffice soffice.exe was not found. Install LibreOffice or set LIBREOFFICE_PROGRAM."
End Function

Function ConvertPathArgument(ByVal value)
    If Len(value) = 0 Then
        ConvertPathArgument = value
        Exit Function
    End If

    If fso.FileExists(value) Or fso.FolderExists(value) Then
        ConvertPathArgument = PathToUri(value)
    Else
        ConvertPathArgument = value
    End If
End Function

Function PathToUri(ByVal path)
    Dim absolutePath, uriPath

    absolutePath = fso.GetAbsolutePathName(path)
    uriPath = Replace(absolutePath, "\", "/")
    uriPath = EscapeUriPath(uriPath)

    If Left(uriPath, 2) = "//" Then
        PathToUri = "file:" & uriPath
    Else
        PathToUri = "file:///" & uriPath
    End If
End Function

Function EscapeUriPath(ByVal value)
    value = Replace(value, "%", "%25")
    value = Replace(value, "#", "%23")
    value = Replace(value, "?", "%3F")
    value = Replace(value, " ", "%20")
    EscapeUriPath = value
End Function

Function Quote(ByVal value)
    Quote = """" & Replace(value, """", "\""") & """"
End Function

Sub Fail(ByVal message)
    WScript.Echo message
    WScript.Quit 1
End Sub
