@echo off
REM =====================================================================
REM  JAH-WinPe  ::  menu.bat  -  INTERFAZ PRINCIPAL DEL TALLER
REM =====================================================================
REM  PROYECTO   : JAH-WinPe - herramienta de soporte tecnico en consola
REM               (Windows completo y WinPE de arranque).
REM  COMPONENTE : menu.bat -^> pantalla de bienvenida, menu principal,
REM               ayuda del sistema, modulos de disco con diskpart y
REM               salida ordenada.
REM  FASE       : 2 (modulos de disco ACTIVOS: maquetacion rapida y
REM               borrado seguro, siempre con confirmacion escrita).
REM  VERSION    : 1.1.0
REM
REM  --------------------------------------------------------------------
REM  MAPA DE NAVEGACION (etiquetas del script)
REM  --------------------------------------------------------------------
REM    BIENVENIDA  -^> bienvenida una sola vez -^> MENU
REM    MENU        -^> [1] OP_DISCO ......... maquetacion guiada (diskpart)
REM                -^> [2] OP_SANITIZAR ..... borrado seguro    (diskpart)
REM                -^> [3] OP_CONSOLA ....... CMD interactivo
REM                -^> [4] OP_AYUDA ......... 2 paginas + help nativo
REM                -^> [5] OP_SALIR ......... apagar / salir (con confirmacion)
REM    FIN_SCRIPT  -^> salida limpia del script
REM    FIN_APAGADO -^> salida tras solicitar el apagado
REM    (al final)  -^> subrutinas internas invocadas con 'call :etiqueta'
REM
REM    FLUJO DE LAS OPCIONES DE DISCO (comparten las mismas piezas):
REM      PREPARAR_ENTORNO .. carpeta escribible + diskpart + permisos
REM      LISTAR_DISCOS ..... diskpart /s (list disk + list volume)
REM      PEDIR_DISCO ....... numero de disco validado y comprobado
REM      DISCO_EXISTE ...... contraste del numero con el listado
REM      GENERAR_SCRIPT_* .. escribe el guion temporal de diskpart
REM      MOSTRAR_SCRIPT .... imprime el guion (auditoria previa)
REM      CONFIRMAR_DESTR ... el tecnico teclea una palabra literal
REM      EJECUTAR_DISKPART . lanza diskpart /s y muestra su salida
REM      MOSTRAR_RESULTADO . vuelve a listar para verificar
REM      BORRAR_TEMPORALES . limpia los ficheros de trabajo
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
REM      Ademas de pulsar la opcion hay que TECLEAR una palabra literal
REM      (PREPARAR / BORRAR): un tecleo al azar jamas borra un disco.
REM   6) Los comandos de diskpart se escriben en ficheros TEMPORALES con
REM      'echo'. En esas lineas no pueden aparecer simbolos de
REM      redireccion sueltos: cmd los interpretaria como parte del
REM      redireccionamiento y no como texto. Por eso los guiones que
REM      generamos contienen solo comandos simples, sin caracteres raros.
REM
REM  COMO HABLA ESTE SCRIPT CON DISKPART (resumen para mantenimiento):
REM   diskpart admite un guion en texto plano mediante la opcion /s:
REM        diskpart /s "C:\Temp\guion.txt"
REM   Cada linea del guion es UN comando, en orden, sin preguntas.
REM   El script FABRICA ese guion con 'echo', lo ensena en pantalla para
REM   que el tecnico lo revise, lo ejecuta y lo BORRA al terminar.
REM   Ventaja doble: cero errores de tecleo en el momento critico y
REM   trazabilidad exacta de lo que se ha ejecutado.
REM
REM  PENDIENTE PARA FASES SIGUIENTES:
REM   - Registro de actividad (log) persistente en la unidad de arranque.
REM   - Deteccion de firmware (BIOS/UEFI) para elegir GPT o MBR solo.
REM   - Lectura del tamano real del disco para estimar el 'clean all'.
REM   - Localizacion de textos (castellano / ingles).
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
set "TOOL_VER=1.1.0"
set "TOOL_FASE=2"

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

REM --- Deteccion del entorno de ejecucion (se hace UNA sola vez) --------
REM  wpeutil.exe existe SOLO en WinPE. Es el detector mas fiable que hay
REM  sin depender de variables ni de la version de Windows, y nos sirve
REM  para dos cosas distintas:
REM    1) saber si el equipo arranco desde un medio de recuperacion,
REM    2) recordar que en WinPE todos los discos del equipo son
REM       "candidatos", mientras que en Windows completo uno de ellos es
REM       el disco del sistema en ejecucion (el que NO hay que borrar).
set "ES_WINPE=NO"
if exist "%SystemRoot%\System32\wpeutil.exe" set "ES_WINPE=SI"

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
echo        Las opciones 1 y 2 listan los discos antes de preguntar.
echo     2. Las opciones 1 y 2 son DESTRUCTIVAS: borran la tabla de
echo        particiones (y en la opción 2, todo el contenido del disco).
echo        Ninguna actúa sin que tú teclees una palabra de confirmación.
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
echo   Aviso: [1] y [2] modifican DISCOS de verdad y piden confirmación
echo          escrita. [3], [4] y [5] no tocan el hardware por sí solas.
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
REM  PASO 4 - OPCION [1] PREPARACION RAPIDA DE DISCO (maquetacion)
REM =====================================================================
REM  Este bloque es solo el "interruptor": todo el trabajo real vive en
REM  la subrutina MODULO_PREPARAR (PASO 11). Asi el flujo principal se
REM  lee de un vistazo: se elige opcion, se llama al modulo y se vuelve.
REM  'call' ejecuta la subrutina y REGRESA aqui cuando esta cierra con
REM  'exit /b'; despues volvemos al menu, pase lo que pase.
REM =====================================================================
:OP_DISCO
call :MODULO_PREPARAR
goto MENU

REM =====================================================================
REM  PASO 5 - OPCION [2] BORRADO SEGURO / SANITIZACION
REM =====================================================================
REM  Mismo esquema que la opcion 1: el flujo vive en MODULO_SANITIZAR.
REM =====================================================================
:OP_SANITIZAR
call :MODULO_SANITIZAR
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
echo   DISKPART ........................ gestor de discos de Windows
echo       Formas de uso:
echo         diskpart                    abre la consola interactiva
echo         diskpart /s guion.txt       ejecuta un guion de comandos
echo                                     (es lo que hacen las opciones 1 y 2)
echo       list disk                    discos físicos y su tamaño
echo       list volume                  volúmenes/unidades y sus letras
echo       select disk N                elige el disco N (ÍNDICE, no letra)
echo       detail disk                  informe del disco seleccionado
echo       clean                        borra la tabla de particiones
echo                                     (rápido: los datos siguen ahí)
echo       clean all                    sobrescribe TODO con ceros
echo                                     (lento: destrucción lógica)
echo       convert gpt                  pasa el disco a esquema GPT
echo       convert mbr                  pasa el disco a esquema MBR
echo       create partition primary     crea una partición primaria
echo                                     (opcional: size=100000 en MB)
echo       format fs=ntfs quick         formateo rápido en NTFS
echo                                     (opcional: label="SISTEMA")
echo       assign letter=Z              asigna una letra concreta
echo                                     ('assign' solo = letra libre)
echo       exit                         salir de diskpart
echo     Nota: diskpart exige permisos de administrador. En modo /s no
echo     admite teclado: el guion manda y se ejecuta línea a línea.
echo(
echo     CHKDSK X: /f .................. repara errores de la tabla de archivos
echo     CHKDSK X: /r .................. busca sectores dañados (MUY lento)
echo     CHKDSK X: /scan ............... análisis sin desmontar la unidad
echo     FORMAT X: /fs:ntfs /q ......... formateo rápido (sin usar diskpart)
echo     FORMAT X: /fs:ntfs /q /p:1 .... + un pase de ceros (Windows completo)
echo(
echo     Los guiones temporales de las opciones 1 y 2 se crean en la
echo     carpeta temporal del sistema y se borran al terminar.
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
echo     wmic os get caption,version ... versión exacta del sistema operativo
echo     sfc /scannow .................. integridad de archivos del sistema
echo(
echo   ESTADO DE LOS DISCOS (aviso SMART)
echo     wmic diskdrive get status ......... devuelve uno de estos valores:
echo         OK          el disco responde sin avisos de fallo
echo         Pred Fail   aviso de fallo inminente: COPIA los datos YA y
echo                     sustituye el disco (no lo formatees ni lo borres)
echo     wmic diskdrive get model,size,status ... modelo + tamaño + estado
echo     Nota: 'wmic' está en desuso en Windows 11. Su equivalente en
echo     PowerShell es:  Get-CimInstance Win32_DiskDrive
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
echo    - En WinPE solo existen los comandos incluidos en la imagen.
echo      Si un comando no aparece, no está: pruébalo en la opción 3.
echo    - Antes de formatear un disco, mira su estado SMART con la orden
echo      de arriba: un disco con 'Pred Fail' no merece una instalación
echo      nueva (el trabajo se perdería en semanas, no en años).
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

REM =====================================================================
REM  PASO 11 - SUBRUTINAS DE LOS MODULOS DE DISCO (Fase 2)
REM =====================================================================
REM  Aqui vive el trabajo "de verdad": las opciones [1] y [2] del menu
REM  solo hacen 'call :MODULO_...' y vuelven al menu.
REM
REM  IDEA GENERAL antes de leer el codigo:
REM  ------------------------------------------------------------------
REM  diskpart no atiende preguntas ni teclado cuando trabaja con un
REM  guion: recibe UNA LISTA DE COMANDOS en un fichero de texto (opcion
REM  /s) y los ejecuta en orden. Este script construye ese fichero con
REM  'echo', lo imprime en pantalla para que el tecnico lo LEA antes de
REM  ejecutarlo, lo lanza y por ultimo lo BORRA. Los tres beneficios:
REM    1) Cero errores de tecleo en el momento critico (el guion es fijo).
REM    2) Auditoria: el tecnico ve exactamente lo que se va a ejecutar.
REM    3) Repetibilidad: el mismo disco siempre se prepara igual.
REM  Todo guion temporal se guarda en una carpeta escribible (%TEMP% o,
REM  si no existe, la raiz del disco de sistema) y se borra al final.
REM =====================================================================

REM ---------------------------------------------------------------------
REM  LEER_NUMERO - captura y VALIDA un numero tecleado por el tecnico.
REM  -------------------------------------------------------------------
REM  Uso:      call :LEER_NUMERO "texto del prompt" NOMBRE_VARIABLE
REM  Devuelve: la variable indicada (solo si NUM_OK vale SI) y NUM_OK:
REM              SI       -^> numero valido (0, 1, 2, 12...)
REM              NO       -^> entrada invalida (ya se ha avisado)
REM              CANCELAR -^> el tecnico tecleo la letra A
REM
REM  Por que no usar 'choice' aqui? Porque el numero de disco NO es una
REM  lista cerrada: un equipo puede tener 1, 4 o 20 discos. El tecnico
REM  escribe libremente y NOSOTROS comprobamos caracter a caracter.
REM  Ninguna entrada se usa sin pasar por esta validacion.
REM ---------------------------------------------------------------------
:LEER_NUMERO
set "NUM_OK=NO"
set "NUM_TXT="
REM 'set /p' deja la variable INTACTA si se pulsa ENTER sin escribir
REM nada; por eso la limpiamos justo antes: asi ENTER significa
REM "entrada vacia" y no un valor viejo de una vuelta anterior. En un
REM menu de borrado, ese detalle es la diferencia entre no hacer nada
REM y borrar el disco equivocado.
set /p "NUM_TXT=%~1"
if not defined NUM_TXT goto LEER_NUMERO_ERROR
REM --- Limpieza de comillas y espacios (defensa en profundidad) -------
REM Mismo razonamiento que en LEER_OPCION: el valor se va a insertar en
REM lineas 'if "..."=="..."'; si contuviera comillas, podria romper la
REM sintaxis de la linea y abortar el guion.
set "NUM_TXT=%NUM_TXT:"=%"
set "NUM_TXT=%NUM_TXT: =%"
if not defined NUM_TXT goto LEER_NUMERO_ERROR
REM --- Salida voluntaria: la letra A cancela y vuelve al menu ---------
if /i "%NUM_TXT%"=="A" goto LEER_NUMERO_CANCELAR
REM --- Un numero de disco no lleva ceros a la izquierda --------------
if "%NUM_TXT:~0,1%"=="0" if not "%NUM_TXT%"=="0" goto LEER_NUMERO_ERROR
REM --- Recorrido caracter a caracter ---------------------------------
set "TXT=%NUM_TXT%"
set "NUM_LARGO=0"
:LEER_NUMERO_BUCLE
if not defined TXT goto LEER_NUMERO_VALIDO
set "CAR=%TXT:~0,1%"
set "TXT=%TXT:~1%"
call :ES_DIGITO "%CAR%"
if not "%DIGITO_OK%"=="SI" goto LEER_NUMERO_ERROR
REM 'set /a' hace aritmetica entera SIN necesitar expansion retrasada:
REM lee y escribe el valor de la variable por su nombre. La usamos solo
REM para contar caracteres y limitar la longitud (maximo 2 digitos: no
REM existen equipos de taller con mas de 99 discos).
set /a NUM_LARGO+=1
if %NUM_LARGO% GTR 2 goto LEER_NUMERO_ERROR
goto LEER_NUMERO_BUCLE
:LEER_NUMERO_VALIDO
REM Asignacion indirecta: %2 es el NOMBRE de la variable destino. Con
REM 'set "%~2=..."' escribimos en esa variable (aqui no hace falta
REM expansion retrasada porque solo ESCRIBIMOS, no leemos).
set "%~2=%NUM_TXT%"
set "NUM_OK=SI"
exit /b 0
:LEER_NUMERO_CANCELAR
set "NUM_OK=CANCELAR"
exit /b 0
:LEER_NUMERO_ERROR
echo(
echo   [!] Entrada no válida: escribe SOLO el número de disco (por
echo       ejemplo: 0, 1, 2, 10), sin ceros a la izquierda, o la letra
echo       A para cancelar y volver al menú.
set "NUM_OK=NO"
exit /b 0

REM ---------------------------------------------------------------------
REM  ES_DIGITO - comprueba si un caracter es un digito del 0 al 9.
REM  -------------------------------------------------------------------
REM  Uso:      call :ES_DIGITO "%CAR%"  (siempre el caracter entre comillas)
REM  Devuelve: DIGITO_OK = SI / NO
REM
REM  Detalle didactico: diez comparaciones explicitas son mas faciles de
REM  revisar para un tecnico que empieza que una expresion regular. El
REM  rendimiento es irrelevante (el bucle recorre 2 caracteres).
REM ---------------------------------------------------------------------
:ES_DIGITO
set "DIGITO_OK=NO"
set "DIGITO=%~1"
if "%DIGITO%"=="0" set "DIGITO_OK=SI"
if "%DIGITO%"=="1" set "DIGITO_OK=SI"
if "%DIGITO%"=="2" set "DIGITO_OK=SI"
if "%DIGITO%"=="3" set "DIGITO_OK=SI"
if "%DIGITO%"=="4" set "DIGITO_OK=SI"
if "%DIGITO%"=="5" set "DIGITO_OK=SI"
if "%DIGITO%"=="6" set "DIGITO_OK=SI"
if "%DIGITO%"=="7" set "DIGITO_OK=SI"
if "%DIGITO%"=="8" set "DIGITO_OK=SI"
if "%DIGITO%"=="9" set "DIGITO_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  COMPROBAR_ADMIN - averigua si la consola tiene privilegios.
REM  -------------------------------------------------------------------
REM  Devuelve ES_ADMIN = SI / NO.
REM  Estrategia: en WinPE ya se ejecuta como SYSTEM (nada que comprobar);
REM  en Windows completo se usa 'fltmc' (administrador de filtros del
REM  sistema), un comando inocuo que falla con "acceso denegado" si la
REM  consola no esta elevada. Es la prueba mas sencilla y sin efectos.
REM ---------------------------------------------------------------------
:COMPROBAR_ADMIN
set "ES_ADMIN=SI"
if exist "%SystemRoot%\System32\wpeutil.exe" exit /b 0
if not exist "%SystemRoot%\System32\fltmc.exe" exit /b 0
fltmc >nul 2>&1
if errorlevel 1 set "ES_ADMIN=NO"
exit /b 0

REM ---------------------------------------------------------------------
REM  PREPARAR_ENTORNO - deja listo el terreno antes de tocar un disco.
REM  -------------------------------------------------------------------
REM  Devuelve ENTORNO_OK = SI / NO. Si es NO, el modulo NO continua:
REM  preferimos no hacer nada a hacer algo a medias.
REM  Comprueba, por este orden:
REM    1) Que exista una carpeta ESCRIBIBLE para los ficheros de trabajo.
REM    2) Que diskpart.exe este disponible en esta imagen.
REM    3) Que la consola tenga permisos (avisando, no bloqueando).
REM ---------------------------------------------------------------------
:PREPARAR_ENTORNO
set "ENTORNO_OK=NO"
REM --- 1) Carpeta de trabajo ------------------------------------------
REM Preferimos %TEMP% (escribible para el usuario actual; en WinPE suele
REM ser la RAM del arranque X:\...). Si no existiera, caemos a la raiz
REM del disco de sistema y, en ultimo caso, al directorio actual.
set "DIR_TRABAJO="
if defined TEMP if exist "%TEMP%\" set "DIR_TRABAJO=%TEMP%"
if not defined DIR_TRABAJO if exist "%SystemDrive%\" set "DIR_TRABAJO=%SystemDrive%"
if not defined DIR_TRABAJO set "DIR_TRABAJO=."
REM --- 2) Prueba REAL de escritura ------------------------------------
REM Que la carpeta exista no garantiza poder escribir en ella (medios de
REM solo lectura, permisos...). Creamos y borramos un fichero de prueba:
REM es la unica forma honesta de saberlo.
set "F_PRUEBA=%DIR_TRABAJO%\_jah_prueba.tmp"
echo prueba> "%F_PRUEBA%" 2>nul
if not exist "%F_PRUEBA%" goto PREPARAR_ENTORNO_SIN_ESCRITURA
del /f /q "%F_PRUEBA%" >nul 2>&1
REM --- 3) Ficheros de trabajo -----------------------------------------
set "F_SCRIPT=%DIR_TRABAJO%\_jah_diskpart.txt"
set "F_SALIDA=%DIR_TRABAJO%\_jah_diskpart_salida.txt"
REM Borramos restos de una ejecucion anterior: asi nunca se puede
REM ejecutar por error un guion viejo (o el de otro disco).
call :BORRAR_TEMPORALES
REM --- 4) Esta diskpart disponible? -----------------------------------
if not exist "%SystemRoot%\System32\diskpart.exe" goto PREPARAR_ENTORNO_SIN_DISKPART
REM --- 5) Permisos ----------------------------------------------------
call :COMPROBAR_ADMIN
if "%ES_ADMIN%"=="SI" goto PREPARAR_ENTORNO_LISTO
echo   [!] Esta consola NO parece tener permisos de administrador.
echo       diskpart podrá listar los discos, pero NO podrá modificarlos
echo       (devolverá "acceso denegado" en 'clean').
echo(
call :LEER_OPCION "   Continuar de todos modos? [1=Sí / 2=No]:  " "1 2"
if not "%OPCION%"=="1" exit /b 0
:PREPARAR_ENTORNO_LISTO
set "ENTORNO_OK=SI"
exit /b 0

:PREPARAR_ENTORNO_SIN_ESCRITURA
echo(
echo   [!] No he podido crear ficheros de trabajo en:
echo           %DIR_TRABAJO%
echo       Sin una carpeta escribible no puedo generar el guion de
echo       diskpart, y sin guion no se ejecuta nada. ABORTAMOS sin
echo       tocar ningún disco (la seguridad primero).
echo(
exit /b 0

:PREPARAR_ENTORNO_SIN_DISKPART
echo(
echo   [!] No encuentro diskpart.exe en esta imagen.
echo       ¿Es un WinPE muy recortado? Este módulo no puede continuar.
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  BORRAR_TEMPORALES - higiene: elimina los ficheros de trabajo.
REM  -------------------------------------------------------------------
REM  Se llama AL EMPEZAR (para no arrastrar restos de otra sesion) y AL
REM  TERMINAR. Borrar el guion es especialmente importante: es una
REM  "receta" de borrado con un numero de disco escrito dentro; no debe
REM  quedarse por ahi para que alguien la ejecute por error mas tarde.
REM  Las redirecciones a NUL silencian fallos (si el fichero no existe,
REM  'del' avisaria y no queremos ensuciar la pantalla: no es un error).
REM ---------------------------------------------------------------------
:BORRAR_TEMPORALES
if exist "%F_SCRIPT%" del /f /q "%F_SCRIPT%" >nul 2>&1
if exist "%F_SALIDA%" del /f /q "%F_SALIDA%" >nul 2>&1
if exist "%F_PRUEBA%" del /f /q "%F_PRUEBA%" >nul 2>&1
exit /b 0

REM ---------------------------------------------------------------------
REM  DISCO_EXISTE - intenta comprobar que el disco elegido existe.
REM  -------------------------------------------------------------------
REM  Entrada:  %DISCO% (el numero validado) y %F_SALIDA% (listado previo)
REM  Devuelve: EXISTE = SI / NO / ?
REM
REM  COMO se comprueba: se busca en el listado ya capturado una linea que
REM  empiece por "Disk N " o "Disco N " (diskpart traduce sus mensajes:
REM  en un Windows en espanol los discos aparecen como "Disco 0"). Con
REM  'findstr /c:' la busqueda es LITERAL, espacios incluidos, de modo
REM  que "Disk 1 " nunca confunde al Disco 1 con el Disco 10.
REM
REM  LIMITACION HONESTA: si el idioma del sistema usa otras palabras, la
REM  comprobacion no encuentra nada y devolvemos "?" para que PEDIR_DISCO
REM  pregunte al tecnico en vez de decidir por el. Nunca inventamos un
REM  "si" ni un "no": ante la duda, manda la persona.
REM ---------------------------------------------------------------------
:DISCO_EXISTE
set "EXISTE=NO"
if not defined DISCO exit /b 0
if not exist "%F_SALIDA%" goto DISCO_EXISTE_DUDA
REM findstr puede faltar en WinPE muy recortados: si no esta, dudamos.
if not exist "%SystemRoot%\System32\findstr.exe" goto DISCO_EXISTE_DUDA
findstr /c:"Disk %DISCO% " "%F_SALIDA%" >nul 2>&1
if not errorlevel 1 set "EXISTE=SI"
findstr /c:"Disco %DISCO% " "%F_SALIDA%" >nul 2>&1
if not errorlevel 1 set "EXISTE=SI"
exit /b 0
:DISCO_EXISTE_DUDA
set "EXISTE=?"
exit /b 0

REM ---------------------------------------------------------------------
REM  PEDIR_DISCO - pide, valida y confirma el numero de disco a usar.
REM  -------------------------------------------------------------------
REM  Devuelve DISCO (numero) y DISCO_OK = SI / NO.
REM  Bucle de seguridad: no se sale de aqui hasta tener un numero valido
REM  o hasta que el tecnico cancele con la letra A.
REM ---------------------------------------------------------------------
:PEDIR_DISCO
set "DISCO_OK=NO"
set "DISCO="
if not "%LISTADO_OK%"=="SI" exit /b 0
:PEDIR_DISCO_BUCLE
echo(
echo   ------------------------------------------------------------------
echo   Teclea el NUMERO de disco sobre el que quieres trabajar.
echo   Ese numero es la PRIMERA columna del listado de arriba
echo   (Disk 0 / Disco 0, Disk 1 / Disco 1...). Nunca es una letra.
echo   Para cancelar y volver al menu: teclea  A  y pulsa ENTER.
echo   ------------------------------------------------------------------
call :LEER_NUMERO "   Número de disco:  " DISCO
if "%NUM_OK%"=="CANCELAR" exit /b 0
if not "%NUM_OK%"=="SI" goto PEDIR_DISCO_BUCLE
REM --- Contraste con el listado ya capturado --------------------------
call :DISCO_EXISTE
if "%EXISTE%"=="SI" goto PEDIR_DISCO_OK
echo(
echo   [!] NO he podido confirmar que el Disco %DISCO% aparezca en el
echo       listado. Puede ser por dos motivos:
echo         a) el número no existe (te has equivocado al leerlo), o
echo         b) tu Windows traduce el listado con otras palabras y la
echo            comprobación automática no sabe reconocerlo.
echo(
call :LEER_OPCION "   ¿Qué hacemos? [1=Corregir / 2=Continuar / 3=Cancelar]:  " "1 2 3"
if "%OPCION%"=="1" goto PEDIR_DISCO_BUCLE
if "%OPCION%"=="2" goto PEDIR_DISCO_OK
exit /b 0
:PEDIR_DISCO_OK
set "DISCO_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  CONFIRMAR_DESTRUCTIVO - la barrera humana antes de destruir datos.
REM  -------------------------------------------------------------------
REM  Uso:      call :CONFIRMAR_DESTRUCTIVO "PALABRA" [DISCO]
REM    %~1 = palabra que el tecnico debe teclear EXACTAMENTE (lista blanca
REM          textual: "PREPARAR" o "BORRAR"). No vale un ENTER, ni "si",
REM          ni cualquier otra cosa: si no coincide, no se hace nada.
REM    %~2 = si vale DISCO, se pide ADEMAS repetir el numero de disco
REM          (doble control: palabra + numero). Se usa en el borrado
REM          seguro, que es irreversible.
REM  Devuelve CONFIRMADO = SI / NO.
REM
REM  Por que teclear una palabra y no pulsar "s"? Porque un ENTER de mas
REM  o una tecla rozada no se parece en nada a escribir BORRAR. Es el
REM  mismo principio que usan los sistemas serios para acciones
REM  irreversibles, y aqui cuesta dos segundos que ahorran un desastre.
REM ---------------------------------------------------------------------
:CONFIRMAR_DESTRUCTIVO
set "CONFIRMADO=NO"
set "CONF_TXT="
set /p "CONF_TXT=   Para continuar, teclea %~1 y pulsa ENTER (ENTER vacío cancela): "
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT:"=%"
set "CONF_TXT=%CONF_TXT: =%"
if /i not "%CONF_TXT%"=="%~1" goto CONFIRMAR_DESTRUCTIVO_NO
if "%~2"=="DISCO" goto CONFIRMAR_DESTRUCTIVO_DISCO
set "CONFIRMADO=SI"
exit /b 0
:CONFIRMAR_DESTRUCTIVO_DISCO
set "CONF_DISCO="
set /p "CONF_DISCO=   Repite el NÚMERO del disco afectado (%DISCO%) para confirmar: "
if not defined CONF_DISCO goto CONFIRMAR_DESTRUCTIVO_NO
set "CONF_DISCO=%CONF_DISCO:"=%"
set "CONF_DISCO=%CONF_DISCO: =%"
if "%CONF_DISCO%"=="%DISCO%" set "CONFIRMADO=SI"
if not "%CONFIRMADO%"=="SI" goto CONFIRMAR_DESTRUCTIVO_NO
exit /b 0
:CONFIRMAR_DESTRUCTIVO_NO
echo(
echo   [i] Confirmación no reconocida: NO se ha ejecutado nada.
exit /b 0

REM ---------------------------------------------------------------------
REM  GENERAR_SCRIPT_MAQUETAR - escribe el guion de la opcion [1].
REM  -------------------------------------------------------------------
REM  Cada linea del guion es UN comando de diskpart, en este orden:
REM    select disk N           elige el disco (obligatorio antes de nada)
REM    clean                   borra la tabla de particiones (rapido)
REM    convert gpt             esquema GPT (el que pide UEFI moderno)
REM    create partition primary  una particion con TODO el espacio libre
REM    format fs=ntfs quick label="SISTEMA"  NTFS rapido con etiqueta
REM    assign                  asigna la primera letra de unidad libre
REM  'echo' escribe cada linea en el fichero temporal. La PRIMERA linea
REM  usa una redireccion simple (crea el fichero de cero) y las
REM  siguientes una doble (anaden sin borrar lo anterior).
REM ---------------------------------------------------------------------
:GENERAR_SCRIPT_MAQUETAR
if not defined DISCO exit /b 0
> "%F_SCRIPT%" echo rem JAH-WinPe - maquetacion rapida del Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean
>> "%F_SCRIPT%" echo convert gpt
>> "%F_SCRIPT%" echo create partition primary
>> "%F_SCRIPT%" echo format fs=ntfs quick label="SISTEMA"
>> "%F_SCRIPT%" echo assign
exit /b 0

REM ---------------------------------------------------------------------
REM  GENERAR_SCRIPT_BORRAR - escribe el guion de la opcion [2].
REM  -------------------------------------------------------------------
REM    select disk N   elige el disco
REM    clean all       escribe CEROS en todas las areas direccionables:
REM                    destruccion logica de los datos (lenta).
REM  Nota: no anadimos 'convert gpt' ni formateo. Un disco sanitizado se
REM  deja EN BRUTO a proposito: asi se ve que ya no queda nada y el
REM  tecnico decide despues (por ejemplo, con la opcion [1]).
REM ---------------------------------------------------------------------
:GENERAR_SCRIPT_BORRAR
if not defined DISCO exit /b 0
> "%F_SCRIPT%" echo rem JAH-WinPe - borrado seguro (clean all) del Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean all
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_SCRIPT - imprime el guion generado (auditoria previa).
REM  -------------------------------------------------------------------
REM  Ensenar el guion ANTES de ejecutarlo es la parte mas valiosa del
REM  diseno: lo que se va a hacer deja de ser una caja negra. El tecnico
REM  puede leerlo, compararlo con lo que espera y cancelar si algo no
REM  cuadra. Un fichero de texto plano se revisa en dos segundos.
REM ---------------------------------------------------------------------
:MOSTRAR_SCRIPT
echo   ------------------------------------------------------------------
echo   GUION TEMPORAL que se va a ejecutar (%F_SCRIPT%):
echo   ------------------------------------------------------------------
type "%F_SCRIPT%"
echo   ------------------------------------------------------------------
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  EJECUTAR_DISKPART - lanza el guion temporal y muestra el resultado.
REM  -------------------------------------------------------------------
REM  Por que SIN redireccion? Porque 'clean all' puede tardar HORAS y
REM  diskpart informa del avance (porcentaje) en la propia pantalla. Si
REM  guardaramos el texto en un fichero, el tecnico veria una ventana
REM  congelada sin saber si el trabajo sigue vivo... y un proceso que
REM  parece colgado se interrumpe (lo peor que se puede hacer aqui).
REM  El codigo de salida (ERRORLEVEL) sigue disponible aunque no se
REM  capture el texto, y lo consultamos justo despues.
REM ---------------------------------------------------------------------
:EJECUTAR_DISKPART
echo(
echo   ------------------------------------------------------------------
echo   EJECUTANDO DISKPART. No pulses teclas, no cierres la ventana y no
echo   apagues el equipo mientras el comando esté en curso.
echo   ------------------------------------------------------------------
echo(
diskpart /s "%F_SCRIPT%"
set "RESULTADO=%errorlevel%"
echo(
echo   ------------------------------------------------------------------
if "%RESULTADO%"=="0" echo   [OK] diskpart terminó sin errores (código 0).
if not "%RESULTADO%"=="0" echo   [!] diskpart devolvió el código de error %RESULTADO%.
echo   ------------------------------------------------------------------
echo(
echo   Nota: diskpart escribe en el idioma del sistema. Si ves caracteres
echo   raros, prueba en la Consola Avanzada:  chcp 850   y luego  chcp 65001
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_RESULTADO - verificacion: volvemos a listar el equipo.
REM  -------------------------------------------------------------------
REM  Nunca damos por bueno un borrado "porque no hubo error": se vuelve
REM  a listar y se COMPRUEBA con los ojos. Reutilizamos LISTAR_DISCOS
REM  (misma pieza de codigo, cero duplicacion) y anadimos la lectura.
REM ---------------------------------------------------------------------
:MOSTRAR_RESULTADO
echo   VERIFICACIÓN FINAL: este es el estado ACTUAL del equipo.
call :LISTAR_DISCOS
echo   Cómo comprobar el resultado:
echo     - Maquetación (opción 1): el Disco %DISCO% debe mostrar Gpt y,
echo       en 'list volume', un volumen SISTEMA en NTFS con su letra.
echo     - Borrado seguro (opción 2): el Disco %DISCO% aparecerá EN BRUTO
echo       (sin particiones ni volúmenes). Eso es lo correcto.
echo     - Si el disco no muestra el resultado esperado, revisa el aviso
echo       que dio diskpart antes de repetir cualquier operación.
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  LISTAR_DISCOS - muestra los discos fisicos y los volumenes actuales.
REM  -------------------------------------------------------------------
REM  Devuelve LISTADO_OK = SI / NO.
REM  Se usa dos veces en cada modulo: al empezar (para elegir con datos a
REM  la vista) y al terminar (para verificar). Es SIEMPRE de solo
REM  lectura: 'list disk' y 'list volume' no modifican nada.
REM  Por que se captura la salida a un fichero y luego se imprime con
REM  'type'? Para poder conservarla y analizarla (DISCO_EXISTE busca en
REM  ella) ademas de mostrarla. La captura une la salida de error a la
REM  normal (dos mayor que ampersand uno) para no perder ningun aviso
REM  de diskpart.
REM ---------------------------------------------------------------------
:LISTAR_DISCOS
set "LISTADO_OK=NO"
echo(
echo   Consultando los discos del equipo con diskpart (solo lectura)...
echo(
> "%F_SCRIPT%" echo rem JAH-WinPe - listado del equipo (solo lectura)
>> "%F_SCRIPT%" echo list disk
>> "%F_SCRIPT%" echo list volume
diskpart /s "%F_SCRIPT%" > "%F_SALIDA%" 2>&1
set "RESULTADO_LISTADO=%errorlevel%"
if not "%RESULTADO_LISTADO%"=="0" goto LISTAR_DISCOS_FIN
type "%F_SALIDA%"
echo(
echo   Cómo leer este listado:
echo     - 'list disk'    los discos físicos: mira la PRIMERA columna
echo                      (Disk 0, Disk 1...) y compárala con el TAMAÑO.
echo     - Estado 'Online' o 'En línea': el disco está operativo.
echo     - La marca '*' en la columna 'Gpt' significa que ya es GPT.
echo     - 'list volume'  qué volúmenes hay y con qué LETRA de unidad.
echo     - Truco de seguridad: mira la ETIQUETA del disco en la caja del
echo       equipo. Un disco de 500 GB no puede ser el de 1 TB.
echo(
set "LISTADO_OK=SI"
exit /b 0
:LISTAR_DISCOS_FIN
echo   [!] diskpart no ha podido completar el listado (código %RESULTADO_LISTADO%).
echo       Sin listado no se puede elegir disco con seguridad: volvemos
echo       al menú sin tocar nada.
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  MODULO_PREPARAR - opcion [1]: maquetacion rapida del disco elegido.
REM  -------------------------------------------------------------------
REM  Cadena de pasos (cada uno puede cancelar el siguiente):
REM    entorno -^> listar -^> elegir disco -^> generar guion -^> ensenarlo
REM    -^> confirmar por escrito -^> ejecutar -^> verificar -^> limpiar
REM ---------------------------------------------------------------------
:MODULO_PREPARAR
cls
call :MOSTRAR_CABECERA
echo(
echo   [1] PREPARACIÓN RÁPIDA DE DISCO (maquetación)
echo   ------------------------------------------------------------------
echo(
echo   Este módulo deja un disco listo para instalar Windows:
echo(
echo     a) Lista los discos físicos y sus tamaños (diskpart, solo lectura).
echo     b) Te pide el NÚMERO del disco a preparar (entrada validada).
echo     c) Genera el guion de diskpart con los comandos exactos y te lo
echo        muestra para que lo leas ANTES de ejecutar nada.
echo     d) Exige que teclees la palabra PREPARAR para continuar.
echo     e) Ejecuta y vuelve a listar el equipo para verificar.
echo(
echo   Orden exacto de comandos:  clean  -^>  convert gpt  -^>
echo   create partition primary  -^>  format fs=ntfs quick label=SISTEMA
echo   -^>  assign (letra libre que Windows elija).
echo(
echo   RECUERDA: 'clean' borra la tabla de particiones del disco elegido.
echo   Todo lo que hubiera en él dejará de ser visible de inmediato.
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para empezar por el listado..."
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :LISTAR_DISCOS
call :PEDIR_DISCO
if not "%DISCO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :GENERAR_SCRIPT_MAQUETAR
cls
call :MOSTRAR_CABECERA
echo(
echo   [1] PREPARACIÓN RÁPIDA DE DISCO - RESUMEN Y CONFIRMACIÓN
echo   ------------------------------------------------------------------
echo(
echo   Disco elegido:  Disco %DISCO%
echo   Acción:         borrar la tabla de particiones y crear una única
echo                   partición GPT NTFS con la etiqueta SISTEMA.
echo(
call :MOSTRAR_SCRIPT
if "%ES_WINPE%"=="SI" goto MODULO_PREPARAR_AVISO_OK
echo   [!] Estás en Windows COMPLETO, no en WinPE. Si el Disco %DISCO%
echo       fuera el disco donde está instalado el sistema en ejecución,
echo       esta operación lo dejaría inservible. Ante la mínima duda:
echo       cancela y comprueba antes con 'list volume' (letra C:).
echo(
:MODULO_PREPARAR_AVISO_OK
call :CONFIRMAR_DESTRUCTIVO "PREPARAR"
if not "%CONFIRMADO%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :EJECUTAR_DISKPART
call :MOSTRAR_RESULTADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "Módulo terminado. Pulsa cualquier tecla para volver al menú..."
exit /b 0

:MODULO_PREPARAR_CANCELADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "Operación cancelada: no se ha tocado ningún disco."
exit /b 0

REM ---------------------------------------------------------------------
REM  MODULO_SANITIZAR - opcion [2]: borrado seguro (clean all).
REM  -------------------------------------------------------------------
REM  Mismos pasos que la opcion 1, con dos diferencias por ser
REM  IRREVERSIBLE: el aviso del tiempo estimado y la doble confirmacion
REM  (palabra BORRAR + repetir el numero de disco).
REM ---------------------------------------------------------------------
:MODULO_SANITIZAR
cls
call :MOSTRAR_CABECERA
echo(
echo   [2] BORRADO SEGURO / SANITIZACIÓN
echo   ------------------------------------------------------------------
echo(
echo   Qué hace: escribe CEROS sobre todas las áreas direccionables del
echo   disco para que los datos anteriores no se puedan recuperar con
echo   utilidades de recuperación. En diskpart:  clean all
echo(
echo   Marco de referencia (NIST SP 800-88, nivel PURGE):
echo     'clean'      destruye solo la tabla de particiones (segundos),
echo                  pero los datos siguen en el disco: se recuperan.
echo     'clean all'  sobrescribe el contenido (horas) y la recuperación
echo                  práctica deja de ser viable. Es lo que haremos.
echo   Para el nivel DESTROY (destrucción física del medio) no hay
echo   software que valga: trituradora o incineradora certificadas.
echo(
call :PULSA_TECLA "Pulsa cualquier tecla para empezar por el listado..."
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :LISTAR_DISCOS
call :PEDIR_DISCO
if not "%DISCO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :GENERAR_SCRIPT_BORRAR
cls
call :MOSTRAR_CABECERA
echo(
echo   [2] BORRADO SEGURO - RESUMEN Y CONFIRMACIÓN
echo   ------------------------------------------------------------------
echo(
echo   Disco elegido:  Disco %DISCO%
echo   Acción:         clean all  (sobrescritura completa con ceros)
echo(
echo   TIEMPO ESTIMADO (orientativo; depende del disco y de su conexión):
echo     Disco de 250 GB ......... de 30 a 60 minutos
echo     Disco de 500 GB ......... de 1 a 2 horas
echo     Disco de 1 TB ........... de 2 a 4 horas
echo     Disco de 2 TB ........... de 4 a 8 horas
echo     SSD (mejor por USB) ..... suele ir más rápido, pero ver aviso
echo(
echo   AVISOS IMPORTANTES:
echo     - NO interrumpas el proceso (ni teclas, ni reinicio, ni apagado):
echo       un 'clean all' a medias deja el disco en un estado irregular.
echo     - En SSD, 'clean all' NO garantiza el borrado físico: el
echo       controlador reparte las escrituras. Para eso se usa la
echo       herramienta del fabricante o el ATA Secure Erase.
echo     - Si el disco ya tiene fallos físicos, esto no los arregla.
echo     - Un disco sanitizado queda EN BRUTO (sin particiones): luego
echo       puedes maquetarlo con la opción [1].
echo(
if "%ES_WINPE%"=="SI" goto MODULO_SANITIZAR_AVISO_OK
echo   [!] Estás en Windows COMPLETO, no en WinPE. Comprueba que el
echo       Disco %DISCO% NO sea el del sistema en ejecución: en 'list
echo       volume' busca qué disco contiene la letra C:. Si hay duda,
echo       cancela ahora.
echo(
:MODULO_SANITIZAR_AVISO_OK
call :MOSTRAR_SCRIPT
echo   Para el borrado seguro se piden DOS confirmaciones escritas.
echo(
call :CONFIRMAR_DESTRUCTIVO "BORRAR" DISCO
if not "%CONFIRMADO%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :EJECUTAR_DISKPART
call :MOSTRAR_RESULTADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "Módulo terminado. Pulsa cualquier tecla para volver al menú..."
exit /b 0

:MODULO_SANITIZAR_CANCELADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "Operación cancelada: no se ha tocado ningún disco."
exit /b 0
