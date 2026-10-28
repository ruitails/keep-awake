# Keep the PC awake: vertical sweep between two fixed screen points, click at each end.
# Built-in PowerShell + user32.dll only. Ctrl+C to stop.
#
# Target points are the two red dots from a 1440x900 reference screenshot,
# scaled onto the primary monitor so layout stays correct at other resolutions.

param(
    # Reference canvas the red-dot coords were measured against
    [int]$RefWidth = 1440,
    [int]$RefHeight = 900,
    # Red-dot positions on that 1440x900 canvas (from screenshot pixel detect + scale)
    [int]$RefTopX = 14,
    [int]$RefTopY = 219,
    [int]$RefBottomX = 14,
    [int]$RefBottomY = 761,
    [int]$Steps = 40,
    [int]$StepDelayMs = 12,
    [int]$EndPauseMs = 150,
    [int]$CyclePauseSec = 5
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms

if (-not ("KeepAwakeMouse" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class KeepAwakeMouse {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP   = 0x0004;

    public static void LeftClick() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP,   0, 0, 0, UIntPtr.Zero);
    }
}
"@
}

function Get-CursorPoint {
    $p = New-Object KeepAwakeMouse+POINT
    if (-not [KeepAwakeMouse]::GetCursorPos([ref]$p)) {
        throw "GetCursorPos failed"
    }
    return $p
}

function Move-CursorSmooth([int]$FromX, [int]$FromY, [int]$ToX, [int]$ToY) {
    for ($i = 1; $i -le $Steps; $i++) {
        $t = $i / [double]$Steps
        $x = [int]([Math]::Round($FromX + ($ToX - $FromX) * $t))
        $y = [int]([Math]::Round($FromY + ($ToY - $FromY) * $t))
        if (-not [KeepAwakeMouse]::SetCursorPos($x, $y)) {
            throw "SetCursorPos failed at ($x,$y)"
        }
        Start-Sleep -Milliseconds $StepDelayMs
    }
}

function Click-AtEnd([string]$Label, [int]$ExpectX, [int]$ExpectY) {
    if (-not [KeepAwakeMouse]::SetCursorPos($ExpectX, $ExpectY)) {
        throw "SetCursorPos before click failed at ($ExpectX,$ExpectY)"
    }
    Start-Sleep -Milliseconds $EndPauseMs
    [KeepAwakeMouse]::LeftClick()
    $now = Get-CursorPoint
    Write-Host ("  click @ {0} ({1},{2})" -f $Label, $now.X, $now.Y)
    Start-Sleep -Milliseconds $EndPauseMs
}

# Map 1440x900 red-dot coords onto the primary monitor
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$topX = $screen.X + [int]([Math]::Round($RefTopX * $screen.Width / [double]$RefWidth))
$topY = $screen.Y + [int]([Math]::Round($RefTopY * $screen.Height / [double]$RefHeight))
$botX = $screen.X + [int]([Math]::Round($RefBottomX * $screen.Width / [double]$RefWidth))
$botY = $screen.Y + [int]([Math]::Round($RefBottomY * $screen.Height / [double]$RefHeight))
# Keep a perfectly vertical path (same X)
$x = [int]([Math]::Round(($topX + $botX) / 2.0))

Write-Host "Keep-awake running."
Write-Host ("Primary screen: {0},{1} {2}x{3}" -f $screen.X, $screen.Y, $screen.Width, $screen.Height)
Write-Host ("Red dots (scaled from {0}x{1}): top=({2},{3})  bottom=({2},{4})" -f `
    $RefWidth, $RefHeight, $x, $topY, $botY)
Write-Host "Vertical travel between dots; click at each end. Ctrl+C to stop."
Write-Host ""

if (-not [KeepAwakeMouse]::SetCursorPos($x, $topY)) {
    throw "Initial SetCursorPos failed"
}

while ($true) {
    $cur = Get-CursorPoint
    Move-CursorSmooth $cur.X $cur.Y $x $botY
    Click-AtEnd "bottom" $x $botY

    $cur = Get-CursorPoint
    Move-CursorSmooth $cur.X $cur.Y $x $topY
    Click-AtEnd "top" $x $topY

    if ($CyclePauseSec -gt 0) {
        Start-Sleep -Seconds $CyclePauseSec
    }
}
