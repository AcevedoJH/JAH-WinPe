@echo off
REM =====================================================================
REM  JAH-WinPe :: build_iso.bat   (Fase 3 - lanzador de la compilacion)
REM  ---------------------------------------------------------------------
REM  QUE HACE
REM    Es un "envoltorio" comodo alrededor de build_iso.ps1:
REM      1) Comprueba que la consola es de Administrador (obligatorio
REM         para que DISM pueda montar boot.wim).
REM      2) Localiza Windows PowerShell 5.1 (viene con Windows).
REM      3) Llama a build_iso.ps1 pasandole TAL CUAL los parametros que
REM         le hayas dado a este .bat.
REM
REM  POR QUE UN .BAT SI YA HAY UN .PS1
REM    En muchos equipos de taller, la politica de ejecucion de PowerShell
REM    (ExecutionPolicy) bloquea los .ps1 al hacer doble clic. Este .bat lo
REM    lanza con -ExecutionPolicy Bypass (solo para esta ejecucion) y deja
REM    la ventana abierta al terminar, para que se pueda leer el error.
REM
REM  USO (desde una consola COMO ADMINISTRADOR):
REM    build_iso.bat                       compilacion normal
REM    build_iso.bat -Force                regenera la carpeta de trabajo
REM    build_iso.bat -Arch amd64 -PromptKey
REM    build_iso.bat -OutputIso C:\isos\JAH-WinPe.iso
REM  (Todos los parametros se pasan a build_iso.ps1; ver su ayuda con:
REM       powershell -File build_iso.ps1 -?)
REM
REM  SOBRE LOS ACENTOS: este .bat y build_iso.ps1 se han escrito en ASCII
REM  puro (sin tildes) a proposito: asi funcionan igual bajo cualquier
REM  pagina de codigos y no dependen del BOM. Es una decision de
REM  portabilidad, no un olvido.
REM =====================================================================

setlocal

REM --- 1) Comprobar permisos de Administrador --------------------------
REM  'net session' necesita privilegios elevados: si responde sin error,
REM  somos Administrador. Es el metodo clasico y no depende de PowerShell.
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [!] Esta consola NO es de Administrador.
    echo      Cierra esta ventana y abre:  Simbolo del sistema ^(Administrador^)
    echo      o Windows PowerShell ^(Administrador^), y vuelve a ejecutar:
    echo          build_iso.bat
    echo.
    pause
    exit /b 1
)

REM --- 2) Localizar Windows PowerShell 5.1 -----------------------------
REM  Preferimos la ruta canonica del sistema. Si no estuviera, probamos
REM  PowerShell 7+ (pwsh) que puede estar instalado aparte.
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=pwsh.exe"

REM --- 3) Ejecutar el script de compilacion ----------------------------
REM  %~dp0 es la carpeta de ESTE .bat (build\), con barra final incluida.
REM  -NoProfile        : no carga perfiles del usuario (mas predecible).
REM  -ExecutionPolicy Bypass : permite ejecutar el .ps1 aunque la politica
REM                            del equipo lo bloquee (solo esta vez).
REM  -File             : ejecuta el fichero indicado.
REM  %*                : reenvia todos los parametros tal cual.
echo.
echo  JAH-WinPe - compilacion de la ISO (build_iso.ps1)
echo  ------------------------------------------------------------------
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_iso.ps1" %*

REM --- Pausa final para leer el resultado ------------------------------
REM  'pause' evita que la ventana se cierre de golpe al hacer doble clic.
echo.
pause
endlocal
exit /b 0
