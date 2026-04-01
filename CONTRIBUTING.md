# Contributing

Thanks for your interest in contributing!

## Reporting Bugs

Use the [Bug Report](https://github.com/MeninoNias/claude-code-notification/issues/new?template=bug_report.md) template. Include your Windows version, PowerShell version, and terminal app.

## Suggesting Features

Use the [Feature Request](https://github.com/MeninoNias/claude-code-notification/issues/new?template=feature_request.md) template.

## Development Setup

```powershell
git clone https://github.com/MeninoNias/claude-code-notification.git
cd claude-code-notification
.\install.ps1
```

To reinstall after changes:

```powershell
.\install.ps1 -Force
```

## Pull Requests

1. Fork the repo and create a branch from `master`
2. Make your changes
3. Test on Windows (at least one version)
4. Ensure scripts parse correctly:
   ```powershell
   Get-ChildItem -Filter *.ps1 -Recurse | ForEach-Object {
       $t = $null; $e = $null
       [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$t, [ref]$e)
       if ($e) { Write-Host "FAIL: $_"; $e } else { Write-Host "OK: $($_.Name)" }
   }
   ```
5. Open a PR targeting `master`

## Code Style

- Use `$ErrorActionPreference = 'Stop'` in scripts that should fail fast
- Include `#Requires -Version 5.1` where applicable
- Maintain compatibility with both PowerShell 5.1 and 7+
- Keep scripts self-contained (no external dependencies beyond BurntToast)
