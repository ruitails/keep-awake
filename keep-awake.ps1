# Keep the PC awake: vertical sweep between two fixed screen points, click at each end.
# Built-in PowerShell + user32.dll only. Ctrl+C to stop.
#
# Target points are the two red dots from a 1440x900 reference screenshot,
# scaled onto the primary monitor so layout stays correct at other resolutions.

param(
    # 1 = Primary, 2 = Secondary, 0 = prompt interactively
    # Named Monitor (not Screen) — PowerShell vars are case-insensitive.
    [int]$Monitor = 0,
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
    public static extern bool SetProcessDPIAware();

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

# Must run before reading screen bounds so coords match SetCursorPos under DPI scaling
[void][KeepAwakeMouse]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms

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

$allScreens = [System.Windows.Forms.Screen]::AllScreens
$primary = [System.Windows.Forms.Screen]::PrimaryScreen
$secondary = @($allScreens | Where-Object { -not $_.Primary })

$menu = @()
$menu += [pscustomobject]@{
    Number = 1
    Label  = "Primary"
    Screen = $primary
}
if ($secondary.Count -ge 1) {
    $menu += [pscustomobject]@{
        Number = 2
        Label  = "Secondary"
        Screen = $secondary[0]
    }
}

function Format-ScreenChoice($item) {
    $b = $item.Screen.Bounds
    return ("{0}. {1} ({2}x{3})" -f $item.Number, $item.Label, $b.Width, $b.Height)
}

$choice = $Monitor
if ($choice -eq 0) {
    Write-Host "Choose screen:"
    foreach ($item in $menu) {
        Write-Host (Format-ScreenChoice $item)
    }
    Write-Host ""
    $raw = Read-Host "Enter number"
    if (-not [int]::TryParse($raw, [ref]$choice)) {
        throw "Invalid selection: '$raw'"
    }
}

$selected = $menu | Where-Object { $_.Number -eq $choice } | Select-Object -First 1
if (-not $selected) {
    $valid = ($menu | ForEach-Object { $_.Number }) -join ', '
    throw "Screen $choice is not available. Choose one of: $valid"
}

# Map 1440x900 red-dot coords onto the chosen monitor
$bounds = $selected.Screen.Bounds
$topX = $bounds.X + [int]([Math]::Round($RefTopX * $bounds.Width / [double]$RefWidth))
$topY = $bounds.Y + [int]([Math]::Round($RefTopY * $bounds.Height / [double]$RefHeight))
$botX = $bounds.X + [int]([Math]::Round($RefBottomX * $bounds.Width / [double]$RefWidth))
$botY = $bounds.Y + [int]([Math]::Round($RefBottomY * $bounds.Height / [double]$RefHeight))
# Keep a perfectly vertical path (same X)
$x = [int]([Math]::Round(($topX + $botX) / 2.0))

Write-Host ""
Write-Host "Keep-awake running."
Write-Host ("Selected: {0}" -f (Format-ScreenChoice $selected))
Write-Host ("Screen bounds: {0},{1} {2}x{3}" -f $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)
Write-Host ("Red dots (scaled from {0}x{1}): top=({2},{3})  bottom=({2},{4})" -f `
    $RefWidth, $RefHeight, $x, $topY, $botY)
Write-Host "Vertical travel between dots; click at each end. Ctrl+C to stop."
Write-Host ""

if (-not [KeepAwakeMouse]::SetCursorPos($x, $topY)) {
    throw "Initial SetCursorPos failed"
}

while ($true) {
    $cur = Get-CursorPoint
    # Pin X so travel stays strictly vertical even if the cursor is bumped mid-cycle
    Move-CursorSmooth $x $cur.Y $x $botY
    Click-AtEnd "bottom" $x $botY

    $cur = Get-CursorPoint
    Move-CursorSmooth $x $cur.Y $x $topY
    Click-AtEnd "top" $x $topY

    if ($CyclePauseSec -gt 0) {
        Start-Sleep -Seconds $CyclePauseSec
    }
}
