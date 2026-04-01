# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-04-01

### Added
- Toast notifications for Claude Code Stop, Notification, and SubagentStop hooks
- Click-to-focus: clicking a notification brings the terminal to foreground
- `claude-focus://` protocol handler with Win32 API focus methods
- VBS wrapper for silent protocol handler execution
- Support for PowerShell 5.1 and PowerShell 7+
- Custom "Claude Code" app identity for toast branding (PS 5.1)
- BurntToast auto-install during setup
- Idempotent installer with `-Force` flag for upgrades
- Uninstaller with optional BurntToast removal (`-RemoveBurntToast`)
- Settings.json merge preserving existing user configuration
- GitHub issue and PR templates

[1.0.0]: https://github.com/MeninoNias/claude-code-notification/releases/tag/v1.0.0
