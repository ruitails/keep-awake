@echo off
setlocal
REM Keep the PC awake by nudging the mouse every INTERVAL seconds.
REM Uses only built-in PowerShell + user32.dll (no installs).
REM Press Ctrl+C to stop.

set "INTERVAL=60"

echo Keep-awake running. Mouse nudge every %INTERVAL%s. Ctrl+C to stop.
echo.

:loop
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class M { [DllImport(\"user32.dll\")] public static extern bool GetCursorPos(out POINT p); [DllImport(\"user32.dll\")] public static extern bool SetCursorPos(int x, int y); public struct POINT { public int X; public int Y; } }'; $p = New-Object M+POINT; [void][M]::GetCursorPos([ref]$p); [void][M]::SetCursorPos($p.X + 1, $p.Y); Start-Sleep -Milliseconds 50; [void][M]::SetCursorPos($p.X, $p.Y)"
timeout /t %INTERVAL% /nobreak >nul
goto loop
