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
REM  POR QUE ESTE ORDEN DE PASOS
REM    1) wpeinit .... inicializa Plug and Play (discos, USB) y red.
REM    2) espera ..... pequeno margen para que termine de enumerar los USB.
REM    3) buscar ..... localiza menu.bat en cualquier unidad.
REM    4) fuente ..... fija Lucida Console 18 px para la consola nueva.
REM    5) lanzar ..... ejecuta menu.bat (la interfaz del taller).
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
REM  Buscamos por orden de PRIORIDAD (gana la primera coincidencia):
REM    1. X:\JAH\menu.bat    copia que VIAJA DENTRO de la ISO: el script
REM                          de compilacion la metio en boot.wim.
REM    2. X:\menu.bat        por si alguien la dejo suelta en la raiz.
REM    3. Cualquier unidad A..Z -> por si el tecnico lleva menu.bat en un
REM       pendrive aparte (ej. E:\JAH\menu.bat o E:\menu.bat).
REM  Buscar con 'if exist' es solo lectura: no modifica nada de los
REM  discos. El bucle recorre las 26 letras y se detiene en la primera
REM  coincidencia (la subrutina comprueba 'MENU_RUTA' antes de seguir).
set "MENU_RUTA="

if exist "X:\JAH\menu.bat" set "MENU_RUTA=X:\JAH\menu.bat"
if defined MENU_RUTA goto LANZAR
if exist "X:\menu.bat" set "MENU_RUTA=X:\menu.bat"
if defined MENU_RUTA goto LANZAR

for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if not defined MENU_RUTA call :BUSCAR_UNIDAD %%L
if defined MENU_RUTA goto LANZAR
goto NO_ENCONTRADO

REM ---------------------------------------------------------------------
REM  BUSCAR_UNIDAD - comprueba UNA letra (subrutina del bucle anterior).
REM    %~1 = letra sola sin dos puntos (por ejemplo: E)
REM  Se buscan las dos ubicaciones posibles, igual que en X:.
REM ---------------------------------------------------------------------
:BUSCAR_UNIDAD
if exist "%~1:\JAH\menu.bat" set "MENU_RUTA=%~1:\JAH\menu.bat"
if defined MENU_RUTA exit /b 0
if exist "%~1:\menu.bat" set "MENU_RUTA=%~1:\menu.bat"
exit /b 0

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
echo        - o dentro de una carpeta JAH               (ej.: E:\JAH\menu.bat)
echo      Despues reinicia el equipo y arranca de nuevo desde WinPE.
echo.
echo      Se abre una consola de emergencia SOLO para este error critico.
echo      Escribe 'exit' para reiniciar el equipo.
echo.
cmd
goto REINICIAR
