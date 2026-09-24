@echo off
chcp 65001 >nul
REM Le point d entree : une fenetre qui demande ce que vous voulez faire.
REM Windows refuse d executer un .ps1 par double-clic ; ce fichier contourne
REM ce blocage pour ce seul lancement. Les deux sont lisibles dans le
REM Bloc-notes : ouvrez-les avant de les lancer si vous voulez verifier.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0migration-pc.ps1" %*
if errorlevel 1 (
  echo.
  echo  Le lanceur s est arrete sur une erreur.
  pause
)
