# CLAUDE.md

Project guidelines for Claude Code when working on this repository.

## Project Overview

Windows toast notification system for Claude Code hooks with click-to-focus.
Users clone this repo and run `install.ps1` to set everything up.

## Tech Stack

- **PowerShell 5.1 / 7+** — all scripts must work on both versions
- **BurntToast** — PowerShell module for Windows toast notifications
- **Win32 API** (via P/Invoke) — for window focus management
- **VBScript** — wrapper to launch PowerShell hidden (no console flash)
- **Windows Registry (HKCU)** — protocol handler registration

## Architecture

```
Hook (Stop/Notification/SubagentStop)
  → show-toast.ps1 (finds HWND, builds toast with claude-focus:// protocol)
  → [user clicks]
  → Windows protocol handler
  → claude-focus.vbs (hidden launcher)
  → claude-focus.ps1 (Win32 focus via SetForegroundWindow + fallbacks)
```

## Key Files

| File | Purpose |
|---|---|
| `src/show-toast.ps1` | Main notification script. Walks process tree for HWND, builds BurntToast with protocol activation |
| `src/claude-focus.ps1` | Click handler. Parses HWND from `claude-focus://` URI, uses multiple Win32 methods to focus window |
| `src/claude-focus.vbs` | Invisible wrapper. Launches claude-focus.ps1 via `WScript.Shell.Run` with window style 0 |
| `config/hooks.json` | Hook definitions for Stop, Notification, SubagentStop. Merged into user's settings.json |
| `install.ps1` | Idempotent installer. Copies files, registers protocol, creates shortcut, merges hooks |
| `uninstall.ps1` | Reverses everything install.ps1 does. Backs up settings.json before modifying |

## Code Conventions

- Use `$ErrorActionPreference = 'Stop'` in scripts that should fail fast
- Include `#Requires -Version 5.1` for scripts requiring minimum PS version
- Pipe to `Out-Null` for Win32 API calls whose return value is unused
- Use `try/catch` with fallback paths for PS 5.1 vs PS 7+ differences
- WinRT type loading (`[Type, Assembly, ContentType = WindowsRuntime]`) only works in PS 5.1 — always wrap in inner try/catch

## PS 5.1 vs PS 7+ Compatibility

This is the most critical constraint. Key differences:

- **WinRT types**: Load natively in PS 5.1, fail in PS 7+. Always use inner try/catch with BurntToast fallback
- **ConvertFrom-Json**: Returns PSCustomObject in PS 5.1, supports `-AsHashtable` only in PS 7+. Use PSCustomObject for both
- **Get-Process .Parent**: Only available in PS 7+. Use `Get-CimInstance Win32_Process` for parent PID in both versions

## Install Script Rules

- **Idempotent**: running twice must not break anything
- **Non-destructive**: always backup settings.json before modifying
- **Merge, don't replace**: hooks are appended to existing arrays, other settings are preserved
- **Detection**: check for `show-toast.ps1` in hook command strings to detect if already installed

## Testing Changes

After modifying scripts, test with:

```powershell
# Reinstall from repo
.\install.ps1 -Force

# Manual toast test
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\show-toast.ps1" -Title "Test" -Message "Click me" -Icon "$env:USERPROFILE\.claude\claude-icon.png"

# Test click-to-focus: minimize terminal, click notification
```

## Release Process

1. Update `CHANGELOG.md` with new version entry
2. Commit changes
3. Tag: `git tag -a v1.x.x -m "v1.x.x - description"`
4. Push: `git push origin master --tags`
5. Release workflow auto-creates GitHub Release with zip bundle
