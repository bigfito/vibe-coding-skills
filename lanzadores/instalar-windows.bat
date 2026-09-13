@echo off
setlocal
rem Lanzador de doble clic de Vibe Coding Skills para Windows.
rem
rem Descarga este archivo y haz doble clic. Se abre una ventana y arranca el
rem instalador: no hace falta escribir ningun comando.
rem
rem La primera vez Windows puede avisar de que el archivo viene de internet.
rem En ese caso: "Mas informacion" -> "Ejecutar de todas formas".

chcp 65001 >nul 2>&1

if "%VIBE_SKILLS_RAW%"=="" set "VIBE_SKILLS_RAW=%AGENT_SKILLS_RAW%"
if "%VIBE_SKILLS_RAW%"=="" set "VIBE_SKILLS_RAW=https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main"

echo.
echo   Vibe Coding Skills - instalador para Windows
echo   Se abrira un menu para elegir las skills y la carpeta de tu proyecto.
echo.

where powershell >nul 2>&1
if errorlevel 1 (
    echo   No se encontro PowerShell, que hace falta para ejecutar el instalador.
    echo   Viene incluido en Windows: busca "PowerShell" en el menu Inicio.
    echo.
    pause
    exit /b 1
)

rem El instalador se descarga a un archivo y se ejecuta desde ahi, en lugar de
rem con `irm ^| iex`, para que pueda recibir argumentos y leer las respuestas.
set "SCRIPT=%TEMP%\vibe-coding-skills-install.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Invoke-WebRequest -UseBasicParsing '%VIBE_SKILLS_RAW%/install.ps1' -OutFile '%SCRIPT%' } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo   No se pudo descargar el instalador ^(hay conexion a internet?^).
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "ESTADO=%ERRORLEVEL%"

del "%SCRIPT%" >nul 2>&1

echo.
pause
exit /b %ESTADO%
