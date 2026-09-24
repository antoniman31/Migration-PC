@echo off
chcp 65001 >nul
REM Meme principe que 1-scanner-ce-pc.bat : voir les commentaires de ce
REM fichier. A lancer sur le NOUVEAU PC, avec le profil sur la meme cle.
setlocal
cd /d "%~dp0"
echo.
echo  Verification du NOUVEAU PC
echo  --------------------------
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verifier-pc.ps1" %*
if errorlevel 1 (
  echo.
  echo  La verification s est arretee sur une erreur. La fenetre reste ouverte
  echo  pour que vous puissiez lire le message ci-dessus.
)
echo.
pause
