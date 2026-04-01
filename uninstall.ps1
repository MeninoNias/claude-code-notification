#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstalls Claude Code toast notifications.
.DESCRIPTION
    - Removes notification hooks from settings.json
    - Removes protocol handler registry entry
    - Removes Start Menu shortcut
    - Removes installed scripts from ~/.claude/
#>

[CmdletBinding()]
param(
    [switch]$RemoveBurntToast
)

$ErrorActionPreference = 'Stop'
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

Write-Host "`n=== Claude Code Notification - Uninstaller ===" -ForegroundColor Cyan

# --- Remove hooks from settings.json ---
Write-Host "`n[1/4] Removing hooks from settings.json..." -ForegroundColor Yellow
if (Test-Path $settingsPath) {
    $backupPath = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $settingsPath $backupPath
    Write-Host "  Backup: $backupPath" -ForegroundColor Gray

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    if ($settings.PSObject.Properties['hooks']) {
        $hookTypes = @('Stop', 'Notification', 'SubagentStop')
        foreach ($hookType in $hookTypes) {
            if ($settings.hooks.PSObject.Properties[$hookType]) {
                $filtered = @($settings.hooks.$hookType | Where-Object {
                    $hasOurHook = $false
                    foreach ($h in $_.hooks) {
                        if ($h.command -match 'show-toast\.ps1') { $hasOurHook = $true }
                    }
                    -not $hasOurHook
                })

                if ($filtered.Count -eq 0) {
                    $settings.hooks.PSObject.Properties.Remove($hookType)
                    Write-Host "  $hookType hook - removed." -ForegroundColor Green
                } else {
                    $settings.hooks.$hookType = $filtered
                    Write-Host "  $hookType hook - our entry removed (other hooks preserved)." -ForegroundColor Green
                }
            }
        }

        # Remove hooks key if empty
        $remainingHooks = $settings.hooks.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
        if (-not $remainingHooks) {
            $settings.PSObject.Properties.Remove('hooks')
        }

        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        Write-Host "  settings.json updated." -ForegroundColor Green
    } else {
        Write-Host "  No hooks found, skipping." -ForegroundColor Gray
    }
} else {
    Write-Host "  settings.json not found, skipping." -ForegroundColor Gray
}

# --- Remove protocol handler ---
Write-Host "`n[2/4] Removing claude-focus:// protocol..." -ForegroundColor Yellow
$regBase = 'HKCU:\Software\Classes\claude-focus'
if (Test-Path $regBase) {
    Remove-Item -Path $regBase -Recurse -Force
    Write-Host "  Protocol removed." -ForegroundColor Green
} else {
    Write-Host "  Protocol not found, skipping." -ForegroundColor Gray
}

# --- Remove Start Menu shortcut ---
Write-Host "`n[3/4] Removing Start Menu shortcut..." -ForegroundColor Yellow
$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Code.lnk'
if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "  Shortcut removed." -ForegroundColor Green
} else {
    Write-Host "  Shortcut not found, skipping." -ForegroundColor Gray
}

# --- Remove scripts ---
Write-Host "`n[4/4] Removing scripts from ~/.claude/..." -ForegroundColor Yellow
$filesToRemove = @('show-toast.ps1', 'claude-focus.ps1', 'claude-focus.vbs')
foreach ($file in $filesToRemove) {
    $path = Join-Path $claudeDir $file
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  $file - removed." -ForegroundColor Green
    } else {
        Write-Host "  $file - not found, skipping." -ForegroundColor Gray
    }
}
# Note: claude-icon.png is kept as it may be used by other tools

# --- Optionally remove BurntToast ---
if ($RemoveBurntToast) {
    Write-Host "`nRemoving BurntToast module..." -ForegroundColor Yellow
    Uninstall-Module -Name BurntToast -Force -ErrorAction SilentlyContinue
    Write-Host "  BurntToast removed." -ForegroundColor Green
}

# --- Done ---
Write-Host "`n=== Uninstall complete! ===" -ForegroundColor Cyan
Write-Host @"

  Removed:
    - Hooks from settings.json (backup created)
    - claude-focus:// protocol handler
    - Start Menu shortcut
    - Notification scripts

  Note: claude-icon.png was kept. Delete manually if not needed.
  To also remove BurntToast: .\uninstall.ps1 -RemoveBurntToast

"@ -ForegroundColor White
