@echo off
REM IYTE eduroam Onarim Araci - baslatici
REM Sadece IYTE-Eduroam-Onar.ps1 dosyasini calistirir; baska hicbir sey yapmaz.
REM Arayuz acmadan konsol modu icin:  Eduroam-Onar.bat /quick
setlocal
cd /d "%~dp0"

if not exist "IYTE-Eduroam-Onar.ps1" (
    echo IYTE-Eduroam-Onar.ps1 bulunamadi. ZIP dosyasini once klasore cikarin,
    echo sonra bu dosyayi ayni klasorden calistirin.
    pause
    exit /b 1
)

set "MODE="
if /i "%~1"=="/quick" set "MODE=-NoGui"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0IYTE-Eduroam-Onar.ps1" %MODE%
endlocal
