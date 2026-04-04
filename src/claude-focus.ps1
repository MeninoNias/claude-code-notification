param($uri)

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

try {
    $hwndVal = [long]($uri -replace '^claude-focus://', '' -replace '[/\\s]', '')
    if ($hwndVal -eq 0) { Log "[FOCUS] ERR hwnd=0"; exit }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
'@

    $hwnd = [IntPtr]::new($hwndVal)

    if (-not [WinFocus]::IsWindow($hwnd)) { Log "[FOCUS] ERR hwnd=$hwndVal gone"; exit }

    # Reject known bad window classes
    $sb = [System.Text.StringBuilder]::new(256)
    [WinFocus]::GetClassName($hwnd, $sb, 256) | Out-Null
    $winClass = $sb.ToString()
    $badClasses = @('ThumbnailDeviceHelperWnd', 'Shell_TrayWnd', 'WorkerW', 'Progman', 'NotifyIconOverflowWindow')
    if ($winClass -in $badClasses) { Log "[FOCUS] SKIP class=$winClass"; exit }

    $minimized = [WinFocus]::IsIconic($hwnd)

    # Wait for Action Center to dismiss
    Start-Sleep -Milliseconds 300

    if ($minimized) {
        [WinFocus]::ShowWindow($hwnd, 9) | Out-Null
        Start-Sleep -Milliseconds 100
    }

    # Focus with retries
    $success = $false
    for ($i = 1; $i -le 3; $i++) {
        [WinFocus]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
        [WinFocus]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)

        $fgWnd = [WinFocus]::GetForegroundWindow()
        $fgPid = [uint32]0
        $fgThread = [WinFocus]::GetWindowThreadProcessId($fgWnd, [ref]$fgPid)
        $curThread = [WinFocus]::GetCurrentThreadId()
        $attached = [WinFocus]::AttachThreadInput($curThread, $fgThread, $true)

        $sfg = [WinFocus]::SetForegroundWindow($hwnd)
        [WinFocus]::BringWindowToTop($hwnd) | Out-Null

        if ($attached) { [WinFocus]::AttachThreadInput($curThread, $fgThread, $false) | Out-Null }

        $flags = [WinFocus]::SWP_NOMOVE -bor [WinFocus]::SWP_NOSIZE -bor [WinFocus]::SWP_SHOWWINDOW
        [WinFocus]::SetWindowPos($hwnd, [WinFocus]::HWND_TOPMOST, 0, 0, 0, 0, $flags) | Out-Null
        [WinFocus]::SetWindowPos($hwnd, [WinFocus]::HWND_NOTOPMOST, 0, 0, 0, 0, $flags) | Out-Null

        $newFg = [WinFocus]::GetForegroundWindow()
        if ($newFg.ToInt64() -eq $hwndVal) { $success = $true; break }
        Start-Sleep -Milliseconds ($i * 200)
    }

    if (-not $success) {
        $winPid = [uint32]0
        [WinFocus]::GetWindowThreadProcessId($hwnd, [ref]$winPid) | Out-Null
        if ($winPid -gt 0) {
            try { (New-Object -ComObject WScript.Shell).AppActivate($winPid) | Out-Null } catch {}
        }
    }

    $fg = [WinFocus]::GetForegroundWindow().ToInt64()
    $ok = if ($fg -eq $hwndVal) { 'OK' } else { 'FAIL' }
    Log "[FOCUS] $ok hwnd=$hwndVal class=$winClass min=$minimized attempts=$i fg=$fg"

} catch {
    Log "[FOCUS] ERR $($_.Exception.Message)"
}
