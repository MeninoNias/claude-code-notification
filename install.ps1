#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Claude Code toast notifications with click-to-focus support on Windows.
.DESCRIPTION
    - Installs BurntToast module (if missing)
    - Copies notification scripts to ~/.claude/
    - Registers claude-focus:// protocol handler
    - Creates Start Menu shortcut for toast branding
    - Merges notification hooks into Claude Code settings.json
.NOTES
    Safe to run multiple times (idempotent).
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

Write-Host "`n=== Claude Code Notification - Installer ===" -ForegroundColor Cyan

# --- Pre-flight checks ---
if ($env:OS -ne 'Windows_NT') {
    Write-Host "ERROR: This tool is Windows-only." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $claudeDir)) {
    Write-Host "ERROR: ~/.claude/ not found. Is Claude Code installed?" -ForegroundColor Red
    exit 1
}

# --- Install BurntToast if missing ---
Write-Host "`n[1/5] Checking BurntToast module..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Write-Host "  Installing NuGet provider (if needed)..." -ForegroundColor Gray
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Host "  Installing BurntToast..." -ForegroundColor Gray
    Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber
    Write-Host "  BurntToast installed." -ForegroundColor Green
} else {
    Write-Host "  BurntToast already installed." -ForegroundColor Green
}

# --- Copy scripts and icon ---
Write-Host "`n[2/5] Copying files to ~/.claude/..." -ForegroundColor Yellow
$filesToCopy = @(
    @{ Src = 'src\show-toast.ps1';    Dst = 'show-toast.ps1' }
    @{ Src = 'src\claude-focus.ps1';  Dst = 'claude-focus.ps1' }
    @{ Src = 'src\claude-focus.vbs';  Dst = 'claude-focus.vbs' }
    @{ Src = 'assets\claude-icon.png'; Dst = 'claude-icon.png' }
)

foreach ($file in $filesToCopy) {
    $src = Join-Path $scriptDir $file.Src
    $dst = Join-Path $claudeDir $file.Dst
    if ((Test-Path $dst) -and -not $Force) {
        $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
        if ($srcHash -eq $dstHash) {
            Write-Host "  $($file.Dst) - unchanged, skipping." -ForegroundColor Gray
            continue
        }
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  $($file.Dst) - copied." -ForegroundColor Green
}

# --- Register protocol handler ---
Write-Host "`n[3/5] Registering claude-focus:// protocol..." -ForegroundColor Yellow
$regBase = 'HKCU:\Software\Classes\claude-focus'
$vbsPath = Join-Path $claudeDir 'claude-focus.vbs'

New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name '(Default)' -Value 'URL:Claude Focus Protocol'
New-ItemProperty -Path $regBase -Name 'URL Protocol' -Value '' -Force | Out-Null
New-Item -Path "$regBase\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$regBase\shell\open\command" -Name '(Default)' -Value "wscript.exe `"$vbsPath`" `"%1`""
Write-Host "  Protocol registered." -ForegroundColor Green

# --- Create Start Menu shortcut with AUMID ---
Write-Host "`n[4/5] Creating Start Menu shortcut..." -ForegroundColor Yellow
$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Code.lnk'

Import-Module BurntToast
if (Get-Command New-BTShortcut -ErrorAction SilentlyContinue) {
    $iconPath = Join-Path $claudeDir 'claude-icon.png'
    New-BTShortcut -AppId 'Claude.Code' -ShortcutPath $shortcutPath -DisplayName 'Claude Code' -IconPath $iconPath
    Write-Host "  Shortcut created via BurntToast." -ForegroundColor Green
} else {
    # Fallback: create shortcut manually
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($shortcutPath)
    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshPath) { $pwshPath = (Get-Command powershell).Source }
    $lnk.TargetPath = $pwshPath
    $lnk.Description = 'Claude Code Notifications'
    $lnk.Save()
    Write-Host "  Shortcut created (manual fallback)." -ForegroundColor Green
}

# --- Merge hooks into settings.json ---
Write-Host "`n[5/5] Configuring Claude Code hooks..." -ForegroundColor Yellow

$hooksJsonPath = Join-Path $scriptDir 'config\hooks.json'
$newHooks = Get-Content $hooksJsonPath -Raw | ConvertFrom-Json

if (Test-Path $settingsPath) {
    # Backup existing settings
    $backupPath = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $settingsPath $backupPath
    Write-Host "  Backup: $backupPath" -ForegroundColor Gray

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

# Ensure hooks property exists
if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
}

$hookTypes = @('Stop', 'Notification', 'SubagentStop')
foreach ($hookType in $hookTypes) {
    $newHookEntries = $newHooks.$hookType

    if (-not $settings.hooks.PSObject.Properties[$hookType]) {
        # Hook type doesn't exist - add it
        $settings.hooks | Add-Member -NotePropertyName $hookType -NotePropertyValue $newHookEntries
        Write-Host "  $hookType hook - added." -ForegroundColor Green
    } else {
        # Check if our hook is already installed (look for show-toast.ps1 in commands)
        $existing = $settings.hooks.$hookType
        $alreadyInstalled = $false
        foreach ($entry in $existing) {
            foreach ($hook in $entry.hooks) {
                if ($hook.command -match 'show-toast\.ps1') {
                    $alreadyInstalled = $true
                    break
                }
            }
        }

        if ($alreadyInstalled -and -not $Force) {
            Write-Host "  $hookType hook - already installed, skipping." -ForegroundColor Gray
        } else {
            if ($alreadyInstalled) {
                # Remove old entry first when using -Force
                $settings.hooks.$hookType = @($existing | Where-Object {
                    $dominated = $false
                    foreach ($h in $_.hooks) { if ($h.command -match 'show-toast\.ps1') { $dominated = $true } }
                    -not $dominated
                })
            }
            # Append new hook entries
            $settings.hooks.$hookType = @($settings.hooks.$hookType) + @($newHookEntries)
            Write-Host "  $hookType hook - configured." -ForegroundColor Green
        }
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "  settings.json updated." -ForegroundColor Green

# --- Done ---
Write-Host "`n=== Installation complete! ===" -ForegroundColor Cyan
Write-Host @"

  What was installed:
    - Scripts:  ~/.claude/show-toast.ps1, claude-focus.ps1, claude-focus.vbs
    - Icon:     ~/.claude/claude-icon.png
    - Protocol: claude-focus:// (HKCU registry)
    - Shortcut: Start Menu/Claude Code.lnk
    - Hooks:    Stop, Notification, SubagentStop

  Click any Claude Code notification to bring the terminal to focus.
  Run uninstall.ps1 to remove everything.

"@ -ForegroundColor White
