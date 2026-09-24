@echo off
chcp 65001 >nul
REM Windows refuse d executer un .ps1 par double-clic : c est une protection
REM qu on ne retire pas, mais qu on peut contourner pour ce seul lancement.
REM Ce fichier est lisible dans le Bloc-notes, contrairement a un .exe, et le
REM script qu il appelle l est aussi : ouvrez-les avant de les lancer.
setlocal
cd /d "%~dp0"
echo.
echo  Inventaire de CE PC
echo  -------------------
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan-pc.ps1" %*
if errorlevel 1 (
  echo.
  echo  Le scan s est arrete sur une erreur. La fenetre reste ouverte pour que
  echo  vous puissiez lire le message ci-dessus.
)
echo.
pause
