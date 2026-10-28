@echo off
setlocal
REM Keep-awake launcher. Uses sibling keep-awake.ps1 (PowerShell + user32 only).
REM Prompts for Primary/Secondary screen, then vertical sweep + click. Ctrl+C to stop.

cd /d "%~dp0"

echo Starting keep-awake...
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0keep-awake.ps1" %*
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo keep-awake failed with exit code %ERR%.
  pause
  exit /b %ERR%
)
