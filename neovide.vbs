' Hidden launcher for Neovide (Windows).
'
' Why this file exists:
'   A .cmd always allocates a console window, so double-clicking neovide.cmd
'   leaves a black window on screen for as long as Neovide runs. There is no
'   way to suppress that from inside the batch file itself: "start /min" only
'   minimizes it, and it stays in the taskbar.
'   WScript.Shell.Run with window style 0 starts the .cmd with SW_HIDE, so no
'   console is ever created. The environment the .cmd sets (XDG_*, TMPDIR,
'   PATH) is inherited through this process chain, so behaviour is identical.
'
' Use neovide.cmd instead when you want to read errors in a terminal.
'
' IMPORTANT: keep this file ASCII-only, same reason as nvim.cmd -- WSH reads
' .vbs using the system OEM code page and mis-decodes non-ASCII bytes.

Option Explicit

Dim sh, fso, root, cmdline, args, i, rc

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Resolve the directory this script lives in, so the launcher keeps working
' after the package is moved elsewhere.
root = fso.GetParentFolderName(WScript.ScriptFullName)

' Forward any arguments (files dropped onto the icon, or passed by a shortcut)
' to neovide.cmd, which appends them to the nvim command line.
args = ""
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & Chr(34) & WScript.Arguments(i) & Chr(34)
Next

cmdline = Chr(34) & root & "\neovide.cmd" & Chr(34) & args

' 0 = hidden window. True = wait for it to finish, so a startup failure can be
' surfaced: without a console, a failed launch would otherwise be completely
' silent and look like "double-click does nothing".
rc = sh.Run(cmdline, 0, True)

If rc <> 0 Then
    MsgBox "Neovide failed to start (exit code " & rc & ")." & vbCrLf & vbCrLf & _
           "Run neovide.cmd in a terminal to see the actual error.", _
           16, "packednvim"
End If
