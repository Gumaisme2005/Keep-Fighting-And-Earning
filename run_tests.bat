@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -File "%~dp0tools\run_tests.ps1" %*
exit /b %ERRORLEVEL%
