@echo off
chcp 65001 >nul
REM Le seul fichier a lancer. Il demande ce que vous voulez faire et
REM s occupe du reste. Les scripts qu il appelle sont dans scripts\.
REM Windows refuse d executer un .ps1 par double-clic ; ce fichier contourne
REM ce blocage pour ce seul lancement. Les deux sont lisibles dans le
REM Bloc-notes : ouvrez-les avant de les lancer si vous voulez verifier.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\migration-pc.ps1" %*
if errorlevel 1 (
  echo.
  echo  Le lanceur s est arrete sur une erreur.
  pause
)
