@echo off
REM =====================================================================
REM  JAH-WinPe  ::  menu.bat  -  INTERFAZ PRINCIPAL DEL TALLER
REM =====================================================================
REM  PROYECTO   : JAH-WinPe - herramienta de soporte tecnico en consola
REM               (Windows completo y WinPE de arranque).
REM  COMPONENTE : menu.bat -^> pantalla de bienvenida, menu principal,
REM               ayuda del sistema y salida ordenada.
REM  FASE       : 1 (solo interfaz; todavia NO ejecuta comandos
REM               destructivos sobre discos).
REM  VERSION    : 1.0.0
REM
REM  --------------------------------------------------------------------
REM  MAPA DE NAVEGACION (etiquetas del script)
REM  --------------------------------------------------------------------
REM    BIENVENIDA  -^> bienvenida una sola vez -^> MENU
REM    MENU        -^> [1] OP_DISCO ......... preparacion de disco (Fase 2)
REM                -^> [2] OP_SANITIZAR ..... borrado seguro      (Fase 2)
REM                -^> [3] OP_CONSOLA ....... CMD interactivo
REM                -^> [4] OP_AYUDA ......... 2 paginas + help nativo
REM                -^> [5] OP_SALIR ......... apagar / salir (con confirmacion)
REM    FIN_SCRIPT  -^> salida limpia del script
REM    FIN_APAGADO -^> salida tras solicitar el apagado
REM    (al final)  -^> subrutinas internas invocadas con 'call :etiqueta'
REM
REM  --------------------------------------------------------------------
REM  CONVENCIONES QUE DEBES SEGUIR AL EDITAR ESTE ARCHIVO
REM  --------------------------------------------------------------------
REM   1) Comentarios con REM, nunca con '::'. '::' es en realidad una
REM      ETIQUETA vacia: dentro de bloques parentesados o con
REM      redirecciones puede romper el script. REM es siempre seguro...
REM      pero OJO: cmd interpreta los simbolos especiales (ampersand,
REM      tuberia, mayor y menor que) tambien en lineas REM, por eso en
REM      los comentarios los escribimos con el caracter de escape (caret)
REM      o directamente con palabras, si hace falta.
REM   2) Etiquetas y variables en ASCII puro: cmd las busca por bytes y
REM      un acento podria romper un 'goto' segun el codigo de pagina.
REM      El TEXTO visible si lleva acentos: forzamos UTF-8 en el PASO 1.
REM   3) Asignaciones con la forma  set "VAR=valor"  (comillas alrededor
REM      de toda la asignacion): evita espacios finales accidentales.
REM   4) Expansion retrasada (DelayedExpansion) NO se usa en Fase 1:
REM      asi los signos de exclamacion del texto se imprimen tal cual.
REM   5) Ninguna accion destructiva se ejecuta sin confirmacion previa.
REM
REM  PENDIENTE PARA FASE 2:
REM   - Submenu guiado de diskpart para las opciones 1 y 2.
REM   - Registro de actividad (log) en la unidad de arranque o en TEMP.
REM   - Deteccion de firmware (BIOS/UEFI) para preparar discos GPT/MBR.
REM =====================================================================

REM =====================================================================
REM  PASO 1 - CONFIGURACION INICIAL DEL ENTORNO
REM =====================================================================

REM 'setlocal' abre un AMBITO de variables propio de este script: todo lo
REM que declaremos aqui se descarta al terminar, dejando la consola del
REM tecnico exactamente como estaba (sin variables "sucias" a medias).
REM 'EnableExtensions' activa explicitamente las extensiones de comando
REM (if, for, call con subrutinas...). Vienen activas por defecto, pero
REM ser explicitos nos protege de configuraciones exoticas del sistema.
setlocal EnableExtensions

REM --- Codigo de pagina de la consola (encoding) -----------------------
REM El archivo esta guardado en UTF-8. La consola arranca en una pagina
REM de codigos heredada (437/850 en equipos en espanol): sin sincronizar
REM ambas, los acentos se imprimirian como "runas" (mojibake).
REM   chcp 65001  -^> cambia la consola a UTF-8. Debe ejecutarse ANTES de
REM                   imprimir cualquier texto con acentos.
REM   La redireccion a NUL silencia el mensaje 'Codigo de pagina activo'.
REM FALLBACK: si aun vieras caracteres raros, guarda menu.bat en ANSI
REM (Windows-1252) y comenta la linea chcp.
chcp 65001 >nul 2>&1

REM --- Identidad de la herramienta --------------------------------------
REM Centralizamos los textos repetidos: si manana cambiamos de version
REM solo tocamos aqui y se actualiza cabecera, titulo y mensajes.
set "TOOL_NAME=JAH-WinPe"
set "TOOL_VER=1.0.0"
set "TOOL_FASE=1"

REM --- Apariencia de la consola -----------------------------------------
REM title  -^> texto de la barra de titulo de la ventana.
REM mode   -^> tamano de la ventana (columnas x lineas). Fijamos ~44 lineas
REM            para que quepan cabecera + menu + mensajes sin scroll.
REM            Se silencia su salida porque 'mode' puede fallar si la
REM            consola no permite redimensionar (ventanas embebidas en
REM            otros programas) y ese fallo no debe tumbar el script.
REM color  -^> DOS digitos hexadecimales: PRIMERO el fondo, SEGUNDO el
REM            texto.  0 = fondo negro, A = texto verde claro.
REM            Otros ejemplos: 07 gris, 0B cian, 0E amarillo,
REM            0F blanco brillante. Solo hay que cambiar esta linea.
title %TOOL_NAME% - Soporte Tecnico v%TOOL_VER% - Fase %TOOL_FASE%
mode con: cols=94 lines=44 >nul 2>&1
color 0A

REM --- Deteccion del metodo de lectura de teclado ----------------------
REM Preferimos 'choice.exe' porque SOLO acepta las teclas que le
REM indiquemos: cualquier otro tecleo emite un 'beep' y no devuelve
REM nada, luego un error de dedo jamas puede cerrar el menu ni salirse
REM del guion. Es la captura de entrada mas segura que existe en batch.
REM Algunas imagenes WinPE minimales no incluyen choice.exe, asi que
REM detectamos su presencia y, si falta, caemos a una ruta alternativa
REM con 'set /p' + validacion estricta (ver subrutina LEER_OPCION).
set "MODO_ENTRADA=SETP"
if exist "%SystemRoot%\System32\choice.exe" set "MODO_ENTRADA=CHOICE"

REM De aqui saltamos directamente a la pantalla de bienvenida. Se usa
REM 'goto' (salto sin retorno) porque es el flujo normal del programa.
goto BIENVENIDA

REM =====================================================================
REM  PASO 2 - PANTALLA DE BIENVENIDA (se muestra UNA sola vez)
REM =====================================================================
:BIENVENIDA
cls
call :MOSTRAR_CABECERA
echo(
echo   Bienvenido, técnico.
echo   Esta herramienta centraliza las operaciones más usadas del taller
echo   para dar soporte a equipos Windows y preparar discos de forma
echo   (rápida, repetible y sin sorpresas).
echo(
echo   REGLAS DE ORO antes de tocar un disco:
echo     1. Identifica SIEMPRE el disco correcto antes de borrar nada.
echo        En la opción 1 se listará con: diskpart  -^>  list disk.
echo     2. Las opciones 1 y 2 son DESTRUCTIVAS. En la Fase 1 están en
echo        modo "punto de partida": aún no ejecutan cambios reales.
echo     3. Ante la duda, consulta primero la opción 4 (Ayuda) y no
echo        improvises con comandos que no conoces.
echo(
echo   Forma de uso: teclea el número de la opción que aparece en el
echo   menú. Según el entorno bastará con la tecla o con pulsar ENTER.
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para entrar en el menú principal..."
goto MENU

REM =====================================================================
REM  PASO 3 - MENU PRINCIPAL (bucle infinito: SIEMPRE vuelve aqui)
REM =====================================================================
:MENU
cls
call :MOSTRAR_CABECERA
echo(
echo   MENÚ PRINCIPAL
echo   ------------------------------------------------------------------
echo(
echo      [1]  Preparación rápida de disco        limpieza y formato básico
echo      [2]  Borrado seguro / Sanitización      destrucción lógica de datos
echo      [3]  Consola Avanzada                   salir a CMD interactivo
echo      [4]  Ayuda del sistema                  guía rápida del técnico
echo      [5]  Salir / Apagar equipo
echo(
echo   ------------------------------------------------------------------
echo      Fecha y hora: %date%  %time:~0,5%
echo      Modo de entrada: %MODO_ENTRADA%
echo(
echo   (Si la consola no reacciona a una sola tecla, teclea el número
echo    y termina con ENTER.)
echo(

REM --- Captura segura de la seleccion -----------------------------------
REM 'call :subrutina' invoca una subrutina y REGRESA a la linea siguiente
REM cuando esta cierra con 'exit /b'. Le pasamos dos argumentos:
REM   1) el texto que vera el tecnico,
REM   2) los digitos permitidos (lista blanca).
REM El resultado queda en la variable global %OPCION%.
call :LEER_OPCION "   Su opción [1-5]:  " "1 2 3 4 5"

REM --- Despacho (reparto de la opcion elegida) --------------------------
REM Comparamos %OPCION% con cada tecla posible y saltamos a la seccion
REM correspondiente. Cada 'if' ocupa UNA linea y no usa bloques
REM parentesados: asi evitamos problemas de expansion de variables
REM dentro de bloques (que exigen expansion retrasada).
REM
REM ALTERNATIVA classica, si despacharamos directamente con choice:
REM     if errorlevel 5 goto OP_SALIR
REM     if errorlevel 4 goto OP_AYUDA
REM     ...siempre de MAYOR a MENOR, porque 'if errorlevel N' significa
REM     "errorlevel MAYOR O IGUAL que N" y no "igual a N".
REM Nosotros capturamos el valor en %OPCION% para reutilizar la misma
REM logica tanto en el modo choice como en el modo set /p.
if "%OPCION%"=="1" goto OP_DISCO
if "%OPCION%"=="2" goto OP_SANITIZAR
if "%OPCION%"=="3" goto OP_CONSOLA
if "%OPCION%"=="4" goto OP_AYUDA
if "%OPCION%"=="5" goto OP_SALIR

REM Si llegamos aqui, la entrada no fue un digito valido del 1 al 5.
REM Solo puede pasar en dos casos: el tecnico respondio a la pregunta de
REM Ctrl+C con "no" (choice devuelve 0 o 255) o el modo set /p recibio
REM algo raro. En cualquier caso: NI SE CIERRA NI SE SALE; simplemente
REM repintamos el menu y volvemos a pedir la opcion.
goto MENU

REM =====================================================================
REM  PASO 4 - OPCION [1] PREPARACION RAPIDA DE DISCO  (stub de Fase 2)
REM =====================================================================
:OP_DISCO
cls
call :MOSTRAR_CABECERA
echo(
echo   [1] PREPARACIÓN RÁPIDA DE DISCO
echo   ------------------------------------------------------------------
echo(
echo   Módulo en desarrollo (Fase 2). Esta pantalla NO ejecuta todavía
echo   ningún cambio sobre el hardware: es el punto de partida del flujo.
echo(
echo   El flujo previsto será guiado y con confirmación doble:
echo     Paso 1  Listar discos       diskpart -^> list disk
echo     Paso 2  Elegir disco por ÍNDICE (nunca "adivinar" el destino)
echo     Paso 3  Confirmar borrado  doble confirmación obligatoria
echo     Paso 4  clean + partición primaria + format NTFS rápido
echo     Paso 5  Asignar letra y verificar con: diskpart -^> list volume
echo(
echo   Mientras tanto puedes practicar en modo solo lectura con la
echo   opción 3 (Consola Avanzada) y los comandos:
echo       diskpart     luego: list disk   /   detail disk   /   exit
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para volver al menú..."
goto MENU

REM =====================================================================
REM  PASO 5 - OPCION [2] BORRADO SEGURO / SANITIZACION  (stub Fase 2)
REM =====================================================================
:OP_SANITIZAR
cls
call :MOSTRAR_CABECERA
echo(
echo   [2] BORRADO SEGURO / SANITIZACIÓN
echo   ------------------------------------------------------------------
echo(
echo   Módulo en desarrollo (Fase 2). Tampoco ejecuta cambios todavía.
echo(
echo   Destrucción lógica prevista, según la norma NIST SP 800-88:
echo     Nivel Purge   sobrescribir todas las áreas direccionables del
echo                    disco y después VERIFICAR la sobrescritura.
echo                    Implementación prevista: diskpart -^> clean all
echo                    (escribe ceros en todo el medio; es lento).
echo     Nivel Destroy  invalidar físicamente el medio cuando el nivel
echo                    anterior no sea suficiente para el riesgo.
echo(
echo   DIFERENCIA CLAVE que debes entender:
echo     'clean'      borra solo la tabla de particiones: rápido, pero
echo                   los datos siguen en el disco (recuperables).
echo     'clean all'  sobrescribe el contenido: más lento, destrucción
echo                   lógica real.
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para volver al menú..."
goto MENU

REM =====================================================================
REM  PASO 6 - OPCION [3] CONSOLA AVANZADA (CMD interactivo)
REM =====================================================================
:OP_CONSOLA
cls
call :MOSTRAR_CABECERA
echo(
echo   [3] CONSOLA AVANZADA
echo   ------------------------------------------------------------------
echo(
echo   Abriendo una consola CMD interactiva en la MISMA ventana.
echo(
echo   - Escribe 'exit' para volver al menú principal.
echo   - Heredas el entorno actual (unidad de trabajo, variables).
echo   - OJO: los cambios que hagas en variables NO afectan al menú.
REM     Cada cmd.exe es un proceso con su propio bloque de variables en
REM     memoria; ademas este script esta dentro de 'setlocal', que crea
REM     un ambito aislado que se destruye al terminar.
echo(
echo   Recuerda: primero mira, después actúa. Para discos:
echo       diskpart  -^>  list disk  -^>  detail disk  -^>  exit
echo(

REM 'cmd' sin argumentos lanza un shell hijo interactivo y ESPERA a que
REM el tecnico escriba 'exit'. En ese momento el control regresa a la
REM linea siguiente de este script (vuelta al menu).
REM Nota sobre variantes que veras en otros scripts:
REM   cmd /c comando  -^> ejecuta el comando y TERMINA (no sirve aqui).
REM   cmd /k comando   -^> ejecuta el comando y mantiene el shell abierto.
REM   cmd              -^> shell interactivo completo (lo que queremos).
cmd
goto MENU

REM =====================================================================
REM  PASO 7 - OPCION [4] AYUDA DEL SISTEMA (2 paginas + help nativo)
REM =====================================================================
:OP_AYUDA
cls
call :MOSTRAR_CABECERA
echo(
echo   [4] AYUDA DEL SISTEMA - Página 1 de 2: discos y almacenamiento
echo   ------------------------------------------------------------------
echo(
echo   DISKPART ........................ gestor de discos interactivo
echo       list disk                    discos físicos conectados y tamaños
echo       select disk N                selecciona el disco N
echo                                      ATENCIÓN: N es el ÍNDICE que
echo                                      muestra list disk, no una letra.
echo       detail disk                  informe del disco seleccionado
echo       clean                        borra tabla de particiones (rápido;
echo                                      los datos quedan en el disco)
echo       clean all                    sobrescribe TODO el disco con ceros
echo                                      (lento; destrucción lógica)
echo       create partition primary     crea una partición primaria
echo       format fs=ntfs quick         formateo rápido NTFS
echo       assign letter=Z              asigna letra de unidad
echo       exit                         salir de diskpart
echo(
echo     CHKDSK X: /f /r ............... repara errores de archivo y sectores
echo     FORMAT X: /fs:ntfs /q ......... formateo rápido sin diskpart
echo     DISKPART /s script.txt ........ ejecuta un lote sin interacción
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para continuar con la página 2..."

:OP_AYUDA_P2
cls
call :MOSTRAR_CABECERA
echo(
echo   [4] AYUDA DEL SISTEMA - Página 2 de 2: sistema, red y utilidades
echo   ------------------------------------------------------------------
echo(
echo   SISTEMA E INVENTARIO
echo     systeminfo .................... ficha técnica completa del equipo
echo     wmic bios get serialnumber .... número de serie del equipo
echo     wmic diskdrive get model,size,status ... estado de los discos
echo     wmic os get caption,version ... versión exacta del sistema operativo
echo     sfc /scannow .................. integridad de archivos del sistema
echo(
echo   RED
echo     ipconfig /all ................. configuración IP detallada
echo     ping 8.8.8.8 .................. prueba de salida a Internet
echo     nslookup ejemplo.com .......... prueba de resolución DNS
echo     netstat -an ................... puertos y conexiones abiertas
echo(
echo   FICHEROS Y PROCESOS
echo     dir /s /b nombre.ext .......... busca archivos en subcarpetas
echo     findstr /i "texto" fichero .... busca texto dentro de un fichero
echo     robocopy ORIGEN DESTINO /E .... copia recursiva robusta
echo     tasklist ...................... procesos en marcha
echo     taskkill /IM nombre.exe /F .... fuerza el cierre de un proceso
echo(
echo   Notas para el taller:
echo    - 'wmic' está en desuso en Windows 11; su equivalente moderno en
echo      PowerShell es Get-CimInstance (mismos datos, otra sintaxis).
echo    - En WinPE solo existen los comandos incluidos en la imagen.
echo(
call :LEER_OPCION "   Ejecutar también el 'help' nativo de CMD? [1=Sí / 2=No]:  " "1 2"
if not "%OPCION%"=="1" goto OP_AYUDA_FIN
echo(
echo   --- AYUDA NATIVA DE CMD (rueda del ratón para hacer scroll) ---
echo(
help
:OP_AYUDA_FIN
call :PULSA_TECLA "Pulsa cualquier tecla para volver al menú principal..."
goto MENU

REM =====================================================================
REM  PASO 8 - OPCION [5] SALIR / APAGAR EQUIPO
REM  (todas las acciones de esta seccion piden confirmacion previa)
REM =====================================================================
:OP_SALIR
cls
call :MOSTRAR_CABECERA
echo(
echo   [5] SALIR / APAGAR EQUIPO
echo   ------------------------------------------------------------------
echo(
echo      [1]  Apagar el equipo
echo      [2]  Salir de la herramienta y volver al sistema
echo      [3]  Volver al menú principal (me he equivocado)
echo(
call :LEER_OPCION "   Su opción [1-3]:  " "1 2 3"
if "%OPCION%"=="1" goto CONFIRMAR_APAGADO
if "%OPCION%"=="2" goto FIN_SCRIPT
if "%OPCION%"=="3" goto MENU
REM Entrada no valida (solo posible con Ctrl+C en modo choice): repetimos.
goto OP_SALIR

REM ---------------------------------------------------------------------
REM  Confirmacion EXPLICITA del apagado: doble check. Primero elegimos
REM  apagar y ahora lo confirmamos. Ante cualquier respuesta dudosa
REM  (opcion 2 o entrada rara) volvemos al menu: por defecto, NO se
REM  apaga nada. Esa es la filosofia segura de todo el script.
REM ---------------------------------------------------------------------
:CONFIRMAR_APAGADO
cls
call :MOSTRAR_CABECERA
echo(
echo   !!!  ATENCIÓN  !!!
echo   ------------------------------------------------------------------
echo(
echo   Vas a apagar el equipo. Se interrumpirá cualquier trabajo en
echo   curso y, si arrancaste desde WinPE, terminará la sesión de
echo   recuperación actual (los cambios ya guardados en el arranque RAM
echo   no se conservan).
echo(
call :LEER_OPCION "   Confirmar apagado? [1=Sí / 2=No]:  " "1 2"
if "%OPCION%"=="1" goto DETECTAR_ENTORNO_APAGADO
REM "No" o cualquier respuesta no valida -^> no apagamos y volvemos.
goto MENU

REM ---------------------------------------------------------------------
REM  Deteccion del entorno: WinPE y Windows completo apagan distinto.
REM    wpeutil.exe SOLO existe en WinPE  -^> su ruta de apagado.
REM    shutdown.exe existe en Windows    -^> su ruta de apagado.
REM  Comprobamos primero WinPE porque es el entorno "especial".
REM ---------------------------------------------------------------------
:DETECTAR_ENTORNO_APAGADO
if exist "%SystemRoot%\System32\wpeutil.exe" goto APAGAR_WINPE
goto APAGAR_WINDOWS

:APAGAR_WINPE
echo(
echo   Enviando señal de apagado con wpeutil (entorno WinPE detectado)...
REM wpeutil es la herramienta oficial de WinPE: solo admite un comando
REM por linea y 'shutdown' apaga la sesion inmediatamente.
wpeutil shutdown
goto FIN_APAGADO

:APAGAR_WINDOWS
echo(
echo   Apagado programado en 5 segundos.
echo   Si te arrepientes desde OTRA consola escribe:  shutdown /a
REM   /s   = shutdown (apagar).  /reboot seria para reiniciar.
REM   /t 5 = espera de 5 segundos antes de apagar (tiempo para abortar).
REM   /f   = fuerza el cierre de aplicaciones abiertas.
REM   /c   = mensaje que se muestra en pantalla (va entre comillas).
shutdown /s /t 5 /f /c "%TOOL_NAME%: apagado solicitado por el tecnico."
goto FIN_APAGADO

REM =====================================================================
REM  PASO 9 - SALIDAS ORDENADAS DEL SCRIPT
REM =====================================================================

REM Salida normal (opcion 2 del submenu salir): despedida + pausa para
REM que el tecnico pueda leerla antes de que la ventana se cierre.
:FIN_SCRIPT
echo(
echo   Sesión finalizada. Gracias por usar %TOOL_NAME% v%TOOL_VER%.
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para cerrar..."
endlocal
REM 'exit /b' devuelve el control a quien llamo este script SIN cerrar la
REM ventana: es lo correcto si menu.bat se ejecuta desde otro .bat.
REM Un 'exit' sin '/b' cerraria la instancia de cmd.exe por completo.
exit /b 0

REM Salida tras apagar: SIN pausa, porque el equipo se esta apagando y
REM una espera aqui solo retrasaria el cierre de la sesion WinPE.
:FIN_APAGADO
endlocal
exit /b 0

REM =====================================================================
REM  PASO 10 - SUBRUTINAS INTERNAS (se invocan con 'call :etiqueta')
REM =====================================================================
REM  Una subrutina en batch es simplemente un bloque con etiqueta que se
REM  llama con   call :nombre   y se cierra con   exit /b.
REM  REGLA DE ORO: desde una subrutina NUNCA se sale con 'goto' hacia el
REM  flujo principal; se usa 'exit /b' para volver al llamador. Si haces
REM  goto fuera, cmd descarta implicitamente el punto de retorno y el
REM  flujo se vuelve dificil de razonar (y de depurar).
REM =====================================================================

REM ---------------------------------------------------------------------
REM  MOSTRAR_CABECERA - cabecera grafica reutilizable.
REM  Se llama con 'call' desde todas las pantallas para que la marca,
REM  la version y la fase siempre esten visibles y actualizadas.
REM  (Si cambias TOOL_NAME o TOOL_VER, solo se actualizan aqui: nada de
REM  texto duplicado por el archivo, que es donde nacen los errores.)
REM ---------------------------------------------------------------------
:MOSTRAR_CABECERA
echo   ==========================================================================
echo     %TOOL_NAME%   -   Herramienta de Soporte Técnico
echo     Versión %TOOL_VER%   -   Fase %TOOL_FASE%   -   Entorno: Windows / WinPE
echo   ==========================================================================
exit /b 0

REM ---------------------------------------------------------------------
REM  PULSA_TECLA - pausa con mensaje personalizado.
REM    %~1 = texto a mostrar. El guion '~' delante de 1 "descomilla" el
REM          argumento: si llamamos con "hola", %~1 vale  hola  (sin
REM          comillas), y podemos imprimirlo sin que aparezcan en pantalla.
REM ---------------------------------------------------------------------
:PULSA_TECLA
REM 'echo(' imprime una linea en blanco de forma infalible (mas robusto
REM que 'echo.', que puede confundirse con un archivo llamado echo).
echo(
echo   %~1
REM Redirigimos la salida de 'pause' a NUL: 'pause' imprime su propio
REM mensaje ("Pulsa una tecla para continuar...") y aqui ya hemos dado
REM el nuestro; no queremos dos. La redireccion se escribe ANTES del
REM comando y descarta la salida estandar (STDOUT).
>nul pause
exit /b 0

REM ---------------------------------------------------------------------
REM  LEER_OPCION - captura SEGURA de una opcion numerica.
REM  -------------------------------------------------------------------
REM  USO:    call :LEER_OPCION "texto del prompt" "1 2 3 4 5"
REM            %~1 -^> mensaje que vera el tecnico (sin comillas)
REM            %~2 -^> digitos permitidos, separados por espacios
REM                    (es la LISTA BLANCA de entradas validas)
REM  RESULTADO:
REM            %OPCION% -^> el digito elegido (o vacio, si algo fallo)
REM
REM  Esta subrutina es el corazon de la "captura a prueba de errores":
REM  en ningun escenario (tecla rara, ENTER en vacio, Ctrl+C) el script
REM  se cierra ni sale del menu; como maximo, vuelve a pedir la opcion.
REM ---------------------------------------------------------------------
:LEER_OPCION
set "OPCION="
if "%MODO_ENTRADA%"=="CHOICE" goto LEER_CON_CHOICE
goto LEER_CON_SETP

REM --- Ruta OPTIMA: choice.exe ------------------------------------------
REM choice SOLO admite las teclas indicadas en /c; cualquier otra tecla
REM hace un beep y no devuelve nada, asi que el tecleo erroneo ni siquiera
REM llega a interpretarse. Es imposible que un error de dedo rompa el menu.
:LEER_CON_CHOICE
REM Quitamos los espacios de la lista: choice espera las teclas pegadas
REM (/c 12345) y no separadas (/c 1 2 3 4 5). La sintaxis %CLAVES: =%
REM significa "en CLAVES, sustituye cada espacio por nada" (sintaxis
REM general %VAR:busqueda=reemplazo% con reemplazo vacio = borrar).
set "CLAVES=%~2"
set "CLAVES=%CLAVES: =%"
REM   /n oculta la lista automatica de teclas (nuestro prompt ya la dice)
REM   /m muestra el mensaje que pasamos en %~1
choice /c %CLAVES% /n /m "%~1"
REM choice devuelve en ERRORLEVEL el INDICE de la tecla pulsada (la
REM primera tecla de la lista = 1, la segunda = 2, y asi sucesivamente).
REM Como todos nuestros conjuntos son digitos consecutivos (1..5), el
REM indice coincide con el propio digito: la tecla "3" es la tercera de
REM la lista, luego errorlevel 3 -^> OPCION=3.
REM   Si el tecnico pulsa Ctrl+C y responde "no" a la pregunta de cmd,
REM   choice devuelve 0 (o 255 si hay error): quedara fuera de la lista
REM   blanca y el menu simplemente repintara e insistira.
REM ADVERTENCIA classica: %ERRORLEVEL% es una variable mas y podria ser
REM "sombreada" con 'set errorlevel=...'. No la usamos jamas para eso.
set "OPCION=%errorlevel%"
exit /b 0

REM --- Ruta ALTERNATIVA: set /p -----------------------------------------
REM Se usa solo si la imagen no incluye choice.exe. set /p acepta
REM CUALQUIER texto tecleado, asi que aqui la validacion es NUESTRA
REM responsabilidad: siempre con lista blanca, nunca "confiando".
:LEER_CON_SETP
set "OPCION="
REM set /p escribe en la variable lo que se teclee. Si se pulsa solo
REM ENTER, la variable NO se toca (por eso la limpiamos justo antes:
REM asi ENTER produce OPCION vacia y no una opcion vieja de un bucle
REM anterior, que seria un error GRAVE de seguridad en un menu de borrado).
set /p "OPCION=%~1"
REM --- Sanitizacion (defensa en profundidad) ---
REM Eliminamos comillas y espacios tecleados ANTES de comparar. Por que?
REM Porque la expansion %OPCION% se inserta en la linea del 'if' y un
REM valor con comillas podria desbalancear las comillas de la comparacion
REM y provocar un error de sintaxis que aborte el guion. Quitarle las
REM comillas al valor deja SIEMPRE la linea bien formada:
REM     if "valor_limpio"=="1"  -^> siempre balanceada, nunca rompe.
set "OPCION=%OPCION:"=%"
set "OPCION=%OPCION: =%"
REM --- Lista blanca ---
REM 'for' recorre cada digito de la lista (%~2) y compara con lo
REM tecleado. Si coincide, marcamos VALIDA=1. La comparacion entre
REM comillas neutraliza los simbolos peligrosos tecleados (ampersand,
REM tuberia, mayor y menor que) porque dentro de comillas no son
REM operadores: se imprimen o se comparan, pero no se ejecutan.
set "VALIDA="
for %%D in (%~2) do if "%OPCION%"=="%%D" set "VALIDA=1"
if defined VALIDA exit /b 0
REM Entrada invalida (vacia, de mas de un caracter o fuera de la lista):
REM avisamos y VOLVEMOS A PEDIR sin repintar el menu entero.
echo(
echo   [!] Entrada no válida. Teclea solo uno de los digitos permitidos.
goto LEER_CON_SETP
