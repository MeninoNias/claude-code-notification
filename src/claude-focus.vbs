Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & objShell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.claude\claude-focus.ps1"" """ & WScript.Arguments(0) & """", 0, False
