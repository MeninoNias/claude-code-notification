param(
    [string]$Title,
    [string]$Message,
    [string]$Icon,
    [long]$Hwnd = 0
)

$logFile = "$env:USERPROFILE\.claude\toast.log"
$logMax = 50KB
function Log($msg) {
    try {
        $line = "$(Get-Date -Format 'MM-dd HH:mm:ss') $msg"
        $line | Out-File -Append -FilePath $logFile -Encoding utf8
        if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt $logMax) {
            $lines = Get-Content $logFile -Tail 100
            $lines | Set-Content $logFile -Encoding utf8
        }
    } catch {}
}

# Known terminal process names and bad ancestors that mean "tree walk failed"
$terminalProcs = @('WindowsTerminal', 'conhost', 'mintty', 'ConEmu', 'ConEmu64', 'Code', 'wezterm-gui', 'alacritty', 'Hyper', 'Tabby')
$badProcs = @('explorer', 'svchost', 'services', 'wininit', 'csrss', 'lsass', 'winlogon')

# Compute HWND: walk the process tree first
if ($Hwnd -eq 0) {
    try {
        $p = Get-Process -Id $PID
        $depth = 0
        while ($p -and $p.MainWindowHandle -eq [IntPtr]::Zero -and $depth -lt 15) {
            $depth++
            $ppid = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").ParentProcessId
            if (-not $ppid -or $ppid -eq 0) { break }
            $p = Get-Process -Id $ppid -ErrorAction SilentlyContinue
        }
        if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero -and $p.ProcessName -notin $badProcs) {
            $Hwnd = $p.MainWindowHandle.ToInt64()
            Log "[TOAST] HWND=$Hwnd proc=$($p.ProcessName) pid=$($p.Id)"
        } else {
            Log "[TOAST] Tree walk hit '$($p.ProcessName)' - searching for terminal window"
        }
    } catch { Log "[TOAST] ERR tree walk: $_" }
}

# Fallback: find a running terminal window by process name
if ($Hwnd -eq 0) {
    try {
        foreach ($name in $terminalProcs) {
            $candidates = Get-Process -Name $name -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }
            if ($candidates) {
                $best = $candidates | Select-Object -First 1
                $Hwnd = $best.MainWindowHandle.ToInt64()
                Log "[TOAST] FALLBACK HWND=$Hwnd proc=$($best.ProcessName) pid=$($best.Id) title='$($best.MainWindowTitle)'"
                break
            }
        }
        if ($Hwnd -eq 0) { Log "[TOAST] WARN no terminal window found" }
    } catch { Log "[TOAST] ERR fallback: $_" }
}

# PS 7+ can't load WinRT types natively. Re-invoke in PS 5.1 where it works.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $eTitle = $Title -replace "'", "''"
    $eMessage = $Message -replace "'", "''"
    $eIcon = $Icon -replace "'", "''"
    $btBase = (Get-Module -ListAvailable BurntToast -ErrorAction SilentlyContinue | Select-Object -First 1).ModuleBase
    $btDir = if ($btBase) { (Split-Path (Split-Path $btBase)) -replace "'", "''" } else { '' }
    powershell.exe -ExecutionPolicy Bypass -Command "`$env:PSModulePath += ';$btDir'; & '$scriptPath' -Title '$eTitle' -Message '$eMessage' -Icon '$eIcon' -Hwnd $Hwnd"
    return
}

try {
    $hwndVal = $Hwnd

    Import-Module BurntToast

    # Build toast with protocol activation (click triggers claude-focus://)
    $text1 = New-BTText -Text $Title
    $text2 = New-BTText -Text $Message
    $appLogo = New-BTImage -Source $Icon -AppLogoOverride
    $binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appLogo
    $visual = New-BTVisual -BindingGeneric $binding
    $launchUri = "claude-focus://$hwndVal"
    $content = New-BTContent -Visual $visual -Launch $launchUri -ActivationType Protocol
    Log "[TOAST] OK uri=$launchUri title='$Title'"

    # PS 5.1: WinRT API with custom AppId 'Claude Code'
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $xmlContent = $content.GetContent() -replace '>\{', '>' -replace '\}<', '<'
    $xdoc = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xdoc.LoadXml($xmlContent)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xdoc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show($toast)

} catch {
    Log "[TOAST] ERR winrt: $($_.Exception.Message)"
    Import-Module BurntToast
    New-BurntToastNotification -Text $Title, $Message -AppLogo $Icon
}
