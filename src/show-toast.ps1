param(
    [string]$Title,
    [string]$Message,
    [string]$Icon
)

# PS 7+ can't load WinRT types natively. Re-invoke in PS 5.1 where it works.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $eTitle = $Title -replace "'", "''"
    $eMessage = $Message -replace "'", "''"
    $eIcon = $Icon -replace "'", "''"
    # Find BurntToast's module directory and inject into PS 5.1 command
    $btBase = (Get-Module -ListAvailable BurntToast -ErrorAction SilentlyContinue | Select-Object -First 1).ModuleBase
    $btDir = if ($btBase) { (Split-Path (Split-Path $btBase)) -replace "'", "''" } else { '' }
    powershell.exe -ExecutionPolicy Bypass -Command "`$env:PSModulePath += ';$btDir'; & '$scriptPath' -Title '$eTitle' -Message '$eMessage' -Icon '$eIcon'"
    return
}

try {
    # Find terminal window by walking up the process tree
    $p = Get-Process -Id $PID
    while ($p -and $p.MainWindowHandle -eq [IntPtr]::Zero) {
        $ppid = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").ParentProcessId
        if (-not $ppid -or $ppid -eq 0) { break }
        $p = Get-Process -Id $ppid -ErrorAction SilentlyContinue
    }
    $hwndVal = if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero) { $p.MainWindowHandle.ToInt64() } else { 0 }

    Import-Module BurntToast

    # Build toast with protocol activation (click triggers claude-focus://)
    $text1 = New-BTText -Text $Title
    $text2 = New-BTText -Text $Message
    $appLogo = New-BTImage -Source $Icon -AppLogoOverride
    $binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appLogo
    $visual = New-BTVisual -BindingGeneric $binding
    $content = New-BTContent -Visual $visual -Launch "claude-focus://$hwndVal" -ActivationType Protocol

    # PS 5.1: WinRT API with custom AppId 'Claude.Code'
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $xdoc = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xdoc.LoadXml($content.GetContent())
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xdoc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude.Code').Show($toast)

} catch {
    Import-Module BurntToast
    New-BurntToastNotification -Text $Title, $Message -AppLogo $Icon
}
