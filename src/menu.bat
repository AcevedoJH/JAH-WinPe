@echo off
REM =====================================================================
REM  JAH-WinPe  ::  menu.bat  -  INTERFAZ PRINCIPAL DEL TALLER
REM =====================================================================
REM  PROYECTO   : JAH-WinPe - herramienta de soporte tecnico en consola
REM               (Windows completo y WinPE de arranque).
REM  COMPONENTE : menu.bat -^> seleccion de idioma, pantalla de bienvenida,
REM               menu principal, ayuda del sistema, modulos de disco con
REM               diskpart, ESCUDO DE SEGURIDAD del disco de arranque,
REM               DETECCION DE FIRMWARE (UEFI / Legacy), REGISTRO DE
REM               ACTIVIDAD (log) y salida ordenada.
REM  FASE       : 4.0 (deteccion de firmware que adapta el esquema de
REM               particionado GPT/MBR y sistema de AUDITORIA persistente
REM               en 'jah-winpe.log'; se conservan el ESCUDO DE SEGURIDAD
REM               del disco de arranque y el programa MULTILENGUAJE
REM               castellano / ingles de las fases anteriores).
REM  VERSION    : 1.4.0
REM
REM  --------------------------------------------------------------------
REM  MAPA DE NAVEGACION (etiquetas del script)
REM  --------------------------------------------------------------------
REM    SELECCION_IDIOMA -^> elegir castellano/ingles -^> BIENVENIDA
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
REM    MULTILENGUAJE (i18n) -^> ver PASO 2 y ANEXO A:
REM      CARGAR_IDIOMA ..... carga el bloque de textos del idioma activo
REM      IDIOMA_ES ......... diccionario castellano (%LANG%=ES)
REM      IDIOMA_EN ......... diccionario ingles    (%LANG%=EN)
REM      (todo el texto visible sale de variables %T_xxx%: la logica de
REM       los modulos de disco es UNICA y no se duplica por idioma)
REM
REM    FLUJO DE LAS OPCIONES DE DISCO (comparten las mismas piezas):
REM      PREPARAR_ENTORNO .. carpeta escribible + diskpart + permisos
REM      LISTAR_DISCOS ..... diskpart /s (list disk + list volume)
REM      DETECTAR_DISCO_AR . DISCO DE ARRANQUE detectado (PowerShell o
REM                          diskpart) y variables del escudo de seguridad
REM      PEDIR_DISCO ....... numero de disco validado y comprobado
REM      DISCO_EXISTE ...... contraste del numero con el listado
REM      COMPROBAR_DISCO_S . BLOQUEA la operacion si es el disco de arranque
REM      MOSTRAR_BLOQUEO ... pantalla ROJA de denegacion
REM      EVALUAR_SEGURIDAD . decide si hace falta la palabra de RIESGO
REM      GENERAR_SCRIPT_* .. escribe el guion temporal de diskpart
REM      MOSTRAR_SCRIPT .... imprime el guion (auditoria previa)
REM      CONFIRMAR_DESTR ... el tecnico teclea CONFIRMAR + el numero
REM      EJECUTAR_DISKPART . lanza diskpart /s y muestra su salida
REM      MOSTRAR_RESULTADO . vuelve a listar para verificar
REM      BORRAR_TEMPORALES . limpia los ficheros de trabajo
REM
REM    FLUJO DEL FIRMWARE Y DE LA AUDITORIA (Fase 4):
REM      DETECTAR_FIRMWARE . UEFI o Legacy -^> rellena FIRMWARE y
REM                          FIRMWARE_FORMATO (GPT para UEFI, MBR para
REM                          Legacy). No imprime nada: solo prepara datos.
REM      ELEGIR_FORMATO_DUDA si el firmware NO se pudo verificar, pregunta
REM                          al tecnico que esquema aplicar (nunca adivina).
REM      PREPARAR_LOG ...... elige DONDE guardar 'jah-winpe.log' (junto al
REM                          script o en otro disco conectado; si no hay,
REM                          en la RAM con aviso de que se perdera).
REM      REGISTRAR ......... anota UNA linea con fecha, hora, tipo de
REM                          evento, detalle y resultado (auditoria).
REM
REM    NOTA: los textos del log se escriben en castellano tecnico (es un
REM    registro de auditoria para el taller), pero los AVISOS de pantalla
REM    SI se traducen con el diccionario del ANEXO A.
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
REM      Y repetir el numero de disco: en castellano CONFIRMAR / RIESGO,
REM      en ingles CONFIRM / RISK (se guardan en T_CFM_05 y T_CFM_06).
REM      Un tecleo al azar jamas borra un disco. Nota: son palabras SIN
REM      espacios, porque el script las compara tras quitar espacios al
REM      texto tecleado (y en comparaciones sensibles a mayusculas, con
REM      'if /i': CONFIRMAR y confirmar valen lo mismo).
REM   6) Los comandos de diskpart se escriben en ficheros TEMPORALES con
REM      'echo'. En esas lineas no pueden aparecer simbolos de
REM      redireccion sueltos: cmd los interpretaria como parte del
REM      redireccionamiento y no como texto. Por eso los guiones que
REM      generamos contienen solo comandos simples, sin caracteres raros.
REM   7) MULTILENGUAJE: ningun texto visible para el tecnico se escribe
REM      'a pelo' en las secciones de flujo. Todo sale de variables
REM      %T_xxx% del diccionario (ANEXO A). Si anades un texto, anadelo
REM      con el MISMO nombre en los DOS idiomas o quedara en blanco en el
REM      idioma que no lo tenga. Las variables de idioma se llaman igual
REM      en ambos bloques a proposito: asi el codigo es unico.
REM   8) ESCUDO DE SEGURIDAD (Fase 2.8): el disco de ARRANQUE del equipo
REM      (el que lleva el sistema en ejecucion o el medio del que se ha
REM      arrancado) se DETECTA al principio de cada modulo de disco y
REM      queda PROHIBIDO: si el tecnico lo elige, la operacion se DENEGA
REM      en pantalla roja y no se escribe ni se ejecuta ningun guion.
REM      Si el disco no puede identificarse, el script NO calla: avisa y
REM      exige una palabra de RIESGO antes de seguir. Ver el bloque
REM      ESCUDO DE SEGURIDAD en PASO 12.
REM --------------------------------------------------------------------
REM
REM  ESCUDO DE SEGURIDAD (Fase 2.8) - RESUMEN PARA MANTENIMIENTO:
REM   Objetivo: que jamas se pueda borrar el disco que esta en uso.
REM   Tres capas, de dentro hacia fuera:
REM     1) DETECCION (DETECTAR_DISCO_ARRANQUE): convierte las letras del
REM        sistema y del script en INDICES fisicos (DISCO_OS, DISCO_MEDIO).
REM        Metodo 1: PowerShell (exacto). Metodo 2: diskpart 'detail
REM        volume' (respaldo universal). Si ambas fallan: estado DUDA.
REM     2) BLOQUEO (COMPROBAR_DISCO_SEGURO + MOSTRAR_BLOQUEO): si el disco
REM        elegido coincide con el protegido, no se genera ningun guion.
REM     3) DOBLE CONFIRMACION (CONFIRMAR_DESTRUCTIVO): palabra CONFIRMAR
REM        + repeticion del numero de disco, y en casos dudosos una
REM        palabra extra de RIESGO (RIESGO / RISK).
REM   El escudo NUNCA "adivina": un "?" jamas se convierte en un "no".
REM  INTERNACIONALIZACION (i18n) - RESUMEN PARA MANTENIMIENTO:
REM   Patron usado: DOS diccionarios de variables + despacho por etiqueta
REM   dinamica. Al arrancar, el PASO 1 hace:
REM       set "LANG=ES"          (idioma por defecto)
REM       call :CARGAR_IDIOMA    (ejecuta el bloque del idioma activo)
REM   y CARGAR_IDIOMA resuelve el bloque con un salto de nombre construido
REM   en el momento:
REM       goto IDIOMA_%LANG%     -^> IDIOMA_ES  o  IDIOMA_EN
REM   Cada bloque asigna las MISMAS variables T_xxx con su texto; el
REM   bloque termina en 'exit /b 0' y devuelve el control al 'call'.
REM   Ventajas de este diseno frente a duplicar el flujo por idioma:
REM     - La logica (diskpart, validaciones, confirmaciones) existe UNA
REM       sola vez: imposible que un idioma y otro se comporten distinto.
REM     - Traducir = editar un unico anexo, sin tocar el flujo.
REM     - Sin expansion retrasada y sin doble expansion ('call set'): el
REM       texto jamas se re-interpreta y no hay sorpresas con acentos,
REM       exclamaciones ni signos especiales.
REM   Alternativa documentada y descartada: nombres de variable dinamicos
REM       call set "T_MENU_01=%%%LANG%_MENU_01%%"
REM   (funciona, pero es menos legible y mas fragil; ver PASO 2).
REM
REM  FIRMWARE Y AUDITORIA (Fase 4) - RESUMEN PARA MANTENIMIENTO:
REM   FIRMWARE: como saber si el equipo arranco en UEFI o en BIOS Legacy.
REM     Se prueba por capas, de la mas fiable a la menos:
REM       1) REGISTRO: 'wpeutil UpdateBootInfo' (solo WinPE) rellena
REM          HKLM\...\Control\SystemInformation\SystemFirmwareType.
REM          Valor 0x2 -^> UEFI ;  0x1 -^> BIOS Legacy.
REM       2) BCDEDIT: se busca 'winload.efi' (UEFI) o 'winload.exe'
REM          (Legacy) en la entrada de arranque actual.
REM       3) Si ambas fallan, FIRMWARE='?' y NO se adivina: en el modulo
REM          de disco se PREGUNTA que esquema aplicar (GPT o MBR).
REM     Resultado: FIRMWARE (UEFI/LEGACY/MANUAL/?) y FIRMWARE_FORMATO
REM     (GPT o MBR). El generador de guiones escribe 'convert' con el esquema.
REM
REM   AUDITORIA: registro append-only en 'jah-winpe.log'. Cada operacion
REM     relevante llama a  call :REGISTRAR TIPO "detalle" "resultado"  y
REM     la subrutina anade UNA linea:
REM        ^<fecha^> ^<hora^> ^| TIPO ^| detalle ^| resultado
REM     El fichero se ABRE y se CIERRA en cada anotacion (redireccion ^>^>),
REM     asi nunca queda bloqueado aunque el disco se este manipulando.
REM     UBICACION: se intenta primero junto al script; si el script corre
REM     en X: (WinPE, RAM) se busca otro disco ESCRIBIBLE; si no hay, se
REM     deja en la RAM avisando de que se perdera al reiniciar. Nunca se
REM     guarda el texto tecleado por el tecnico: solo datos ya validados
REM     (numeros de disco, codigos de error, palabras clave).
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
REM   - Lectura del tamano real del disco para estimar el 'clean all'.
REM   - Recordar el idioma elegido entre ejecuciones (hoy se pregunta
REM     siempre; seria guardarlo en un fichero junto al script).
REM   - Traducir tambien los comentarios del codigo (hoy van en
REM     castellano a proposito: son documentacion del proyecto).
REM   - Expandir la deteccion del disco de arranque a otros idiomas de
REM     diskpart (hoy cubre 'Disk'/'Disco' y el asterisco de seleccion)
REM     sin romper la politica "nunca adivinar a favor de la destruccion".
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
set "TOOL_VER=1.4.0"
set "TOOL_FASE=4.0"

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
title %TOOL_NAME% v%TOOL_VER%
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

REM --- Idioma por defecto ----------------------------------------------
REM 'LANG' guarda el idioma activo: ES (castellano) o EN (ingles). Se
REM deja en ES desde el primer instante y se cargan sus textos ANTES de
REM preguntar nada, para que incluso los mensajes de error de la pantalla
REM de idioma salgan en un idioma conocido (castellano) y nunca en blanco.
set "LANG=ES"
call :CARGAR_IDIOMA

REM --- Deteccion de PowerShell (escudo de seguridad Fase 2.8) -----------
REM PowerShell es el primer metodo para obtener el numero de disco (exacto,
REM independiente del idioma). Si no existe, caemos al metodo diskpart.
REM 'PS_EXE' apunta a la ruta canónica de PS 5.x/Windows.
set "PS_OK=NO"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%PS_EXE%" set "PS_OK=SI"

REM --- Auditoria y firmware (Fase 4) ------------------------------------
REM Estos dos pasos NO imprimen nada en pantalla: solo dejan listas las
REM variables (LOG_*, FIRMWARE). El texto visible llega luego, ya en el
REM idioma elegido, en el menu principal y en los modulos de disco.
REM ORDEN IMPORTANTE:
REM   1) PREPARAR_LOG       abre la ubicacion del 'jah-winpe.log'.
REM   2) DETECTAR_FIRMWARE  decide UEFI/Legacy y el esquema GPT/MBR.
REM   3) REGISTRAR x4       deja constancia del arranque (auditoria).
call :PREPARAR_LOG
call :DETECTAR_FIRMWARE
call :REGISTRAR INICIO "%TOOL_NAME% v%TOOL_VER% (fase %TOOL_FASE%)" "OK"
call :REGISTRAR ENTORNO "WinPE=%ES_WINPE% PowerShell=%PS_OK%" "OK"
call :REGISTRAR FIRMWARE "%FIRMWARE% / %FIRMWARE_FORMATO% / %FIRMWARE_METODO%" "OK"
call :REGISTRAR LOG "%LOG_UBICACION% / %LOG_PERSISTENTE% / %LOG_ARCHIVO%" "OK"

REM De aqui saltamos a la pantalla de seleccion de idioma. Se usa 'goto'
REM (salto sin retorno) porque es el flujo normal del programa: una vez
REM elegido el idioma ya no se vuelve a esta pantalla.
goto SELECCION_IDIOMA

REM =====================================================================
REM  PASO 2 - SELECCION DE IDIOMA (internacionalizacion / i18n)
REM =====================================================================
REM  Esta pantalla se muestra UNA sola vez, antes de la bienvenida, y es
REM  la unica del programa que NO puede estar traducida todavia: cuando
REM  se pinta aun no sabemos que idioma quiere el tecnico, asi que sus
REM  propios textos van escritos aqui en LOS DOS idiomas (bilingues).
REM
REM  COMO SE HACE UN PROGRAMA MULTILENGUAJE EN BATCH (patron i18n):
REM   1) DICCIONARIO POR IDIOMA. No existen "ficheros de traduccion": se
REM      usa un bloque de variables de texto por idioma, con EXACTAMENTE
REM      los mismos nombres en ambos bloques y distinto valor:
REM          :IDIOMA_ES
REM          set "T_MENU_01=MENU PRINCIPAL"
REM          :IDIOMA_EN
REM          set "T_MENU_01=MAIN MENU"
REM   2) CARGA UNICA AL ARRANCAR. La subrutina CARGAR_IDIOMA ejecuta UNO
REM      de los dos bloques. A partir de ahi, todo el programa imprime
REM      siempre las mismas variables (%T_MENU_01%) sin saber en que
REM      idioma esta: la logica no cambia, cambia el CONTENIDO.
REM   3) DESPACHO CON ETIQUETA DINAMICA. El bloque correcto se elige con
REM      una etiqueta construida al vuelo:  goto IDIOMA_%LANG%
REM      cmd sustituye %LANG% (ES o EN) y salta a IDIOMA_ES o IDIOMA_EN.
REM      Esta es la tecnica de "nombre dinamico" aplicada a ETIQUETAS,
REM      que es la que usa este script por ser la mas clara y segura.
REM   4) VARIANTE DE NOMBRE DE VARIABLE DINAMICO (documentada, NO usada
REM      aqui). Si se quisiera un unico diccionario con prefijo de idioma
REM      se leeria asi, sin expansion retrasada:
REM          set "ES_MENU_01=MENU PRINCIPAL"
REM          set "EN_MENU_01=MAIN MENU"
REM          set "LANG=ES"
REM          call set "T_MENU_01=%%%LANG%_MENU_01%%"
REM      Primera pasada: %LANG% -^> ES y queda %%ES_MENU_01%%. El 'call'
REM      fuerza una SEGUNDA pasada de expansion que lo convierte en el
REM      texto final. Es correcta, pero mas dificil de leer, mas lenta y
REM      fragil si el texto lleva signos especiales; por eso el proyecto
REM      usa el bloque por idioma y reserva el nombre dinamico para el
REM      'goto IDIOMA_%LANG%'.
REM
REM  REGLA DE MANTENIMIENTO (importante): todo texto nuevo debe anadirse
REM  con el MISMO nombre en IDIOMA_ES y en IDIOMA_EN. Si falta en uno, ese
REM  idioma imprimira una linea en blanco (variable vacia). Los bloques
REM  viven en el ANEXO A (final del archivo) y deben tener el mismo numero
REM  de lineas 'set "T_'. Comprobacion rapida desde CMD:
REM      findstr /n /c:"T_" menu.bat
REM  (los dos bloques deben devolver el mismo numero de lineas)
REM =====================================================================
:SELECCION_IDIOMA
cls
call :MOSTRAR_CABECERA_BASE
echo(
echo   Selecciona el idioma / Select the language:
echo(
echo      [1]  Español
echo      [2]  English
echo(
call :LEER_OPCION "   Opción / Option [1-2]:  " "1 2"
REM Solo hay que CAMBIAR la variable si el tecnico elige ingles: si pulsa
REM [1] (o la entrada no es valida) seguimos en castellano, que es el
REM valor por defecto ya asignado en el PASO 1.
if "%OPCION%"=="2" set "LANG=EN"
REM Recargamos el diccionario: ahora si, con el idioma definitivo. A
REM partir de esta linea todas las pantallas salen en el idioma elegido.
call :CARGAR_IDIOMA
REM Dejamos constancia del idioma elegido en el registro de auditoria.
call :REGISTRAR IDIOMA "idioma=%LANG%" "OK"
cls
goto BIENVENIDA

REM ---------------------------------------------------------------------
REM  CARGAR_IDIOMA - carga el bloque de textos del idioma activo.
REM  -------------------------------------------------------------------
REM  USO:     call :CARGAR_IDIOMA
REM  ENTRADA: %LANG%  -^>  ES o EN
REM  SALIDA:  todas las variables T_xxx del idioma elegido.
REM
REM  El 'goto IDIOMA_%LANG%' salta a la etiqueta del bloque; ese bloque
REM  termina con 'exit /b 0'. Aunque el 'goto' haya salido de esta
REM  subrutina, el punto de retorno del 'call' sigue apilado, asi que el
REM  'exit /b' devuelve el control justo a la linea siguiente del 'call'.
REM  Es la forma limpia de ejecutar codigo "en bloque" sin parentesis.
REM ---------------------------------------------------------------------
:CARGAR_IDIOMA
if /i "%LANG%"=="EN" goto IDIOMA_EN
goto IDIOMA_ES

REM ---------------------------------------------------------------------
REM  MOSTRAR_CABECERA_BASE - cabecera SIN texto traducible.
REM  -------------------------------------------------------------------
REM  Se usa donde el diccionario todavia no es utilizable: la pantalla de
REM  seleccion de idioma (no hay idioma elegido aun) y el arranque.
REM  Solo muestra datos neutros (marca y version): ni una palabra que
REM  hubiera que traducir.
REM ---------------------------------------------------------------------
:MOSTRAR_CABECERA_BASE
echo   ==========================================================================
echo     %TOOL_NAME%   -   v%TOOL_VER%
echo   ==========================================================================
exit /b 0

REM =====================================================================
REM  PASO 3 - PANTALLA DE BIENVENIDA (se muestra UNA sola vez)
REM =====================================================================
:BIENVENIDA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_BIEN_01%
echo   %T_BIEN_02%
echo   %T_BIEN_03%
echo   %T_BIEN_04%
echo(
echo   %T_BIEN_05%
echo     %T_BIEN_06%
echo        %T_BIEN_07%
echo     %T_BIEN_08%
echo        %T_BIEN_09%
echo        %T_BIEN_10%
echo     %T_BIEN_11%
echo        %T_BIEN_12%
echo(
echo   %T_BIEN_13%
echo   %T_BIEN_14%
echo(
call :PULSA_TECLA "%T_BIEN_15%"
goto MENU

REM =====================================================================
REM  PASO 4 - MENU PRINCIPAL (bucle infinito: SIEMPRE vuelve aqui)
REM =====================================================================
:MENU
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_MENU_01%
echo   ------------------------------------------------------------------
echo(
echo      %T_MENU_02%
echo      %T_MENU_03%
echo      %T_MENU_04%
echo      %T_MENU_05%
echo      %T_MENU_06%
echo(
echo   ------------------------------------------------------------------
echo   %T_MENU_07%
echo          %T_MENU_08%
echo   ------------------------------------------------------------------
echo      %T_MENU_12% %date%  %time:~0,5%
echo      %T_MENU_13% %MODO_ENTRADA%
echo      %T_MENU_14% %FIRMWARE%   -^>   %FIRMWARE_FORMATO%
if "%LOG_PERSISTENTE%"=="SI" echo      %T_LOG_01% %LOG_ARCHIVO%
if not "%LOG_PERSISTENTE%"=="SI" echo      %T_LOG_02% %LOG_ARCHIVO%
echo(
echo   %T_MENU_09%
echo    %T_MENU_10%
echo(

REM --- Captura segura de la seleccion -----------------------------------
REM 'call :subrutina' invoca una subrutina y REGRESA a la linea siguiente
REM cuando esta cierra con 'exit /b'. Le pasamos dos argumentos:
REM   1) el texto que vera el tecnico,
REM   2) los digitos permitidos (lista blanca).
REM El resultado queda en la variable global %OPCION%.
call :LEER_OPCION "%T_MENU_11%" "1 2 3 4 5"

REM Anotamos la opcion elegida en el registro (auditoria de uso). Se hace
REM solo si hay un digito valido: asi no ensuciamos el log con ENTERs en
REM vacio ni con entradas erroneas.
if defined OPCION call :REGISTRAR MENU "opcion=%OPCION%" "OK"

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
REM  PASO 5 - OPCION [1] PREPARACION RAPIDA DE DISCO (maquetacion)
REM =====================================================================
REM  Este bloque es solo el "interruptor": todo el trabajo real vive en
REM  la subrutina MODULO_PREPARAR (PASO 12). Asi el flujo principal se
REM  lee de un vistazo: se elige opcion, se llama al modulo y se vuelve.
REM  'call' ejecuta la subrutina y REGRESA aqui cuando esta cierra con
REM  'exit /b'; despues volvemos al menu, pase lo que pase.
REM =====================================================================
:OP_DISCO
call :MODULO_PREPARAR
goto MENU

REM =====================================================================
REM  PASO 6 - OPCION [2] BORRADO SEGURO / SANITIZACION
REM =====================================================================
REM  Mismo esquema que la opcion 1: el flujo vive en MODULO_SANITIZAR.
REM =====================================================================
:OP_SANITIZAR
call :MODULO_SANITIZAR
goto MENU

REM =====================================================================
REM  PASO 7 - OPCION [3] CONSOLA AVANZADA (CMD interactivo)
REM =====================================================================
:OP_CONSOLA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_CONS_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_CONS_02%
echo(
echo   %T_CONS_03%
echo   %T_CONS_04%
echo   %T_CONS_05%
REM     Cada cmd.exe es un proceso con su propio bloque de variables en
REM     memoria; ademas este script esta dentro de 'setlocal', que crea
REM     un ambito aislado que se destruye al terminar.
echo(
echo   %T_CONS_06%
echo       %T_CONS_07%
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
REM  PASO 8 - OPCION [4] AYUDA DEL SISTEMA (2 paginas + help nativo)
REM =====================================================================
:OP_AYUDA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_AYU1_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_AYU1_02%
echo       %T_AYU1_03%
echo         %T_AYU1_04%
echo         %T_AYU1_05%
echo                                     %T_AYU1_06%
echo       %T_AYU1_07%
echo       %T_AYU1_08%
echo       %T_AYU1_09%
echo       %T_AYU1_10%
echo       %T_AYU1_11%
echo                                     %T_AYU1_12%
echo       %T_AYU1_13%
echo                                     %T_AYU1_14%
echo       %T_AYU1_15%
echo       %T_AYU1_16%
echo       %T_AYU1_17%
echo                                     %T_AYU1_18%
echo       %T_AYU1_19%
echo                                     %T_AYU1_20%
echo       %T_AYU1_21%
echo                                     %T_AYU1_22%
echo       %T_AYU1_23%
echo     %T_AYU1_24%
echo     %T_AYU1_25%
echo(
echo     %T_AYU1_26%
echo     %T_AYU1_27%
echo     %T_AYU1_28%
echo     %T_AYU1_29%
echo     %T_AYU1_30%
echo(
echo     %T_AYU1_31%
echo     %T_AYU1_32%
echo(
call :PULSA_TECLA "%T_AYU1_33%"

:OP_AYUDA_P2
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_AYU2_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_AYU2_02%
echo     %T_AYU2_03%
echo     %T_AYU2_04%
echo     %T_AYU2_05%
echo     %T_AYU2_06%
echo(
echo   %T_AYU2_07%
echo     %T_AYU2_08%
echo         %T_AYU2_09%
echo         %T_AYU2_10%
echo                     %T_AYU2_11%
echo     %T_AYU2_12%
echo     %T_AYU2_13%
echo     %T_AYU2_14%
echo(
echo   %T_AYU2_15%
echo     %T_AYU2_16%
echo     %T_AYU2_17%
echo     %T_AYU2_18%
echo     %T_AYU2_19%
echo(
echo   %T_AYU2_20%
echo     %T_AYU2_21%
echo     %T_AYU2_22%
echo     %T_AYU2_23%
echo     %T_AYU2_24%
echo     %T_AYU2_25%
echo(
echo   %T_AYU2_26%
echo    %T_AYU2_27%
echo      %T_AYU2_28%
echo    %T_AYU2_29%
echo      %T_AYU2_30%
echo      %T_AYU2_31%
echo(
call :LEER_OPCION "%T_AYU2_32%" "1 2"
if not "%OPCION%"=="1" goto OP_AYUDA_FIN
echo(
echo   %T_AYU2_33%
echo(
help
:OP_AYUDA_FIN
call :PULSA_TECLA "%T_AYU3_01%"
goto MENU

REM =====================================================================
REM  PASO 9 - OPCION [5] SALIR / APAGAR EQUIPO
REM  (todas las acciones de esta seccion piden confirmacion previa)
REM =====================================================================
:OP_SALIR
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_SAL_01%
echo   ------------------------------------------------------------------
echo(
echo      %T_SAL_02%
echo      %T_SAL_03%
echo      %T_SAL_04%
echo(
call :LEER_OPCION "%T_SAL_05%" "1 2 3"
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
echo   %T_SAL_06%
echo   ------------------------------------------------------------------
echo(
echo   %T_SAL_07%
echo   %T_SAL_08%
echo   %T_SAL_09%
echo   %T_SAL_10%
echo(
call :LEER_OPCION "%T_SAL_11%" "1 2"
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
call :REGISTRAR SALIDA "modo=apagar entorno=WinPE" "OK"
echo(
echo   %T_SAL_12%
REM wpeutil es la herramienta oficial de WinPE: solo admite un comando
REM por linea y 'shutdown' apaga la sesion inmediatamente.
wpeutil shutdown
goto FIN_APAGADO

:APAGAR_WINDOWS
call :REGISTRAR SALIDA "modo=apagar entorno=Windows" "OK"
echo(
echo   %T_SAL_13%
echo   %T_SAL_14%
REM   /s   = shutdown (apagar).  /reboot seria para reiniciar.
REM   /t 5 = espera de 5 segundos antes de apagar (tiempo para abortar).
REM   /f   = fuerza el cierre de aplicaciones abiertas.
REM   /c   = mensaje que se muestra en pantalla (va entre comillas).
shutdown /s /t 5 /f /c "%TOOL_NAME%: apagado solicitado por el tecnico."
goto FIN_APAGADO

REM =====================================================================
REM  PASO 10 - SALIDAS ORDENADAS DEL SCRIPT
REM =====================================================================

REM Salida normal (opcion 2 del submenu salir): despedida + pausa para
REM que el tecnico pueda leerla antes de que la ventana se cierre.
:FIN_SCRIPT
call :REGISTRAR SALIDA "modo=salir" "OK"
echo(
echo   %T_SAL_16% %TOOL_NAME% v%TOOL_VER%.
echo(
call :PULSA_TECLA "%T_SAL_15%"
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
REM  PASO 11 - SUBRUTINAS INTERNAS (se invocan con 'call :etiqueta')
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
echo     %TOOL_NAME%   -   %T_COM_42%
echo     %T_COM_43% %TOOL_VER%   -   %T_COM_44% %TOOL_FASE%   -   %T_COM_45% Windows / WinPE
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
echo   %T_COM_01%
goto LEER_CON_SETP

REM =====================================================================
REM  PASO 12 - SUBRUTINAS DE LOS MODULOS DE DISCO (Fase 2)
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
echo   %T_COM_02%
echo       %T_COM_03%
echo       %T_COM_04%
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
REM Ficheros temporales para el ESCUDO DE SEGURIDAD (Fase 2.8).
REM Se crean y se borran siempre en la carpeta de trabajo.
set "F_SEG=%DIR_TRABAJO%\_jah_seguridad.txt"
set "F_SEG_SAL=%DIR_TRABAJO%\_jah_seguridad_salida.txt"
REM Borramos restos de una ejecucion anterior: asi nunca se puede
REM ejecutar por error un guion viejo (o el de otro disco).
call :BORRAR_TEMPORALES
REM --- 4) Esta diskpart disponible? -----------------------------------
if not exist "%SystemRoot%\System32\diskpart.exe" goto PREPARAR_ENTORNO_SIN_DISKPART
REM --- 5) Permisos ----------------------------------------------------
call :COMPROBAR_ADMIN
if "%ES_ADMIN%"=="SI" goto PREPARAR_ENTORNO_LISTO
echo   %T_COM_05%
echo       %T_COM_06%
echo       %T_COM_07%
echo(
call :LEER_OPCION "%T_COM_08%" "1 2"
if not "%OPCION%"=="1" goto PREPARAR_ENTORNO_SIN_ADMIN
:PREPARAR_ENTORNO_LISTO
set "ENTORNO_OK=SI"
call :REGISTRAR ENTORNO "listo admin=%ES_ADMIN% carpeta=%DIR_TRABAJO%" "OK"
exit /b 0

:PREPARAR_ENTORNO_SIN_ADMIN
call :REGISTRAR ENTORNO "admin=NO tecnico_decide_cancelar" "CANCELADO"
exit /b 0

:PREPARAR_ENTORNO_SIN_ESCRITURA
call :REGISTRAR ENTORNO "sin_carpeta_escribible dir=%DIR_TRABAJO%" "ERROR"
echo(
echo   %T_COM_09%
echo           %DIR_TRABAJO%
echo       %T_COM_10%
echo       %T_COM_11%
echo       %T_COM_12%
echo(
exit /b 0

:PREPARAR_ENTORNO_SIN_DISKPART
call :REGISTRAR ENTORNO "sin_diskpart_en_la_imagen" "ERROR"
echo(
echo   %T_COM_13%
echo       %T_COM_14%
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
if exist "%F_SEG%" del /f /q "%F_SEG%" >nul 2>&1
if exist "%F_SEG_SAL%" del /f /q "%F_SEG_SAL%" >nul 2>&1
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
echo   %T_COM_15%
echo   %T_COM_16%
echo   %T_COM_17%
echo   %T_COM_18%
echo   ------------------------------------------------------------------
call :LEER_NUMERO "%T_COM_19%" DISCO
if "%NUM_OK%"=="CANCELAR" exit /b 0
if not "%NUM_OK%"=="SI" goto PEDIR_DISCO_BUCLE
REM --- Contraste con el listado ya capturado --------------------------
call :DISCO_EXISTE
if "%EXISTE%"=="SI" goto PEDIR_DISCO_OK
echo(
echo   %T_SEG_19% %DISCO% %T_SEG_20%
echo       %T_SEG_21%
echo       %T_SEG_22%
echo       %T_SEG_23%
echo(
call :LEER_OPCION "%T_COM_24%" "1 2 3"
if "%OPCION%"=="1" goto PEDIR_DISCO_BUCLE
if "%OPCION%"=="2" goto PEDIR_DISCO_RIESGO
exit /b 0
:PEDIR_DISCO_RIESGO
REM El tecnico elige 'Continuar' pese a la duda: exigimos palabra de RIESGO.
call :CONFIRMAR_DESTRUCTIVO "%T_CFM_06%"
if not "%CONFIRMADO%"=="SI" goto PEDIR_DISCO_BUCLE
goto PEDIR_DISCO_OK
:PEDIR_DISCO_OK
set "DISCO_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  CONFIRMAR_DESTRUCTIVO - la barrera humana antes de destruir datos.
REM  -------------------------------------------------------------------
REM  Uso:      call :CONFIRMAR_DESTRUCTIVO "PALABRA" [DISCO]
REM    %~1 = palabra que el tecnico debe teclear EXACTAMENTE (lista blanca
REM          textual, ej. CONFIRMAR/CONFIRM o RIESGO/RISK). No vale un ENTER,
REM          ni "si", ni cualquier otra cosa: si no coincide, no se hace nada.
REM    %~2 = si vale DISCO, se pide ADEMAS repetir el numero de disco
REM          (doble control: palabra + numero). Se usa en TODAS las
REM          operaciones destructivas (Fase 2.8).
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
set /p "CONF_TXT=   %T_CFM_02% %~1 %T_CFM_03%"
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT:"=%"
set "CONF_TXT=%CONF_TXT: =%"
if /i not "%CONF_TXT%"=="%~1" goto CONFIRMAR_DESTRUCTIVO_NO
if "%~2"=="DISCO" goto CONFIRMAR_DESTRUCTIVO_DISCO
set "CONFIRMADO=SI"
call :REGISTRAR CONFIRMACION "palabra=%~1" "ACEPTADA"
exit /b 0
:CONFIRMAR_DESTRUCTIVO_DISCO
set "CONF_DISCO="
set /p "CONF_DISCO=   %T_CFM_04% (%DISCO%): "
if not defined CONF_DISCO goto CONFIRMAR_DESTRUCTIVO_NO
set "CONF_DISCO=%CONF_DISCO:"=%"
set "CONF_DISCO=%CONF_DISCO: =%"
if "%CONF_DISCO%"=="%DISCO%" set "CONFIRMADO=SI"
if not "%CONFIRMADO%"=="SI" goto CONFIRMAR_DESTRUCTIVO_NO
call :REGISTRAR CONFIRMACION "palabra=%~1 disco=%DISCO%" "ACEPTADA"
exit /b 0
:CONFIRMAR_DESTRUCTIVO_NO
call :REGISTRAR CONFIRMACION "palabra=%~1 disco=%DISCO%" "RECHAZADA"
echo(
echo   %T_CFM_01%
exit /b 0

REM ---------------------------------------------------------------------
REM  GENERAR_SCRIPT_MAQUETAR - escribe el guion de la opcion [1].
REM  -------------------------------------------------------------------
REM  Cada linea del guion es UN comando de diskpart, en este orden:
REM    select disk N           elige el disco (obligatorio antes de nada)
REM    clean                   borra la tabla de particiones (rapido)
REM    convert gpt / mbr       esquema de particionado SEGUN EL FIRMWARE:
REM                            UEFI moderno pide GPT; un equipo antiguo que
REM                            arranca en BIOS Legacy necesita MBR. Por eso
REM                            el comando se escribe con %FIRMWARE_FORMATO%
REM                            y no con un valor fijo.
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
>> "%F_SCRIPT%" echo convert %FIRMWARE_FORMATO%
>> "%F_SCRIPT%" echo create partition primary
>> "%F_SCRIPT%" echo format fs=ntfs quick label="SISTEMA"
>> "%F_SCRIPT%" echo assign
call :REGISTRAR MAQUETAR "disco=%DISCO% esquema=%FIRMWARE_FORMATO%" "GUION_GENERADO"
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
call :REGISTRAR SANITIZAR "disco=%DISCO% comando=clean all" "GUION_GENERADO"
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
echo   %T_COM_47%:
echo   %F_SCRIPT%
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
echo   %T_DP_01%
echo   %T_DP_02%
echo   ------------------------------------------------------------------
echo(
diskpart /s "%F_SCRIPT%"
set "RESULTADO=%errorlevel%"
REM El codigo de salida (0 = exito) es el dato mas importante del log:
REM queda anotado tanto si funciono como si no, con su numero exacto.
if "%RESULTADO%"=="0" call :REGISTRAR DISKPART "codigo=0" "OK"
if not "%RESULTADO%"=="0" call :REGISTRAR DISKPART "codigo=%RESULTADO%" "ERROR"
echo(
echo   ------------------------------------------------------------------
if "%RESULTADO%"=="0" echo   %T_COM_48%
if not "%RESULTADO%"=="0" echo   %T_COM_49% %RESULTADO%
echo   ------------------------------------------------------------------
echo(
echo   %T_DP_03%
echo   %T_DP_04%
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
echo   %T_COM_25%
call :LISTAR_DISCOS
echo   %T_COM_26%
echo     %T_D1_23% %DISCO% %T_D1_25%
echo       %T_COM_27%
echo     %T_D2_33% %DISCO% %T_D2_35%
echo       %T_COM_28%
echo     %T_COM_29%
echo       %T_COM_30%
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
echo   %T_COM_31%
echo(
> "%F_SCRIPT%" echo rem JAH-WinPe - listado del equipo (solo lectura)
>> "%F_SCRIPT%" echo list disk
>> "%F_SCRIPT%" echo list volume
diskpart /s "%F_SCRIPT%" > "%F_SALIDA%" 2>&1
set "RESULTADO_LISTADO=%errorlevel%"
if not "%RESULTADO_LISTADO%"=="0" goto LISTAR_DISCOS_FIN
type "%F_SALIDA%"
echo(
echo   %T_COM_32%
echo     %T_COM_33%
echo                      %T_COM_34%
echo     %T_COM_35%
echo     %T_COM_36%
echo     %T_COM_37%
echo     %T_COM_38%
echo       %T_COM_39%
echo(
set "LISTADO_OK=SI"
exit /b 0
:LISTAR_DISCOS_FIN
echo   %T_COM_50% %RESULTADO_LISTADO%
echo       %T_COM_40%
echo       %T_COM_41%
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
echo   %T_D1_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_D1_02%
echo(
echo     %T_D1_03%
echo     %T_D1_04%
echo     %T_D1_05%
echo        %T_D1_06%
echo     %T_D1_07% %T_CFM_05% %T_D1_26%
echo     %T_D1_08%
echo(
echo   %T_D1_09%
echo   %T_D1_10%
echo   %T_D1_11%
echo(
echo   %T_D1_12%
echo   %T_D1_13%
echo(
call :PULSA_TECLA "%T_D1_14%"
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :LISTAR_DISCOS
call :DETECTAR_DISCO_ARRANQUE
call :PEDIR_DISCO
if not "%DISCO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :REGISTRAR DISCO "modulo=maquetar disco=%DISCO%" "SELECCIONADO"
call :COMPROBAR_DISCO_SEGURO
if "%BLOQUEADO%"=="SI" goto MODULO_PREPARAR_BLOQUEO
call :ELEGIR_FORMATO_DUDA
if not "%FORMATO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :GENERAR_SCRIPT_MAQUETAR
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_D1_15%
echo   ------------------------------------------------------------------
echo(
echo   %T_COM_51% %DISCO%
if "%PROTECCION_ESTADO%"=="ACTIVA" echo   %T_SEG_16%
if "%PROTECCION_ESTADO%"=="DUDA" echo   %T_SEG_17%
if "%PROTECCION_ESTADO%"=="NA" echo   %T_SEG_18%
echo   %T_FW_02% %FIRMWARE%   -   %T_FW_03% %FIRMWARE_FORMATO%
echo   %T_FW_04%
echo   %T_D1_16%
echo                   %T_D1_17%
echo(
call :MOSTRAR_SCRIPT
if "%ES_WINPE%"=="SI" goto MODULO_PREPARAR_FIN_AVISO
echo   %T_D1_24%
echo       %T_D1_18%
echo       %T_D1_19%
echo       %T_D1_20%
echo(
:MODULO_PREPARAR_FIN_AVISO
call :EVALUAR_SEGURIDAD
if not "%RIESGO_NECESARIO%"=="SI" goto MODULO_PREPARAR_CONFIRMAR
call :MOSTRAR_AVISO_RIESGO
color 0A
call :CONFIRMAR_DESTRUCTIVO "%T_CFM_06%"
if not "%CONFIRMADO%"=="SI" goto MODULO_PREPARAR_CANCELADO
:MODULO_PREPARAR_CONFIRMAR
call :CONFIRMAR_DESTRUCTIVO "%T_CFM_05%" DISCO
if not "%CONFIRMADO%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :EJECUTAR_DISKPART
call :MOSTRAR_RESULTADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "%T_D1_21%"
exit /b 0
:MODULO_PREPARAR_BLOQUEO
call :REGISTRAR BLOQUEO "modulo=maquetar disco=%DISCO%" "DENEGADO"
call :MOSTRAR_BLOQUEO
goto MODULO_BLOQUEADO

:MODULO_PREPARAR_CANCELADO
call :REGISTRAR CANCELADO "modulo=maquetar disco=%DISCO%" "CANCELADO"
call :BORRAR_TEMPORALES
call :PULSA_TECLA "%T_D1_22%"
exit /b 0

REM ---------------------------------------------------------------------
REM  MODULO_SANITIZAR - opcion [2]: borrado seguro (clean all).
REM  -------------------------------------------------------------------
REM  Mismos pasos que la opcion 1, con diferencias por ser IRREVERSIBLE:
REM  el aviso del tiempo estimado (clean all) y la doble confirmacion
REM  (palabra CONFIRMAR + repetir el numero de disco), ademas del escudo
REM  de seguridad del disco de arranque (bloquea si coincide).
REM ---------------------------------------------------------------------
:MODULO_SANITIZAR
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_D2_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_D2_02%
echo   %T_D2_03%
echo   %T_D2_04%
echo(
echo   %T_D2_05%
echo     %T_D2_06%
echo                  %T_D2_07%
echo     %T_D2_08%
echo                  %T_D2_09%
echo   %T_D2_10%
echo   %T_D2_11%
echo(
call :PULSA_TECLA "%T_D1_14%"
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :LISTAR_DISCOS
call :DETECTAR_DISCO_ARRANQUE
call :PEDIR_DISCO
if not "%DISCO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :REGISTRAR DISCO "modulo=sanitizar disco=%DISCO%" "SELECCIONADO"
call :COMPROBAR_DISCO_SEGURO
if "%BLOQUEADO%"=="SI" goto MODULO_SANITIZAR_BLOQUEO
call :GENERAR_SCRIPT_BORRAR
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_D2_12%
echo   ------------------------------------------------------------------
echo(
echo   %T_COM_51% %DISCO%
if "%PROTECCION_ESTADO%"=="ACTIVA" echo   %T_SEG_16%
if "%PROTECCION_ESTADO%"=="DUDA" echo   %T_SEG_17%
if "%PROTECCION_ESTADO%"=="NA" echo   %T_SEG_18%
echo   %T_FW_02% %FIRMWARE%
echo   %T_D2_13%
echo(
echo   %T_D2_14%
echo     %T_D2_15%
echo     %T_D2_16%
echo     %T_D2_17%
echo     %T_D2_18%
echo     %T_D2_19%
echo(
echo   %T_D2_20%
echo     %T_D2_21%
echo       %T_D2_22%
echo     %T_D2_23%
echo       %T_D2_24%
echo       %T_D2_25%
echo     %T_D2_26%
echo     %T_D2_27%
echo       %T_D2_28%
echo(
if "%ES_WINPE%"=="SI" goto MODULO_SANITIZAR_AVISO_OK
echo   %T_D2_29%
echo       %T_D2_34%
echo       %T_D2_30%
echo       %T_D2_31%
echo(
:MODULO_SANITIZAR_AVISO_OK
call :MOSTRAR_SCRIPT
echo   %T_D2_32%
echo(
call :EVALUAR_SEGURIDAD
if not "%RIESGO_NECESARIO%"=="SI" goto MODULO_SANITIZAR_CONFIRMAR
call :MOSTRAR_AVISO_RIESGO
color 0A
call :CONFIRMAR_DESTRUCTIVO "%T_CFM_06%"
if not "%CONFIRMADO%"=="SI" goto MODULO_SANITIZAR_CANCELADO
:MODULO_SANITIZAR_CONFIRMAR
call :CONFIRMAR_DESTRUCTIVO "%T_CFM_05%" DISCO
if not "%CONFIRMADO%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :EJECUTAR_DISKPART
call :MOSTRAR_RESULTADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "%T_D1_21%"
exit /b 0
:MODULO_SANITIZAR_BLOQUEO
call :REGISTRAR BLOQUEO "modulo=sanitizar disco=%DISCO%" "DENEGADO"
call :MOSTRAR_BLOQUEO
goto MODULO_BLOQUEADO

:MODULO_SANITIZAR_CANCELADO
call :REGISTRAR CANCELADO "modulo=sanitizar disco=%DISCO%" "CANCELADO"
call :BORRAR_TEMPORALES
call :PULSA_TECLA "%T_D1_22%"
exit /b 0

:MODULO_BLOQUEADO
call :BORRAR_TEMPORALES
exit /b 0

REM #####################################################################
REM  ESCUDO DE SEGURIDAD - Fase 2.8
REM #####################################################################
REM  Bloque de subrutinas que identifican el DISCO DE ARRANQUE (el disco
REM  fisico desde donde se ejecuta WinPE o el disco con el sistema en
REM  marcha) y blindan las operaciones destructivas.
REM
REM  La variable de estado es PROTECCION_ESTADO:
REM      ACTIVA   -^> todas las referencias aplicables se resolvieron
REM      DUDA     -^> alguna referencia aplicable NO se pudo resolver
REM      NA       -^> ninguna referencia aplicable (p. ej. WinPE en RAM)
REM  Combinado con BLOQUEADO (SI/NO) y RIESGO_NECESARIO (SI/NO).
REM #####################################################################

REM ---------------------------------------------------------------------
REM  DETECTAR_DISCO_ARRANQUE - identifica discos de arranque
REM  -------------------------------------------------------------------
REM  Calcula:
REM      LETRA_SISTEMA, LETRA_MEDIO
REM      DISCO_OS, DISCO_MEDIO (numeros o ?)
REM      REF_SISTEMA, REF_MEDIO (SI/NO)
REM      RESOLVER_MEDIO
REM      PROTECCION_ESTADO, PROTECCION_OK
REM ---------------------------------------------------------------------
:DETECTAR_DISCO_ARRANQUE
set "DISCO_OS=?"
set "DISCO_MEDIO=?"
set "LETRA_SISTEMA="
set "LETRA_MEDIO="
REM Letra del disco del sistema (%SystemDrive%)
set "LETRA_SISTEMA=%SystemDrive:~0,1%"
REM Letra del disco desde donde se ejecuta este fichero
set "DIR_SCRIPT=%~d0"
if "%DIR_SCRIPT:~1,1%"==":" set "LETRA_MEDIO=%DIR_SCRIPT:~0,1%"
REM Aplicabilidad
set "REF_SISTEMA=SI"
set "REF_MEDIO=SI"
if "%ES_WINPE%"=="SI" if /i "%LETRA_SISTEMA%"=="X" set "REF_SISTEMA=NO"
if "%ES_WINPE%"=="SI" if /i "%LETRA_MEDIO%"=="X" set "REF_MEDIO=NO"
if not defined LETRA_MEDIO set "REF_MEDIO=NO"
if not defined LETRA_SISTEMA set "REF_SISTEMA=NO"
REM Resolver
set "PROTECCION_OK=SI"
set "RESOLVER_MEDIO=SI"
if "%REF_MEDIO%"=="NO" set "RESOLVER_MEDIO=NO"
REM Si las dos referencias son la MISMA letra, resolvemos una sola vez.
if "%LETRA_SISTEMA%"=="%LETRA_MEDIO%" set "RESOLVER_MEDIO=NO"
if "%REF_SISTEMA%"=="SI" call :DISCO_DE_UNIDAD "%LETRA_SISTEMA%"
if "%REF_SISTEMA%"=="SI" set "DISCO_OS=%UNIDAD_DISCO%"
if "%RESOLVER_MEDIO%"=="SI" call :DISCO_DE_UNIDAD "%LETRA_MEDIO%"
if "%RESOLVER_MEDIO%"=="SI" set "DISCO_MEDIO=%UNIDAD_DISCO%"
if "%RESOLVER_MEDIO%"=="NO" set "DISCO_MEDIO=%DISCO_OS%"
REM Estado
set "PROTECCION_ESTADO=ACTIVA"
if "%REF_SISTEMA%"=="NO" if "%REF_MEDIO%"=="NO" set "PROTECCION_ESTADO=NA"
if "%REF_SISTEMA%"=="SI" if "%DISCO_OS%"=="?" set "PROTECCION_ESTADO=DUDA"
if "%REF_MEDIO%"=="SI" if "%DISCO_MEDIO%"=="?" set "PROTECCION_ESTADO=DUDA"
if not "%PROTECCION_ESTADO%"=="ACTIVA" set "PROTECCION_OK=NO"
if "%PROTECCION_ESTADO%"=="NA" set "PROTECCION_OK=NO"
exit /b 0

REM ---------------------------------------------------------------------
REM  DISCO_DE_UNIDAD - obtiene el numero de disco para una letra
REM  -------------------------------------------------------------------
:DISCO_DE_UNIDAD
set "UNIDAD_DISCO=?"
if "%~1"=="" exit /b 0
REM Metodo 1: PowerShell (exacto, independiente del idioma)
if "%PS_OK%"=="SI" call :DISCO_DE_UNIDAD_PS "%~1"
if not "%UNIDAD_DISCO%"=="?" exit /b 0
REM Metodo 2: diskpart 'select volume' + 'detail volume' (respaldo)
call :DISCO_DE_UNIDAD_DP "%~1"
exit /b 0

REM ---------------------------------------------------------------------
REM  DISCO_DE_UNIDAD_PS - Metodo 1 (PowerShell)
REM  -------------------------------------------------------------------
:DISCO_DE_UNIDAD_PS
set "UNIDAD_DISCO=?"
REM Construimos el comando de PowerShell por partes: en una sola linea
REM pasaria de 94 columnas y romperia el formato de consola.
set "PS_CMD=$p=Get-Partition -DriveLetter %~1 -ErrorAction SilentlyContinue"
set "PS_CMD=%PS_CMD%; if($p){$p.DiskNumber}else{'-'}"
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_SEG_SAL%" 2>nul
REM Leemos la SALIDA (no el codigo de salida): asi el disco 0 no se
REM confunde con un error y un fallo de PowerShell nunca parece un disco.
set "UNIDAD_DISCO="
if not exist "%F_SEG_SAL%" set "UNIDAD_DISCO=?"
for /f "usebackq delims=" %%A in ("%F_SEG_SAL%") do set "UNIDAD_DISCO=%%A"
if "%UNIDAD_DISCO%"=="-" set "UNIDAD_DISCO=?"
if "%UNIDAD_DISCO%"=="" set "UNIDAD_DISCO=?"
exit /b 0

REM ---------------------------------------------------------------------
REM  DISCO_DE_UNIDAD_DP - Metodo 2 (diskpart)
REM  -------------------------------------------------------------------
:DISCO_DE_UNIDAD_DP
set "UNIDAD_DISCO=?"
if not exist "%SystemRoot%\System32\diskpart.exe" exit /b 0
if not exist "%SystemRoot%\System32\findstr.exe" exit /b 0
> "%F_SEG%" echo select volume %~1
>> "%F_SEG%" echo detail volume
diskpart /s "%F_SEG%" > "%F_SEG_SAL%" 2>&1
REM En 'detail volume' la tabla de discos marca el disco ACTUAL con un
REM asterisco al principio de la linea. Ese '*' NO depende del idioma,
REM y el indice del disco siempre es el tercer elemento separado por
REM espacios: por eso buscamos lineas que empiecen por '* ' y nos
REM quedamos con el token 3. Si el formato cambiara, no encontramos
REM nada y devolvemos '?' (ante la duda, pregunta el tecnico).
for /f "tokens=3" %%A in ('findstr /b /c:"* " "%F_SEG_SAL%"') do set "UNIDAD_DISCO=%%A"
if "%UNIDAD_DISCO%"=="" set "UNIDAD_DISCO=?"
exit /b 0

REM ---------------------------------------------------------------------
REM  COMPROBAR_DISCO_SEGURO - bloquea si el disco elegido es protegido
REM  -------------------------------------------------------------------
:COMPROBAR_DISCO_SEGURO
set "BLOQUEADO=NO"
if not defined DISCO exit /b 0
if "%REF_SISTEMA%"=="SI" if "%DISCO_OS%"=="%DISCO%" set "BLOQUEADO=SI"
if "%REF_MEDIO%"=="SI" if "%DISCO_MEDIO%"=="%DISCO%" set "BLOQUEADO=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_BLOQUEO - pantalla roja de denegacion
REM  -------------------------------------------------------------------
:MOSTRAR_BLOQUEO
color 0C
cls
call :MOSTRAR_CABECERA
echo(
echo   ==================================================================
echo   %T_SEG_01%
echo   ==================================================================
echo(
echo   %T_SEG_02% %DISCO% %T_SEG_03%
echo(
if "%REF_SISTEMA%"=="SI" if "%DISCO_OS%"=="%DISCO%" echo       %T_SEG_04% %SystemDrive%
if "%REF_MEDIO%"=="SI" if "%DISCO_MEDIO%"=="%DISCO%" echo       %T_SEG_05%
echo(
echo   %T_SEG_06%
echo   %T_SEG_07%
echo(
echo   %T_SEG_08%
echo(
call :PULSA_TECLA "%T_SEG_09%"
color 0A
exit /b 0

REM ---------------------------------------------------------------------
REM  EVALUAR_SEGURIDAD - decide si hace falta confirmacion de riesgo
REM  -------------------------------------------------------------------
:EVALUAR_SEGURIDAD
set "RIESGO_NECESARIO=NO"
if not "%PROTECCION_ESTADO%"=="ACTIVA" set "RIESGO_NECESARIO=SI"
if "%PROTECCION_ESTADO%"=="NA" set "RIESGO_NECESARIO=NO"
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_AVISO_RIESGO - aviso amarillo cuando no se ha podido verificar
REM  -------------------------------------------------------------------
:MOSTRAR_AVISO_RIESGO
color 0E
echo(
echo   ==================================================================
echo   %T_SEG_10%
echo   ==================================================================
echo(
echo   %T_SEG_11%
echo   %T_SEG_12%
echo(
echo   %T_SEG_13%
echo   %T_SEG_14%
echo   %T_SEG_15%
echo(
exit /b 0

REM #####################################################################
REM  PASO 13 - FIRMWARE Y AUDITORIA DE TALLER (Fase 4)
REM #####################################################################
REM  Dos subsistemas que comparten una idea: dar CONTEXTO y TRAZABILIDAD
REM  a las operaciones destructivas del taller.
REM    1) FIRMWARE: detectar si el equipo arranco en UEFI o en Legacy para
REM       escribir el esquema de particionado correcto (GPT o MBR).
REM    2) AUDITORIA: dejar un rastro en 'jah-winpe.log' de todo lo que se
REM       hace, con fecha y hora, para reconstruir una intervencion.
REM #####################################################################

REM ---------------------------------------------------------------------
REM  DETECTAR_FIRMWARE - UEFI o BIOS Legacy? (Fase 4)
REM  -------------------------------------------------------------------
REM  Rellena:
REM     FIRMWARE          -^> UEFI / LEGACY / MANUAL / ?
REM     FIRMWARE_FORMATO  -^> GPT  / MBR
REM     FIRMWARE_DUDA     -^> SI / NO  (SI = no se pudo verificar)
REM     FIRMWARE_METODO   -^> REGISTRO / BCDEDIT / MANUAL / ?
REM
REM  NO imprime nada: solo datos. La pantalla lo traduce despues (ANEXO A).
REM  Para entender de donde sale cada dato, lee el bloque "FIRMWARE Y
REM  AUDITORIA (Fase 4) - RESUMEN PARA MANTENIMIENTO" de la cabecera.
REM ---------------------------------------------------------------------
:DETECTAR_FIRMWARE
set "FIRMWARE=?"
set "FIRMWARE_FORMATO=GPT"
set "FIRMWARE_DUDA=SI"
set "FIRMWARE_METODO=?"
REM En WinPE la informacion de arranque vive en el registro, pero hay que
REM pedirle al sistema que la rellene: eso hace 'wpeutil UpdateBootInfo'.
if not "%ES_WINPE%"=="SI" goto DETECTAR_FIRMWARE_REG
if not exist "%SystemRoot%\System32\wpeutil.exe" goto DETECTAR_FIRMWARE_REG
wpeutil UpdateBootInfo >nul 2>&1
:DETECTAR_FIRMWARE_REG
REM Capa 1: registro del sistema (la mas fiable, independiente del idioma).
call :FIRMWARE_POR_REGISTRO
if not "%FIRMWARE%"=="?" goto DETECTAR_FIRMWARE_FIN
REM Capa 2: entrada de arranque del BCD (winload.efi frente a winload.exe).
call :FIRMWARE_POR_BCDEDIT
if not "%FIRMWARE%"=="?" goto DETECTAR_FIRMWARE_FIN
REM Si llegamos aqui NINGUN metodo ha funcionado: seguimos con FIRMWARE=?
REM (nunca adivinamos) y se preguntara al tecnico en el modulo de disco.
:DETECTAR_FIRMWARE_FIN
if "%FIRMWARE%"=="UEFI" set "FIRMWARE_FORMATO=GPT"
if "%FIRMWARE%"=="LEGACY" set "FIRMWARE_FORMATO=MBR"
if not "%FIRMWARE%"=="?" set "FIRMWARE_DUDA=NO"
exit /b 0

REM ---------------------------------------------------------------------
REM  FIRMWARE_POR_REGISTRO - Metodo 1 (registro del sistema)
REM  -------------------------------------------------------------------
REM  Clave: HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation
REM  Valor: SystemFirmwareType  -^>  0x1 = BIOS/Legacy ; 0x2 = UEFI.
REM  'reg query' deja en el fichero temporal una linea tipo
REM      SystemFirmwareType    REG_DWORD    0x2
REM  y el dato que queremos es el TERCER elemento (tokens=3).
REM  La clave se guarda en una variable para no pasar de 94 columnas.
REM ---------------------------------------------------------------------
:FIRMWARE_POR_REGISTRO
if not exist "%SystemRoot%\System32\reg.exe" exit /b 0
call :ARCHIVO_TEMP_FW
set "FW_CLAVE=HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation"
reg query "%FW_CLAVE%" /v SystemFirmwareType > "%F_FW%" 2>nul
if not exist "%F_FW%" exit /b 0
set "FW_REG="
for /f "usebackq tokens=3" %%A in ("%F_FW%") do set "FW_REG=%%A"
if exist "%F_FW%" del /f /q "%F_FW%" >nul 2>&1
if /i "%FW_REG%"=="0x2" set "FIRMWARE=UEFI"
if /i "%FW_REG%"=="0x2" set "FIRMWARE_METODO=REGISTRO"
if /i "%FW_REG%"=="0x1" set "FIRMWARE=LEGACY"
if /i "%FW_REG%"=="0x1" set "FIRMWARE_METODO=REGISTRO"
exit /b 0

REM ---------------------------------------------------------------------
REM  ARCHIVO_TEMP_FW - fichero temporal comun para la deteccion de firmware
REM  -------------------------------------------------------------------
REM  Se usa tanto para 'reg query' como para 'bcdedit'. Se coloca en la
REM  carpeta temporal del sistema y SIEMPRE se borra al terminar.
REM ---------------------------------------------------------------------
:ARCHIVO_TEMP_FW
set "F_FW="
if defined TEMP set "F_FW=%TEMP%\_jah_fw.txt"
if not defined F_FW set "F_FW=%SystemDrive%\_jah_fw.txt"
exit /b 0

REM ---------------------------------------------------------------------
REM  FIRMWARE_POR_BCDEDIT - Metodo 2 (entrada de arranque)
REM  -------------------------------------------------------------------
REM  El cargador de arranque es 'winload.efi' en UEFI y 'winload.exe' en
REM  Legacy. Buscamos esas cadenas en 'bcdedit /enum {current}'.
REM  Se hacen dos busquedas separadas con 'findstr /c:' (texto LITERAL)
REM  para que 'winload.efi' no se confunda con 'winload.exe'.
REM ---------------------------------------------------------------------
:FIRMWARE_POR_BCDEDIT
if not exist "%SystemRoot%\System32\bcdedit.exe" exit /b 0
if not exist "%SystemRoot%\System32\findstr.exe" exit /b 0
call :ARCHIVO_TEMP_FW
bcdedit /enum {current} > "%F_FW%" 2>nul
if not exist "%F_FW%" exit /b 0
set "FW_BCD="
findstr /i /c:"winload.efi" "%F_FW%" >nul 2>&1
if not errorlevel 1 set "FW_BCD=EFI"
if not defined FW_BCD findstr /i /c:"winload.exe" "%F_FW%" >nul 2>&1
if not defined FW_BCD if not errorlevel 1 set "FW_BCD=EXE"
if exist "%F_FW%" del /f /q "%F_FW%" >nul 2>&1
if "%FW_BCD%"=="EFI" set "FIRMWARE=UEFI"
if "%FW_BCD%"=="EFI" set "FIRMWARE_METODO=BCDEDIT"
if "%FW_BCD%"=="EXE" set "FIRMWARE=LEGACY"
if "%FW_BCD%"=="EXE" set "FIRMWARE_METODO=BCDEDIT"
exit /b 0

REM ---------------------------------------------------------------------
REM  ELEGIR_FORMATO_DUDA - pregunta el esquema si no hubo deteccion
REM  -------------------------------------------------------------------
REM  Solo actua cuando FIRMWARE_DUDA=SI (los dos metodos fallaron). En ese
REM  caso preguntamos GPT o MBR en lugar de "adivinar": escribir el
REM  esquema equivocado haria que el disco no arrancase tras instalar.
REM  Devuelve FORMATO_OK = SI / NO.
REM ---------------------------------------------------------------------
:ELEGIR_FORMATO_DUDA
set "FORMATO_OK=SI"
if not "%FIRMWARE_DUDA%"=="SI" exit /b 0
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_FW_01%
echo   ------------------------------------------------------------------
echo(
echo   %T_FW_05%
echo(
call :LEER_OPCION "%T_FW_06%" "1 2"
if "%OPCION%"=="1" set "FIRMWARE_FORMATO=GPT"
if "%OPCION%"=="2" set "FIRMWARE_FORMATO=MBR"
if not "%OPCION%"=="1" if not "%OPCION%"=="2" set "FORMATO_OK=NO"
if "%FORMATO_OK%"=="NO" echo(
if "%FORMATO_OK%"=="NO" echo   %T_FW_07%
if "%FORMATO_OK%"=="SI" set "FIRMWARE=MANUAL"
if "%FORMATO_OK%"=="SI" set "FIRMWARE_DUDA=NO"
if "%FORMATO_OK%"=="SI" set "FIRMWARE_METODO=MANUAL"
if "%FORMATO_OK%"=="SI" call :REGISTRAR FIRMWARE "MANUAL / %FIRMWARE_FORMATO%" "OK"
exit /b 0

REM ---------------------------------------------------------------------
REM  PREPARAR_LOG - elige DONDE guardar 'jah-winpe.log' (Fase 4)
REM  -------------------------------------------------------------------
REM  Rellena: LOG_ARCHIVO, LOG_PERSISTENTE (SI/NO), LOG_UBICACION, LOG_OK.
REM  Estrategia (de mas a menos persistente):
REM    1) Junto al script, si NO corre desde X: (WinPE en RAM).
REM    2) Cualquier otro disco ESCRIBIBLE del equipo (USB, disco 2...).
REM    3) %TEMP% (memoria de WinPE): funciona, pero se pierde al apagar.
REM  Para saber si una carpeta es de verdad escribible se crea y se borra
REM  un fichero de prueba: no basta con que la carpeta exista.
REM ---------------------------------------------------------------------
:PREPARAR_LOG
set "LOG_NOMBRE=jah-winpe.log"
set "LOG_ARCHIVO="
set "LOG_PERSISTENTE=NO"
set "LOG_UBICACION=RAM"
set "LOG_OK=SI"
REM Letra de la unidad desde la que se ejecuta el script (1 caracter).
set "LETRA_SCRIPT=%~d0"
if "%LETRA_SCRIPT%"=="" set "LETRA_SCRIPT=%SystemDrive%"
set "LETRA_SCRIPT=%LETRA_SCRIPT:~0,1%"
REM --- Intento 1: junto al script (si no es la RAM X:) -----------------
if /i "%LETRA_SCRIPT%"=="X" goto PREPARAR_LOG_OTRO
call :PROBAR_ESCRITURA "%~dp0"
if not "%ESCRIBIBLE%"=="SI" goto PREPARAR_LOG_OTRO
set "LOG_ARCHIVO=%~dp0%LOG_NOMBRE%"
set "LOG_PERSISTENTE=SI"
set "LOG_UBICACION=JUNTO_AL_SCRIPT"
:PREPARAR_LOG_OTRO
REM --- Intento 2: otro disco escribible (X: es RAM, se excluye) --------
if not defined LOG_ARCHIVO call :BUSCAR_UNIDAD_LOG
REM --- Intento 3: ultimo recurso, la memoria (no persistente) ----------
if not defined LOG_ARCHIVO call :LOG_EN_MEMORIA
if not defined LOG_ARCHIVO set "LOG_ARCHIVO=%SystemDrive%\%LOG_NOMBRE%"
REM --- Cabecera de sesion en el fichero --------------------------------
>> "%LOG_ARCHIVO%" echo ================================================== 2>nul
exit /b 0

REM ---------------------------------------------------------------------
REM  BUSCAR_UNIDAD_LOG - recorre las letras buscando un disco escribible
REM  -------------------------------------------------------------------
REM  Se llama desde PREPARAR_LOG. La orden 'for' recorre las letras y la
REM  subrutina PROBAR_UNIDAD decide. La condicion 'if defined LOG_ARCHIVO'
REM  de PROBAR_UNIDAD corta el bucle en cuanto encuentra una valida.
REM ---------------------------------------------------------------------
:BUSCAR_UNIDAD_LOG
for %%L in (D E F G H I J K L M N O P Q R S T U V W Y Z A B C) do call :PROBAR_UNIDAD %%L
exit /b 0

REM ---------------------------------------------------------------------
REM  PROBAR_UNIDAD - intenta usar ^<letra^>:\ como ubicacion del log
REM  -------------------------------------------------------------------
REM  Uso:  call :PROBAR_UNIDAD D
REM ---------------------------------------------------------------------
:PROBAR_UNIDAD
if defined LOG_ARCHIVO exit /b 0
if /i "%~1"=="X" exit /b 0
if not exist "%~1:\" exit /b 0
call :PROBAR_ESCRITURA "%~1:\"
if not "%ESCRIBIBLE%"=="SI" exit /b 0
set "LOG_ARCHIVO=%~1:\%LOG_NOMBRE%"
set "LOG_PERSISTENTE=SI"
set "LOG_UBICACION=UNIDAD_%~1"
exit /b 0

REM ---------------------------------------------------------------------
REM  LOG_EN_MEMORIA - ultimo recurso: dejar el log en la RAM (%TEMP%)
REM  -------------------------------------------------------------------
REM  En WinPE, %TEMP% vive en el disco RAM X:. El log funciona, pero se
REM  pierde al reiniciar; por eso LOG_PERSISTENTE se queda en NO y la
REM  pantalla lo avisa con un texto traducido (T_LOG_02).
REM ---------------------------------------------------------------------
:LOG_EN_MEMORIA
if defined LOG_ARCHIVO exit /b 0
if not defined TEMP exit /b 0
if not exist "%TEMP%\" exit /b 0
set "LOG_ARCHIVO=%TEMP%\%LOG_NOMBRE%"
exit /b 0

REM ---------------------------------------------------------------------
REM  PROBAR_ESCRITURA - comprueba si se puede escribir en una carpeta
REM  -------------------------------------------------------------------
REM  Uso:      call :PROBAR_ESCRITURA "D:\carpeta\"   (con barra final)
REM  Devuelve: ESCRIBIBLE = SI / NO.
REM  Se crea y se borra un fichero de prueba: es la unica forma honesta de
REM  saber si la carpeta admite escrituras (los CD/DVD y los medios de
REM  solo lectura fallan aqui y quedan descartados automaticamente).
REM ---------------------------------------------------------------------
:PROBAR_ESCRITURA
set "ESCRIBIBLE=NO"
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0
set "LOG_PRUEBA=%~1_jah_log_prueba.tmp"
echo prueba> "%LOG_PRUEBA%" 2>nul
if not exist "%LOG_PRUEBA%" exit /b 0
del /f /q "%LOG_PRUEBA%" >nul 2>&1
set "ESCRIBIBLE=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  REGISTRAR - anota UNA linea en el registro de actividad (Fase 4)
REM  -------------------------------------------------------------------
REM  Uso:  call :REGISTRAR TIPO "detalle" "resultado"
REM    TIPO      -^> palabra corta en mayusculas: INICIO, MENU, DISCO,
REM                 MAQUETAR, SANITIZAR, BLOQUEO, DISKPART, SALIDA...
REM    detalle   -^> texto SIN comillas ni simbolos raros.
REM    resultado -^> OK / ERROR / CANCELADO / DENEGADO / un codigo numerico.
REM
REM  El '^>^>' ANEXA al final del fichero sin borrar lo anterior: por eso el
REM  log crece y nunca se pierde lo ya anotado. Cada llamada abre, escribe
REM  y cierra el fichero, de modo que NO queda bloqueado entre lineas (algo
REM  importante cuando el disco se esta borrando justo debajo).
REM  El separador '^|' se escribe escapado para que cmd no lo confunda con
REM  una tuberia, y el '2^>nul' final silencia cualquier fallo al escribir.
REM ---------------------------------------------------------------------
:REGISTRAR
if not "%LOG_OK%"=="SI" exit /b 0
if "%~1"=="" exit /b 0
set "LOG_RES=%~3"
if "%LOG_RES%"=="" set "LOG_RES=OK"
>> "%LOG_ARCHIVO%" echo %date% %time:~0,8% ^| %~1 ^| %~2 ^| %LOG_RES% 2>nul
exit /b 0

REM #####################################################################
REM  ANEXO A - DICCIONARIO DE TEXTOS (multilenguaje)
REM #####################################################################
REM  Cada bloque define LAS MISMAS variables T_xxx con el texto de su
REM  idioma. No forman parte del flujo normal: se ENTRA en ellos desde el
REM  'goto IDIOMA_%LANG%' de CARGAR_IDIOMA y se SALE con 'exit /b 0'.
REM
REM  REGLAS AL EDITAR ESTOS BLOQUES:
REM   1) Los nombres de variable deben ser IDENTICOS en ES y en EN.
REM   2) Nunca escribas una comilla doble dentro del valor: rompe la
REM      forma  set "VAR=valor".
REM   3) El signo mayor que se escribe escapado con el caret (^), como en
REM      las flechas -^> de mas abajo: sin el caret, cmd lo interpretaria
REM      como una redireccion y crearia ficheros basura en el directorio.
REM   4) El signo de porcentaje tampoco puede aparecer dentro del valor.
REM   5) Los comentarios van en castellano (documentacion del proyecto):
REM      lo unico que se traduce es el TEXTO VISIBLE para el tecnico.
REM   6) Los textos se parten en lineas cortas a proposito: cada 'echo'
REM      imprime UNA variable y asi ninguna linea pasa de 94 columnas
REM      (el ancho de la consola fijado con 'mode con: cols=94').
REM =====================================================================

REM ---------------------------------------------------------------------
REM  IDIOMA_ES - castellano (%LANG%=ES). Idioma por defecto.
REM ---------------------------------------------------------------------
:IDIOMA_ES
set "T_AYU1_01=[4] AYUDA DEL SISTEMA - Página 1 de 2: discos y almacenamiento"
set "T_AYU1_02=DISKPART ........................ gestor de discos de Windows"
set "T_AYU1_03=Formas de uso:"
set "T_AYU1_04=diskpart                    abre la consola interactiva"
set "T_AYU1_05=diskpart /s guion.txt       ejecuta un guion de comandos"
set "T_AYU1_06=(es lo que hacen las opciones 1 y 2)"
set "T_AYU1_07=list disk                    discos físicos y su tamaño"
set "T_AYU1_08=list volume                  volúmenes/unidades y sus letras"
set "T_AYU1_09=select disk N                elige el disco N (ÍNDICE, no letra)"
set "T_AYU1_10=detail disk                  informe del disco seleccionado"
set "T_AYU1_11=clean                        borra la tabla de particiones"
set "T_AYU1_12=(rápido: los datos siguen ahí)"
set "T_AYU1_13=clean all                    sobrescribe TODO con ceros"
set "T_AYU1_14=(lento: destrucción lógica)"
set "T_AYU1_15=convert gpt                  pasa el disco a esquema GPT"
set "T_AYU1_16=convert mbr                  pasa el disco a esquema MBR"
set "T_AYU1_17=create partition primary     crea una partición primaria"
set "T_AYU1_18=(opcional: size=100000 en MB)"
set "T_AYU1_19=format fs=ntfs quick         formateo rápido en NTFS"
set "T_AYU1_20=(opcional: label=SISTEMA)"
set "T_AYU1_21=assign letter=Z              asigna una letra concreta"
set "T_AYU1_22=('assign' solo = letra libre)"
set "T_AYU1_23=exit                         salir de diskpart"
set "T_AYU1_24=Nota: diskpart exige permisos de administrador. En modo /s no"
set "T_AYU1_25=admite teclado: el guion manda y se ejecuta línea a línea."
set "T_AYU1_26=CHKDSK X: /f .................. repara errores de la tabla de archivos"
set "T_AYU1_27=CHKDSK X: /r .................. busca sectores dañados (MUY lento)"
set "T_AYU1_28=CHKDSK X: /scan ............... análisis sin desmontar la unidad"
set "T_AYU1_29=FORMAT X: /fs:ntfs /q ......... formateo rápido (sin usar diskpart)"
set "T_AYU1_30=FORMAT X: /fs:ntfs /q /p:1 .... + un pase de ceros (Windows completo)"
set "T_AYU1_31=Los guiones temporales de las opciones 1 y 2 se crean en la"
set "T_AYU1_32=carpeta temporal del sistema y se borran al terminar."
set "T_AYU1_33=Pulsa cualquier tecla para continuar con la página 2..."
set "T_AYU2_01=[4] AYUDA DEL SISTEMA - Página 2 de 2: sistema, red y utilidades"
set "T_AYU2_02=SISTEMA E INVENTARIO"
set "T_AYU2_03=systeminfo .................... ficha técnica completa del equipo"
set "T_AYU2_04=wmic bios get serialnumber .... número de serie del equipo"
set "T_AYU2_05=wmic os get caption,version ... versión exacta del sistema operativo"
set "T_AYU2_06=sfc /scannow .................. integridad de archivos del sistema"
set "T_AYU2_07=ESTADO DE LOS DISCOS (aviso SMART)"
set "T_AYU2_08=wmic diskdrive get status ......... devuelve uno de estos valores:"
set "T_AYU2_09=OK          el disco responde sin avisos de fallo"
set "T_AYU2_10=Pred Fail   aviso de fallo inminente: COPIA los datos YA y"
set "T_AYU2_11=sustituye el disco (no lo formatees ni lo borres)"
set "T_AYU2_12=wmic diskdrive get model,size,status ... modelo + tamaño + estado"
set "T_AYU2_13=Nota: 'wmic' está en desuso en Windows 11. Su equivalente en"
set "T_AYU2_14=PowerShell es:  Get-CimInstance Win32_DiskDrive"
set "T_AYU2_15=RED"
set "T_AYU2_16=ipconfig /all ................. configuración IP detallada"
set "T_AYU2_17=ping 8.8.8.8 .................. prueba de salida a Internet"
set "T_AYU2_18=nslookup ejemplo.com .......... prueba de resolución DNS"
set "T_AYU2_19=netstat -an ................... puertos y conexiones abiertas"
set "T_AYU2_20=FICHEROS Y PROCESOS"
set "T_AYU2_21=dir /s /b nombre.ext .......... busca archivos en subcarpetas"
set "T_AYU2_22=findstr /i palabra fichero .... busca texto dentro de un fichero"
set "T_AYU2_23=robocopy ORIGEN DESTINO /E .... copia recursiva robusta"
set "T_AYU2_24=tasklist ...................... procesos en marcha"
set "T_AYU2_25=taskkill /IM nombre.exe /F .... fuerza el cierre de un proceso"
set "T_AYU2_26=Notas para el taller:"
set "T_AYU2_27=- En WinPE solo existen los comandos incluidos en la imagen."
set "T_AYU2_28=Si un comando no aparece, no está: pruébalo en la opción 3."
set "T_AYU2_29=- Antes de formatear un disco, mira su estado SMART con la orden"
set "T_AYU2_30=de arriba: un disco con 'Pred Fail' no merece una instalación"
set "T_AYU2_31=nueva (el trabajo se perdería en semanas, no en años)."
set "T_AYU2_32=   Ejecutar también el 'help' nativo de CMD? [1=Sí / 2=No]:  "
set "T_AYU2_33=--- AYUDA NATIVA DE CMD (rueda del ratón para hacer scroll) ---"
set "T_AYU3_01=Pulsa cualquier tecla para volver al menú principal..."
set "T_BIEN_01=Bienvenido, técnico."
set "T_BIEN_02=Esta herramienta centraliza las operaciones más usadas del taller"
set "T_BIEN_03=para dar soporte a equipos Windows y preparar discos de forma"
set "T_BIEN_04=(rápida, repetible y sin sorpresas)."
set "T_BIEN_05=REGLAS DE ORO antes de tocar un disco:"
set "T_BIEN_06=1. Identifica SIEMPRE el disco correcto antes de borrar nada."
set "T_BIEN_07=Las opciones 1 y 2 listan los discos antes de preguntar."
set "T_BIEN_08=2. Las opciones 1 y 2 son DESTRUCTIVAS: borran la tabla de"
set "T_BIEN_09=particiones (y en la opción 2, todo el contenido del disco)."
set "T_BIEN_10=Ninguna actúa sin que tú teclees una palabra de confirmación."
set "T_BIEN_11=3. Ante la duda, consulta primero la opción 4 (Ayuda) y no"
set "T_BIEN_12=improvises con comandos que no conoces."
set "T_BIEN_13=Forma de uso: teclea el número de la opción que aparece en el"
set "T_BIEN_14=menú. Según el entorno bastará con la tecla o con pulsar ENTER."
set "T_BIEN_15=Pulsa cualquier tecla para entrar en el menú principal..."
set "T_CFM_01=[i] Confirmación no reconocida: NO se ha ejecutado nada."
set "T_CFM_02=Para continuar, teclea"
set "T_CFM_03=y pulsa ENTER (ENTER vacío cancela):"
set "T_CFM_04=Repite el NÚMERO del disco afectado"
set "T_CFM_05=CONFIRMAR"
set "T_CFM_06=RIESGO"
set "T_COM_01=[!] Entrada no válida. Teclea solo uno de los digitos permitidos."
set "T_COM_02=[!] Entrada no válida: escribe SOLO el número de disco (por"
set "T_COM_03=ejemplo: 0, 1, 2, 10), sin ceros a la izquierda, o la letra"
set "T_COM_04=A para cancelar y volver al menú."
set "T_COM_05=[!] Esta consola NO parece tener permisos de administrador."
set "T_COM_06=diskpart podrá listar los discos, pero NO podrá modificarlos"
set "T_COM_07=(devolverá acceso denegado en 'clean')."
set "T_COM_08=   Continuar de todos modos? [1=Sí / 2=No]:  "
set "T_COM_09=[!] No he podido crear ficheros de trabajo en:"
set "T_COM_10=Sin una carpeta escribible no puedo generar el guion de"
set "T_COM_11=diskpart, y sin guion no se ejecuta nada. ABORTAMOS sin"
set "T_COM_12=tocar ningún disco (la seguridad primero)."
set "T_COM_13=[!] No encuentro diskpart.exe en esta imagen."
set "T_COM_14=¿Es un WinPE muy recortado? Este módulo no puede continuar."
set "T_COM_15=Teclea el NUMERO de disco sobre el que quieres trabajar."
set "T_COM_16=Ese numero es la PRIMERA columna del listado de arriba"
set "T_COM_17=(Disk 0 / Disco 0, Disk 1 / Disco 1...). Nunca es una letra."
set "T_COM_18=Para cancelar y volver al menu: teclea  A  y pulsa ENTER."
set "T_COM_19=   Número de disco:  "
set "T_COM_24=   ¿Qué hacemos? [1=Corregir / 2=Continuar / 3=Cancelar]:  "
set "T_COM_25=VERIFICACIÓN FINAL: este es el estado ACTUAL del equipo."
set "T_COM_26=Cómo comprobar el resultado:"
set "T_COM_27=en 'list volume', un volumen SISTEMA en NTFS con su letra."
set "T_COM_28=(sin particiones ni volúmenes). Eso es lo correcto."
set "T_COM_29=- Si el disco no muestra el resultado esperado, revisa el aviso"
set "T_COM_30=que dio diskpart antes de repetir cualquier operación."
set "T_COM_31=Consultando los discos del equipo con diskpart (solo lectura)..."
set "T_COM_32=Cómo leer este listado:"
set "T_COM_33=- 'list disk'    los discos físicos: mira la PRIMERA columna"
set "T_COM_34=(Disk 0, Disk 1...) y compárala con el TAMAÑO."
set "T_COM_35=- Estado 'Online' o 'En línea': el disco está operativo."
set "T_COM_36=- La marca '*' en la columna 'Gpt' significa que ya es GPT."
set "T_COM_37=- 'list volume'  qué volúmenes hay y con qué LETRA de unidad."
set "T_COM_38=- Truco de seguridad: mira la ETIQUETA del disco en la caja del"
set "T_COM_39=equipo. Un disco de 500 GB no puede ser el de 1 TB."
set "T_COM_40=Sin listado no se puede elegir disco con seguridad: volvemos"
set "T_COM_41=al menú sin tocar nada."
set "T_COM_42=Herramienta de Soporte Técnico"
set "T_COM_43=Versión"
set "T_COM_44=Fase"
set "T_COM_45=Entorno:"
set "T_COM_47=GUION TEMPORAL que se va a ejecutar"
set "T_COM_48=[OK] diskpart terminó sin errores (código 0)."
set "T_COM_49=[!] diskpart devolvió el código de error"
set "T_COM_50=[!] diskpart no ha podido completar el listado. Código de error:"
set "T_COM_51=Disco elegido:"
set "T_CONS_01=[3] CONSOLA AVANZADA"
set "T_CONS_02=Abriendo una consola CMD interactiva en la MISMA ventana."
set "T_CONS_03=- Escribe 'exit' para volver al menú principal."
set "T_CONS_04=- Heredas el entorno actual (unidad de trabajo, variables)."
set "T_CONS_05=- OJO: los cambios que hagas en variables NO afectan al menú."
set "T_CONS_06=Recuerda: primero mira, después actúa. Para discos:"
set "T_CONS_07=diskpart  -^>  list disk  -^>  detail disk  -^>  exit"
set "T_D1_01=[1] PREPARACIÓN RÁPIDA DE DISCO (maquetación)"
set "T_D1_02=Este módulo deja un disco listo para instalar Windows:"
set "T_D1_03=a) Lista los discos físicos y sus tamaños (diskpart, solo lectura)."
set "T_D1_04=b) Te pide el NÚMERO del disco a preparar (entrada validada)."
set "T_D1_05=c) Genera el guion de diskpart con los comandos exactos y te lo"
set "T_D1_06=muestra para que lo leas ANTES de ejecutar nada."
set "T_D1_07=d) Exige que teclees la palabra"
set "T_D1_08=e) Ejecuta y vuelve a listar el equipo para verificar."
set "T_D1_09=Orden de comandos:  clean  -^>  convert (GPT o MBR)  -^>"
set "T_D1_10=create partition primary  -^>  format fs=ntfs quick label=SISTEMA"
set "T_D1_11=-^>  assign (letra libre que Windows elija)."
set "T_D1_12=RECUERDA: 'clean' borra la tabla de particiones del disco elegido."
set "T_D1_13=Todo lo que hubiera en él dejará de ser visible de inmediato."
set "T_D1_14=Pulsa cualquier tecla para empezar por el listado..."
set "T_D1_15=[1] PREPARACIÓN RÁPIDA DE DISCO - RESUMEN Y CONFIRMACIÓN"
set "T_D1_16=Acción:         borrar la tabla de particiones y crear una única"
set "T_D1_17=partición NTFS (GPT o MBR segun firmware) con la etiqueta SISTEMA."
set "T_D1_18=ejecución. La protección de arranque bloquea el disco del sistema"
set "T_D1_19=cuando consigue identificarlo; si arriba no aparece como protegido,"
set "T_D1_20=el riesgo es tuyo: ante la mínima duda, cancela (letra C:)."
set "T_D1_21=Módulo terminado. Pulsa cualquier tecla para volver al menú..."
set "T_D1_22=Operación cancelada: no se ha tocado ningún disco."
set "T_D1_23=- Maquetación (opción 1): el Disco"
set "T_D1_24=[!] Estás en Windows COMPLETO, no en WinPE: hay un sistema en"
set "T_D1_25=debe mostrar Gpt y,"
set "T_D1_26=y repites el número de disco para continuar."
set "T_D2_01=[2] BORRADO SEGURO / SANITIZACIÓN"
set "T_D2_02=Qué hace: escribe CEROS sobre todas las áreas direccionables del"
set "T_D2_03=disco para que los datos anteriores no se puedan recuperar con"
set "T_D2_04=utilidades de recuperación. En diskpart:  clean all"
set "T_D2_05=Marco de referencia (NIST SP 800-88, nivel PURGE):"
set "T_D2_06='clean'      destruye solo la tabla de particiones (segundos),"
set "T_D2_07=pero los datos siguen en el disco: se recuperan."
set "T_D2_08='clean all'  sobrescribe el contenido (horas) y la recuperación"
set "T_D2_09=práctica deja de ser viable. Es lo que haremos."
set "T_D2_10=Para el nivel DESTROY (destrucción física del medio) no hay"
set "T_D2_11=software que valga: trituradora o incineradora certificadas."
set "T_D2_12=[2] BORRADO SEGURO - RESUMEN Y CONFIRMACIÓN"
set "T_D2_13=Acción:         clean all  (sobrescritura completa con ceros)"
set "T_D2_14=TIEMPO ESTIMADO (orientativo; depende del disco y de su conexión):"
set "T_D2_15=Disco de 250 GB ......... de 30 a 60 minutos"
set "T_D2_16=Disco de 500 GB ......... de 1 a 2 horas"
set "T_D2_17=Disco de 1 TB ........... de 2 a 4 horas"
set "T_D2_18=Disco de 2 TB ........... de 4 a 8 horas"
set "T_D2_19=SSD (mejor por USB) ..... suele ir más rápido, pero ver aviso"
set "T_D2_20=AVISOS IMPORTANTES:"
set "T_D2_21=- NO interrumpas el proceso (ni teclas, ni reinicio, ni apagado):"
set "T_D2_22=un 'clean all' a medias deja el disco en un estado irregular."
set "T_D2_23=- En SSD, 'clean all' NO garantiza el borrado físico: el"
set "T_D2_24=controlador reparte las escrituras. Para eso se usa la"
set "T_D2_25=herramienta del fabricante o el ATA Secure Erase."
set "T_D2_26=- Si el disco ya tiene fallos físicos, esto no los arregla."
set "T_D2_27=- Un disco sanitizado queda EN BRUTO (sin particiones): luego"
set "T_D2_28=puedes maquetarlo con la opción [1]."
set "T_D2_29=[!] Estás en Windows COMPLETO, no en WinPE: hay un sistema en"
set "T_D2_30=cuando consigue identificarlo; si arriba no aparece como protegido,"
set "T_D2_31=el riesgo es tuyo: ante la mínima duda, cancela (letra C:)."
set "T_D2_32=Para el borrado seguro se piden DOS confirmaciones escritas."
set "T_D2_33=- Borrado seguro (opción 2): el Disco"
set "T_D2_34=ejecución. La protección de arranque bloquea el disco del sistema"
set "T_D2_35=aparecerá EN BRUTO"
set "T_FW_01=FIRMWARE Y ESQUEMA DE PARTICIONADO"
set "T_FW_02=Firmware detectado:"
set "T_FW_03=Esquema de particionado:"
set "T_FW_04=Ajuste automatico: UEFI -^> GPT ;  BIOS Legacy -^> MBR."
set "T_FW_05=[!] Firmware SIN VERIFICAR (ni registro ni BCD): elige el esquema."
set "T_FW_06=   Esquema a aplicar [1=GPT / 2=MBR]:  "
set "T_FW_07=Esquema no elegido: operacion cancelada, no se toca nada."
set "T_DP_01=EJECUTANDO DISKPART. No pulses teclas, no cierres la ventana y no"
set "T_DP_02=apagues el equipo mientras el comando esté en curso."
set "T_DP_03=Nota: diskpart escribe en el idioma del sistema. Si ves caracteres"
set "T_DP_04=raros, prueba en la Consola Avanzada:  chcp 850   y luego  chcp 65001"
set "T_MENU_01=MENÚ PRINCIPAL"
set "T_MENU_02=[1]  Preparación rápida de disco        limpieza y formato básico"
set "T_MENU_03=[2]  Borrado seguro / Sanitización      destrucción lógica de datos"
set "T_MENU_04=[3]  Consola Avanzada                   salir a CMD interactivo"
set "T_MENU_05=[4]  Ayuda del sistema                  guía rápida del técnico"
set "T_MENU_06=[5]  Salir / Apagar equipo"
set "T_MENU_07=Aviso: [1] y [2] modifican DISCOS de verdad y piden confirmación"
set "T_MENU_08=escrita. [3], [4] y [5] no tocan el hardware por sí solas."
set "T_MENU_09=(Si la consola no reacciona a una sola tecla, teclea el número"
set "T_MENU_10=y termina con ENTER.)"
set "T_MENU_11=   Su opción [1-5]:  "
set "T_MENU_12=Fecha y hora:"
set "T_MENU_13=Modo de entrada:"
set "T_MENU_14=Firmware:"
set "T_LOG_01=Registro (log): PERSISTENTE en"
set "T_LOG_02=Registro (log): solo en RAM (se perdera al reiniciar):"
set "T_SAL_01=[5] SALIR / APAGAR EQUIPO"
set "T_SAL_02=[1]  Apagar el equipo"
set "T_SAL_03=[2]  Salir de la herramienta y volver al sistema"
set "T_SAL_04=[3]  Volver al menú principal (me he equivocado)"
set "T_SAL_05=   Su opción [1-3]:  "
set "T_SAL_06=!!!  ATENCIÓN  !!!"
set "T_SAL_07=Vas a apagar el equipo. Se interrumpirá cualquier trabajo en"
set "T_SAL_08=curso y, si arrancaste desde WinPE, terminará la sesión de"
set "T_SAL_09=recuperación actual (los cambios ya guardados en el arranque RAM"
set "T_SAL_10=no se conservan)."
set "T_SAL_11=   Confirmar apagado? [1=Sí / 2=No]:  "
set "T_SAL_12=Enviando señal de apagado con wpeutil (entorno WinPE detectado)..."
set "T_SAL_13=Apagado programado en 5 segundos."
set "T_SAL_14=Si te arrepientes desde OTRA consola escribe:  shutdown /a"
set "T_SAL_15=Pulsa cualquier tecla para cerrar..."
set "T_SAL_16=Sesión finalizada. Gracias por usar"
set "T_SEG_01=[!] BLOQUEO DE SEGURIDAD: OPERACIÓN DENEGADA"
set "T_SEG_02=El disco número"
set "T_SEG_03=está PROTEGIDO: no puede prepararse ni borrarse con esta herramienta."
set "T_SEG_04=Motivo: es el disco del sistema en ejecución (Windows) -^> unidad"
set "T_SEG_05=Motivo: es el disco desde el que se ha arrancado/lanzado esta herramienta."
set "T_SEG_06=Ningún guion de diskpart se ha generado ni se va a ejecutar."
set "T_SEG_07=Elige OTRO disco si de verdad querías operar sobre otro."
set "T_SEG_08=Si necesitas borrar este disco, hazlo desde OTRO equipo o soporte."
set "T_SEG_09=Pulsa cualquier tecla para volver al menú..."
set "T_SEG_10=[!] AVISO: NO SE HA PODIDO VERIFICAR EL DISCO DE ARRANQUE"
set "T_SEG_11=La herramienta no puede saber ahora mismo cuál de los discos"
set "T_SEG_12=es el de arranque (WinPE recortado, sin PowerShell o diskpart en otro idioma)."
set "T_SEG_13=Es tu RESPONSABILIDAD no elegir el disco del sistema en ejecución"
set "T_SEG_14=ni el medio desde el que se ha arrancado. Ante la mínima duda: CANCELA."
set "T_SEG_15=Para seguir tendrás que teclear una palabra de RIESGO y luego CONFIRMAR."
set "T_SEG_16=Protección de arranque: ACTIVA (este disco NO es el de arranque)."
set "T_SEG_17=Protección de arranque: SIN VERIFICAR (podría ser el de arranque)."
set "T_SEG_18=Protección de arranque: no aplica (WinPE en memoria RAM)."
set "T_SEG_19=[!] El disco número"
set "T_SEG_20=no aparece en el listado de discos."
set "T_SEG_21=Puede ser que el número esté mal, o que tu Windows"
set "T_SEG_22=traduzca la salida de diskpart con otras palabras."
set "T_SEG_23=Si eliges 'Continuar' tendrás que confirmarlo con una palabra extra."
exit /b 0

REM ---------------------------------------------------------------------
REM  IDIOMA_EN - ingles (%LANG%=EN).
REM  Mismos nombres de variable que el bloque anterior, uno a uno.
REM ---------------------------------------------------------------------
:IDIOMA_EN
set "T_AYU1_01=[4] SYSTEM HELP - Page 1 of 2: disks and storage"
set "T_AYU1_02=DISKPART ........................ Windows disk manager"
set "T_AYU1_03=Ways to use it:"
set "T_AYU1_04=diskpart                    opens the interactive console"
set "T_AYU1_05=diskpart /s script.txt      runs a batch of commands"
set "T_AYU1_06=(this is what options 1 and 2 do)"
set "T_AYU1_07=list disk                    physical disks and their size"
set "T_AYU1_08=list volume                  volumes/drives and their letters"
set "T_AYU1_09=select disk N                picks disk N (INDEX, not a letter)"
set "T_AYU1_10=detail disk                  report of the selected disk"
set "T_AYU1_11=clean                        erases the partition table"
set "T_AYU1_12=(fast: the data is still there)"
set "T_AYU1_13=clean all                    overwrites EVERYTHING with zeros"
set "T_AYU1_14=(slow: logical destruction)"
set "T_AYU1_15=convert gpt                  converts the disk to GPT layout"
set "T_AYU1_16=convert mbr                  converts the disk to MBR layout"
set "T_AYU1_17=create partition primary     creates one primary partition"
set "T_AYU1_18=(optional: size=100000 in MB)"
set "T_AYU1_19=format fs=ntfs quick         quick NTFS format"
set "T_AYU1_20=(optional: label=SISTEMA)"
set "T_AYU1_21=assign letter=Z              assigns a specific drive letter"
set "T_AYU1_22=('assign' alone = next free letter)"
set "T_AYU1_23=exit                         leaves diskpart"
set "T_AYU1_24=Note: diskpart needs administrator rights. In /s mode it"
set "T_AYU1_25=accepts no keyboard: the script rules and runs line by line."
set "T_AYU1_26=CHKDSK X: /f .................. repairs file table errors"
set "T_AYU1_27=CHKDSK X: /r .................. scans for bad sectors (VERY slow)"
set "T_AYU1_28=CHKDSK X: /scan ............... checks without dismounting the drive"
set "T_AYU1_29=FORMAT X: /fs:ntfs /q ......... quick format (without diskpart)"
set "T_AYU1_30=FORMAT X: /fs:ntfs /q /p:1 .... + one zero pass (full Windows)"
set "T_AYU1_31=The temporary scripts of options 1 and 2 are created in the"
set "T_AYU1_32=system temp folder and are deleted when finished."
set "T_AYU1_33=Press any key to continue to page 2..."
set "T_AYU2_01=[4] SYSTEM HELP - Page 2 of 2: system, network and tools"
set "T_AYU2_02=SYSTEM AND INVENTORY"
set "T_AYU2_03=systeminfo .................... full technical sheet of the machine"
set "T_AYU2_04=wmic bios get serialnumber .... machine serial number"
set "T_AYU2_05=wmic os get caption,version ... exact operating system version"
set "T_AYU2_06=sfc /scannow .................. system file integrity"
set "T_AYU2_07=DISK HEALTH (SMART warning)"
set "T_AYU2_08=wmic diskdrive get status ......... returns one of these values:"
set "T_AYU2_09=OK          the disk answers with no failure warning"
set "T_AYU2_10=Pred Fail   imminent failure warning: COPY the data NOW and"
set "T_AYU2_11=replace the disk (do not format or erase it)"
set "T_AYU2_12=wmic diskdrive get model,size,status ... model + size + status"
set "T_AYU2_13=Note: 'wmic' is deprecated in Windows 11. Its equivalent in"
set "T_AYU2_14=PowerShell is:  Get-CimInstance Win32_DiskDrive"
set "T_AYU2_15=NETWORK"
set "T_AYU2_16=ipconfig /all ................. detailed IP configuration"
set "T_AYU2_17=ping 8.8.8.8 .................. Internet connectivity test"
set "T_AYU2_18=nslookup example.com .......... DNS resolution test"
set "T_AYU2_19=netstat -an ................... open ports and connections"
set "T_AYU2_20=FILES AND PROCESSES"
set "T_AYU2_21=dir /s /b name.ext ............ searches files in subfolders"
set "T_AYU2_22=findstr /i word file .......... searches text inside a file"
set "T_AYU2_23=robocopy SOURCE TARGET /E .... robust recursive copy"
set "T_AYU2_24=tasklist ...................... running processes"
set "T_AYU2_25=taskkill /IM name.exe /F ...... forces a process to close"
set "T_AYU2_26=Notes for the workshop:"
set "T_AYU2_27=- In WinPE only the commands included in the image exist."
set "T_AYU2_28=If a command is missing, it is not there: try it in option 3."
set "T_AYU2_29=- Before formatting a disk, check its SMART status with the"
set "T_AYU2_30=command above: a disk with 'Pred Fail' does not deserve a new"
set "T_AYU2_31=install (the work would be lost in weeks, not in years)."
set "T_AYU2_32=   Also run the native CMD 'help'? [1=Yes / 2=No]:  "
set "T_AYU2_33=--- NATIVE CMD HELP (use the mouse wheel to scroll) ---"
set "T_AYU3_01=Press any key to return to the main menu..."
set "T_BIEN_01=Welcome, technician."
set "T_BIEN_02=This tool brings together the workshop's most common"
set "T_BIEN_03=operations to service Windows machines and prepare disks"
set "T_BIEN_04=in a fast, repeatable and surprise-free way."
set "T_BIEN_05=GOLDEN RULES before touching any disk:"
set "T_BIEN_06=1. ALWAYS identify the right disk before erasing anything."
set "T_BIEN_07=Options 1 and 2 list the disks before asking."
set "T_BIEN_08=2. Options 1 and 2 are DESTRUCTIVE: they erase the partition"
set "T_BIEN_09=table (and in option 2, all the data on the disk)."
set "T_BIEN_10=None of them acts unless you type a confirmation word."
set "T_BIEN_11=3. When in doubt, read option 4 (Help) first and do not"
set "T_BIEN_12=improvise with commands you do not know."
set "T_BIEN_13=How to use it: type the number of the option shown in the"
set "T_BIEN_14=menu. Depending on the environment the key alone or ENTER will do."
set "T_BIEN_15=Press any key to enter the main menu..."
set "T_CFM_01=[i] Confirmation not recognised: NOTHING has been executed."
set "T_CFM_02=To continue, type"
set "T_CFM_03=and press ENTER (empty ENTER cancels):"
set "T_CFM_04=Type the NUMBER of the affected disk again"
set "T_CFM_05=CONFIRM"
set "T_CFM_06=RISK"
set "T_COM_01=[!] Invalid input. Type only one of the allowed digits."
set "T_COM_02=[!] Invalid input: type ONLY the disk number (for"
set "T_COM_03=example: 0, 1, 2, 10), with no leading zeros, or the letter"
set "T_COM_04=A to cancel and return to the menu."
set "T_COM_05=[!] This console does NOT seem to have administrator rights."
set "T_COM_06=diskpart will be able to list the disks, but NOT to modify them"
set "T_COM_07=(it will return access denied on 'clean')."
set "T_COM_08=   Continue anyway? [1=Yes / 2=No]:  "
set "T_COM_09=[!] I could not create working files in:"
set "T_COM_10=Without a writable folder I cannot build the diskpart"
set "T_COM_11=script, and without a script nothing runs. WE ABORT without"
set "T_COM_12=touching any disk (safety first)."
set "T_COM_13=[!] I cannot find diskpart.exe in this image."
set "T_COM_14=Is it a very trimmed WinPE? This module cannot continue."
set "T_COM_15=Type the disk NUMBER you want to work on."
set "T_COM_16=That number is the FIRST column of the listing above"
set "T_COM_17=(Disk 0, Disk 1...). It is never a drive letter."
set "T_COM_18=To cancel and return to the menu: type  A  and press ENTER."
set "T_COM_19=   Disk number:  "
set "T_COM_24=   What do we do? [1=Fix / 2=Continue / 3=Cancel]:  "
set "T_COM_25=FINAL CHECK: this is the CURRENT state of the machine."
set "T_COM_26=How to check the result:"
set "T_COM_27=in 'list volume', a SISTEMA volume in NTFS with its letter."
set "T_COM_28=(with no partitions or volumes). That is correct."
set "T_COM_29=- If the disk does not show the expected result, check the"
set "T_COM_30=warning diskpart gave before repeating any operation."
set "T_COM_31=Reading the machine disks with diskpart (read only)..."
set "T_COM_32=How to read this listing:"
set "T_COM_33=- 'list disk'    the physical disks: look at the FIRST column"
set "T_COM_34=(Disk 0, Disk 1...) and compare it with the SIZE."
set "T_COM_35=- Status 'Online': the disk is operational."
set "T_COM_36=- The '*' mark in the 'Gpt' column means it is already GPT."
set "T_COM_37=- 'list volume'  which volumes exist and with which drive LETTER."
set "T_COM_38=- Safety tip: look at the LABEL on the case of the machine."
set "T_COM_39=A 500 GB disk cannot possibly be the 1 TB one."
set "T_COM_40=Without a listing no disk can be chosen safely: we return"
set "T_COM_41=to the menu without touching anything."
set "T_COM_42=Technical Support Tool"
set "T_COM_43=Version"
set "T_COM_44=Phase"
set "T_COM_45=Environment:"
set "T_COM_47=TEMPORARY SCRIPT about to be run"
set "T_COM_48=[OK] diskpart finished with no errors (code 0)."
set "T_COM_49=[!] diskpart returned the error code"
set "T_COM_50=[!] diskpart could not complete the listing. Error code:"
set "T_COM_51=Selected disk:"
set "T_CONS_01=[3] ADVANCED CONSOLE"
set "T_CONS_02=Opening an interactive CMD console in the SAME window."
set "T_CONS_03=- Type 'exit' to return to the main menu."
set "T_CONS_04=- You inherit the current environment (work drive, variables)."
set "T_CONS_05=- NOTE: any variable change you make does NOT affect the menu."
set "T_CONS_06=Remember: look first, act later. For disks:"
set "T_CONS_07=diskpart  -^>  list disk  -^>  detail disk  -^>  exit"
set "T_D1_01=[1] QUICK DISK PREPARATION (layout)"
set "T_D1_02=This module leaves a disk ready to install Windows:"
set "T_D1_03=a) Lists the physical disks and sizes (diskpart, read only)."
set "T_D1_04=b) Asks you for the NUMBER of the disk (validated input)."
set "T_D1_05=c) Builds the diskpart script with the exact commands and"
set "T_D1_06=shows it so that you read it BEFORE running anything."
set "T_D1_07=d) Requires you to type the word"
set "T_D1_08=e) Runs it and lists the machine again to verify."
set "T_D1_09=Command order:  clean  -^>  convert (GPT or MBR)  -^>"
set "T_D1_10=create partition primary  -^>  format fs=ntfs quick label=SISTEMA"
set "T_D1_11=-^>  assign (free letter chosen by Windows)."
set "T_D1_12=REMEMBER: 'clean' erases the partition table of the chosen disk."
set "T_D1_13=Everything on it stops being visible immediately."
set "T_D1_14=Press any key to start with the listing..."
set "T_D1_15=[1] QUICK DISK PREPARATION - SUMMARY AND CONFIRMATION"
set "T_D1_16=Action:         erase the partition table and create one single"
set "T_D1_17=NTFS partition (GPT or MBR per firmware) with the SISTEMA label."
set "T_D1_18=here. The boot protection blocks the system disk when it"
set "T_D1_19=can identify it; if it does not appear as protected above,"
set "T_D1_20=the risk is yours: at the slightest doubt, cancel (drive C:)."
set "T_D1_21=Module finished. Press any key to return to the menu..."
set "T_D1_22=Operation cancelled: no disk has been touched."
set "T_D1_23=- Layout (option 1): Disk"
set "T_D1_24=[!] You are in FULL Windows, not in WinPE: a system is running"
set "T_D1_25=must show Gpt and,"
set "T_D1_26=and retype the disk NUMBER to continue."
set "T_D2_01=[2] SECURE ERASE / SANITIZATION"
set "T_D2_02=What it does: writes ZEROS over every addressable area of the"
set "T_D2_03=disk so that the previous data cannot be recovered with"
set "T_D2_04=recovery utilities. In diskpart:  clean all"
set "T_D2_05=Reference framework (NIST SP 800-88, PURGE level):"
set "T_D2_06='clean'      destroys only the partition table (seconds),"
set "T_D2_07=but the data stays on the disk: it can be recovered."
set "T_D2_08='clean all'  overwrites the content (hours) and practical"
set "T_D2_09=recovery is no longer viable. That is what we will do."
set "T_D2_10=For the DESTROY level (physical destruction of the media) no"
set "T_D2_11=software helps: a certified shredder or incinerator."
set "T_D2_12=[2] SECURE ERASE - SUMMARY AND CONFIRMATION"
set "T_D2_13=Action:         clean all  (full overwrite with zeros)"
set "T_D2_14=ESTIMATED TIME (rough; depends on the disk and its connection):"
set "T_D2_15=250 GB disk ......... from 30 to 60 minutes"
set "T_D2_16=500 GB disk ......... from 1 to 2 hours"
set "T_D2_17=1 TB disk ........... from 2 to 4 hours"
set "T_D2_18=2 TB disk ........... from 4 to 8 hours"
set "T_D2_19=SSD (better over USB) .... usually faster, but see the warning"
set "T_D2_20=IMPORTANT WARNINGS:"
set "T_D2_21=- Do NOT interrupt the process (no keys, no reboot, no power off):"
set "T_D2_22=a half done 'clean all' leaves the disk in an irregular state."
set "T_D2_23=- On SSD, 'clean all' does NOT guarantee a physical erase: the"
set "T_D2_24=controller spreads the writes. For that the manufacturer tool"
set "T_D2_25=or the ATA Secure Erase is used."
set "T_D2_26=- If the disk already has physical faults, this does not fix them."
set "T_D2_27=- A sanitized disk is left RAW (no partitions): you can then"
set "T_D2_28=lay it out with option [1]."
set "T_D2_29=[!] You are in FULL Windows, not in WinPE: a system is running"
set "T_D2_30=can identify it; if it does not appear as protected above,"
set "T_D2_31=the risk is yours: at the slightest doubt, cancel (drive C:)."
set "T_D2_32=For the secure erase TWO written confirmations are required."
set "T_D2_33=- Secure erase (option 2): Disk"
set "T_D2_34=here. The boot protection blocks the system disk when it"
set "T_D2_35=will appear RAW"
set "T_FW_01=FIRMWARE AND PARTITION LAYOUT"
set "T_FW_02=Detected firmware:"
set "T_FW_03=Partition layout:"
set "T_FW_04=Automatic fit: UEFI -^> GPT ;  BIOS Legacy -^> MBR."
set "T_FW_05=[!] Firmware UNVERIFIED (no registry or BCD): choose the layout."
set "T_FW_06=   Layout to apply [1=GPT / 2=MBR]:  "
set "T_FW_07=No layout chosen: operation cancelled, nothing is touched."
set "T_DP_01=RUNNING DISKPART. Do not press keys, do not close the window and"
set "T_DP_02=do not power off the machine while the command is running."
set "T_DP_03=Note: diskpart writes in the system language. If you see strange"
set "T_DP_04=characters, try the Advanced Console:  chcp 850   then  chcp 65001"
set "T_MENU_01=MAIN MENU"
set "T_MENU_02=[1]  Quick disk preparation             wipe table and format"
set "T_MENU_03=[2]  Secure erase / Sanitization        logical data destruction"
set "T_MENU_04=[3]  Advanced console                   drop to interactive CMD"
set "T_MENU_05=[4]  System help                        technician quick guide"
set "T_MENU_06=[5]  Exit / Shut down the computer"
set "T_MENU_07=Warning: [1] and [2] really modify DISKS and ask for a written"
set "T_MENU_08=confirmation. [3], [4] and [5] do not touch hardware on their own."
set "T_MENU_09=(If the console does not react to a single key, type the number"
set "T_MENU_10=and finish with ENTER.)"
set "T_MENU_11=   Your option [1-5]:  "
set "T_MENU_12=Date and time:"
set "T_MENU_13=Input mode:"
set "T_MENU_14=Firmware:"
set "T_LOG_01=Activity log: PERSISTENT at"
set "T_LOG_02=Activity log: RAM only (lost on reboot):"
set "T_SAL_01=[5] EXIT / SHUT DOWN THE COMPUTER"
set "T_SAL_02=[1]  Shut down the computer"
set "T_SAL_03=[2]  Exit the tool and return to the system"
set "T_SAL_04=[3]  Return to the main menu (my mistake)"
set "T_SAL_05=   Your option [1-3]:  "
set "T_SAL_06=!!!  WARNING  !!!"
set "T_SAL_07=You are about to shut down the computer. Any work in progress"
set "T_SAL_08=will be interrupted and, if you booted from WinPE, the current"
set "T_SAL_09=recovery session will end (changes already saved in the RAM boot"
set "T_SAL_10=are not kept)."
set "T_SAL_11=   Confirm shutdown? [1=Yes / 2=No]:  "
set "T_SAL_12=Sending the shutdown signal with wpeutil (WinPE detected)..."
set "T_SAL_13=Shutdown scheduled in 5 seconds."
set "T_SAL_14=If you change your mind from ANOTHER console type:  shutdown /a"
set "T_SAL_15=Press any key to close..."
set "T_SAL_16=Session finished. Thank you for using"
set "T_SEG_01=[!] SECURITY BLOCK: OPERATION DENIED"
set "T_SEG_02=Disk number"
set "T_SEG_03=is PROTECTED: it cannot be prepared or wiped by this tool."
set "T_SEG_04=Reason: it is the disk of the running Windows system -^> drive"
set "T_SEG_05=Reason: it is the disk this tool was booted/launched from."
set "T_SEG_06=No diskpart script has been generated or will be executed."
set "T_SEG_07=Choose ANOTHER disk if you really meant to work on a different one."
set "T_SEG_08=If you must wipe this disk, do it from ANOTHER computer or media."
set "T_SEG_09=Press any key to return to the menu..."
set "T_SEG_10=[!] WARNING: THE BOOT DISK COULD NOT BE VERIFIED"
set "T_SEG_11=The tool cannot tell right now which of the disks"
set "T_SEG_12=is the boot one (trimmed WinPE, no PowerShell or diskpart in another language)."
set "T_SEG_13=It is YOUR RESPONSIBILITY not to pick the running system disk"
set "T_SEG_14=nor the media WinPE was booted from. At the slightest doubt: CANCEL."
set "T_SEG_15=To continue you will have to type a RISK word and then CONFIRM."
set "T_SEG_16=Boot protection: ACTIVE (this disk is NOT the boot disk)."
set "T_SEG_17=Boot protection: UNVERIFIED (it might be the boot disk)."
set "T_SEG_18=Boot protection: not applicable (WinPE in RAM memory)."
set "T_SEG_19=[!] Disk number"
set "T_SEG_20=does not appear in the disk listing."
set "T_SEG_21=The number may be wrong, or your Windows"
set "T_SEG_22=translates the diskpart output with different words."
set "T_SEG_23=If you pick 'Continue' you will have to confirm with an extra word."
exit /b 0
