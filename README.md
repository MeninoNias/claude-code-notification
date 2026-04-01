# Claude Code Notification

Windows toast notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with **click-to-focus** support. Get notified when Claude finishes a task, needs permission, or completes a subagent — and click the notification to instantly bring the terminal back to focus.

## Features

- **Stop** notification when Claude finishes a task (shows summary of response)
- **Permission** notification when Claude needs user approval
- **Subagent** notification when a background agent completes
- **Click-to-focus**: click any notification to bring the terminal window to the foreground
- **Zero background processes** — uses Windows protocol activation, not persistent listeners
- Works with **Windows Terminal**, **VS Code**, and any terminal with a window handle
- Supports **PowerShell 5.1** and **PowerShell 7+**

## Prerequisites

- Windows 10/11
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- PowerShell 5.1+ (included with Windows)

## Install

```powershell
git clone https://github.com/MeninoNias/claude-code-notification.git
cd claude-code-notification
.\install.ps1
```

The installer will:
1. Install [BurntToast](https://github.com/Windos/BurntToast) module (if missing)
2. Copy notification scripts to `~/.claude/`
3. Register the `claude-focus://` protocol handler
4. Create a Start Menu shortcut for toast branding
5. Merge notification hooks into Claude Code `settings.json`

Safe to run multiple times. Use `.\install.ps1 -Force` to overwrite existing files.

## Uninstall

```powershell
.\uninstall.ps1
```

To also remove the BurntToast module:

```powershell
.\uninstall.ps1 -RemoveBurntToast
```

## How It Works

### Architecture

```
Claude Code hook (Stop/Notification/SubagentStop)
  |
  v
show-toast.ps1
  |-- Walks process tree to find terminal window (HWND)
  |-- Builds toast via BurntToast with protocol activation
  |-- Shows notification with launch URI: claude-focus://{HWND}
  v
[User clicks notification]
  |
  v
Windows protocol handler -> claude-focus.vbs -> claude-focus.ps1
  |-- Parses HWND from URI
  |-- Uses Win32 API to bring window to foreground:
  |     1. keybd_event (Alt trick for activation rights)
  |     2. AttachThreadInput + SetForegroundWindow + BringWindowToTop
  |     3. SetWindowPos TOPMOST flash
  |     4. WScript.Shell AppActivate fallback
  v
Terminal window is focused
```

### Why a VBS wrapper?

When Windows triggers a protocol handler, it launches the registered command. Using `powershell.exe` directly would briefly flash a console window. The VBS wrapper (`WScript.Shell.Run` with window style `0`) launches PowerShell completely hidden.

### PowerShell 5.1 vs 7+

| Feature | PS 5.1 | PS 7+ (pwsh) |
|---|---|---|
| Toast submission | WinRT API directly | BurntToast Submit-BTNotification |
| Custom AppId | Yes ("Claude Code" header) | Falls back to BurntToast AppId |
| Click-to-focus | Yes | Yes |

## File Structure

```
~/.claude/
  show-toast.ps1      # Main notification script
  claude-focus.ps1     # Click-to-focus handler (Win32 API)
  claude-focus.vbs     # Hidden launcher for focus handler
  claude-icon.png      # Notification icon
  settings.json        # Claude Code settings (hooks merged here)
```

## Troubleshooting

**Notifications don't appear**
- Check BurntToast is installed: `Get-Module -ListAvailable BurntToast`
- Check Windows notification settings: Settings > System > Notifications
- Ensure Focus Assist is not blocking notifications

**Click doesn't bring window to focus**
- The HWND is captured when the notification is created. If the terminal was closed and reopened, the HWND is stale
- Some terminal multiplexers may not expose a MainWindowHandle

**"PowerShell 7" shows as app name instead of "Claude Code"**
- This happens when running in PS 7+ where WinRT types aren't available directly
- The click-to-focus still works, only the branding differs

## License

MIT
