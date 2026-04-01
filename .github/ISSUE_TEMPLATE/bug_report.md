---
name: Bug Report
about: Report a problem with notifications or click-to-focus
title: "[BUG] "
labels: bug
assignees: MeninoNias
---

## Describe the bug

A clear description of what the bug is.

## Environment

- **Windows version**: (e.g., Windows 11 24H2)
- **PowerShell version**: (run `$PSVersionTable.PSVersion`)
- **Terminal**: (Windows Terminal / VS Code / cmd / other)
- **BurntToast version**: (run `(Get-Module BurntToast -ListAvailable).Version`)
- **Claude Code version**: (run `claude --version`)

## Steps to reproduce

1. ...
2. ...
3. ...

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened.

## Screenshots

If applicable, add screenshots of the notification or error.

## Logs

If relevant, run the hook manually and share output:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\show-toast.ps1" -Title "Test" -Message "Test" -Icon "$env:USERPROFILE\.claude\claude-icon.png"
```
