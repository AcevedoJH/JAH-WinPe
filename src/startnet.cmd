@echo off
REM =====================================================================
REM  JAH-WinPe :: startnet.cmd   (Fase 3 - arranque automatico en WinPE)
REM  ---------------------------------------------------------------------
REM  QUE ES ESTE ARCHIVO Y POR QUE EXISTE
REM    Dentro de la imagen WinPE, 'winpeshl.exe' arranca como primer
REM    proceso de usuario y busca, por defecto, este fichero:
REM         %SystemRoot%\System32\startnet.cmd
REM    (es decir, X:\Windows\System32\startnet.cmd, una vez que el
REM    contenido de boot.wim se ha expandido en el disco RAM X:).
REM    Sustituyendo el startnet.cmd de serie por ESTE, el equipo arranca
REM    directamente nuestra herramienta: el tecnico no teclea nada.
REM
REM  ORDEN DE PASOS
REM    1) wpeinit .... inicializa Plug and Play (discos, USB) y red.
REM    2) buscar ..... localiza menu.bat en cualquier unidad.
REM    3) ram ........ copia JAH-WinPe a X:\JAH-WinPe (memoria RAM),
REM                    EXCEPTO la carpeta 'Tools' de utilidades, que
REM                    permanece en el pendrive para no inflar la RAM.
REM    4) fuente ..... fija Lucida Console 18 px para la consola nueva.
REM    5) lanzar ..... ejecuta menu.bat desde X:\JAH-WinPe.
REM
REM  NOTA SOBRE ACENTOS
REM    TODO este fichero va en ASCII puro (sin acentos, ni siquiera en los
REM    comentarios) a proposito: es lo primero que se ejecuta y todavia no
REM    sabemos que pagina de codigos usa la consola. Asi es imposible que
REM    aparezca un caracter raro en pantalla. menu.bat ya ajusta su propia
REM    codificacion interna (chcp) nada mas arrancar.
REM =====================================================================

REM --- Paso 1: inicializar el entorno WinPE ----------------------------
REM  'wpeinit' hace el trabajo que en un Windows normal haria la fase de
REM  instalacion (MiniSetup): detecta hardware, arranca la red por DHCP y
REM  deja listos los discos y los puertos USB. Deja su registro en:
REM         X:\Windows\System32\wpeinit.log
REM  Si esa linea fallara (imagen muy recortada sin wpeinit.exe), el
REM  script continuara igual: no es critico para el taller.
wpeinit

REM --- Paso 2: sin demora (arranque instantaneo) -----------------------
REM  Se elimina toda espera artificial. wpeinit ya inicializa PnP/USB;
REM  la busqueda de menu.bat se hace directamente.

REM --- Paso 3: localizar menu.bat --------------------------------------
REM  Orden de prioridad (gana la primera coincidencia):
REM    1. X:\JAH-WinPe\menu.bat    copia que viaja dentro de la ISO/boot.wim
REM    2. X:\JAH\menu.bat          compatibilidad con estructura anterior
REM    3. X:\menu.bat              por si alguien la dejo suelta
REM    4. Cualquier unidad A..Z -> pendrive USB (JAH-WinPe\menu.bat,
REM       JAH\menu.bat o menu.bat suelto).
REM  Buscar con 'if exist' es solo lectura: no modifica nada de los discos.
set "MENU_RUTA="

if exist "X:\JAH-WinPe\menu.bat" set "MENU_RUTA=X:\JAH-WinPe\menu.bat"
if defined MENU_RUTA goto PREPARAR_RAM
if exist "X:\JAH\menu.bat" set "MENU_RUTA=X:\JAH\menu.bat"
if defined MENU_RUTA goto PREPARAR_RAM
if exist "X:\menu.bat" set "MENU_RUTA=X:\menu.bat"
if defined MENU_RUTA goto PREPARAR_RAM

for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if not defined MENU_RUTA call :BUSCAR_UNIDAD %%L
if defined MENU_RUTA goto PREPARAR_RAM
goto NO_ENCONTRADO

REM ---------------------------------------------------------------------
REM  BUSCAR_UNIDAD - comprueba UNA letra (subrutina del bucle anterior).
REM    %~1 = letra sola sin dos puntos (por ejemplo: E)
REM ---------------------------------------------------------------------
:BUSCAR_UNIDAD
if exist "%~1:\JAH-WinPe\menu.bat" set "MENU_RUTA=%~1:\JAH-WinPe\menu.bat"
if defined MENU_RUTA exit /b 0
if exist "%~1:\JAH\menu.bat" set "MENU_RUTA=%~1:\JAH\menu.bat"
if defined MENU_RUTA exit /b 0
if exist "%~1:\menu.bat" set "MENU_RUTA=%~1:\menu.bat"
exit /b 0

REM ---------------------------------------------------------------------
REM  PREPARAR_RAM - copia JAH-WinPe a la memoria RAM de WinPE (X:)
REM  -------------------------------------------------------------------
REM  Objetivo: el tecnico puede arrancar el equipo, copiar la herramienta
REM  a la RAM y retirar el pendrive USB para usarlo en otro equipo.
REM  - SOURCE_DIR: carpeta donde esta menu.bat (p. ej. E:\JAH-WinPe).
REM  - RAM_DIR:    destino fijo en RAM (X:\JAH-WinPe).
REM  - JAH_USB_NOMBRE: nombre de la carpeta raiz en el USB; se hereda
REM    por el entorno para que menu.bat pueda detectar el pendrive en
REM    caliente cuando entre en "Herramientas y Utilidades".
REM  Se excluye la carpeta 'Tools' del copiado: las utilidades pesadas
REM  se ejecutan directamente desde el USB, no de la RAM.
REM ---------------------------------------------------------------------
:PREPARAR_RAM
for %%F in ("%MENU_RUTA%") do set "SOURCE_DIR=%%~dpF"
REM  Quitamos la barra final para tener una ruta de carpeta limpia.
if "%SOURCE_DIR:~-1%"=="\" set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"
for %%F in ("%SOURCE_DIR%") do set "JAH_USB_NOMBRE=%%~nxF"
if not defined JAH_USB_NOMBRE set "JAH_USB_NOMBRE=JAH-WinPe"

set "RAM_DIR=X:\JAH-WinPe"

REM  Si ya estamos en X:\JAH-WinPe no hace falta copiar (por ejemplo, la
REM  propia ISO ya la trae ahi). En cualquier otro caso, copiamos TODO
REM  excepto la carpeta Tools al disco RAM.
if /i "%SOURCE_DIR%"=="%RAM_DIR%" goto RAM_LISTA
if not exist "%RAM_DIR%" mkdir "%RAM_DIR%"
robocopy "%SOURCE_DIR%" "%RAM_DIR%" /E /R:0 /W:0 /XD Tools /NFL /NDL /NJH /NJS >nul 2>&1
if errorlevel 8 (
    REM  Si robocopy falla (imagen muy recortada), arrancamos desde el USB
    REM  directamente. La funcionalidad basica sigue disponible.
    set "RAM_DIR=%SOURCE_DIR%"
    goto RAM_LISTA
)

:RAM_LISTA
set "MENU_RUTA=%RAM_DIR%\menu.bat"
set "JAH_RAM_DIR=%RAM_DIR%"

REM --- Paso 4: fuente de consola legible -------------------------------
REM  WinPE arranca con una fuente raster comprimida. Estas claves son las
REM  mismas que usan CMD/PowerShell: Lucida Console, 18 px, peso normal.
REM  Se aplican al ABRIR la consola nueva del paso 5.
:LANZAR
for %%K in ("HKCU\Console" "HKCU\Console\JAH-WinPe") do (
    reg add %%K /v FaceName /t REG_SZ /d "Lucida Console" /f >nul 2>&1
    reg add %%K /v FontFamily /t REG_DWORD /d 54 /f >nul 2>&1
    reg add %%K /v FontWeight /t REG_DWORD /d 400 /f >nul 2>&1
    reg add %%K /v FontSize /t REG_DWORD /d 1179648 /f >nul 2>&1
)
echo.
echo  JAH-WinPe: arrancando el menu desde  %MENU_RUTA%
echo.
REM  Se abre una consola NUEVA para que nazca con la fuente configurada.
REM  /max inicia la ventana maximizada (pantalla completa) por defecto.
REM  /wait mantiene startnet vivo y, al cerrar menu.bat, se reinicia.
start "JAH-WinPe" /max /wait cmd /c "%MENU_RUTA%"
if errorlevel 1 goto LANZAR_ACTUAL
goto REINICIAR
:LANZAR_ACTUAL
REM  Si 'start' no puede abrir otra consola (WinPE muy recortado), se
REM  ejecuta en la actual: la herramienta funciona igual.
call "%MENU_RUTA%"
REM  Si llegamos aqui, el tecnico ha salido del menu (opcion [2]) o el
REM  menu termino. En WinPE no hay escritorio al que volver: reiniciamos
REM  el equipo de forma limpia y directa. La consola original queda
REM  detras de la nueva y ambas se cierran al reiniciar: no se deja
REM  ninguna consola huerfana.
goto REINICIAR

REM ---------------------------------------------------------------------
REM  REINICIAR - salida limpia del entorno WinPE.
REM    wpeutil es la herramienta oficial de WinPE y reinicia al instante;
REM    si no existiera, 'shutdown /r /t 0' hace lo mismo en Windows.
REM    Si ambas fallan, 'exit /b' devuelve el control sin bloquear.
REM ---------------------------------------------------------------------
:REINICIAR
echo.
echo  JAH-WinPe: reiniciando el equipo...
echo.
if exist "%SystemRoot%\System32\wpeutil.exe" wpeutil reboot
shutdown /r /t 0 >nul 2>&1
exit /b 0

REM --- menu.bat no encontrado ------------------------------------------
:NO_ENCONTRADO
echo.
echo  [!] No se ha encontrado menu.bat en ninguna unidad.
echo.
echo      Como solucionarlo:
echo        - Copia menu.bat a la raiz de un pendrive   (ej.: E:\menu.bat)
echo        - o dentro de una carpeta JAH-WinPe         (ej.: E:\JAH-WinPe\menu.bat)
echo      Despues reinicia el equipo y arranca de nuevo desde WinPE.
echo.
echo      Se abre una consola de emergencia SOLO para este error critico.
echo      Escribe 'exit' para reiniciar el equipo.
echo.
cmd
goto REINICIAR
