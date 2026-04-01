param($uri)
try {
    $hwndVal = [long]($uri -replace '^claude-focus://', '' -replace '[/\\s]', '')
    if ($hwndVal -eq 0) { exit }

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

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
'@

    $hwnd = [IntPtr]::new($hwndVal)

    # Bail if window no longer exists
    if (-not [WinFocus]::IsWindow($hwnd)) { exit }

    # Restore if minimized
    if ([WinFocus]::IsIconic($hwnd)) { [WinFocus]::ShowWindow($hwnd, 9) | Out-Null }

    # Method 1: Alt key trick + AttachThreadInput + SetForegroundWindow
    [WinFocus]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [WinFocus]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)

    $fgWnd = [WinFocus]::GetForegroundWindow()
    $fgThread = [WinFocus]::GetWindowThreadProcessId($fgWnd, [ref]0)
    $curThread = [WinFocus]::GetCurrentThreadId()
    $attached = [WinFocus]::AttachThreadInput($curThread, $fgThread, $true)

    [WinFocus]::SetForegroundWindow($hwnd) | Out-Null
    [WinFocus]::BringWindowToTop($hwnd) | Out-Null

    if ($attached) { [WinFocus]::AttachThreadInput($curThread, $fgThread, $false) | Out-Null }

    # Method 2: TopMost flash - briefly set as topmost then remove
    $flags = [WinFocus]::SWP_NOMOVE -bor [WinFocus]::SWP_NOSIZE -bor [WinFocus]::SWP_SHOWWINDOW
    [WinFocus]::SetWindowPos($hwnd, [WinFocus]::HWND_TOPMOST, 0, 0, 0, 0, $flags) | Out-Null
    [WinFocus]::SetWindowPos($hwnd, [WinFocus]::HWND_NOTOPMOST, 0, 0, 0, 0, $flags) | Out-Null

    # Method 3: WScript.Shell AppActivate as last resort
    $pid = 0
    [WinFocus]::GetWindowThreadProcessId($hwnd, [ref]$pid) | Out-Null
    if ($pid -gt 0) {
        try { (New-Object -ComObject WScript.Shell).AppActivate($pid) | Out-Null } catch {}
    }
} catch {}
