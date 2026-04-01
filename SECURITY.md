# Security

## What This Project Does

This project modifies your system in the following ways:

- **Registry (HKCU)**: Registers a `claude-focus://` protocol handler under `HKCU:\Software\Classes\claude-focus`
- **Start Menu**: Creates a shortcut at `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk`
- **User profile**: Copies scripts to `%USERPROFILE%\.claude\`
- **Claude Code settings**: Merges hook entries into `%USERPROFILE%\.claude\settings.json`

All changes are user-level only (no admin required, no system-wide modifications).

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## Reporting a Vulnerability

If you discover a security issue, please use [GitHub's private vulnerability reporting](https://github.com/MeninoNias/claude-code-notification/security/advisories/new) instead of opening a public issue.

You can expect an initial response within 48 hours.
