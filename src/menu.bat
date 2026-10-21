@echo off
REM =====================================================================
REM  PALETA ANSI (se define ANTES de imprimir cualquier texto)
REM  -------------------------------------------------------------------
REM  La consola de Windows/WinPE entiende secuencias ANSI/VT. cmd.exe no
REM  tiene una variable oficial para el caracter ESC (0x1B), asi que se
REM  obtiene con el truco clasico de 'prompt':
REM     $E -^> caracter de escape
REM  A partir de ESC se definen los colores por linea. NUNCA se usa el
REM  comando 'color': ese comando repinta toda la consola y provoca el
REM  parpadeo a blanco que queremos evitar.
REM  Si ESC no se pudiera obtener, los colores quedan vacios y el texto
REM  se imprime igual (la interfaz nunca se rompe por falta de color).
REM  C_FIN devuelve la consola al color de reposo (blanco brillante).
REM =====================================================================
set "ESC="
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "C_VERDE="
set "C_AMARILLO="
set "C_ROJO="
set "C_BLANCO="
set "C_RESET="
if defined ESC set "C_VERDE=%ESC%[92m"
if defined ESC set "C_AMARILLO=%ESC%[93m"
if defined ESC set "C_ROJO=%ESC%[91m"
if defined ESC set "C_BLANCO=%ESC%[97m"
if defined ESC set "C_RESET=%ESC%[0m"
set "C_FIN=%C_RESET%%C_BLANCO%"

REM =====================================================================
REM  JAH-WinPe  ::  menu.bat  -  INTERFAZ PRINCIPAL DEL TALLER
REM =====================================================================
REM  PROYECTO   : JAH-WinPe - herramienta de soporte tecnico en consola
REM               (Windows completo y WinPE de arranque).
REM  COMPONENTE : menu.bat -^> seleccion de idioma, pantalla de bienvenida,
REM               menu principal, ayuda del sistema, modulos de disco con
REM               diskpart, ESCUDO DE SEGURIDAD del disco de arranque,
REM               DETECCION DE FIRMWARE (UEFI / Legacy), REGISTRO DE
REM               ACTIVIDAD (log), DIAGNOSTICO / INVENTARIO de solo
REM               lectura, LECTURA DEL TAMANO REAL del disco con
REM               ESTIMACION del tiempo de borrado y salida ordenada.
REM  FASE       : 1.0 (anade el modulo de INVENTARIO de hardware de solo
REM               lectura y la LECTURA DEL TAMANO REAL del disco para
REM               ESTIMAR el tiempo del borrado seguro 'clean all'; se
REM               conservan el firmware, el log, el escudo de seguridad
REM               y el multilenguaje de las fases anteriores).
REM  VERSION    : 1.0.0
REM
REM  --------------------------------------------------------------------
REM  MAPA DE NAVEGACION (etiquetas del script)
REM  --------------------------------------------------------------------
REM    SELECCION_IDIOMA -^> elegir castellano/ingles -^> BIENVENIDA
REM    BIENVENIDA  -^> bienvenida una sola vez -^> MENU
REM    MENU        -^> [1] OP_DISCO ......... operaciones sobre discos y particiones
REM                -^> [2] OP_SANITIZAR ..... borrado 3 NIVELES: clean/TRIM/clean all
REM                -^> [3] OP_INVENTARIO ... diagnostico y salud de hardware
REM                -^> [4] OP_CONSOLA ....... consola de comandos (CMD)
REM                -^> [5] OP_AYUDA ......... ayuda y documentacion tecnica
REM                -^> [6] OP_TERCEROS ..... herramientas de terceros (en desarrollo)
REM                -^> [7] OP_SALIR ......... apagar o reiniciar el equipo
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
REM      EVALUAR_SEGURIDAD . decide si hay que anadir el aviso de riesgo
REM      GENERAR_SCRIPT_* .. escribe el guion temporal de diskpart
REM      MOSTRAR_SCRIPT .... imprime el guion (auditoria previa)
REM      CONFIRMAR_DESTR ... el tecnico responde S/N con UNA sola tecla
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
REM    FLUJO DEL INVENTARIO Y DE LA ESTIMACION (Fase 4.5):
REM      MODULO_INVENTARIO . pantalla de diagnostico SOLO LECTURA: sistema,
REM                          procesador, RAM, placa base y discos fisicos.
REM                          No genera ningun guion ni modifica nada.
REM      LEER_TAMANO_DISCO . lee el tamano REAL del disco elegido (en
REM                          bytes, con wmic) y lo convierte a GB.
REM      DETECTAR_MEDIA .... intenta saber si el disco es HDD o SSD (WMI
REM                          de almacenamiento); si no puede, PREGUNTA.
REM      CALCULAR_ESTIMADO . convierte tamano + tipo de disco en un
REM                          rango de tiempo ORIENTATIVO de borrado.
REM      MOSTRAR_AVISO_T .. pinta ese aviso (en amarillo) ANTES de pedir
REM                          la confirmacion S/N del borrado seguro.
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
REM      Ademas de pulsar la opcion hay que RESPONDER con UNA sola tecla:
REM      'S' en castellano o 'Y' en ingles (la pregunta es T_CFM_02 y se
REM      muestra como 'S/N' o 'Y/N'). 'N', un ENTER vacio o cualquier
REM      otra respuesta CANCELAN: jamas un tecleo raro borra un disco.
REM      El aviso con el resumen y los datos del disco permanece en
REM      pantalla mientras el tecnico responde (texto saneado con
REM      'set "VAR=%VAR: =%"' y comparacion con 'if /i').
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
REM      exige una confirmacion explicita (tecla S) antes de seguir. Ver
REM      el bloque ESCUDO DE SEGURIDAD en PASO 13.
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
REM     3) CONFIRMACION (CONFIRMAR_DESTRUCTIVO): se ve el aviso con los
REM        datos del disco y responde UNA tecla S/N (Y/N en ingles); si
REM        el escudo no pudo verificar el disco, a ese mismo aviso se le
REM        anade la pantalla amarilla de riesgo.
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
REM     (numeros de disco, codigos de error y decision de confirmacion).
REM
REM  INVENTARIO Y ESTIMACION (Fase 4.5) - RESUMEN PARA MANTENIMIENTO:
REM   INVENTARIO (SOLO LECTURA): la opcion [3] usa 'wmic' (instrumental de
REM     Windows) para leer sistema, CPU, RAM, placa base y discos. 'wmic'
REM     y 'diskpart list disk' NO modifican nada: solo informan. Si la
REM     imagen WinPE viene recortada y no trae wmic, el modulo se degrada
REM     con elegancia: para los discos usa 'diskpart list disk' (probado
REM     en la Fase 2) y para la CPU lee variables de entorno de Windows
REM     (%PROCESSOR_IDENTIFIER%, %NUMBER_OF_PROCESSORS%), que SIEMPRE
REM     existen. Ante un dato ausente se avisa; nunca se inventa.
REM   TAMANO Y TIEMPO: antes de confirmar un 'clean all' se LEE el tamano
REM     real del disco (wmic diskdrive ... size, en bytes) y se estima un
REM     rango de tiempo. Como las velocidades de disco varian mucho, la
REM     cifra es ORIENTATIVA (un aviso, no una promesa): se calcula con
REM     dos velocidades tipicas de referencia segun sea HDD o SSD y se
REM     presenta como "de X a Y". El tipo de disco se intenta detectar con
REM     el WMI de almacenamiento (MSFT_PhysicalDisk: 3=HDD, 4=SSD) y, si
REM     no se puede, se PREGUNTA al tecnico. Nunca se adivina.
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
set "TOOL_VER=1.0.0"
set "TOOL_FASE=1.0"

REM --- Apariencia de la consola -----------------------------------------
REM title  -^> texto de la barra de titulo de la ventana.
REM mode   -^> tamano de la ventana (columnas x lineas). Fijamos ~44 lineas
REM            para que quepan cabecera + menu + mensajes sin scroll.
REM            Se silencia su salida porque 'mode' puede fallar si la
REM            consola no permite redimensionar (ventanas embebidas en
REM            otros programas) y ese fallo no debe tumbar el script.
REM color  -^> NO se usa. La paleta se aplica con las variables ANSI
REM            definidas al inicio (C_VERDE, C_AMARILLO, C_ROJO,
REM            C_BLANCO, C_RESET). Asi no hay repintados globales ni
REM            parpadeos a blanco durante la ejecucion de los modulos.
title %TOOL_NAME% v%TOOL_VER%
mode con: cols=94 lines=44 >nul 2>&1
<nul set /p "=%C_BLANCO%"

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
REM 'PS_EXE' apunta a la ruta canonica de PS 5.x/Windows.
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
REM Cabecera en VERDE ANSI; cada linea vuelve al blanco brillante base
REM con C_FIN, de modo que el cuerpo de la pantalla siga siendo legible.
echo   %C_VERDE%==========================================================================%C_FIN%
echo     %C_VERDE%%TOOL_NAME%   -   v%TOOL_VER%%C_FIN%
echo   %C_VERDE%==========================================================================%C_FIN%
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
REM SALIDA_M marca una vuelta al menu pedida por el tecnico con la letra
REM M: se limpia en cada repinta para que un M antiguo no influya nunca en
REM el comportamiento de una operacion posterior.
set "SALIDA_M=NO"
call :MOSTRAR_CABECERA
echo(
echo   %T_MENU_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo      %T_MENU_02%
echo      %T_MENU_03%
echo      %T_MENU_04%
echo      %T_MENU_05%
echo      %T_MENU_06%
echo      %T_MENU_15%
echo      %T_MENU_16%
echo(
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo   %T_MENU_07%
echo          %T_MENU_08%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
call :LEER_OPCION "%T_MENU_11%" "1 2 3 4 5 6 7"

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
REM     if errorlevel 7 goto OP_SALIR
REM     if errorlevel 6 goto OP_TERCEROS
REM     if errorlevel 5 goto OP_AYUDA
REM     ...siempre de MAYOR a MENOR, porque 'if errorlevel N' significa
REM     "errorlevel MAYOR O IGUAL que N" y no "igual a N".
REM Nosotros capturamos el valor en %OPCION% para reutilizar la misma
REM logica tanto en el modo choice como en el modo set /p.
if "%OPCION%"=="1" goto OP_DISCO
if "%OPCION%"=="2" goto OP_SANITIZAR
if "%OPCION%"=="3" goto OP_INVENTARIO
if "%OPCION%"=="4" goto OP_CONSOLA
if "%OPCION%"=="5" goto OP_AYUDA
if "%OPCION%"=="6" goto OP_TERCEROS
if "%OPCION%"=="7" goto OP_SALIR

REM Si llegamos aqui, la entrada no fue un digito valido del 1 al 7.
REM Solo puede pasar en dos casos: el tecnico respondio a la pregunta de
REM Ctrl+C con "no" (choice devuelve 0 o 255) o el modo set /p recibio
REM algo raro. En cualquier caso: NI SE CIERRA NI SE SALE; simplemente
REM repintamos el menu y volvemos a pedir la opcion.
goto MENU

REM =====================================================================
REM  PASO 5 - OPCION [1] OPERACIONES SOBRE DISCOS Y PARTICIONES (maquetacion)
REM =====================================================================
REM  Este bloque es solo el "interruptor": todo el trabajo real vive en
REM  la subrutina MODULO_PREPARAR (PASO 13). Asi el flujo principal se
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
REM  PASO 7 - OPCION [3] DIAGNOSTICO / INVENTARIO (solo lectura, Fase 4.5)
REM =====================================================================
REM  Tercera opcion "de taller": consultar el equipo SIN tocar nada. Igual
REM  que las otras, este bloque es solo el interruptor; el trabajo real
REM  vive en la subrutina MODULO_INVENTARIO (PASO 15). Es una operacion de
REM  SOLO LECTURA: no genera guiones ni modifica discos.
REM =====================================================================
:OP_INVENTARIO
call :MODULO_INVENTARIO
goto MENU

REM =====================================================================
REM  PASO 8 - OPCION [4] CONSOLA AVANZADA (CMD interactivo)
REM =====================================================================
:OP_CONSOLA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_CONS_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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

call :OP_CONSOLA_CMD
goto MENU

REM ---------------------------------------------------------------------
REM  OP_CONSOLA_CMD - Consola interactiva con flujo CERRADO.
REM ---------------------------------------------------------------------
REM  No lanza cmd directamente en la ruta del menu para evitar, bajo
REM  ninguna circunstancia, que el control quede huerfano. El shell hijo
REM  se abre aqui dentro de la subrutina y cuando el tecnico escribe 'exit'
REM  el control vuelve SIEMPRE a MENU, sin pausa intermedia.
REM ---------------------------------------------------------------------
:OP_CONSOLA_CMD
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_CONS_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_CONS_02%
echo(
echo   %T_CONS_03%
echo   %T_CONS_04%
echo   %T_CONS_05%
echo(
echo   %T_CONS_06%
echo       %T_CONS_07%
echo(
call cmd
REM Vuelta inmediata y segura al MENU. Nunca sale a X:\Windows\System32.
goto MENU

REM =====================================================================
REM  PASO 9 - OPCION [5] AYUDA DEL SISTEMA (3 apartados + comandos reales)
REM  El 'help' nativo NO existe en WinPE: en su lugar se imprime con
REM  'echo' una lista de comandos que SI estan en la imagen.
REM =====================================================================
:OP_AYUDA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_AYU_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_AYU_02%
echo(
echo     %T_AYU_03%
echo     %T_AYU_04%
echo     %T_AYU_05%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :LEER_OPCION "%T_AYU_06%" "1 2 3" M A
if /i "%OPCION%"=="M" goto MENU
if /i "%OPCION%"=="A" goto MENU
if "%OPCION%"=="1" goto OP_AYUDA_P1
if "%OPCION%"=="2" goto OP_AYUDA_GUIA
if "%OPCION%"=="3" goto OP_AYUDA_NAV
goto OP_AYUDA

REM --- Apartado 1: comandos y herramientas de WinPE ---------------------
:OP_AYUDA_P1
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_AYU1_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
echo   %T_AYU1_33%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :AYUDA_PAGINA
if "%AYU_DESTINO%"=="MENU" goto MENU
if "%AYU_DESTINO%"=="ATRAS" goto OP_AYUDA
goto OP_AYUDA_P2

:OP_AYUDA_P2
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_AYU2_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
call :LEER_SN "%T_AYU2_32%"
if not "%SN%"=="SI" goto OP_AYUDA_P2_FIN
echo(
echo   %T_AYU2_33%
echo(
echo   %T_AYU3_02%
echo   %T_AYU3_03%
echo   %T_AYU3_04%
echo   %T_AYU3_05%
echo   %T_AYU3_06%
echo   %T_AYU3_07%
echo   %T_AYU3_08%
echo(
echo   %T_AYU3_09%
echo   %T_AYU3_10%
echo   %T_AYU3_11%
echo   %T_AYU3_12%
echo(
echo   %T_AYU3_13%
echo   %T_AYU3_14%
echo(
:OP_AYUDA_P2_FIN
echo   %T_AYU3_01%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :AYUDA_PAGINA
if "%AYU_DESTINO%"=="MENU" goto MENU
if "%AYU_DESTINO%"=="ATRAS" goto OP_AYUDA_P1
goto OP_AYUDA

REM --- Apartado 2: guia paso a paso de la Opcion 1 y de la Opcion 2 -----
:OP_AYUDA_GUIA
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_GUIA_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_GUIA_02%
echo(
echo     %T_GUIA_03%
echo     %T_GUIA_04%
echo     %T_GUIA_05%
echo     %T_GUIA_06%
echo     %T_GUIA_07%
echo     %T_GUIA_08%
echo     %T_GUIA_09%
echo     %T_GUIA_10%
echo(
echo   %T_GUIA_11%
echo   %T_GUIA_12%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :AYUDA_PAGINA
if "%AYU_DESTINO%"=="MENU" goto MENU
if "%AYU_DESTINO%"=="ATRAS" goto OP_AYUDA
goto OP_AYUDA_GUIA_P2

:OP_AYUDA_GUIA_P2
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_GUIA_14%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_GUIA_15%
echo(
echo     %T_GUIA_16%
echo     %T_GUIA_17%
echo     %T_GUIA_18%
echo     %T_GUIA_19%
echo     %T_GUIA_20%
echo     %T_GUIA_21%
echo     %T_GUIA_22%
echo(
echo   %T_GUIA_23%
echo     %T_GUIA_24%
echo     %T_GUIA_25%
echo     %T_GUIA_26%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :AYUDA_PAGINA
if "%AYU_DESTINO%"=="MENU" goto MENU
if "%AYU_DESTINO%"=="ATRAS" goto OP_AYUDA_GUIA
goto OP_AYUDA

REM --- Apartado 3: codigos de navegacion y atajos ------------------------
:OP_AYUDA_NAV
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_NAV_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_NAV_02%
echo(
echo   %T_NAV_03%
echo   %T_NAV_04%
echo   %T_NAV_05%
echo   %T_NAV_06%
echo   %T_NAV_07%
echo(
echo   %T_NAV_08%
echo   %T_NAV_09%
echo   %T_NAV_10%
echo   %T_NAV_11%
echo(
echo   %T_NAV_12%
echo   %T_NAV_13%
echo   %T_NAV_14%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :AYUDA_PAGINA
if "%AYU_DESTINO%"=="MENU" goto MENU
goto OP_AYUDA

REM =====================================================================
REM  PASO 9.1 - OPCION [6] HERRAMIENTAS DE TERCEROS (contenedor)
REM =====================================================================
REM  Pantalla informativa: de momento NO ejecuta binarios externos. A y M
REM  vuelven siempre al menu principal, de modo que esta pantalla no puede
REM  caer nunca a un prompt de System32.
REM =====================================================================
:OP_TERCEROS
cls
call :MOSTRAR_CABECERA
echo(
echo   %C_VERDE%%T_TER_01%%C_FIN%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %C_VERDE%%T_TER_02%%C_FIN%
echo(
echo     %C_BLANCO%%T_TER_03%%C_FIN%
echo     %C_BLANCO%%T_TER_04%%C_FIN%
echo     %C_BLANCO%%T_TER_05%%C_FIN%
echo(
echo   %C_BLANCO%%T_TER_06%%C_FIN%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :LEER_OPCION "%T_TER_07%" "1" M A
REM A (paso anterior) y M (menu principal) regresan al MENU. Cualquier
REM otra salida de la captura tambien vuelve aqui: no hay caida a System32.
goto MENU

REM =====================================================================
REM  PASO 10 - OPCION [7] SALIR / APAGAR EQUIPO
REM  (todas las acciones de esta seccion piden confirmacion previa)
REM =====================================================================
:OP_SALIR
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_SAL_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo      %T_SAL_02%
echo      %T_SAL_03%
echo      %T_SAL_04%
echo(
call :LEER_OPCION "%T_SAL_05%" "1 2 3" M
if /i "%OPCION%"=="M" goto MENU
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
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_SAL_07%
echo   %T_SAL_08%
echo   %T_SAL_09%
echo   %T_SAL_10%
echo(
call :LEER_SN "%T_SAL_11%"
if "%SN%"=="SI" goto DETECTAR_ENTORNO_APAGADO
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
REM  PASO 11 - SALIDAS ORDENADAS DEL SCRIPT
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
REM  PASO 12 - SUBRUTINAS INTERNAS (se invocan con 'call :etiqueta')
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
REM Cabecera en VERDE ANSI: marca, version y fase destacan como en una
REM consola PowerShell. Cada linea termina en C_FIN (blanco brillante),
REM asi el resto de la pantalla sigue siendo legible.
echo   %C_VERDE%==========================================================================%C_FIN%
echo     %C_VERDE%%TOOL_NAME%   -   %T_COM_42%%C_FIN%
echo     %C_VERDE%%T_COM_43% %TOOL_VER%   -   %T_COM_44% %TOOL_FASE%   -   %T_COM_45% Windows / WinPE%C_FIN%
echo   %C_VERDE%==========================================================================%C_FIN%
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
REM  PULSA_TECLA_MENU - pausa de pantallas de SOLO LECTURA con salida
REM  directa al menu principal.
REM  -------------------------------------------------------------------
REM  USO:      call :PULSA_TECLA_MENU "texto de la pantalla"
REM  Devuelve: VUELTA_MENU = SI / NO.
REM    - NO  -^> el tecnico tecleo C + ENTER (continuar): el llamante
REM      sigue su flujo.
REM    - SI  -^> el tecnico tecleo M + ENTER (menu): el llamante debe
REM      volver al menu. Los modulos encadenados con 'call' hacen
REM      'exit /b 0' (despues el bloque OP_x pinta el menu con
REM      'goto MENU') y las pantallas encadenadas con 'goto' saltan
REM      directamente a MENU, que repinta con 'cls'.
REM
REM  Por que C y M con ENTER? Porque 'choice' no puede leer ENTER (solo
REM  admite a-z, A-Z, 0-9 y los codigos 128-254) y un ENTER vacio como
REM  "continuar" se saltaria la pantalla con el minimo impulso (riesgo
REM  de salto accidental). Con 'set /p' se leen lineas completas y las
REM  dos teclas quedan simetricas: C + ENTER continua, M + ENTER vuelve
REM  al menu, y cualquier otra letra vuelve a pedirla. Como 'set /p'
REM  sirve igual en los dos modos, desaparece la bifurcacion
REM  choice/setp de esta pantalla. (ESC sigue sin ser legible en cmd:
REM  ver el motivo en PULSA_TECLA).
REM ---------------------------------------------------------------------
:PULSA_TECLA_MENU
set "VUELTA_MENU=NO"
echo(
echo   %~1
:PULSA_TECLA_MENU_BUCLE
echo   %C_VERDE%%T_COM_54%%C_FIN%
set "TECLA_MENU="
set /p "TECLA_MENU=%C_VERDE%%T_COM_55%%C_FIN%"
if /i "%TECLA_MENU%"=="C" exit /b 0
if /i "%TECLA_MENU%"=="M" set "VUELTA_MENU=SI"
if "%VUELTA_MENU%"=="SI" exit /b 0
goto PULSA_TECLA_MENU_BUCLE

REM ---------------------------------------------------------------------
REM  AYUDA_PAGINA - avance fluido entre las paginas de la Ayuda.
REM -------------------------------------------------------------------
REM  ENTER (o cualquier texto + ENTER) pasa a la pagina siguiente sin
REM  teclear '1'. Se conservan los dos escapes de siempre:
REM    A -^> AYU_DESTINO=ATRAS   (vuelve a la pagina anterior)
REM    M -^> AYU_DESTINO=MENU    (vuelve al menu principal)
REM  Con set /p, ENTER deja la variable sin definir: eso significa
REM  "SIGUIENTE" y es el camino normal, no un error.
REM ---------------------------------------------------------------------
:AYUDA_PAGINA
set "AYU_DESTINO=SIGUIENTE"
set "AYU_PAG="
set /p "AYU_PAG=%C_VERDE%%T_AYU_07%%C_RESET%"
if not defined AYU_PAG exit /b 0
set "AYU_PAG=%AYU_PAG:"=%"
if not defined AYU_PAG exit /b 0
set "AYU_PAG=%AYU_PAG: =%"
if /i "%AYU_PAG%"=="M" set "AYU_DESTINO=MENU"
if /i "%AYU_PAG%"=="A" set "AYU_DESTINO=ATRAS"
exit /b 0

REM ---------------------------------------------------------------------
REM  LEER_OPCION - captura SEGURA de una opcion numerica.
REM  -------------------------------------------------------------------
REM  USO:    call :LEER_OPCION "texto del prompt" "1 2 3 4 5" [M] [A]
REM            %~1 -^> mensaje que vera el tecnico (sin comillas)
REM            %~2 -^> digitos permitidos, separados por espacios
REM                    (es la LISTA BLANCA de entradas validas)
REM            %~3 -^> opcional: 'M' para admitir tambien la letra M y
REM                    volver al menu principal de forma inmediata
REM            %~4 -^> opcional: 'A' para admitir tambien la letra A y
REM                    volver al paso anterior (OPCION queda en A)
REM  RESULTADO:
REM            %OPCION% -^> el digito elegido (o vacio, si algo fallo)
REM
REM  Esta subrutina es el corazon de la "captura a prueba de errores":
REM  en ningun escenario (tecla rara, ENTER en vacio, Ctrl+C) el script
REM  se cierra ni sale del menu; como maximo, vuelve a pedir la opcion.
REM ---------------------------------------------------------------------
:LEER_OPCION
set "OPCION="
REM  Tercer argumento opcional: si vale M, la letra M se acepta como
REM  salida al menu principal ademas de los digitos de la lista blanca.
set "PERMITE_M=NO"
if /i "%~3"=="M" set "PERMITE_M=SI"
REM  Cuarto argumento opcional: si vale A, la letra A se acepta como
REM  salida al paso anterior. El llamante decide a donde lleva esa A.
set "PERMITE_A=NO"
if /i "%~4"=="A" set "PERMITE_A=SI"
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
REM Sufijo de navegacion: A y/o M se anaden AL FINAL de los digitos.
REM Su posicion real se calcula contando los digitos de la lista blanca.
set "SUFIJO="
if "%PERMITE_A%"=="SI" set "SUFIJO=A"
if "%PERMITE_M%"=="SI" set "SUFIJO=%SUFIJO%M"
if not defined SUFIJO goto LEER_CON_CHOICE_SIMPLE
set "CLAVES_N=0"
set "CLAVES_TMP=%CLAVES%"
:LEER_CON_CHOICE_CONTAR
if not defined CLAVES_TMP goto LEER_CON_CHOICE_LISTO
set "CLAVES_TMP=%CLAVES_TMP:~1%"
set /a CLAVES_N+=1
goto LEER_CON_CHOICE_CONTAR
:LEER_CON_CHOICE_LISTO
REM   /n oculta la lista automatica de teclas (nuestro prompt ya la dice)
REM   /m muestra el mensaje que pasamos en %~1
choice /c %CLAVES%%SUFIJO% /n /m "%C_VERDE%%~1%C_FIN%"
set "ELECT=%errorlevel%"
REM choice devuelve 0 si el tecnico aborta con Ctrl+C: se sale sin opcion
REM y el llamante vuelve a pintar el menu (nunca se interpreta como "0").
if "%ELECT%"=="0" exit /b 0
REM Indice dentro de los digitos: es la propia opcion.
if %ELECT% LEQ %CLAVES_N% set "OPCION=%ELECT%"
if defined OPCION exit /b 0
REM Fuera de los digitos: la posicion del sufijo dice la tecla pulsada.
set /a OFFSET=ELECT-CLAVES_N
if "%OFFSET%"=="1" set "OPCION=%SUFIJO:~0,1%"
if "%OFFSET%"=="2" set "OPCION=%SUFIJO:~1,1%"
exit /b 0

:LEER_CON_CHOICE_SIMPLE
REM   /n oculta la lista automatica de teclas (nuestro prompt ya la dice)
REM   /m muestra el mensaje que pasamos en %~1
choice /c %CLAVES% /n /m "%C_VERDE%%~1%C_FIN%"
set "ELECT=%errorlevel%"
if "%ELECT%"=="0" exit /b 0
set "OPCION=%ELECT%"
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
set /p "OPCION=%C_VERDE%%~1%C_FIN%"
REM --- ENTER vacio: sin esto el guion SE ABORTARIA ----------------------
REM 'set /p' NO escribe nada si se pulsa solo ENTER: la variable queda
REM SIN DEFINIR. Aplicarle acto seguido una sustitucion de texto
REM ('%OPCION:"=%') a una variable indefinida hace que cmd deje el patron
REM LITERAL con las comillas sin balancear, y la siguiente linea 'if'
REM provoca un error de sintaxis que TERMINA todo menu.bat.
REM Por eso se comprueba 'if not defined' ANTES de tocar nada, y otra vez
REM tras quitar las comillas (una entrada de solo comillas deja la
REM variable vacia).
if not defined OPCION goto LEER_CON_SETP_INVALIDA
REM --- Sanitizacion (defensa en profundidad) ---
REM Eliminamos comillas y espacios tecleados ANTES de comparar. Por que?
REM Porque la expansion %OPCION% se inserta en la linea del 'if' y un
REM valor con comillas podria desbalancear las comillas de la comparacion
REM y provocar un error de sintaxis que aborte el guion. Quitarle las
REM comillas al valor deja SIEMPRE la linea bien formada:
REM     if "valor_limpio"=="1"  -^> siempre balanceada, nunca rompe.
set "OPCION=%OPCION:"=%"
if not defined OPCION goto LEER_CON_SETP_INVALIDA
set "OPCION=%OPCION: =%"
REM --- Salida directa al menu: tecla M admitida -------------------------
REM Solo si el llamante la pidio como tercer argumento: asi los menus que
REM no ofrecen M (idioma, formato, tipo de medio) siguen siendo estrictos.
if not "%PERMITE_M%"=="SI" goto LEER_CON_SETP_VER_A
if /i "%OPCION%"=="M" exit /b 0
:LEER_CON_SETP_VER_A
if not "%PERMITE_A%"=="SI" goto LEER_CON_SETP_LISTA
if /i "%OPCION%"=="A" exit /b 0
:LEER_CON_SETP_LISTA
REM --- Lista blanca ---
REM 'for' recorre cada digito de la lista (%~2) y compara con lo
REM tecleado. Si coincide, marcamos VALIDA=1. La comparacion entre
REM comillas neutraliza los simbolos peligrosos tecleados (ampersand,
REM tuberia, mayor y menor que) porque dentro de comillas no son
REM operadores: se imprimen o se comparan, pero no se ejecutan.
set "VALIDA="
for %%D in (%~2) do if "%OPCION%"=="%%D" set "VALIDA=1"
if defined VALIDA exit /b 0
:LEER_CON_SETP_INVALIDA
REM Entrada invalida (vacia, de mas de un caracter o fuera de la lista):
REM avisamos y VOLVEMOS A PEDIR sin repintar el menu entero.
echo(
echo   %T_COM_01%
goto LEER_CON_SETP

REM ---------------------------------------------------------------------
REM  LEER_SN - pregunta de SI/NO con lista blanca, BILINGUE.
REM  -------------------------------------------------------------------
REM  USO:       call :LEER_SN "texto del prompt"
REM  Devuelve:  SN = SI / NO   (vacio solo si algo raro paso en choice)
REM
REM  El juego de teclas depende del idioma activo (LANG):
REM    ES -^> 'choice /c SN'  y se acepta S, SI, N, NO
REM    EN -^> 'choice /c YN'  y se acepta Y, YES, N, NO
REM  Asi el texto en ingles puede mostrar [Y/N] sin enganar al tecnico.
REM    - Modo choice: lee UNA tecla (sin ENTER).
REM    - Modo set /p: lee la linea completa (mayusculas o minusculas);
REM      cualquier otra cosa se vuelve a pedir.
REM  Igual que LEER_OPCION: una tecla rara nunca cancela nada por
REM  accidente, como mucho repite la pregunta.
REM ---------------------------------------------------------------------
:LEER_SN
set "SN="
set "SN_CLAVES=SN"
set "SN_SI=S"
set "SN_SI2=SI"
set "SN_NO=N"
if /i "%LANG%"=="EN" set "SN_CLAVES=YN"
if /i "%LANG%"=="EN" set "SN_SI=Y"
if /i "%LANG%"=="EN" set "SN_SI2=YES"
if "%MODO_ENTRADA%"=="CHOICE" goto LEER_SN_CHOICE
goto LEER_SN_SETP
:LEER_SN_CHOICE
choice /c %SN_CLAVES% /n /m "%C_VERDE%%~1%C_FIN%"
if errorlevel 2 goto LEER_SN_CHOICE_NO
if errorlevel 1 goto LEER_SN_CHOICE_SI
REM errorlevel 0 (fallo de choice o Ctrl+C neutro): repetimos la tecla.
goto LEER_SN_CHOICE
:LEER_SN_CHOICE_SI
set "SN=SI"
exit /b 0
:LEER_SN_CHOICE_NO
set "SN=NO"
exit /b 0
:LEER_SN_SETP
set "SN_TXT="
set /p "SN_TXT=%C_VERDE%%~1%C_FIN%"
REM ENTER vacio -^> se vuelve a preguntar. La guardia es OBLIGATORIA antes
REM de las sustituciones: si la variable esta indefinida, cmd deja el
REM patron literal con las comillas sin balancear y el 'if' siguiente
REM daria un error de sintaxis que abortaria todo el guion.
if not defined SN_TXT goto LEER_SN_SETP_INVALIDA
set "SN_TXT=%SN_TXT:"=%"
if not defined SN_TXT goto LEER_SN_SETP_INVALIDA
set "SN_TXT=%SN_TXT: =%"
if /i "%SN_TXT%"=="%SN_SI%" set "SN=SI"
if /i "%SN_TXT%"=="%SN_SI2%" set "SN=SI"
if /i "%SN_TXT%"=="%SN_NO%" set "SN=NO"
if /i "%SN_TXT%"=="NO" set "SN=NO"
if defined SN exit /b 0
:LEER_SN_SETP_INVALIDA
echo(
echo   %T_COM_01%
goto LEER_SN_SETP

REM =====================================================================
REM  PASO 13 - SUBRUTINAS DE LOS MODULOS DE DISCO (Fase 2)
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
REM              CANCELAR -^> el tecnico tecleo la letra M (menu principal)
REM              ATRAS    -^> el tecnico tecleo A, o solo ENTER: vuelve al
REM                       paso ANTERIOR sin tocar nada (sin ciclar aqui)
REM
REM  PUNTO DE ESCAPE: no hay forma de quedarse atrapado en este prompt.
REM    M       -^> menu principal (salida inmediata, sin pausa).
REM    A       -^> paso anterior del modulo que llama.
REM    ENTER   -^> idem a A, con un aviso previo (nunca un error de
REM              sintaxis: la entrada vacia se trata como dato).
REM  Ninguna entrada se usa sin pasar por esta validacion.
REM
REM  DOS VIA segun lo que ofrezca la imagen (ver MODO_ENTRADA):
REM    - Modo choice: cada digito se captura SOLO (sin ENTER) y se imprime
REM      en pantalla EN EL INSTANTE en que se pulsa: entrada visible,
REM      jamas a ciegas. Las teclas M, A y S son directas (sin ENTER). Si
REM      el numero tecleado ya existe se confirma al momento; la tecla 'S'
REM      fuerza la confirmacion cuando tambien podria ser prefijo (1 y 10).
REM    - Modo set /p (WinPE sin choice.exe): el eco del propio tecleo lo
REM      pinta la consola (tambien visible), se acepta con ENTER y se
REM      vuelve al menu con M + ENTER (o al paso anterior con A + ENTER).
REM      En cmd puro sin choice no hay forma de leer una sola tecla:
REM      limitacion documentada del entorno.
REM  Ninguna entrada se usa sin pasar por esta validacion.
REM ---------------------------------------------------------------------
:LEER_NUMERO
set "NUM_OK=NO"
set "NUM_TXT="
set "NUM_LARGO=0"
REM --- Ruta choice: digitos directos, visibles y sin ENTER --------------
if "%MODO_ENTRADA%"=="CHOICE" goto LEER_NUMERO_CON_CHOICE
REM --- Ruta set /p (clasica) --------------------------------------------
REM 'set /p' deja la variable INTACTA si se pulsa ENTER sin escribir
REM nada; por eso la limpiamos justo antes: asi ENTER significa
REM "entrada vacia" y no un valor viejo de una vuelta anterior. En un
REM menu de borrado, ese detalle es la diferencia entre no hacer nada
REM y borrar el disco equivocado.
set /p "NUM_TXT=%C_VERDE%%~1%C_FIN%"
if not defined NUM_TXT goto LEER_NUMERO_ATRAS_VACIO
REM --- Limpieza de comillas y espacios (defensa en profundidad) -------
REM Mismo razonamiento que en LEER_OPCION: el valor se va a insertar en
REM lineas 'if "..."=="..."'; si contuviera comillas, podria romper la
REM sintaxis de la linea y abortar el guion.
set "NUM_TXT=%NUM_TXT:"=%"
set "NUM_TXT=%NUM_TXT: =%"
if not defined NUM_TXT goto LEER_NUMERO_ATRAS_VACIO
REM --- Salida voluntaria: la letra M vuelve al menu principal ---------
if /i "%NUM_TXT%"=="M" goto LEER_NUMERO_CANCELAR
REM --- Retroceso: la letra A vuelve al paso anterior del modulo -------
if /i "%NUM_TXT%"=="A" goto LEER_NUMERO_ATRAS
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

REM --- Ruta choice: captura de UNA tecla por digito ----------------------
:LEER_NUMERO_CON_CHOICE
REM Imprimimos el prompt SIN salto de linea ('set /p' con la entrada en
REM NUL escribe el texto y, al no tener entrada, se para al instante):
REM los digitos que lleguen se pegaran justo detras, visibles tecleo a
REM tecleo. Esta es la garantia de entrada VISIBLE en modo choice.
set /p "NUM_ECO=%C_VERDE%%~1%C_FIN%" <nul
:LEER_NUMERO_CHOICE_BUCLE
REM choice captura UNA sola tecla de la lista y devuelve su posicion:
REM tecla 0 -^> 1, tecla 1 -^> 2, ..., tecla 9 -^> 10, M -^> 11, S -^> 12,
REM A -^> 13. Las demas teclas hacen 'beep' sin consumirse: jamas entra
REM basura.
REM (choice solo admite a-z, A-Z, 0-9 y ASCII 128-254: por eso la
REM tecla de confirmacion es S y no un simbolo como '*').
choice /c 0123456789MSA /n
if errorlevel 13 goto LEER_NUMERO_ATRAS
if errorlevel 12 goto LEER_NUMERO_CHOICE_CONFIRMAR
if errorlevel 11 goto LEER_NUMERO_CANCELAR
REM La posicion N corresponde al digito N-1 (la tecla 0 esta en la 1).
set /a NUM_VALOR=%errorlevel%-1
set "CAR=%NUM_VALOR%"
REM Un disco no lleva ceros a la izquierda: si ya hay un '0' y llega
REM otro digito, es un error.
if "%NUM_TXT%"=="0" goto LEER_NUMERO_ERROR
set /a NUM_LARGO+=1
if %NUM_LARGO% GTR 2 goto LEER_NUMERO_ERROR
REM Eco inmediato: el digito se ve en pantalla ANTES de seguir.
set "NUM_TXT=%NUM_TXT%%CAR%"
set /p "NUM_ECO=%CAR%" <nul
REM Sin lista parseada (formato de discopart no reconocido) no hay nada
REM que comprobar: aceptamos el numero ya validado en formato y luego
REM DISCO_EXISTE dudara y mandara el tecnico, como en el resto del guion.
if not defined LISTA_DISCOS goto LEER_NUMERO_VALIDO
REM Si el numero existe y no puede ser prefijo de otro, ya esta: se
REM confirma SOLO, sin teclear ENTER.
call :COMPROBAR_DISCO_LISTA "%NUM_TXT%"
if "%HAY_EXACTO%"=="SI" if "%HAY_PREFIJO%"=="NO" goto LEER_NUMERO_VALIDO
REM Si existe pero tambien es prefijo (disco 1 y disco 10): seguimos
REM esperando otro digito o la tecla 'S' que fuerza la confirmacion.
if "%HAY_EXACTO%"=="SI" goto LEER_NUMERO_CHOICE_BUCLE
REM Si es el principio de un numero mayor, seguimos tecleando.
if "%HAY_PREFIJO%"=="SI" goto LEER_NUMERO_CHOICE_BUCLE
goto LEER_NUMERO_ERROR
:LEER_NUMERO_CHOICE_CONFIRMAR
REM La tecla 'S' solo confirma un numero que YA existe en el listado.
if not defined NUM_TXT goto LEER_NUMERO_ERROR
call :COMPROBAR_DISCO_LISTA "%NUM_TXT%"
if "%HAY_EXACTO%"=="SI" goto LEER_NUMERO_VALIDO
goto LEER_NUMERO_ERROR

:LEER_NUMERO_VALIDO
REM Confirmacion visible de lo recibido: prompt + digitos + esta linea.
REM El tecnico VE que disco ha quedado registrado antes de continuar.
echo(
echo   %T_COM_52% %NUM_TXT%
REM Asignacion indirecta: %2 es el NOMBRE de la variable destino. Con
REM 'set "%~2=..."' escribimos en esa variable (aqui no hace falta
REM expansion retrasada porque solo ESCRIBIMOS, no leemos).
set "%~2=%NUM_TXT%"
set "NUM_OK=SI"
exit /b 0
:LEER_NUMERO_CANCELAR
echo(
set "NUM_OK=CANCELAR"
REM El tecnico pidio volver al menu con M: el llamante debe abandonar el
REM modulo SIN ninguna pausa intermedia (vuelta inmediata al menu).
set "SALIDA_M=SI"
exit /b 0
:LEER_NUMERO_ATRAS_VACIO
REM ENTER sin escribir nada: no es un ERROR, es una forma honesta de
REM decir "no quiero seguir". Se avisa y se vuelve al paso anterior.
REM (Antes este caso devolvia 'entrada invalida' y el prompt volvia a
REM  aparecer sin salida: ahora siempre hay un camino de vuelta.)
echo(
echo   %T_COM_57%
:LEER_NUMERO_ATRAS
echo(
set "NUM_OK=ATRAS"
set "SALIDA_M=NO"
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
call :LEER_SN "%T_COM_08%"
if not "%SN%"=="SI" goto PREPARAR_ENTORNO_SIN_ADMIN
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
REM  F_INV es el temporal de las consultas de inventario (wmic, Fase 4.5).
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
exit /b 0

REM ---------------------------------------------------------------------
REM  PARSER_DISCOS - extrae los identificadores de disco del listado.
REM  -------------------------------------------------------------------
REM  Entrada:  %F_SALIDA% (salida de 'list disk' + 'list volume')
REM  Devuelve: LISTA_DISCOS = identificadores numericos de la PRIMERA
REM            columna, separados por espacios y con espacios de
REM            reserva en los extremos: " 0 1 10 ".
REM
REM  Por que un parser propio? Porque diskpart traduce sus mensajes:
REM  "Disk 0", "Disco 0", "Datentrager 0"... La PALABRA cambia con el
REM  idioma, pero el NUMERO siempre va en la primera columna. La maquina
REM  de estados es agnostica al idioma:
REM    - Estado 0: espera la linea de guiones que abre la tabla discos.
REM    - Estado 1: lee las filas; el primer campo numerico (o el segundo,
REM      tras la palabra Disk/Disco/...) es el identificador. El resto de
REM      campos (tamano, estado) se ignoran.
REM    - Estado 2: la SEGUNDA linea de guiones abre la tabla de
REM      volumenes: a partir de ahi ya no se mira nada mas, asi que un
REM      "Volumen 0" jamas puede colarse en la lista de discos.
REM  Si el formato no encaja, la lista queda vacia y DISCO_EXISTE duda:
REM  ante la duda manda el tecnico, nunca una suposicion.
REM ---------------------------------------------------------------------
:PARSER_DISCOS
set "LISTA_DISCOS="
set "PARSER_ESTADO=0"
if not exist "%F_SALIDA%" exit /b 0
for /f "usebackq tokens=1,2" %%A in ("%F_SALIDA%") do call :PARSER_DISCOS_LINEA "%%A" "%%B"
exit /b 0

:PARSER_DISCOS_LINEA
REM %~1 y %~2 son los dos primeros campos de la linea. Los pasamos por
REM variables para poder aplicarles la sustitucion %VAR:busqueda=% (los
REM argumentos %~1 no admiten sustitucion de texto).
set "P1=%~1"
set "P2=%~2"
if "%PARSER_ESTADO%"=="2" exit /b 0
REM Un campo con '-' es la linea separadora de tablas de diskpart.
if not "%P1:-=%"=="%P1%" goto PARSER_DISCOS_SEPARADOR
if "%PARSER_ESTADO%"=="0" exit /b 0
REM El primer campo es un numero puro? Entonces ya es el identificador.
call :ES_DIGITO_CADENA "%P1%"
if "%CADENA_OK%"=="SI" goto PARSER_DISCOS_GUARDAR
REM Formato 'Disk 0' / 'Disco 0': el identificador va en el SEGUNDO campo.
call :ES_DIGITO_CADENA "%P2%"
if "%CADENA_OK%"=="SI" goto PARSER_DISCOS_GUARDAR2
exit /b 0
:PARSER_DISCOS_SEPARADOR
REM CUIDADO - trampa clasica de cmd: aqui NO hay 'else' y cada linea se
REM evalua ya con el valor nuevo. Si el primer 'if' sube el estado 0 a 1,
REM la linea siguiente lo veria como 1 y lo subiria a 2 de un salto: el
REM PRIMER separador borraria todas las filas de discos de golpe (bug real
REM que dejaba LISTA_DISCOS vacia y hacia fallar la eleccion de disco 0).
REM Por eso cada transicion vive en su PROPIO bloque via 'goto'.
if "%PARSER_ESTADO%"=="0" goto PARSER_SEP_A_1
set "PARSER_ESTADO=2"
exit /b 0
:PARSER_SEP_A_1
set "PARSER_ESTADO=1"
exit /b 0
:PARSER_DISCOS_GUARDAR
call :PARSER_SUMAR_DISCO "%P1%"
exit /b 0
:PARSER_DISCOS_GUARDAR2
call :PARSER_SUMAR_DISCO "%P2%"
exit /b 0
:PARSER_SUMAR_DISCO
REM Solo identificadores de 1 o 2 cifras (no hay equipos con 100+ discos);
REM cualquier otro numero largo que pudiera aparecer no es un id y se
REM ignora. El espacio final deja espacios de reserva: " 1 " solo puede
REM coincidir con el disco entero 1, nunca con el 10.
set "PID=%~1"
if not "%PID:~2,1%"=="" exit /b 0
set "LISTA_DISCOS=%LISTA_DISCOS% %PID% "
exit /b 0

REM ---------------------------------------------------------------------
REM  ES_DIGITO_CADENA - comprueba que TODA una cadena son digitos.
REM  -------------------------------------------------------------------
REM  Uso:      call :ES_DIGITO_CADENA "texto"
REM  Devuelve: CADENA_OK = SI (solo digitos) / NO (vacia o con mas cosas)
REM ---------------------------------------------------------------------
:ES_DIGITO_CADENA
set "CADENA_OK=NO"
set "CTXT=%~1"
if not defined CTXT exit /b 0
:ES_DIGITO_CADENA_BUCLE
if not defined CTXT goto ES_DIGITO_CADENA_FIN
set "CCAR=%CTXT:~0,1%"
set "CTXT=%CTXT:~1%"
call :ES_DIGITO "%CCAR%"
if not "%DIGITO_OK%"=="SI" exit /b 0
goto ES_DIGITO_CADENA_BUCLE
:ES_DIGITO_CADENA_FIN
set "CADENA_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  COMPROBAR_DISCO_LISTA - prueba de pertenencia contra LISTA_DISCOS.
REM  -------------------------------------------------------------------
REM  Uso:      call :COMPROBAR_DISCO_LISTA "1"
REM  Devuelve: HAY_EXACTO  = SI si ese numero existe tal cual.
REM            HAY_PREFIJO = SI si existen ids mas largos que empiezan
REM            igual (p. ej. "1" cuando hay discos 1 y 10). Solo se
REM            comprueba con UN digito tecleado: los ids tienen como
REM            maximo 2 cifras, asi que con 2 digitos no puede haber
REM            ningun id mas largo que los encabece.
REM ---------------------------------------------------------------------
:COMPROBAR_DISCO_LISTA
set "HAY_EXACTO=NO"
set "HAY_PREFIJO=NO"
set "CAND=%~1"
if not defined CAND exit /b 0
if not defined LISTA_DISCOS exit /b 0
REM --- Coincidencia exacta: recorremos la lista y comparamos igual a igual
for %%I in (%LISTA_DISCOS%) do if "%%I"=="%CAND%" set "HAY_EXACTO=SI"
if not "%CAND:~1%"=="" exit /b 0
for %%I in (%LISTA_DISCOS%) do call :COMPROBAR_PREFIJO "%%I" "%CAND%"
exit /b 0
:COMPROBAR_PREFIJO
REM %~1 = id de la lista; %~2 = digito tecleado. Si al quitarle el
REM primer caracter al id queda algo, el id es mas largo: comparamos el
REM id completo con 'digito + resto'. Asi "10" se detecta como prefijo
REM de "1", pero "1" no es prefijo de si mismo.
set "SEGUNDO=%~1"
set "SEGUNDO=%SEGUNDO:~1%"
if not defined SEGUNDO exit /b 0
if "%~1"=="%~2%SEGUNDO%" set "HAY_PREFIJO=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  DISCO_EXISTE - intenta comprobar que el disco elegido existe.
REM  -------------------------------------------------------------------
REM  Entrada:  %DISCO% (el numero validado) y LISTA_DISCOS (parser previo)
REM  Devuelve: EXISTE = SI / NO / ?
REM
REM  COMO se comprueba: prueba de pertenencia EXACTA contra la lista de
REM  identificadores que extrajo PARSER_DISCOS. Los ids estan rodeados de
REM  espacios de reserva, de modo que el disco 1 nunca se confunde con el
REM  10 ni con el 11, y no importa en que idioma hable el discopart.
REM
REM  LIMITACION HONESTA: si el parser no reconoce el formato del listado
REM  (lista vacia), devolvemos "?" para que PEDIR_DISCO pregunte al
REM  tecnico en vez de decidir por el. Nunca inventamos un "si" ni un
REM  "no": ante la duda, manda la persona.
REM ---------------------------------------------------------------------
:DISCO_EXISTE
set "EXISTE=NO"
if not defined DISCO exit /b 0
if not defined LISTA_DISCOS goto DISCO_EXISTE_DUDA
call :COMPROBAR_DISCO_LISTA "%DISCO%"
if "%HAY_EXACTO%"=="SI" set "EXISTE=SI"
exit /b 0
:DISCO_EXISTE_DUDA
set "EXISTE=?"
exit /b 0

REM ---------------------------------------------------------------------
REM  PEDIR_DISCO - pide, valida y confirma el numero de disco a usar.
REM  -------------------------------------------------------------------
REM  Devuelve DISCO (numero), DISCO_OK = SI / NO y DISCO_ATRAS = SI / NO.
REM  Bucle de seguridad: no se sale de aqui hasta tener un numero valido o
REM  hasta que el tecnico vuelva al menu con la letra M (tecla directa en
REM  modo choice; M + ENTER en modo set /p).
REM  PUNTO DE ESCAPE: ademas de M, la tecla A o un ENTER vacio devuelven
REM  al paso ANTERIOR del modulo (DISCO_ATRAS=SI) sin tocar nada. El pie
REM  de pantalla lo recuerda siempre con la linea estandar T_COM_56.
REM ---------------------------------------------------------------------
:PEDIR_DISCO
set "DISCO_OK=NO"
set "DISCO_ATRAS=NO"
set "DISCO="
if not "%LISTADO_OK%"=="SI" exit /b 0
:PEDIR_DISCO_BUCLE
echo(
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo   %T_COM_15%
echo   %T_COM_16%
echo   %T_COM_17%
REM El aviso de vuelta al menu cambia con el modo de entrada: en modo
REM choice basta pulsar M (una tecla, sin ENTER); en modo set /p hace
REM falta M + ENTER, porque ahi no existe lectura de una sola tecla.
if "%MODO_ENTRADA%"=="CHOICE" echo   %C_VERDE%%T_COM_53%%C_RESET%
if not "%MODO_ENTRADA%"=="CHOICE" echo   %C_VERDE%%T_COM_18%%C_RESET%
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
call :LEER_NUMERO "%T_COM_19%" DISCO
if "%NUM_OK%"=="CANCELAR" exit /b 0
if "%NUM_OK%"=="ATRAS" goto PEDIR_DISCO_ATRAS
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
call :LEER_OPCION "%T_COM_24%" "1 2 3" M A
if /i "%OPCION%"=="M" set "SALIDA_M=SI"
if /i "%OPCION%"=="M" exit /b 0
if /i "%OPCION%"=="A" goto PEDIR_DISCO_BUCLE
if "%OPCION%"=="1" goto PEDIR_DISCO_BUCLE
if "%OPCION%"=="2" goto PEDIR_DISCO_RIESGO
exit /b 0
:PEDIR_DISCO_RIESGO
REM El tecnico elige 'Continuar' pese a la duda: pregunta S/N del PASO 1.
call :CONFIRMAR_DESTRUCTIVO "riesgo"
if not "%CONFIRMADO%"=="SI" exit /b 0
goto PEDIR_DISCO_OK
:PEDIR_DISCO_ATRAS
REM El tecnico tecleo 'A' o solo ENTER en el prompt del numero de disco.
REM No es un error: se devuelve el control al modulo llamante para que
REM regrese al paso ANTERIOR (elegir nivel, en sanitizar) o al menu
REM principal (en maquetar, que no tiene paso previo). SIN pausa.
set "DISCO_ATRAS=SI"
exit /b 0
:PEDIR_DISCO_OK
set "DISCO_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  CONFIRMAR_DESTRUCTIVO - autorizacion DIFERIDA en DOS pasos.
REM  -------------------------------------------------------------------
REM  USO:      call :CONFIRMAR_DESTRUCTIVO "etapa"
REM    %~1 = etiqueta corta para el log de auditoria (maquetar, sanitizar,
REM          riesgo...). NO se pide ninguna palabra escrita: el PASO 1 es
REM          una tecla (o linea + ENTER en modo set /p) y el PASO 2 es
REM          SIEMPRE linea + ENTER. El tecleo de 'CONFIRMAR' o 'RIESGO'
REM          ha quedado ABOLIDO.
REM
REM    PASO 1 - 'Confirmar operacion? [S/N]: '. Los datos del disco y el
REM             resumen de la operacion siguen en pantalla: el tecnico
REM             decide viendolo entero.
REM    PASO 2 - resumen de los COMANDOS en AMARILLO y despues
REM             'Atencion: Esta completamente seguro de ejecutar esta
REM             accion? [S/N]: '. Se reimprime el guion temporal exacto
REM             que se va a lanzar ('type "%F_SCRIPT%"), para que la
REM             segunda decision se tome mirando los comandos y no de
REM             memoria.
REM
REM    Solo DOS 'S' (o 'Y' en ingles) seguidas ejecutan el guion. 'N', un
REM    ENTER vacio o cualquier otra respuesta en CUALQUIER de los dos
REM    pasos CANCELA y el modulo pinta su aviso de operacion cancelada.
REM    El PASO 2 es deliberadamente ESTRICTO: 'SI'/'YES' ya NO valen,
REM    solo la letra S/s (o Y/y) exacta. Se lee siempre con set /p para
REM    que cualquier otra tecla cancele sin quedarse esperando.
REM  Cada paso queda en el log por separado (etapa=... paso=1/2).
REM  Devuelve CONFIRMADO = SI / NO.
REM ---------------------------------------------------------------------
:CONFIRMAR_DESTRUCTIVO
set "CONFIRMADO=NO"
set "CONF_ETAPA=%~1"
set "CONF_CLAVES=SN"
set "CONF_SI=S"
set "CONF_SI2=SI"
set "CONF_NO=N"
if /i "%LANG%"=="EN" set "CONF_CLAVES=YN"
if /i "%LANG%"=="EN" set "CONF_SI=Y"
if /i "%LANG%"=="EN" set "CONF_SI2=YES"
if /i "%LANG%"=="EN" set "CONF_NO=N"
REM --- PASO 1: los datos del disco estan arriba; una sola tecla --------
call :CONFIRMAR_LEER "%T_CFM_02%"
if not "%CONFIRMADO%"=="SI" goto CONFIRMAR_DESTRUCTIVO_NO1
REM --- PASO 2: resumen de comandos en AMARILLO + autorizacion final ----
call :CONFIRMAR_RESUMEN
call :CONFIRMAR_LEER_SEGURO "%T_CFM_03%"
if not "%CONFIRMADO%"=="SI" goto CONFIRMAR_DESTRUCTIVO_NO2
goto CONFIRMAR_DESTRUCTIVO_OK

REM ---------------------------------------------------------------------
REM  CONFIRMAR_LEER - captura de UNA sola pregunta S/N (o Y/N).
REM  -------------------------------------------------------------------
REM  USO:      call :CONFIRMAR_LEER "texto de la pregunta"
REM  Devuelve: CONFIRMADO = SI / NO.
REM  Es la rutina del PASO 1. El PASO 2 usa CONFIRMAR_LEER_SEGURO, que
REM  reutiliza la misma sanitizacion pero solo admite S/s (o Y/y).
REM  Ninguna entrada, por rara que sea, puede romper el guion.
REM ---------------------------------------------------------------------
:CONFIRMAR_LEER
set "CONFIRMADO=NO"
if "%MODO_ENTRADA%"=="CHOICE" goto CONFIRMAR_LEER_CHOICE
goto CONFIRMAR_LEER_SETP
:CONFIRMAR_LEER_CHOICE
REM errorlevel 1 = tecla SI (S/Y); errorlevel 2 = tecla NO (N). 'choice'
REM no devuelve ninguna otra cifra, asi que fuera de la lista NO existe
REM autorizacion posible.
choice /c %CONF_CLAVES% /n /m "%C_VERDE%%~1%C_FIN%"
if errorlevel 2 exit /b 0
if errorlevel 1 set "CONFIRMADO=SI"
exit /b 0
:CONFIRMAR_LEER_SETP
set "CONF_TXT="
set /p "CONF_TXT=%C_VERDE%%~1%C_FIN%"
REM ENTER vacio -^> se CANCELA. La guardia es OBLIGATORIA antes de cada
REM sustitucion: 'set /p' no toca la variable si la linea viene vacia, y
REM aplicar '%VAR:"=%' a una variable indefinida hace que cmd deje el
REM patron LITERAL con las comillas sin balancear, de modo que el 'if'
REM siguiente provoca un error de sintaxis que TERMINA todo menu.bat.
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT:"=%"
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT: =%"
if /i "%CONF_TXT%"=="%CONF_SI%" set "CONFIRMADO=SI"
if /i "%CONF_TXT%"=="%CONF_SI2%" set "CONFIRMADO=SI"
if /i "%CONF_TXT%"=="%CONF_NO%" exit /b 0
if "%CONFIRMADO%"=="SI" exit /b 0
REM Cualquier otra cosa tecleada (o un ENTER vacio) CANCELA: jamas un
REM tecleo raro autoriza una operacion destructiva. Se avisa una vez.
echo(
echo   %T_CFM_01%
exit /b 0

REM ---------------------------------------------------------------------
REM  CONFIRMAR_LEER_SEGURO - SEGUNDA confirmacion, ESTRICTA.
REM -------------------------------------------------------------------
REM  Solo una letra afirma: S/s (o Y/y si la interfaz esta en ingles).
REM  'SI'/'YES', ENTER vacio, N y CUALQUIER otra cosa CANCELAN. Es la
REM  ultima puerta antes de un borrado: aqui no se admite ambiguedad.
REM  Se usa SIEMPRE set /p (tambien en modo choice) para que una tecla
REM  distinta de S no quede ignorada esperando: se lee la linea completa
REM  y, si no es exactamente S/s, se cancela al instante.
REM ---------------------------------------------------------------------
:CONFIRMAR_LEER_SEGURO
set "CONFIRMADO=NO"
set "CONF_TXT="
set /p "CONF_TXT=%C_VERDE%%~1%C_FIN%"
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT:"=%"
if not defined CONF_TXT exit /b 0
set "CONF_TXT=%CONF_TXT: =%"
if /i "%CONF_TXT%"=="%CONF_SI%" set "CONFIRMADO=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  CONFIRMAR_RESUMEN - el bloque AMARILLO del PASO 2.
REM  -------------------------------------------------------------------
REM  Reimprime el guion temporal EXACTO que se va a lanzar. Si el fichero
REM  todavia no existe (paso de riesgo, que se pregunta antes de generar
REM  el guion) se lo explica al tecnico con T_CFM_06 en vez de imprimir
REM  un recuadro vacio. Se pinta en amarillo (C_AMARILLO) y se vuelve a
REM  C_FIN al terminar.
REM ---------------------------------------------------------------------
:CONFIRMAR_RESUMEN
<nul set /p "=%C_AMARILLO%"
echo(
echo   ==================================================================
echo   %T_CFM_04%
echo   ==================================================================
echo(
if exist "%F_SCRIPT%" type "%F_SCRIPT%"
if not exist "%F_SCRIPT%" echo   %T_CFM_06%
echo(
echo   %T_CFM_05%
echo(
<nul set /p "=%C_FIN%"
exit /b 0

:CONFIRMAR_DESTRUCTIVO_OK
call :REGISTRAR CONFIRMACION "etapa=%CONF_ETAPA% paso=1" "ACEPTADA"
call :REGISTRAR CONFIRMACION "etapa=%CONF_ETAPA% paso=2" "ACEPTADA"
exit /b 0
:CONFIRMAR_DESTRUCTIVO_NO1
call :REGISTRAR CONFIRMACION "etapa=%CONF_ETAPA% paso=1" "RECHAZADA"
exit /b 0
:CONFIRMAR_DESTRUCTIVO_NO2
call :REGISTRAR CONFIRMACION "etapa=%CONF_ETAPA% paso=2" "RECHAZADA"
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
REM  El guion que se escribe depende del NIVEL elegido en :ELEGIR_NIVEL:
REM    Nivel 1  select disk N + clean        (SOLO estructura: MBR/GPT y
REM               firma; instantaneo y sin tocar las celdas)
REM    Nivel 2  fase 1/3: clean + create partition primary +
REM               format fs=ntfs quick (prepara un volumen TEMPORAL para
REM               que PowerShell pueda aplicarle el TRIM en la fase 2/3;
REM               la fase 3/3 usa :GENERAR_SCRIPT_LIMPIO para acabar)
REM    Nivel 3  select disk N + clean all    (sobrescritura con ceros)
REM  Nota: no anadimos 'convert gpt' ni formateo permanente. Un disco
REM  sanitizado se deja EN BRUTO a proposito: asi se ve que ya no queda
REM  nada y el tecnico decide despues (por ejemplo, con la opcion [1]).
REM ---------------------------------------------------------------------
:GENERAR_SCRIPT_BORRAR
if not defined DISCO exit /b 0
if "%NIVEL_BORRADO%"=="3" goto GENERAR_BORRAR_CEROS
if "%NIVEL_BORRADO%"=="2" goto GENERAR_BORRAR_TRIM
REM --- Nivel 1: SOLO estructura ('clean', sin sobrescritura) ----------
> "%F_SCRIPT%" echo rem JAH-WinPe - nivel 1 limpieza de estructura Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean
call :REGISTRAR SANITIZAR "disco=%DISCO% nivel=%NIVEL_BORRADO% comando=clean" "GUION_GENERADO"
exit /b 0
:GENERAR_BORRAR_TRIM
REM --- Nivel 2, fase 1/3: volumen temporal para el TRIM ---------------
> "%F_SCRIPT%" echo rem JAH-WinPe - nivel 2 fase 1/3 volumen temporal Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean
>> "%F_SCRIPT%" echo create partition primary
>> "%F_SCRIPT%" echo format fs=ntfs quick
call :REGISTRAR SANITIZAR "disco=%DISCO% nivel=2 fase=1 comando=clean+format" "GUION_GENERADO"
exit /b 0
:GENERAR_BORRAR_CEROS
REM --- Nivel 3: sobrescritura completa ('clean all') -------------------
> "%F_SCRIPT%" echo rem JAH-WinPe - nivel 3 borrado con ceros (clean all) Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean all
call :REGISTRAR SANITIZAR "disco=%DISCO% nivel=%NIVEL_BORRADO% comando=clean all" "GUION_GENERADO"
exit /b 0

REM ---------------------------------------------------------------------
REM  GENERAR_SCRIPT_LIMPIO - guion de 'clean' (estructura) reutilizable.
REM  -------------------------------------------------------------------
REM  Pieza COMPARTIDA: es el guion del nivel [1] y tambien la fase 3/3
REM  del nivel [2] (vuelve a dejar el disco EN BRUTO tras el TRIM).
REM ---------------------------------------------------------------------
:GENERAR_SCRIPT_LIMPIO
if not defined DISCO exit /b 0
> "%F_SCRIPT%" echo rem JAH-WinPe - limpieza de estructura (clean) Disco %DISCO%
>> "%F_SCRIPT%" echo select disk %DISCO%
>> "%F_SCRIPT%" echo clean
call :REGISTRAR SANITIZAR "disco=%DISCO% nivel=%NIVEL_BORRADO% comando=clean" "GUION_GENERADO"
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
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo   %T_COM_47%:
echo   %F_SCRIPT%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
type "%F_SCRIPT%"
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo   %T_DP_01%
echo   %T_DP_02%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
diskpart /s "%F_SCRIPT%"
set "RESULTADO=%errorlevel%"
REM El codigo de salida (0 = exito) es el dato mas importante del log:
REM queda anotado tanto si funciono como si no, con su numero exacto.
if "%RESULTADO%"=="0" call :REGISTRAR DISKPART "codigo=0" "OK"
if not "%RESULTADO%"=="0" call :REGISTRAR DISKPART "codigo=%RESULTADO%" "ERROR"
echo(
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
REM Resultado en color ANSI por linea: VERDE si diskpart acabo sin
REM errores, ROJO si devolvio un codigo de error. Nunca se repinta la
REM consola entera (sin parpadeos a blanco).
if "%RESULTADO%"=="0" echo   %C_VERDE%%T_COM_48%%C_FIN%
if not "%RESULTADO%"=="0" echo   %C_ROJO%%T_COM_49% %RESULTADO%%C_FIN%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_DP_03%
echo   %T_DP_04%
echo(
exit /b 0

REM ---------------------------------------------------------------------
REM  EJECUTAR_TRIM - fase 2/3 del nivel [2]: reset SSD/NVMe (ReTrim)
REM  -------------------------------------------------------------------
REM  Desasigna (TRIM / deallocate) los bloques LIBRES de los volumenes
REM  del disco elegido: devuelve esos bloques al controlador para que la
REM  unidad recupere rendimiento de escritura SIN sobrescribir ceros
REM  celda a celda (cero desgaste de por vida, TBW). Es el paso que
REM  diferencia el nivel [2] de un simple 'clean'.
REM
REM  COMANDO: cmdlet NATIVO de PowerShell, sin ningun programa de terceros
REM      Optimize-Volume -DriveLetter L -ReTrim -Defrag -Verbose
REM  (No existe ninguna herramienta 'PowerChg': el TRIM se pide SIEMPRE
REM  con el cmdlet anterior. -Defrag reorganiza lo poco que queda util y
REM  -Verbose deja rastro de lo que hizo cada volumen.)
REM
REM  COMPATIBILIDAD HONESTA:
REM    - SSD/NVMe fisico con soporte de TRIM  -^> se aplica de verdad.
REM    - Disco virtual (VM) sin soporte del hipervisor, o controlador que
REM      no acepta deallocate -^> Optimize-Volume lanza excepcion; se
REM      CAPTURA volumen a volumen, se informa en AMARILLO y el script
REM      SIGUE con la fase 3 sin romperse ni fingir un exito.
REM    - Volumen sin letra asignada -^> no admite -DriveLetter; se avisa
REM      con T_NIV_45 y se omite SOLO ese volumen.
REM
REM  El comando PowerShell se arma en TROZOS (variable PS_CMD) porque en
REM  una sola linea pasaria de 94 columnas. Las 'pipe' van DENTRO de las
REM  comillas del 'set': dentro de comillas cmd no las interpreta como
REM  operadores y se guardan literales; luego la invocacion tambien las
REM  mantiene entre comillas ("%PS_CMD%").
REM
REM  NUNCA se inventa un resultado: se mira el marcador que solo puede
REM  escribir el propio PowerShell ('TRIM_OK' / 'TRIM_PARCIAL' /
REM  'TRIM_NADA' / 'SIN_VOLUMENES') y el codigo de salida. Si algo falla,
REM  se muestra el error tal cual. Requiere PowerShell (PS_OK); si no
REM  existe se lo dice al tecnico y se registra en el log, jamas se finge
REM  que el TRIM se aplico.
REM ---------------------------------------------------------------------
:EJECUTAR_TRIM
if not "%PS_OK%"=="SI" goto EJECUTAR_TRIM_SIN_PS
echo   %T_NIV_36% %DISCO%
set "PS_CMD=$a=@(Get-Partition -DiskNumber %DISCO% -ErrorAction SilentlyContinue)"
set "PS_CMD=%PS_CMD%; $p=@($a | Where-Object {$_.DriveLetter})"
set "PS_CMD=%PS_CMD%; if($a.Count -eq 0){ 'SIN_VOLUMENES' } else {"
set "PS_CMD=%PS_CMD% $s=$a.Count-$p.Count; if($s -gt 0){ 'SINLETRA|'+$s }"
set "PS_CMD=%PS_CMD%; $ok=0; $ko=0"
set "PS_CMD=%PS_CMD%; foreach($x in $p){ try{ Optimize-Volume -DriveLetter $x.DriveLetter"
set "PS_CMD=%PS_CMD% -ReTrim -Defrag -Verbose -ErrorAction Stop | Out-Null"
set "PS_CMD=%PS_CMD% $ok++ } catch { $ko++; 'FALLO|'+$x.DriveLetter+'|'+$_.Exception.Message } }"
set "PS_CMD=%PS_CMD%; if($ok -eq 0){ 'TRIM_NADA' } elseif($ko -gt 0){ 'TRIM_PARCIAL' } else { 'TRIM_OK' } }"
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_SEG_SAL%" 2>&1
set "TRIM_RC=%errorlevel%"
REM Aviso informativo: volumenes del disco sin letra (no admiten
REM -DriveLetter). Se pinta en amarillo y no corta el proceso. El salto
REM es OBLIGATORIO: cada 'if errorlevel' consume el codigo de salida, asi
REM que no pueden encadenarse dos comprobaciones sobre la misma cifra.
findstr /c:"SINLETRA|" "%F_SEG_SAL%" >nul 2>&1
if errorlevel 1 goto EJECUTAR_TRIM_SINLETRA_FIN
<nul set /p "=%C_AMARILLO%"
echo   %T_NIV_45%
<nul set /p "=%C_FIN%"
:EJECUTAR_TRIM_SINLETRA_FIN
findstr /c:"TRIM_OK" "%F_SEG_SAL%" >nul 2>&1
if not errorlevel 1 goto EJECUTAR_TRIM_OK
findstr /c:"TRIM_PARCIAL" "%F_SEG_SAL%" >nul 2>&1
if not errorlevel 1 goto EJECUTAR_TRIM_PARCIAL
findstr /c:"TRIM_NADA" "%F_SEG_SAL%" >nul 2>&1
if not errorlevel 1 goto EJECUTAR_TRIM_NADA
findstr /c:"SIN_VOLUMENES" "%F_SEG_SAL%" >nul 2>&1
if not errorlevel 1 goto EJECUTAR_TRIM_VACIO
goto EJECUTAR_TRIM_ERROR
:EJECUTAR_TRIM_OK
REM Buenas noticias: el TRIM se aplico. Mensaje en VERDE (C_VERDE).
<nul set /p "=%C_VERDE%"
echo   %T_NIV_31%
<nul set /p "=%C_FIN%"
call :REGISTRAR TRIM "disco=%DISCO% codigo=%TRIM_RC%" "OK"
exit /b 0
:EJECUTAR_TRIM_PARCIAL
REM Algun volumen ha sido desasignado y otro ha fallado. AMARILLO y se
REM muestra la salida cruda de PowerShell con el detalle por volumen.
<nul set /p "=%C_AMARILLO%"
echo   %T_NIV_42%
if exist "%F_SEG_SAL%" findstr /c:"FALLO|" "%F_SEG_SAL%"
<nul set /p "=%C_FIN%"
call :REGISTRAR TRIM "disco=%DISCO% codigo=%TRIM_RC%" "PARCIAL"
exit /b 0
:EJECUTAR_TRIM_NADA
REM Ningun volumen ha podido recibir el TRIM: disco virtual (VM) cuyo
REM hipervisor no implementa deallocate, controlador que lo rechaza o
REM volumenes sin letra. Se INFORMA limpiamente en AMARILLO y el modulo
REM sigue con la fase 3: no se finge exito y no se rompe el script.
<nul set /p "=%C_AMARILLO%"
echo   %T_NIV_43%
echo   %T_NIV_44%
if exist "%F_SEG_SAL%" findstr /c:"FALLO|" "%F_SEG_SAL%"
<nul set /p "=%C_FIN%"
call :REGISTRAR TRIM "disco=%DISCO% codigo=%TRIM_RC%" "NO_APLICABLE"
exit /b 0
:EJECUTAR_TRIM_VACIO
echo   %T_NIV_32%
call :REGISTRAR TRIM "disco=%DISCO% codigo=%TRIM_RC%" "SIN_VOLUMENES"
exit /b 0
:EJECUTAR_TRIM_ERROR
REM Error grave del paso TRIM: ROJO (C_ROJO) y se muestra la salida cruda.
<nul set /p "=%C_ROJO%"
echo   %T_NIV_33% %TRIM_RC%
echo   %T_NIV_35%
if exist "%F_SEG_SAL%" type "%F_SEG_SAL%"
<nul set /p "=%C_FIN%"
call :REGISTRAR TRIM "disco=%DISCO% codigo=%TRIM_RC%" "ERROR"
exit /b 0
:EJECUTAR_TRIM_SIN_PS
REM Precaucion (no hay PowerShell): AMARILLO (C_AMARILLO) y a blanco.
<nul set /p "=%C_AMARILLO%"
echo   %T_NIV_34%
<nul set /p "=%C_FIN%"
call :REGISTRAR TRIM "disco=%DISCO%" "SIN_POWERSHELL"
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
REM Mensaje de exito/verificacion en VERDE (C_VERDE); luego vuelve C_FIN.
<nul set /p "=%C_VERDE%"
echo   %T_COM_26%
echo     %T_D1_23% %DISCO% %T_D1_25%
echo       %T_COM_27%
echo     %T_D2_33% %DISCO% %T_D2_35%
echo       %T_COM_28%
echo     %T_COM_29%
echo       %T_COM_30%
<nul set /p "=%C_FIN%"
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
REM Construimos la lista de identificadores (agnostica al idioma) ANTES
REM de pintar: luego DISCO_EXISTE solo tiene que comprobar pertenencia.
call :PARSER_DISCOS
type "%F_SALIDA%"
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
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_D1_09%
echo     %T_D1_10%
echo     %T_D1_11%
echo     %T_D1_27%
echo     %T_D1_28%
echo     %T_D1_29%
echo(
echo   %T_D1_12%
echo   %T_D1_13%
echo(
call :PULSA_TECLA_MENU "%T_D1_14%"
if "%VUELTA_MENU%"=="SI" exit /b 0
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :LISTAR_DISCOS
call :DETECTAR_DISCO_ARRANQUE
call :PEDIR_DISCO
if "%DISCO_ATRAS%"=="SI" exit /b 0
if not "%DISCO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :REGISTRAR DISCO "modulo=maquetar disco=%DISCO%" "SELECCIONADO"
call :COMPROBAR_DISCO_SEGURO
if "%BLOQUEADO%"=="SI" goto MODULO_PREPARAR_BLOQUEO
call :ELEGIR_FORMATO_DUDA
if not "%FORMATO_OK%"=="SI" goto MODULO_PREPARAR_CANCELADO
call :GENERAR_SCRIPT_MAQUETAR
REM Sin 'cls': durante la ejecucion del modulo el historial se queda
REM hacia arriba para que el tecnico pueda hacer scroll y revisarlo.
call :MOSTRAR_CABECERA
echo(
echo   %T_D1_15%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
<nul set /p "=%C_FIN%"
:MODULO_PREPARAR_CONFIRMAR
REM Autorizacion en DOS pasos S/N: [1] ya visible el resumen completo y
REM [2] con el guion exacto impreso en amarillo. Ninguna palabra que
REM teclear: basta 'S' (o 'Y' en ingles) en cada paso.
call :CONFIRMAR_DESTRUCTIVO "maquetar"
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
REM Si la cancelacion vino de la tecla M no hay pausa: vuelta INMEDIATA
REM al menu principal (el llamante hace exit /b y luego goto MENU).
if "%SALIDA_M%"=="SI" exit /b 0
call :PULSA_TECLA "%T_D1_22%"
exit /b 0

REM ---------------------------------------------------------------------
REM  MODULO_SANITIZAR - opcion [2]: borrado en 3 NIVELES.
REM  -------------------------------------------------------------------
REM  El tecnico elige el nivel ANTES de tocar nada (pantalla con 'cls'):
REM    [1] clean      -^> solo la tabla de particiones (segundos)
REM    [2] TRIM       -^> libera bloques en SSD/NVMe; el controlador los
REM                       limpia (Garbage Collection): bloques irrecuperables
REM    [3] clean all  -^> sobrescritura con ceros (horas, solo HDD)
REM  Despues, los mismos pasos seguros de siempre: entorno, listar,
REM  elegir disco, escudo de arranque, resumen + guion a la vista y
REM  doble confirmacion escrita. El aviso de TIEMPO y el AVISO CRITICO
REM  (obligatorio, y con recuerdo extra si el disco es SSD) son del
REM  nivel [3]. Retroceso con la tecla directa [0]: en cmd puro ESC no
REM  es legible (ver el motivo en PULSA_TECLA_MENU).
REM ---------------------------------------------------------------------
:MODULO_SANITIZAR
call :ELEGIR_NIVEL
if not defined NIVEL_BORRADO exit /b 0
call :PREPARAR_ENTORNO
if not "%ENTORNO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :LISTAR_DISCOS
call :DETECTAR_DISCO_ARRANQUE
call :PEDIR_DISCO
if "%DISCO_ATRAS%"=="SI" goto MODULO_SANITIZAR_ATRAS
if not "%DISCO_OK%"=="SI" goto MODULO_SANITIZAR_CANCELADO
call :REGISTRAR DISCO "modulo=sanitizar disco=%DISCO% nivel=%NIVEL_BORRADO%" "SELECCIONADO"
call :COMPROBAR_DISCO_SEGURO
if "%BLOQUEADO%"=="SI" goto MODULO_SANITIZAR_BLOQUEO
REM  Fase 4.5: el tamano y la estimacion de TIEMPO solo interesan al
REM  nivel [3] ('clean all' puede durar horas); los niveles [1] y [2] son
REM  instantaneos. Para el [2] detectamos ademas el TIPO de medio (sin
REM  preguntar) para avisar si el disco es HDD y el TRIM no aporta.
if "%NIVEL_BORRADO%"=="3" call :CALCULAR_ESTIMACION_BORRADO
if "%NIVEL_BORRADO%"=="2" call :DETECTAR_MEDIA
call :GENERAR_SCRIPT_BORRAR
REM Sin 'cls': el resumen y las fases se imprimen hacia abajo para poder
REM revisar todo el historial con la rueda del raton.
call :MOSTRAR_CABECERA
echo(
echo   %T_D2_12%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_COM_51% %DISCO%
if "%PROTECCION_ESTADO%"=="ACTIVA" echo   %T_SEG_16%
if "%PROTECCION_ESTADO%"=="DUDA" echo   %T_SEG_17%
if "%PROTECCION_ESTADO%"=="NA" echo   %T_SEG_18%
echo   %T_FW_02% %FIRMWARE%
REM --- Accion y duracion segun el nivel elegido en :ELEGIR_NIVEL ------
if "%NIVEL_BORRADO%"=="1" echo   %T_NIV_13%
if "%NIVEL_BORRADO%"=="2" echo   %T_NIV_14%
if "%NIVEL_BORRADO%"=="3" echo   %T_D2_13%
if "%NIVEL_BORRADO%"=="2" echo     %T_NIV_37%
if "%NIVEL_BORRADO%"=="2" echo     %T_NIV_38%
if "%NIVEL_BORRADO%"=="2" echo     %T_NIV_39%
echo(
if "%NIVEL_BORRADO%"=="3" echo   %T_D2_14%
if "%NIVEL_BORRADO%"=="3" call :MOSTRAR_TIEMPO_ESTIMADO
if "%NIVEL_BORRADO%"=="1" echo   %T_NIV_15%
if "%NIVEL_BORRADO%"=="2" echo   %T_NIV_16%
echo(
REM --- Avisos: los niveles [1] y [2] NO sobrescriben, son cortos ------
if "%NIVEL_BORRADO%"=="3" goto MODULO_SANITIZAR_AVISOS_N3
echo   %T_D2_20%
echo     %T_NIV_17%
echo     %T_NIV_18%
echo       %T_NIV_19%
echo     %T_D2_27%
echo       %T_D2_28%
if "%NIVEL_BORRADO%"=="2" echo     %T_NIV_20%
if "%NIVEL_BORRADO%"=="2" echo       %T_NIV_21%
if "%NIVEL_BORRADO%"=="2" echo       %T_NIV_40%
if "%NIVEL_BORRADO%"=="2" echo       %T_NIV_41%
if "%NIVEL_BORRADO%"=="2" if "%MEDIA_TIPO%"=="HDD" echo     %T_NIV_24%
if "%NIVEL_BORRADO%"=="2" if "%MEDIA_TIPO%"=="HDD" echo       %T_NIV_25%
if "%NIVEL_BORRADO%"=="2" if "%PS_OK%"=="NO" echo   %T_NIV_22%
if "%NIVEL_BORRADO%"=="2" if "%PS_OK%"=="NO" echo       %T_NIV_23%
goto MODULO_SANITIZAR_AVISOS_FIN
:MODULO_SANITIZAR_AVISOS_N3
echo   %T_D2_20%
echo     %T_D2_21%
echo       %T_D2_22%
echo     %T_D2_23%
echo       %T_D2_24%
echo       %T_D2_25%
echo     %T_D2_26%
echo     %T_D2_27%
echo       %T_D2_28%
:MODULO_SANITIZAR_AVISOS_FIN
echo(
if "%ES_WINPE%"=="SI" goto MODULO_SANITIZAR_AVISO_OK
echo   %T_D2_29%
echo       %T_D2_34%
echo       %T_D2_30%
echo       %T_D2_31%
echo(
:MODULO_SANITIZAR_AVISO_OK
call :MOSTRAR_SCRIPT
if "%NIVEL_BORRADO%"=="3" call :MOSTRAR_AVISO_TIEMPO
if "%NIVEL_BORRADO%"=="3" call :MOSTRAR_AVISO_CRITICO
echo(
echo   %T_D2_32%
echo(
call :EVALUAR_SEGURIDAD
if not "%RIESGO_NECESARIO%"=="SI" goto MODULO_SANITIZAR_CONFIRMAR
call :MOSTRAR_AVISO_RIESGO
<nul set /p "=%C_FIN%"
:MODULO_SANITIZAR_CONFIRMAR
REM Autorizacion en DOS pasos S/N: [1] con el resumen de la operacion en
REM pantalla y [2] con el guion exacto impreso en amarillo. Ninguna
REM palabra que teclear: basta 'S' (o 'Y' en ingles) en cada paso.
call :CONFIRMAR_DESTRUCTIVO "sanitizar"
if not "%CONFIRMADO%"=="SI" goto MODULO_SANITIZAR_CANCELADO
if "%NIVEL_BORRADO%"=="2" goto MODULO_SANITIZAR_NIVEL2
call :EJECUTAR_DISKPART
goto MODULO_SANITIZAR_FIN_EJEC
:MODULO_SANITIZAR_NIVEL2
REM  Nivel [2] en TRES FASES: (1) diskpart deja un volumen temporal,
REM  (2) PowerShell desasigna los bloques libres con ReTrim (TRIM) y
REM  (3) diskpart vuelve a dejar el disco EN BRUTO con 'clean'.
REM  La fase [3] solo se lanza si la fase [1] salio bien (RESULTADO=0).
echo(
echo   %T_NIV_37%
call :EJECUTAR_DISKPART
if not "%RESULTADO%"=="0" call :REGISTRAR SANITIZAR "nivel=2 fase=1" "ERROR"
if not "%RESULTADO%"=="0" goto MODULO_SANITIZAR_FIN_EJEC
echo   %T_NIV_38%
call :EJECUTAR_TRIM
call :GENERAR_SCRIPT_LIMPIO
echo   %T_NIV_39%
call :EJECUTAR_DISKPART
:MODULO_SANITIZAR_FIN_EJEC
call :MOSTRAR_RESULTADO
call :BORRAR_TEMPORALES
call :PULSA_TECLA "%T_D1_21%"
exit /b 0
:MODULO_SANITIZAR_BLOQUEO
call :REGISTRAR BLOQUEO "modulo=sanitizar disco=%DISCO%" "DENEGADO"
call :MOSTRAR_BLOQUEO
goto MODULO_BLOQUEADO

:MODULO_SANITIZAR_ATRAS
REM El tecnico pidio volver al paso ANTERIOR (tecla A o solo ENTER en el
REM prompt del numero de disco). Aqui el paso anterior es la ELECCION DE
REM NIVEL, asi que se vuelve a pintar esa pantalla: jamas se queda en un
REM callejon sin salida. Sin pausa intermedia y sin tocar nada.
call :BORRAR_TEMPORALES
goto MODULO_SANITIZAR

:MODULO_SANITIZAR_CANCELADO
call :REGISTRAR CANCELADO "modulo=sanitizar disco=%DISCO%" "CANCELADO"
call :BORRAR_TEMPORALES
REM Cancelacion con la tecla M: sin pausa, vuelta INMEDIATA al menu.
if "%SALIDA_M%"=="SI" exit /b 0
call :PULSA_TECLA "%T_D1_22%"
exit /b 0

:MODULO_BLOQUEADO
call :BORRAR_TEMPORALES
exit /b 0

REM ---------------------------------------------------------------------
REM  ELEGIR_NIVEL - submenu de los 3 niveles de la opcion [2].
REM  -------------------------------------------------------------------
REM  Pinta una pantalla NUEVA (cls) con los tres niveles de borrado y
REM  devuelve NIVEL_BORRADO:
REM      1 / 2 / 3   -^> nivel elegido (el modulo sigue)
REM      (sin definir) -^> el tecnico pulso [0]: vuelta al menu sin
REM                       tocar nada.
REM
REM  Retroceso con la tecla directa [0] y no con ESC: en cmd puro ESC no
REM  es legible ('choice' lo rechaza y 'set /p' no lo distingue, motivo
REM  documentado en PULSA_TECLA_MENU). Ademas [0] es una sola tecla en
REM  modo choice, como el resto del guion: rapido para el tecnico y
REM  simple de mantener.
REM
REM  ENTRADA DUAL igual que el resto del menu:
REM    - MODO_ENTRADA=CHOICE  -^> elige :LEER_OPCION con lista "1 2 3 0"
REM      y 'choice /c 1230'. OJO: choice devuelve el INDICE de la tecla
REM      ('0' es la CUARTA del listado, errorlevel 4), no el digito, asi
REM      que aqui se traduce 4 -^> 0 antes de mapear el nivel.
REM    - MODO_ENTRADA=SETP    -^> :LEER_OPCION con set /p; la lista
REM      blanca compara el digito literal y devuelve "0" directamente.
REM  Solo 1, 2 y 3 rellenan NIVEL_BORRADO; cualquier otra lectura
REM  (tecla rara, Ctrl+C) deja el nivel vacio y el modulo vuelve al menu.
REM ---------------------------------------------------------------------
:ELEGIR_NIVEL
set "NIVEL_BORRADO="
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_D2_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_NIV_01%
echo(
echo   %T_NIV_02%
echo     %T_NIV_03%
echo     %T_NIV_04%
echo(
echo   %T_NIV_05%
echo     %T_NIV_06%
echo     %T_NIV_07%
echo(
echo   %T_NIV_08%
echo     %T_NIV_09%
echo     %T_NIV_10%
echo(
echo   %T_NIV_11%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :LEER_OPCION "%T_NIV_12%" "1 2 3 0" M A
if /i "%OPCION%"=="M" exit /b 0
if /i "%OPCION%"=="A" exit /b 0
if "%OPCION%"=="4" set "OPCION=0"
set "NIVEL_BORRADO="
if "%OPCION%"=="1" set "NIVEL_BORRADO=1"
if "%OPCION%"=="2" set "NIVEL_BORRADO=2"
if "%OPCION%"=="3" set "NIVEL_BORRADO=3"
if defined NIVEL_BORRADO call :REGISTRAR SANITIZAR "nivel=%NIVEL_BORRADO%" "ELEGIDO"
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_AVISO_CRITICO - aviso OBLIGATORIO del nivel [3].
REM  -------------------------------------------------------------------
REM  La sobrescritura con ceros es destructiva e INADECUADA en SSD/NVMe
REM  (gasta celdas NAND y acorta su vida util), asi que antes de las dos
REM  confirmaciones se muestra este aviso EN PANTALLA, obligatorio, tal
REM  como lo exige el diseno del taller. Se pinta en amarillo ANSI
REM  (C_AMARILLO) como el aviso de riesgo y vuelve a C_FIN al salir.
REM  Si el disco se detecto como SSD, se anade un RECORDATORIO EXTRA
REM  con la alternativa (nivel [2] TRIM); nunca se bloquea el nivel [3].
REM ---------------------------------------------------------------------
:MOSTRAR_AVISO_CRITICO
<nul set /p "=%C_AMARILLO%"
echo(
echo   ==================================================================
echo   %T_NIV_26%
echo   ==================================================================
echo(
echo   %T_NIV_27%
echo   %T_NIV_28%
echo   %T_NIV_29%
if "%MEDIA_TIPO%"=="SSD" echo   %T_NIV_30%
echo(
<nul set /p "=%C_FIN%"
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
cls
call :MOSTRAR_CABECERA
REM El bloque de seguridad se pinta en ROJO DESPUES de la cabecera:
REM asi el C_FIN de la cabecera no borra el color de aviso.
<nul set /p "=%C_ROJO%"
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
<nul set /p "=%C_FIN%"
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
<nul set /p "=%C_AMARILLO%"
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
REM  PASO 14 - FIRMWARE Y AUDITORIA DE TALLER (Fase 4)
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
REM Sin 'cls': la eleccion GPT/MBR es parte del flujo y el listado previo
REM sigue visible arriba para consultarlo.
call :MOSTRAR_CABECERA
echo(
echo   %T_FW_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
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
REM  PASO 15 - DIAGNOSTICO / INVENTARIO DE HARDWARE (Fase 4.5)
REM #####################################################################
REM  Este modulo es de SOLO LECTURA. Su unica mision es MOSTRAR datos: no
REM  genera ningun guion de diskpart ni escribe en ningun disco.
REM
REM  Herramientas que usa (todas nativas de Windows y sin efectos):
REM    wmic      -^> instrumental de Windows (WMI). Consulta al sistema.
REM                 Ruta normal:  %SystemRoot%\System32\wbem\wmic.exe
REM    diskpart  -^> SOLO con 'list disk' (listar, nunca seleccionar ni
REM                 limpiar): es la misma pieza ya probada en la Fase 2.
REM    ver       -^> comando clasico que imprime la version de Windows.
REM
REM  POR QUE 'wmic' PUEDE NO ESTAR: en Windows 11 'wmic' esta en desuso y
REM  en un WinPE recortado puede que ni exista. Por eso cada bloque
REM  comprueba si la herramienta esta ANTES de usarla y, si falta, avisa
REM  con un texto traducido en vez de fallar.
REM
REM  COMO SE LEE CADA DATO (para el tecnico junior):
REM    - wmic os        -^> sistema operativo (Caption, Version).
REM    - wmic csproduct -^> fabricante y modelo del equipo.
REM    - wmic cpu       -^> procesador: nucleos fisicos y logicos.
REM    - wmic baseboard -^> placa base: fabricante y modelo.
REM    - wmic diskdrive -^> discos fisicos: modelo, tamano y estado.
REM    - diskpart list disk -^> discos con su tamano en GB (mas legible).
REM  Los valores de 'wmic' salen en el idioma del sistema operativo: eso
REM  es informacion en bruto, no un texto que debamos traducir nosotros.
REM #####################################################################

REM ---------------------------------------------------------------------
REM  MODULO_INVENTARIO - MENU de diagnostico (solo lectura + chkdsk)
REM ---------------------------------------------------------------------
REM  Pantalla intermedia de la opcion [3]. Desde aqui el tecnico elige
REM  entre el inventario completo (solo lectura), la comprobacion de una
REM  unidad con chkdsk y la consulta de salud SMART. El modulo se llama
REM  con 'call' y vuelve con 'exit /b 0'; el bloque OP_INVENTARIO pinta
REM  despues el menu principal.
REM
REM  DIAG_MENU es la bandera de salida: si vale SI, alguna pantalla pidio
REM  el menu principal con M y hay que desenrollar SIN pausas hasta OP_x.
REM ---------------------------------------------------------------------
:MODULO_INVENTARIO
set "DIAG_MENU=NO"
:MODULO_INVENTARIO_BUCLE
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_DIAG_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_DIAG_02%
echo(
echo     %T_DIAG_03%
echo     %T_DIAG_04%
echo     %T_DIAG_05%
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :LEER_OPCION "%T_DIAG_07%" "1 2 3 0" M A
if /i "%OPCION%"=="M" exit /b 0
if /i "%OPCION%"=="A" exit /b 0
REM  En modo choice la tecla "0" es la CUARTA de la lista: errorlevel=4.
REM  Normalizamos 4 -^> 0 para que el resto del codigo compare siempre "0".
if "%OPCION%"=="4" set "OPCION=0"
if "%OPCION%"=="0" exit /b 0
if "%OPCION%"=="1" call :DIAG_HARDWARE
if "%OPCION%"=="2" call :DIAG_CHKDSK
if "%OPCION%"=="3" call :DIAG_SMART
if "%DIAG_MENU%"=="SI" exit /b 0
goto MODULO_INVENTARIO_BUCLE

REM ---------------------------------------------------------------------
REM  DIAG_HARDWARE - inventario completo del equipo (solo lectura)
REM ---------------------------------------------------------------------
:DIAG_HARDWARE
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_INV_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo   %T_INV_02%
echo(
echo   %T_INV_03%
call :INV_SISTEMA
echo(
echo   %T_INV_04%
call :INV_CPU
echo(
echo   %T_INV_05%
call :INV_RAM
echo(
echo   %T_INV_06%
call :INV_PLACA
echo(
echo   %T_INV_07%
call :INV_DISCOS
echo(
REM  Dejamos constancia en el log de que se consulto el equipo. El detalle
REM  va en ASCII y sin datos personales: es una linea de auditoria.
call :REGISTRAR DIAGNOSTICO "consulta=hardware" "OK"
call :PULSA_TECLA_MENU "%T_DIAG_08%"
if "%VUELTA_MENU%"=="SI" set "DIAG_MENU=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  DIAG_CHKDSK - comprobacion de una unidad logica con chkdsk
REM ---------------------------------------------------------------------
REM  Solo se ejecuta sobre unidades CON LETRA y nunca sobre X: (la unidad
REM  RAM de WinPE). Antes de lanzar nada se muestra el comando exacto y se
REM  pide confirmacion S/N. La letra se valida contra A-Z y contra la
REM  existencia real de la unidad, asi que un tecleo raro no ejecuta nada.
REM ---------------------------------------------------------------------
:DIAG_CHKDSK
if not exist "%SystemRoot%\System32\chkdsk.exe" goto DIAG_CHKDSK_SIN_EXE
cls
call :DIAG_CHKDSK_CABECERA
:DIAG_CHKDSK_PEDIR
set "CHK_LETRA="
set /p "CHK_LETRA=%C_VERDE%%T_DIAG_14%%C_FIN%"
REM ENTER vacio -^> se vuelve al paso anterior. No es un ERROR, es la
REM forma mas natural de decir "no quiero seguir". La guardia es
REM OBLIGATORIA antes de cualquier sustitucion: 'set /p' no toca la
REM variable con la linea vacia y aplicarle '%VAR:"=%' a una indefinida
REM deja el patron con comillas sin balancear, lo que abortaria todo
REM menu.bat con un error de sintaxis.
if not defined CHK_LETRA goto DIAG_CHKDSK_ATRAS
set "CHK_LETRA=%CHK_LETRA:"=%"
set "CHK_LETRA=%CHK_LETRA: =%"
if not defined CHK_LETRA goto DIAG_CHKDSK_ATRAS
REM --- Puntos de escape: A (o ENTER) al paso anterior, M al menu -------
if /i "%CHK_LETRA%"=="A" goto DIAG_CHKDSK_ATRAS
if /i "%CHK_LETRA%"=="M" goto DIAG_CHKDSK_MENU
if "%CHK_LETRA%"=="0" goto DIAG_CHKDSK_MENU
if not "%CHK_LETRA:~1%"=="" goto DIAG_CHKDSK_INVALIDA
set "CHK_LETRA_OK=NO"
for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "%CHK_LETRA%"=="%%L" set "CHK_LETRA_OK=SI"
if not "%CHK_LETRA_OK%"=="SI" goto DIAG_CHKDSK_INVALIDA
if /i "%CHK_LETRA%"=="X" goto DIAG_CHKDSK_X
if not exist "%CHK_LETRA%:\" goto DIAG_CHKDSK_NO_EXISTE
goto DIAG_CHKDSK_MODO

:DIAG_CHKDSK_CABECERA
REM Cabecera COMUN de la opcion [2]: titulo, avisos y LISTADO AUTOMATICO
REM de las unidades montadas (paso previo obligatorio: el tecnico elige
REM sobre letras REALES que acaba de ver, nunca de memoria).
call :MOSTRAR_CABECERA
echo(
echo   %T_DIAG_10%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_DIAG_11%
echo   %T_DIAG_12%
echo   %T_DIAG_13%
echo(
call :DIAG_LISTAR_UNIDADES
echo(
echo   %C_VERDE%%T_COM_56%%C_RESET%
exit /b 0
:DIAG_CHKDSK_VOLVER
REM Vuelta desde el submenu de modo al prompt de letra: se repinta la
REM pantalla COMPLETA para que el listado de unidades siga visible.
cls
call :DIAG_CHKDSK_CABECERA
goto DIAG_CHKDSK_PEDIR
:DIAG_CHKDSK_ATRAS
REM El tecnico pidio volver al paso anterior (A o solo ENTER): se regresa
REM al submenu de la Seccion [3] SIN pausa y SIN ejecutar chkdsk.
REM OJO: NO se toca DIAG_MENU. Si se pusiera a SI, MODULO_INVENTARIO se
REM desenrollaria hasta el menu principal; A debe volver solo UN nivel.
echo(
echo   %T_COM_57%
exit /b 0

:DIAG_CHKDSK_MODO
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_DIAG_15% %CHK_LETRA%:
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo     %T_DIAG_16%
echo     %T_DIAG_17%
echo     %T_DIAG_18%
echo(
echo   %T_DIAG_19%
echo   %C_VERDE%%T_COM_56%%C_RESET%
echo(
call :LEER_OPCION "%T_DIAG_20%" "1 2 3 0" M A
if /i "%OPCION%"=="M" goto DIAG_CHKDSK_MENU
if /i "%OPCION%"=="A" goto DIAG_CHKDSK_VOLVER
if "%OPCION%"=="4" set "OPCION=0"
REM [0] es el PUNTO DE ESCAPE de esta pantalla: vuelve al paso anterior
REM (elegir otra letra) en vez de expulsar del modulo.
if "%OPCION%"=="0" goto DIAG_CHKDSK_VOLVER
set "CHK_ARGS="
if "%OPCION%"=="1" set "CHK_ARGS=/scan"
if "%OPCION%"=="2" set "CHK_ARGS=/f"
if "%OPCION%"=="3" set "CHK_ARGS=/f /r"
if not defined CHK_ARGS goto DIAG_CHKDSK_MODO
set "CHK_MODO=%OPCION%"
echo(
echo   %T_DIAG_22% chkdsk %CHK_LETRA%: %CHK_ARGS%
echo(
call :LEER_SN "%T_DIAG_21%"
if not "%SN%"=="SI" goto DIAG_CHKDSK_CANCELADO
echo(
echo   %T_DIAG_23%
chkdsk %CHK_LETRA%: %CHK_ARGS%
set "CHK_RC=%errorlevel%"
call :DIAG_CHKDSK_RESULTADO
call :REGISTRAR DIAGNOSTICO "chkdsk=%CHK_LETRA% modo=%CHK_MODO% codigo=%CHK_RC%" "OK"
echo(
call :PULSA_TECLA_MENU "%T_DIAG_29%"
if "%VUELTA_MENU%"=="SI" set "DIAG_MENU=SI"
exit /b 0

:DIAG_CHKDSK_RESULTADO
if "%CHK_RC%"=="0" goto DIAG_CHKDSK_RC_OK
if "%CHK_RC%"=="1" goto DIAG_CHKDSK_RC_OK
if "%CHK_RC%"=="2" goto DIAG_CHKDSK_RC_WARN
if "%CHK_RC%"=="3" goto DIAG_CHKDSK_RC_WARN
<nul set /p "=%C_AMARILLO%"
echo   %T_DIAG_28% %CHK_RC%
<nul set /p "=%C_FIN%"
exit /b 0
:DIAG_CHKDSK_RC_OK
<nul set /p "=%C_VERDE%"
if "%CHK_RC%"=="0" echo   %T_DIAG_24%
if "%CHK_RC%"=="1" echo   %T_DIAG_25%
<nul set /p "=%C_FIN%"
exit /b 0
:DIAG_CHKDSK_RC_WARN
<nul set /p "=%C_AMARILLO%"
if "%CHK_RC%"=="2" echo   %T_DIAG_26%
if "%CHK_RC%"=="3" echo   %T_DIAG_27%
<nul set /p "=%C_FIN%"
exit /b 0

:DIAG_CHKDSK_INVALIDA
echo(
echo   %T_DIAG_30%
goto DIAG_CHKDSK_PEDIR
:DIAG_CHKDSK_X
echo(
echo   %T_DIAG_31%
goto DIAG_CHKDSK_PEDIR
:DIAG_CHKDSK_NO_EXISTE
echo(
echo   %T_DIAG_32% %CHK_LETRA%:
goto DIAG_CHKDSK_PEDIR
:DIAG_CHKDSK_CANCELADO
echo(
echo   %T_DIAG_33%
call :PULSA_TECLA_MENU "%T_DIAG_34%"
if "%VUELTA_MENU%"=="SI" set "DIAG_MENU=SI"
exit /b 0
:DIAG_CHKDSK_MENU
set "DIAG_MENU=SI"
exit /b 0
:DIAG_CHKDSK_SIN_EXE
echo(
echo   %T_DIAG_37%
call :PULSA_TECLA_MENU "%T_DIAG_29%"
if "%VUELTA_MENU%"=="SI" set "DIAG_MENU=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  DIAG_LISTAR_UNIDADES - lista de unidades LOGICAS con letra
REM ---------------------------------------------------------------------
REM  Escaneo AUTOMATICO previo a cualquier pregunta. Se prefiere
REM  PowerShell con Get-Volume + Get-Partition porque, ademas de la letra,
REM  la etiqueta y los tamanos, indica el DISCO FISICO sobre el que vive
REM  cada letra: asi el tecnico sabe de un vistazo que C: esta en el disco
REM  0 antes de teclear nada. Si esos cmdlets no estan montados (WinPE
REM  recortado), se cae a Win32_LogicalDisk y despues a wmic.
REM  La salida se imprime con 'type' para que una etiqueta con caracteres
REM  raros nunca se interprete como un comando.
REM ---------------------------------------------------------------------
:DIAG_LISTAR_UNIDADES
echo   %T_DIAG_35%
if "%PS_OK%"=="SI" goto DIAG_LISTAR_UNIDADES_PS
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto DIAG_LISTAR_UNIDADES_WMIC
goto DIAG_LISTAR_UNIDADES_DISKPART
:DIAG_LISTAR_UNIDADES_PS
call :ARCHIVO_TEMP_INV
REM  Sin tuberias en el texto de PowerShell: todo con foreach. La salida se
REM  escribe desde el propio PowerShell en ASCII, asi que cmd no tiene que
REM  interpretar ni convertir nada. Se listan TODAS las letras (fijas,
REM  extraibles y USB); solo se excluye el CD-ROM.
set "PS_CMD=$out=@(); try { $v=@();"
set "PS_CMD=%PS_CMD% try { if(Get-Command Get-Volume -EA SilentlyContinue){ $v=@(Get-Volume -EA Stop) } } catch { $v=@() };"
set "PS_CMD=%PS_CMD% foreach($x in $v){ if($x.DriveLetter -and $x.DriveType -ne 'CD-ROM'){"
set "PS_CMD=%PS_CMD% $d='-'; try { $p=Get-Partition -DriveLetter $x.DriveLetter -EA Stop; if($p){ $d=[string]$p.DiskNumber } } catch { $d='-' };"
set "PS_CMD=%PS_CMD% $out += '  '+$x.DriveLetter+':  '+$x.FileSystemLabel+'  '+$x.FileSystem+'  '+[math]::Round(([double]$x.Size)/1GB)+' GB  '+[math]::Round(([double]$x.SizeRemaining)/1GB)+' GB  disco '+$d } };"
set "PS_CMD=%PS_CMD% if($out.Count -eq 0){ $v=@();"
set "PS_CMD=%PS_CMD% try { $v=@(Get-CimInstance Win32_LogicalDisk -EA Stop) } catch { try { $v=@(Get-WmiObject Win32_LogicalDisk -EA Stop) } catch { $v=@() } };"
set "PS_CMD=%PS_CMD% foreach($x in $v){ if($x.DeviceID -match '^[A-Za-z]:$' -and $x.DriveType -ne 5){"
set "PS_CMD=%PS_CMD% $out += '  '+$x.DeviceID+'  '+$x.VolumeName+'  '+$x.FileSystem+'  '+[math]::Round(([double]$x.Size)/1GB)+' GB  '+[math]::Round(([double]$x.FreeSpace)/1GB)+' GB' } } };"
set "PS_CMD=%PS_CMD% if($out.Count -eq 0){ $out=@('SIN_DATOS') } } catch { $out=@('SIN_DATOS') };"
set "PS_CMD=%PS_CMD% [IO.File]::WriteAllLines('%F_INV%',$out,[Text.Encoding]::ASCII)"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "%PS_CMD%" >nul 2>&1
if not exist "%F_INV%" goto DIAG_LISTAR_UNIDADES_WMIC
findstr /c:"SIN_DATOS" "%F_INV%" >nul 2>&1
if not errorlevel 1 goto DIAG_LISTAR_UNIDADES_LIMPIAR
call :MOSTRAR_TEMP_O_NA
goto DIAG_LISTAR_UNIDADES_FIN
:DIAG_LISTAR_UNIDADES_LIMPIAR
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
:DIAG_LISTAR_UNIDADES_WMIC
if not exist "%SystemRoot%\System32\wbem\wmic.exe" goto DIAG_LISTAR_UNIDADES_DISKPART
wmic logicaldisk get deviceid,drivetype,volumename,filesystem,size,freespace
goto DIAG_LISTAR_UNIDADES_FIN
:DIAG_LISTAR_UNIDADES_DISKPART
REM  Ultimo recurso SIN PowerShell ni WMI: diskpart SI esta en cualquier
REM  WinPE. 'list volume' muestra las letras reales montadas ahora mismo.
call :ARCHIVO_TEMP_INV
echo list volume> "%F_INV%"
if exist "%SystemRoot%\System32\diskpart.exe" goto DIAG_LISTAR_UNIDADES_DP_EXE
diskpart /s "%F_INV%" > "%F_INV%.out" 2>&1
goto DIAG_LISTAR_UNIDADES_DP_VER
:DIAG_LISTAR_UNIDADES_DP_EXE
"%SystemRoot%\System32\diskpart.exe" /s "%F_INV%" > "%F_INV%.out" 2>&1
:DIAG_LISTAR_UNIDADES_DP_VER
if exist "%F_INV%.out" type "%F_INV%.out"
if not exist "%F_INV%.out" echo       %T_INV_10%
del /f /q "%F_INV%" "%F_INV%.out" >nul 2>&1
:DIAG_LISTAR_UNIDADES_FIN
<nul set /p "=%C_AMARILLO%"
echo   %T_DIAG_36%
<nul set /p "=%C_FIN%"
exit /b 0

REM ---------------------------------------------------------------------
REM  DIAG_SMART - salud general / SMART de los discos fisicos
REM ---------------------------------------------------------------------
REM  Se muestran dos fuentes complementarias si estan disponibles:
REM    - Get-PhysicalDisk : HealthStatus (Healthy / Warning / Unhealthy).
REM    - Win32_DiskDrive  : Status (OK / Pred Fail), el aviso clasico.
REM    - MSStorageDriver_FailurePredictStatus : PredictFailure (SMART).
REM  El veredicto final lo decide el propio PowerShell (VERDICT|OK/BAD/NA)
REM  y la consola lo pinta en verde, rojo o amarillo. Nunca se inventa un
REM  "OK": si no hay datos, se dice con claridad.
REM ---------------------------------------------------------------------
:DIAG_SMART
cls
call :MOSTRAR_CABECERA
echo(
echo   %T_DIAG_40%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_DIAG_41%
echo(
REM Escaneo AUTOMATICO previo: ANTES de nada se listan las unidades
REM montadas con su disco fisico y solo despues se consulta la salud.
REM Asi el tecnico relaciona cada letra con su disco y decide sobre
REM datos REALES acaba de ver en pantalla, no de memoria.
call :DIAG_LISTAR_UNIDADES
echo(
echo   %T_DIAG_46%
if "%PS_OK%"=="SI" goto DIAG_SMART_PS
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto DIAG_SMART_WMIC
echo       %T_INV_10%
goto DIAG_SMART_FIN
:DIAG_SMART_PS
call :ARCHIVO_TEMP_INV
REM  Sin tuberias: tres fuentes recorridas con foreach y salida ASCII.
REM  Get-PhysicalDisk da HealthStatus real; Win32_DiskDrive el Status
REM  clasico; MSStorageDriver_FailurePredictStatus el PredictFailure.
REM  Si una fuente no existe, la siguiente decide. Nunca se inventa OK.
set "PS_CMD=$out=@(); $seen=$false; $bad=$false; try {"
set "PS_CMD=%PS_CMD% $d=@(); try { if(Get-Command Get-PhysicalDisk -EA SilentlyContinue){ $d=@(Get-PhysicalDisk -EA Stop) } } catch { $d=@() };"
set "PS_CMD=%PS_CMD% foreach($x in $d){ $seen=$true; $h=[string]$x.HealthStatus; $o=[string]$x.OperationalStatus;"
set "PS_CMD=%PS_CMD% $out += '['+$x.DeviceId+'] '+$x.FriendlyName+'  ('+$x.MediaType+')  '+$h+' / '+$o+'  '+[math]::Round(([double]$x.Size)/1GB)+' GB';"
set "PS_CMD=%PS_CMD% if($h -ne 'Healthy'){ $bad=$true } };"
set "PS_CMD=%PS_CMD% if($d.Count -eq 0){ $w=@();"
set "PS_CMD=%PS_CMD% try { $w=@(Get-CimInstance Win32_DiskDrive -EA Stop) } catch { try { $w=@(Get-WmiObject Win32_DiskDrive -EA Stop) } catch { $w=@() } };"
set "PS_CMD=%PS_CMD% foreach($x in $w){ $seen=$true; $s=[string]$x.Status;"
set "PS_CMD=%PS_CMD% $out += '['+$x.Index+'] '+$x.Model+'  ('+$x.InterfaceType+')  '+$s+'  '+[math]::Round(([double]$x.Size)/1GB)+' GB';"
set "PS_CMD=%PS_CMD% if($s -ne 'OK'){ $bad=$true } } };"
set "PS_CMD=%PS_CMD% $f=@(); try { $f=@(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -EA Stop) } catch { try { $f=@(Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -EA Stop) } catch { $f=@() } };"
set "PS_CMD=%PS_CMD% foreach($x in $f){ $seen=$true; $p=[bool]$x.PredictFailure;"
set "PS_CMD=%PS_CMD% if($p){ $out += 'SMART '+$x.InstanceName+' = PREDICCION DE FALLO'; $bad=$true } else { $out += 'SMART '+$x.InstanceName+' = OK' } };"
set "PS_CMD=%PS_CMD% if(-not $seen){ $out += 'SIN_DATOS'; $out += 'VERDICT|NA' } elseif($bad){ $out += 'VERDICT|BAD' } else { $out += 'VERDICT|OK' }"
set "PS_CMD=%PS_CMD% } catch { $out=@('SIN_DATOS','VERDICT|NA') };"
set "PS_CMD=%PS_CMD% [IO.File]::WriteAllLines('%F_INV%',$out,[Text.Encoding]::ASCII)"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "%PS_CMD%" >nul 2>&1
if not exist "%F_INV%" goto DIAG_SMART_SIN_ARCHIVO
set "SMART_VERDICT=NA"
findstr /c:"VERDICT|OK" "%F_INV%" >nul 2>&1
if not errorlevel 1 set "SMART_VERDICT=OK"
findstr /c:"VERDICT|BAD" "%F_INV%" >nul 2>&1
if not errorlevel 1 set "SMART_VERDICT=BAD"
REM  Si PowerShell no ha podido leer nada, todavia queda wmic.
if "%SMART_VERDICT%"=="NA" if exist "%SystemRoot%\System32\wbem\wmic.exe" goto DIAG_SMART_WMIC
findstr /v /c:"VERDICT|" "%F_INV%" | findstr /v /c:"SIN_DATOS"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
goto DIAG_SMART_VEREDICTO
:DIAG_SMART_WMIC
call :ARCHIVO_TEMP_INV
wmic diskdrive get index,model,status,size > "%F_INV%" 2>&1
set "SMART_VERDICT=OK"
findstr /i /c:"No Instance" /c:"No hay instancias" "%F_INV%" >nul 2>&1
if not errorlevel 1 set "SMART_VERDICT=NA"
REM  PredFailure es el aviso SMART de verdad; se anade a la misma salida.
wmic /namespace:\\root\wmi path MSStorageDriver_FailurePredictStatus get InstanceName,PredictFailure >> "%F_INV%" 2>&1
findstr /i /c:"Pred Fail" /c:"TRUE" "%F_INV%" >nul 2>&1
if not errorlevel 1 set "SMART_VERDICT=BAD"
type "%F_INV%"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
goto DIAG_SMART_VEREDICTO
:DIAG_SMART_SIN_ARCHIVO
set "SMART_VERDICT=NA"
goto DIAG_SMART_VEREDICTO
:DIAG_SMART_VEREDICTO
if "%SMART_VERDICT%"=="OK" goto DIAG_SMART_OK
if "%SMART_VERDICT%"=="BAD" goto DIAG_SMART_BAD
<nul set /p "=%C_AMARILLO%"
echo   %T_DIAG_44%
<nul set /p "=%C_FIN%"
goto DIAG_SMART_LOG
:DIAG_SMART_OK
<nul set /p "=%C_VERDE%"
echo   %T_DIAG_42%
<nul set /p "=%C_FIN%"
goto DIAG_SMART_LOG
:DIAG_SMART_BAD
<nul set /p "=%C_ROJO%"
echo   %T_DIAG_43%
<nul set /p "=%C_FIN%"
:DIAG_SMART_LOG
call :REGISTRAR DIAGNOSTICO "consulta=smart estado=%SMART_VERDICT%" "OK"
:DIAG_SMART_FIN
echo(
call :PULSA_TECLA_MENU "%T_DIAG_45%"
if "%VUELTA_MENU%"=="SI" set "DIAG_MENU=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  INV_SISTEMA - sistema operativo y modelo del equipo
REM ---------------------------------------------------------------------
REM  'wmic os get caption,version /value' imprime el nombre del sistema y
REM  su version. 'wmic csproduct' da el fabricante y el modelo. La opcion
REM  '/value' muestra una linea por dato (Nombre=Valor): asi se lee mejor
REM  que en la tabla ancha por defecto. Si no hay wmic, caemos a 'ver',
REM  que solo da la version numerica: menos, pero siempre disponible.
REM ---------------------------------------------------------------------
:INV_SISTEMA
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto INV_SISTEMA_WMIC
if "%PS_OK%"=="SI" goto INV_SISTEMA_PS
goto INV_SISTEMA_VER
:INV_SISTEMA_WMIC
wmic os get caption,version /value
wmic csproduct get vendor,name /value
exit /b 0
:INV_SISTEMA_PS
set "PS_CMD=$o=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue"
set "PS_CMD=%PS_CMD%; $c=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue"
set "PS_CMD=%PS_CMD%; if($o){'OS: '+$o.Caption+' '+$o.Version}"
set "PS_CMD=%PS_CMD%; if($c){'System: '+$c.Manufacturer+' '+$c.Model}"
set "PS_CMD=%PS_CMD%; if(-not $o -and -not $c){'SIN_DATOS'}"
call :ARCHIVO_TEMP_INV
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_INV%" 2>&1
call :MOSTRAR_TEMP_O_NA
exit /b 0
:INV_SISTEMA_VER
echo       %T_INV_14%
ver
exit /b 0

REM ---------------------------------------------------------------------
REM  INV_CPU - procesador
REM ---------------------------------------------------------------------
REM  'wmic cpu get name,numberofcores,numberoflogicalprocessors /value'
REM  informa del modelo, de los nucleos FISICOS y de los LOGICOS (con
REM  HyperThreading, los logicos suelen ser el doble de los fisicos).
REM  RESPALDO SIN wmic: Windows expone SIEMPRE dos variables de entorno,
REM  %PROCESSOR_IDENTIFIER% y %NUMBER_OF_PROCESSORS%, que valen incluso
REM  en el WinPE mas recortado.
REM ---------------------------------------------------------------------
:INV_CPU
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto INV_CPU_WMIC
if "%PS_OK%"=="SI" goto INV_CPU_PS
goto INV_CPU_ENV
:INV_CPU_WMIC
wmic cpu get name,numberofcores,numberoflogicalprocessors,maxclockspeed /value
exit /b 0
:INV_CPU_PS
set "PS_CMD=$c=Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue"
set "PS_CMD=%PS_CMD%; if($c){'CPU: '+$c.Name+' | C='+$c.NumberOfCores+' L='+$c.NumberOfLogicalProcessors+' '+$c.MaxClockSpeed+' MHz'}else{'SIN_DATOS'}"
call :ARCHIVO_TEMP_INV
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_INV%" 2>&1
call :MOSTRAR_TEMP_O_NA
exit /b 0
:INV_CPU_ENV
echo       %PROCESSOR_IDENTIFIER%
if defined NUMBER_OF_PROCESSORS echo       %T_INV_13% %NUMBER_OF_PROCESSORS%
exit /b 0

REM ---------------------------------------------------------------------
REM  INV_RAM - memoria RAM instalada, disponible y modulos
REM ---------------------------------------------------------------------
REM  Consulta NATIVA con PowerShell embebido, encadenada por CAPAS para que
REM  funcione tanto en WinPE recortado como en maquinas fisicas y
REM  virtuales (era el famoso "dato no disponible" de la seccion 3):
REM
REM    1) Get-CimInstance Win32_PhysicalMemory  suma Capacity de TODOS los
REM       modulos: da la RAM INSTALADA real, aunque la BIOS reserve parte.
REM       (En WinPE necesita el paquete WinPE-WMI.)
REM    2) Get-WmiObject Win32_PhysicalMemory    misma clase por el canal
REM       COM, util cuando los cmdlets CIM no estan montados.
REM    3) Win32_ComputerSystem.TotalPhysicalMemory  por si no hay ni una
REM       ni otra: dato global del sistema, menos fino pero SIEMPRE util.
REM    4) wmic OS / memorychip                   ultimo respaldo, sin PS.
REM    5) T_INV_10 + T_INV_17                   solo si falla TODO.
REM
REM  Cada capa va envuelta en try/catch con -ErrorAction Stop: una capa
REM  caida no aborta la siguiente (el error atrapado no llega jamas a
REM  cmd). Win32_OperatingSystem aporta la RAM libre ACTUAL, y como
REM  FreePhysicalMemory viene en KB se divide por 1024 para salir en MB.
REM
REM  SIN tuberias dentro del texto de PowerShell (todo con foreach) y la
REM  salida la escribe el propio PowerShell en ASCII con WriteAllLines:
REM  cmd no interpreta caracteres raros ni sufre BOM/UTF-16 al redirigir.
REM ---------------------------------------------------------------------
:INV_RAM
if "%PS_OK%"=="SI" goto INV_RAM_PS
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto INV_RAM_WMIC
echo       %T_INV_10%
echo       %T_INV_17%
exit /b 0
:INV_RAM_PS
call :ARCHIVO_TEMP_INV
set "PS_CMD=$out=@(); try {"
set "PS_CMD=%PS_CMD% $m=@();"
set "PS_CMD=%PS_CMD% try { $m=@(Get-CimInstance Win32_PhysicalMemory -EA Stop) } catch { $m=@() };"
set "PS_CMD=%PS_CMD% if($m.Count -eq 0){ try { $m=@(Get-WmiObject Win32_PhysicalMemory -EA Stop) } catch { $m=@() } };"
set "PS_CMD=%PS_CMD% $t=0; $n=0; foreach($x in $m){ $n++; try { $t += [double]$x.Capacity } catch { };"
set "PS_CMD=%PS_CMD% $loc=[string]$x.DeviceLocator; if($loc -eq ''){ $loc='?' }; $spd=[string]$x.Speed; if($spd -eq ''){ $spd='?' };"
set "PS_CMD=%PS_CMD% $out += 'RAMSLOT|'+$loc+'|'+[math]::Round(([double]$x.Capacity)/1GB)+'|'+$spd };"
set "PS_CMD=%PS_CMD% if($t -le 0){ try { $t=[double](Get-CimInstance Win32_ComputerSystem -EA Stop).TotalPhysicalMemory } catch { $t=0 } };"
set "PS_CMD=%PS_CMD% if($t -le 0){ try { $t=[double](Get-WmiObject Win32_ComputerSystem -EA Stop).TotalPhysicalMemory } catch { $t=0 } };"
set "PS_CMD=%PS_CMD% $o=$null; try { $o=Get-CimInstance Win32_OperatingSystem -EA Stop } catch { try { $o=Get-WmiObject Win32_OperatingSystem -EA Stop } catch { $o=$null } };"
set "PS_CMD=%PS_CMD% $free=0; if($o){ if($t -le 0){ $t=[double]$o.TotalVisibleMemorySize*1024 }; $free=[math]::Round([double]$o.FreePhysicalMemory/1024) };"
set "PS_CMD=%PS_CMD% $sl=''; if($n -gt 0){ $sl=[string]$n };"
set "PS_CMD=%PS_CMD% if($t -gt 0){ $out += 'RAM|'+[math]::Round($t/1GB)+'|'+$sl+'|'+$free } else { $out=@('SIN_DATOS') }"
set "PS_CMD=%PS_CMD% } catch { $out=@('SIN_DATOS') };"
set "PS_CMD=%PS_CMD% [IO.File]::WriteAllLines('%F_INV%',$out,[Text.Encoding]::ASCII)"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "%PS_CMD%" >nul 2>&1
if not exist "%F_INV%" goto INV_RAM_WMIC
set "RAM_HECHO=NO"
set "RAM_SLOTS="
for /f "usebackq tokens=1-4 delims=|" %%A in ("%F_INV%") do if "%%A"=="RAM" call :INV_RAM_TOTAL "%%B" "%%C" "%%D"
if defined RAM_SLOTS echo       %T_INV_19%
for /f "usebackq tokens=1-4 delims=|" %%A in ("%F_INV%") do if "%%A"=="RAMSLOT" call :INV_RAM_SLOT "%%B" "%%C" "%%D"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
REM  PowerShell ha intentado las capas 1, 2 y 3. Si NINGUNA ha dado dato,
REM  no nos rendimos: se cae al respaldo con wmic (capa 4). Antes se saltaba
REM  directamente al aviso T_INV_10 y por eso el tecnico veia siempre
REM  "dato no disponible".
if not "%RAM_HECHO%"=="SI" if exist "%SystemRoot%\System32\wbem\wmic.exe" goto INV_RAM_WMIC
if not "%RAM_HECHO%"=="SI" goto INV_RAM_NA
exit /b 0
:INV_RAM_TOTAL
set "RAM_HECHO=SI"
set "RAM_SLOTS=%~2"
<nul set /p "=%C_BLANCO%"
echo       %T_INV_11% %~1 %T_INV_16%
if defined RAM_SLOTS echo       %T_INV_18% %RAM_SLOTS%
if not "%~3"=="" echo       %T_INV_12% %~3 %T_INV_16%
<nul set /p "=%C_FIN%"
exit /b 0
:INV_RAM_SLOT
echo         %~1: %~2 %T_INV_16%   %~3 %T_INV_20%
exit /b 0
:INV_RAM_WMIC
call :ARCHIVO_TEMP_INV
wmic OS get TotalVisibleMemorySize /value > "%F_INV%" 2>nul
set "RAM_TOTAL="
for /f "usebackq tokens=2 delims==" %%A in ("%F_INV%") do set "RAM_TOTAL=%%A"
wmic OS get FreePhysicalMemory /value > "%F_INV%" 2>nul
set "RAM_LIBRE="
for /f "usebackq tokens=2 delims==" %%A in ("%F_INV%") do set "RAM_LIBRE=%%A"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
REM  Quitamos los espacios que wmic suele dejar alrededor del valor. Las
REM  guardias 'if not defined' van ANTES de cada sustitucion: si wmic no
REM  devuelve nada la variable queda SIN DEFINIR y aplicarle '%VAR: =%' a
REM  una indefinida deja el patron literal con comillas sin balancear, lo
REM  que abortaria todo el guion con un error de sintaxis.
if not defined RAM_TOTAL goto INV_RAM_NA
set "RAM_TOTAL=%RAM_TOTAL: =%"
set /a RAM_T_MB=%RAM_TOTAL%/1024
set /a RAM_T_GB=%RAM_T_MB%/1024
echo       %T_INV_11% %RAM_T_MB% %T_INV_15%  ^(%RAM_T_GB% %T_INV_16%^)
if not defined RAM_LIBRE goto INV_RAM_WMIC_SLOTS
set "RAM_LIBRE=%RAM_LIBRE: =%"
set /a RAM_L_MB=%RAM_LIBRE%/1024
set /a RAM_L_GB=%RAM_L_MB%/1024
echo       %T_INV_12% %RAM_L_MB% %T_INV_15%  ^(%RAM_L_GB% %T_INV_16%^)
:INV_RAM_WMIC_SLOTS
echo       %T_INV_19%
wmic memorychip get devicelocator,speed,capacity
exit /b 0
:INV_RAM_NA
echo       %T_INV_10%
echo       %T_INV_17%
exit /b 0

REM ---------------------------------------------------------------------
REM  INV_PLACA - placa base
REM ---------------------------------------------------------------------
:INV_PLACA
if exist "%SystemRoot%\System32\wbem\wmic.exe" goto INV_PLACA_WMIC
if "%PS_OK%"=="SI" goto INV_PLACA_PS
goto INV_PLACA_NA
:INV_PLACA_WMIC
wmic baseboard get manufacturer,product /value
exit /b 0
:INV_PLACA_PS
set "PS_CMD=$b=Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue"
set "PS_CMD=%PS_CMD%; if($b){'BaseBoard: '+$b.Manufacturer+' '+$b.Product}else{'SIN_DATOS'}"
call :ARCHIVO_TEMP_INV
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_INV%" 2>&1
call :MOSTRAR_TEMP_O_NA
exit /b 0
:INV_PLACA_NA
echo       %T_INV_10%
exit /b 0

REM ---------------------------------------------------------------------
REM  INV_DISCOS - discos fisicos
REM ---------------------------------------------------------------------
REM  Dos fuentes complementarias, ambas de SOLO LECTURA:
REM    1) diskpart 'list disk' -^> indice + tamano en GB + estado + GPT.
REM       Se ejecuta con un guion temporal, igual que en la Fase 2.
REM    2) wmic diskdrive       -^> modelo comercial de cada disco.
REM  Si falta diskpart, se intenta al menos wmic; si faltan los dos, se
REM  avisa. En ningun caso se selecciona ni se limpia un disco.
REM ---------------------------------------------------------------------
:INV_DISCOS
set "INV_DISCOS_HECHO=NO"
if exist "%SystemRoot%\System32\diskpart.exe" call :INV_DISCOS_DP
if exist "%SystemRoot%\System32\wbem\wmic.exe" call :INV_DISCOS_WMIC
if not exist "%SystemRoot%\System32\wbem\wmic.exe" if "%PS_OK%"=="SI" call :INV_DISCOS_PS
if "%INV_DISCOS_HECHO%"=="NO" echo       %T_INV_10%
exit /b 0

:INV_DISCOS_DP
set "INV_DISCOS_HECHO=SI"
call :ARCHIVO_TEMP_INV
> "%F_INV%" echo rem JAH-WinPe - inventario de discos (solo lectura)
>> "%F_INV%" echo list disk
diskpart /s "%F_INV%" 2>&1
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
exit /b 0

:INV_DISCOS_WMIC
set "INV_DISCOS_HECHO=SI"
echo(
echo       %T_INV_08%
wmic diskdrive get index,model,size,status
exit /b 0

:INV_DISCOS_PS
set "INV_DISCOS_HECHO=SI"
echo(
echo       %T_INV_08%
set "PS_CMD=$d=@(); if(Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue){$d=@(Get-PhysicalDisk -ErrorAction SilentlyContinue)}"
set "PS_CMD=%PS_CMD%; if($d.Count -gt 0){$d|ForEach-Object{'['+$_.DeviceId+'] '+$_.FriendlyName+'  '+$_.MediaType+'  '+$_.HealthStatus+'  '+[math]::Round($_.Size/1GB)+' GB'}}"
set "PS_CMD=%PS_CMD%; if($d.Count -eq 0){$w=@(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue); if($w.Count -gt 0){$w|ForEach-Object{'['+$_.Index+'] '+$_.Model+'  '+$_.InterfaceType+'  '+$_.Status+'  '+[math]::Round($_.Size/1GB)+' GB'}}else{'SIN_DATOS'}}"
call :ARCHIVO_TEMP_INV
"%PS_EXE%" -NoProfile -Command "%PS_CMD%" > "%F_INV%" 2>&1
call :MOSTRAR_TEMP_O_NA
exit /b 0

REM #####################################################################
REM  PASO 16 - TAMANO REAL Y ESTIMACION DE BORRADO (Fase 4.5)
REM #####################################################################
REM  Antes de un 'clean all' (que puede durar HORAS) leemos el tamano
REM  real del disco y mostramos un aviso con un tiempo estimado. Regla de
REM  oro: la cifra es ORIENTATIVA. Un disco de taller puede ir por SATA o
REM  por USB 2.0 (unas diez veces mas lento) y su estado influye. Por eso
REM  damos un RANGO "de X a Y" y avisamos, en vez de prometer un numero.
REM #####################################################################

REM ---------------------------------------------------------------------
REM  ARCHIVO_TEMP_INV - fichero temporal para las consultas de wmic
REM ---------------------------------------------------------------------
REM  Se usa para capturar la salida de 'wmic' y leer un valor concreto.
REM  Vive en la carpeta temporal del sistema y SIEMPRE se borra despues.
REM ---------------------------------------------------------------------
:ARCHIVO_TEMP_INV
set "F_INV="
if defined TEMP set "F_INV=%TEMP%\_jah_inv.txt"
if not defined F_INV set "F_INV=%SystemDrive%\_jah_inv.txt"
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_TEMP_O_NA - imprime la salida guardada en %F_INV%
REM -------------------------------------------------------------------
REM  Varias consultas de diagnostico (CPU, placa, sistema, discos, unidades)
REM  vuelcan su salida en %F_INV% y la muestran tal cual con 'findstr'.
REM  Motivo: asi un modelo o una etiqueta con '&', '|' o parentesis NUNCA
REM  se interpreta como un comando de cmd; se imprime byte a byte.
REM  Si el fichero solo contiene el centinela SIN_DATOS, se avisa con
REM  T_INV_10. El temporal se borra siempre, pase lo que pase.
REM -------------------------------------------------------------------
:MOSTRAR_TEMP_O_NA
set "TEMP_HECHO=SI"
if not exist "%F_INV%" set "TEMP_HECHO=NO"
if not exist "%F_INV%" goto MOSTRAR_TEMP_O_NA_FIN
if not exist "%SystemRoot%\System32\findstr.exe" goto MOSTRAR_TEMP_O_NA_TYPE
findstr /c:"SIN_DATOS" "%F_INV%" >nul 2>&1
if not errorlevel 1 set "TEMP_HECHO=NO"
if "%TEMP_HECHO%"=="SI" findstr /v /c:"SIN_DATOS" "%F_INV%"
if not "%TEMP_HECHO%"=="SI" echo       %T_INV_10%
goto MOSTRAR_TEMP_O_NA_FIN
:MOSTRAR_TEMP_O_NA_TYPE
type "%F_INV%"
:MOSTRAR_TEMP_O_NA_FIN
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
exit /b 0

REM ---------------------------------------------------------------------
REM  CALCULAR_ESTIMACION_BORRADO - orquesta la lectura y la estimacion
REM ---------------------------------------------------------------------
REM  Entrada: %DISCO%
REM  Salida:  DISCO_GB, MEDIA_TIPO, MEDIA_TXT, EST_TXT
REM  Pasos: leer tamano -^> detectar tipo (o preguntar) -^> estimar tiempo
REM  -^> anotar el resultado en el log.
REM ---------------------------------------------------------------------
:CALCULAR_ESTIMACION_BORRADO
set "DISCO_GB="
set "MEDIA_TIPO=?"
set "MEDIA_TXT="
set "EST_TXT="
call :LEER_TAMANO_DISCO
call :DETECTAR_MEDIA
if not "%MEDIA_TIPO%"=="?" goto CALCULAR_ESTIMACION_LISTO
call :ELEGIR_MEDIA_DUDA
:CALCULAR_ESTIMACION_LISTO
if "%MEDIA_TIPO%"=="HDD" set "MEDIA_TXT=%T_EST_06%"
if "%MEDIA_TIPO%"=="SSD" set "MEDIA_TXT=%T_EST_07%"
if not defined MEDIA_TXT set "MEDIA_TXT=%T_EST_08%"
call :ESTIMAR_TIEMPO_BORRADO
set "DISCO_GB_LOG=%DISCO_GB%"
if not defined DISCO_GB_LOG set "DISCO_GB_LOG=NA"
set "EST_LOG=disco=%DISCO% tamano=%DISCO_GB_LOG%GB media=%MEDIA_TIPO%"
call :REGISTRAR SANITIZAR "%EST_LOG%" "ESTIMADO"
exit /b 0

REM ---------------------------------------------------------------------
REM  LEER_TAMANO_DISCO - lee el tamano REAL del disco en bytes
REM ---------------------------------------------------------------------
REM  'wmic diskdrive where "index=N" get size /value' devuelve la capacidad
REM  EXACTA del disco N en bytes (por ejemplo: Size=500107862016).
REM
REM  CONVERSION bytes -^> GB SIN DESBORDAR: 'set /a' no puede con numeros
REM  de 12 cifras (32 bits), asi que NO dividimos con aritmetica: quitamos
REM  los ultimos 9 digitos con una operacion de TEXTO. Recortar 9 cifras
REM  equivale a dividir entre mil millones y, como 1 GB son mas o menos
REM  1.000.000.000 bytes, el resultado son los GB comerciales del disco.
REM  Antes de recortar VALIDAMOS que la cadena sea solo digitos y tenga al
REM  menos 10 cifras: asi un mensaje de error de wmic jamas se confunde
REM  con un tamano.
REM ---------------------------------------------------------------------
:LEER_TAMANO_DISCO
set "DISCO_GB="
set "DISCO_BYTES="
if not defined DISCO exit /b 0
if not exist "%SystemRoot%\System32\wbem\wmic.exe" exit /b 0
call :ARCHIVO_TEMP_INV
wmic diskdrive where "index=%DISCO%" get size /value > "%F_INV%" 2>nul
if not exist "%F_INV%" exit /b 0
for /f "usebackq tokens=2 delims==" %%A in ("%F_INV%") do set "DISCO_BYTES=%%A"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
REM  Guardia ANTES de la sustitucion: si wmic no devuelve nada la variable
REM  queda SIN DEFINIR y '%VAR: =%' dejaria el patron literal con comillas
REM  sin balancear, lo que abortaria el guion. Espacios fuera.
if not defined DISCO_BYTES exit /b 0
set "DISCO_BYTES=%DISCO_BYTES: =%"
call :ES_NUMERO_GRANDE "%DISCO_BYTES%"
if not "%NUM_GRANDE_OK%"=="SI" exit /b 0
set "DISCO_GB=%DISCO_BYTES:~0,-9%"
exit /b 0

REM ---------------------------------------------------------------------
REM  ES_NUMERO_GRANDE - valida una cadena de solo digitos (10 cifras o mas)
REM ---------------------------------------------------------------------
REM  Uso:      call :ES_NUMERO_GRANDE "%DISCO_BYTES%"
REM  Devuelve: NUM_GRANDE_OK = SI / NO
REM  Reutiliza :ES_DIGITO (definida en el PASO 13) caracter a caracter. Se
REM  exige una longitud minima para descartar cualquier mensaje de texto.
REM ---------------------------------------------------------------------
:ES_NUMERO_GRANDE
set "NUM_GRANDE_OK=NO"
set "NG_TXT=%~1"
if not defined NG_TXT exit /b 0
if "%NG_TXT:~0,10%"=="" exit /b 0
set "NG_BUCLE=%NG_TXT%"
:ES_NUMERO_GRANDE_BUCLE
if not defined NG_BUCLE goto ES_NUMERO_GRANDE_OK
set "NG_CAR=%NG_BUCLE:~0,1%"
set "NG_BUCLE=%NG_BUCLE:~1%"
call :ES_DIGITO "%NG_CAR%"
if not "%DIGITO_OK%"=="SI" exit /b 0
goto ES_NUMERO_GRANDE_BUCLE
:ES_NUMERO_GRANDE_OK
set "NUM_GRANDE_OK=SI"
exit /b 0

REM ---------------------------------------------------------------------
REM  DETECTAR_MEDIA - HDD o SSD? (WMI de almacenamiento)
REM ---------------------------------------------------------------------
REM  Consulta la clase MSFT_PhysicalDisk (espacio de nombres 'storage'):
REM  su propiedad MediaType vale 3 para HDD y 4 para SSD. Si el espacio de
REM  nombres no existe (WinPE recortado) o el disco no aparece, dejamos
REM  MEDIA_TIPO='?' y el modulo PREGUNTARA (nunca adivina).
REM  La orden de 'wmic' se arma en TROZOS (variable MEDIA_WMIC) porque en
REM  una sola linea pasaria de 94 columnas y romperia el ancho de consola.
REM ---------------------------------------------------------------------
:DETECTAR_MEDIA
set "MEDIA_TIPO=?"
if not defined DISCO exit /b 0
if not exist "%SystemRoot%\System32\wbem\wmic.exe" exit /b 0
call :ARCHIVO_TEMP_INV
set "MEDIA_WMIC=/namespace:\\root\microsoft\windows\storage"
set "MEDIA_WMIC=%MEDIA_WMIC% path MSFT_PhysicalDisk"
set "MEDIA_WMIC=%MEDIA_WMIC% where DeviceId='%DISCO%' get MediaType /value"
wmic %MEDIA_WMIC% > "%F_INV%" 2>nul
if not exist "%F_INV%" exit /b 0
set "MEDIA_NUM="
for /f "usebackq tokens=2 delims==" %%A in ("%F_INV%") do set "MEDIA_NUM=%%A"
if exist "%F_INV%" del /f /q "%F_INV%" >nul 2>&1
REM  Guardia ANTES de la sustitucion: con wmic sin salida la variable queda
REM  SIN DEFINIR y '%VAR: =%' la dejaria convertida en patron literal con
REM  comillas sin balancear, rompiendo el guion entero. Sin dato, sin tipo.
if not defined MEDIA_NUM exit /b 0
set "MEDIA_NUM=%MEDIA_NUM: =%"
if "%MEDIA_NUM%"=="3" set "MEDIA_TIPO=HDD"
if "%MEDIA_NUM%"=="4" set "MEDIA_TIPO=SSD"
exit /b 0

REM ---------------------------------------------------------------------
REM  ELEGIR_MEDIA_DUDA - pregunta HDD o SSD si no se pudo detectar
REM ---------------------------------------------------------------------
REM  Solo se entra cuando DETECTAR_MEDIA dejo MEDIA_TIPO='?'. El tipo de
REM  disco influye en el tiempo, asi que si no lo sabemos lo preguntamos
REM  en vez de suponer. Por defecto (o si la entrada no es valida) tomamos
REM  HDD, que es la suposicion CONSERVADORA (la estimacion mas larga).
REM ---------------------------------------------------------------------
:ELEGIR_MEDIA_DUDA
REM Sin 'cls': la identificacion del disco elegido queda arriba.
call :MOSTRAR_CABECERA
echo(
echo   %T_MED_01%
echo   %C_VERDE%------------------------------------------------------------------%C_FIN%
echo(
echo   %T_MED_02% %DISCO% %T_MED_03%
echo(
call :LEER_OPCION "%T_MED_04%" "1 2"
set "MEDIA_TIPO=HDD"
if "%OPCION%"=="2" set "MEDIA_TIPO=SSD"
call :REGISTRAR SANITIZAR "media=manual disco=%DISCO% tipo=%MEDIA_TIPO%" "OK"
exit /b 0

REM ---------------------------------------------------------------------
REM  ESTIMAR_TIEMPO_BORRADO - del tamano al rango de tiempo
REM ---------------------------------------------------------------------
REM  Entrada: DISCO_GB (numero) y MEDIA_TIPO (HDD / SSD)
REM  Salida:  EST_TXT  (por ejemplo: "de 1 h 20 min a 3 h 10 min")
REM
REM  COMO SE CALCULA (aqui esta la "matematica" del aviso):
REM    1) Pasamos los GB a MB:  MB = GB x 1024.
REM    2) Elegimos DOS velocidades de escritura tipicas (en MB/s): la
REM       RAPIDA da el minimo y la LENTA el maximo:
REM          HDD: 150 MB/s (min)  y   60 MB/s (max)
REM          SSD: 300 MB/s (min)  y  100 MB/s (max)
REM    3) minutos = MB / (MB/s) / 60.  Para dividir una sola vez juntamos
REM       las dos divisiones:  minutos = MB / (velocidad x 60).
REM          HDD: 150x60 = 9000  y  60x60 = 3600
REM          SSD: 300x60 = 18000 y 100x60 = 6000
REM    4) 'set /a' trabaja con enteros y redondea hacia abajo; despues
REM       evitamos el "0 minutos" forzando un minimo de 1.
REM  Recuerda: son referencias de taller, no medidas del disco concreto.
REM ---------------------------------------------------------------------
:ESTIMAR_TIEMPO_BORRADO
set "EST_TXT="
if not defined DISCO_GB exit /b 0
set /a EST_MB=%DISCO_GB% * 1024
if /i "%MEDIA_TIPO%"=="SSD" goto ESTIMAR_SSD
set /a EST_MIN_MIN=%EST_MB% / 9000
set /a EST_MIN_MAX=%EST_MB% / 3600
goto ESTIMAR_FIN
:ESTIMAR_SSD
set /a EST_MIN_MIN=%EST_MB% / 18000
set /a EST_MIN_MAX=%EST_MB% / 6000
:ESTIMAR_FIN
if %EST_MIN_MIN% LSS 1 set "EST_MIN_MIN=1"
if %EST_MIN_MAX% LSS %EST_MIN_MIN% set "EST_MIN_MAX=%EST_MIN_MIN%"
call :FORMATO_HORAS %EST_MIN_MIN%
set "EST_TXT=%HORAS_TXT%"
call :FORMATO_HORAS %EST_MIN_MAX%
set "EST_TXT=%T_EST_10% %EST_TXT% %T_EST_11% %HORAS_TXT%"
exit /b 0

REM ---------------------------------------------------------------------
REM  FORMATO_HORAS - convierte minutos en "H h M min" o "M min"
REM ---------------------------------------------------------------------
REM  Uso:      call :FORMATO_HORAS 95   -^>   HORAS_TXT = "1 h 35 min"
REM  'set /a' da la division entera (horas) y el resto con el MODULO '%',
REM  que en un .bat se escribe DOBLE: %%.
REM ---------------------------------------------------------------------
:FORMATO_HORAS
set "HORAS_TXT="
set "FH_MIN=%~1"
if not defined FH_MIN exit /b 0
set /a FH_H=%FH_MIN% / 60
set /a FH_M=%FH_MIN% %% 60
if %FH_H% LSS 1 set "HORAS_TXT=%FH_M% %T_EST_13%"
if %FH_H% GEQ 1 set "HORAS_TXT=%FH_H% %T_EST_12% %FH_M% %T_EST_13%"
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_TIEMPO_ESTIMADO - una linea dentro del resumen del modulo
REM ---------------------------------------------------------------------
REM  Si tenemos tamano y estimacion, mostramos el dato concreto; si no,
REM  caemos a la tabla generica de siempre (T_D2_15..T_D2_19). Asi el
REM  tecnico SIEMPRE ve una referencia de tiempo, sepa el script mucho o
REM  poco del disco elegido.
REM ---------------------------------------------------------------------
:MOSTRAR_TIEMPO_ESTIMADO
if defined EST_TXT goto MOSTRAR_TIEMPO_DETALLE
echo     %T_EST_17%
echo     %T_D2_15%
echo     %T_D2_16%
echo     %T_D2_17%
echo     %T_D2_18%
echo     %T_D2_19%
exit /b 0
:MOSTRAR_TIEMPO_DETALLE
echo     %T_EST_02% %DISCO%   -   %T_EST_03% %DISCO_GB% %T_EST_05%
echo     %T_EST_04% %MEDIA_TXT%   -   %T_EST_09% %EST_TXT%
exit /b 0

REM ---------------------------------------------------------------------
REM  MOSTRAR_AVISO_TIEMPO - aviso amarillo antes de la confirmacion
REM ---------------------------------------------------------------------
REM  Se pinta en amarillo ANSI (C_AMARILLO) para que destaque, igual que
REM  el aviso de riesgo de la Fase 2.8, y se vuelve a C_FIN al
REM  terminar. Se muestra DESPUES del guion y ANTES de pedir la palabra
REM  de confirmacion.
REM ---------------------------------------------------------------------
:MOSTRAR_AVISO_TIEMPO
<nul set /p "=%C_AMARILLO%"
echo(
echo   ==================================================================
echo   %T_EST_01%
echo   ==================================================================
echo(
echo   %T_EST_02% %DISCO%   -   %T_EST_04% %MEDIA_TXT%
if defined DISCO_GB echo   %T_EST_03% %DISCO_GB% %T_EST_05%
if not defined DISCO_GB echo   %T_EST_03% %T_EST_08%
if defined EST_TXT echo   %T_EST_09% %EST_TXT%
if not defined EST_TXT echo   %T_EST_09% %T_EST_17%
echo(
echo   %T_EST_14%
echo   %T_EST_15%
echo   %T_EST_16%
echo(
<nul set /p "=%C_FIN%"
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
set "T_AYU_01=[5] AYUDA Y DOCUMENTACIÓN TÉCNICA"
set "T_AYU_02=Selecciona un apartado del manual:"
set "T_AYU_03=  [1] Comandos útiles y herramientas disponibles en WinPE"
set "T_AYU_04=  [2] Guía paso a paso: Opción 1 (discos y particiones) y Opción 2 (sanitizar)"
set "T_AYU_05=  [3] Códigos de navegación y atajos rápidos"
set "T_AYU_06=   Tu opción [1-3] (A = atrás, M = menú):  "
set "T_AYU_07=   [Enter] Continuar   [A] Atrás   [M] Menú:  "
set "T_GUIA_01=[5] GUÍA PASO A PASO - Página 1 de 2: Opción 1 (discos y particiones)"
set "T_GUIA_02=OPCIÓN 1 - OPERACIONES SOBRE DISCOS Y PARTICIONES"
set "T_GUIA_03=1) Elige la opción [1] en el menú principal."
set "T_GUIA_04=2) Se listan los discos físicos con diskpart (solo lectura)."
set "T_GUIA_05=3) Escribe el NÚMERO del disco (columna Disk / Disco)."
set "T_GUIA_06=4) Elige el esquema: GPT para UEFI, MBR para BIOS Legacy."
set "T_GUIA_07=5) Revisa el guion de diskpart que se muestra en pantalla."
set "T_GUIA_08=6) Confirma DOS veces con S (o Y en inglés)."
set "T_GUIA_09=7) Se ejecutan clean, convert, create, format y assign."
set "T_GUIA_10=8) Al final se vuelve a listar el equipo para verificar."
set "T_GUIA_11=PROTECCIÓN: el disco del sistema y el de arranque de WinPE"
set "T_GUIA_12=quedan bloqueados: la herramienta no permite tocarlos."
set "T_GUIA_14=[5] GUÍA PASO A PASO - Página 2 de 2: Opción 2 y diagnóstico"
set "T_GUIA_15=OPCIÓN 2 - BORRADO SEGURO / SANITIZACIÓN"
set "T_GUIA_16=Nivel [1] clean: borra la tabla de particiones. Los datos"
set "T_GUIA_17=siguen en el disco y son recuperables. Es el nivel más rápido."
set "T_GUIA_18=Nivel [2] TRIM + clean: para SSD/NVMe. Libera los bloques"
set "T_GUIA_19=libres y el controlador los limpia. Datos irrecuperables."
set "T_GUIA_20=En una VM puede no haber soporte TRIM: se avisa y el proceso"
set "T_GUIA_21=sigue sin romperse (nunca se finge un éxito)."
set "T_GUIA_22=Nivel [3] clean all: ceros en todo el disco (horas); en HDD, irrecuperable."
set "T_GUIA_23=DIAGNÓSTICO (Sección 3, solo lectura)"
set "T_GUIA_24=[1] Inventario: CPU, RAM, placa base y discos."
set "T_GUIA_25=[2] CHKDSK: comprueba una unidad con /scan, /f o /f /r."
set "T_GUIA_26=[3] SMART: estado OK / Pre-fail de los discos físicos."
set "T_NAV_01=[5] CÓDIGOS DE NAVEGACIÓN Y ATAJOS RÁPIDOS"
set "T_NAV_02=NAVEGACIÓN"
set "T_NAV_03=M      vuelve al menú principal (sin pausa)"
set "T_NAV_04=A      vuelve al paso anterior (sin pausa)"
set "T_NAV_05=ENTER  cancela la entrada o vuelve al paso anterior"
set "T_NAV_06=0      salir / cancelar en los submenús que lo muestran"
set "T_NAV_07=1-7    elegir una opción del menú principal"
set "T_NAV_08=CONFIRMACIONES"
set "T_NAV_09=Las operaciones destructivas piden DOS confirmaciones: la"
set "T_NAV_10=primera pregunta S/N y después la pregunta de SEGURIDAD."
set "T_NAV_11=Solo la tecla S (Y en inglés) confirma; cualquier otra cancela."
set "T_NAV_12=SEGURIDAD"
set "T_NAV_13=El disco del sistema en ejecución y el disco de arranque de"
set "T_NAV_14=WinPE están protegidos: no se pueden preparar ni borrar."
set "T_AYU1_01=[5] AYUDA DEL SISTEMA - Página 1 de 2: discos y almacenamiento"
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
set "T_AYU1_33=Continúa a la página 2 de la ayuda..."
set "T_AYU2_01=[5] AYUDA DEL SISTEMA - Página 2 de 2: sistema, red y utilidades"
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
set "T_AYU2_28=Si un comando no aparece, no está: pruébalo en la opción 4."
set "T_AYU2_29=- Antes de formatear un disco, mira su estado SMART con la orden"
set "T_AYU2_30=de arriba: un disco con 'Pred Fail' no merece una instalación"
set "T_AYU2_31=nueva (el trabajo se perdería en semanas, no en años)."
set "T_AYU2_32=   Mostrar la lista de comandos de esta imagen? [S/N]:  "
set "T_AYU2_33=--- COMANDOS NATIVOS DE CMD Y DE WINPE (usa la rueda para scroll) ---"
set "T_AYU3_01=Fin de la lista de comandos de esta imagen."
set "T_AYU3_02=DISCO Y ARRANQUE"
set "T_AYU3_03=diskpart                  list / select / clean / convert"
set "T_AYU3_04=wmic diskdrive get status . Estado SMART (OK o Pred Fail)"
set "T_AYU3_05=chkdsk X: /f /r           repara y busca sectores dañados"
set "T_AYU3_06=bootrec /fixmbr /fixboot  repara el arranque"
set "T_AYU3_07=bcdboot C:\\Windows /s S: escribe el gestor de arranque"
set "T_AYU3_08=dism /image:C:\\ /add-driver  inyecta controladores"
set "T_AYU3_09=SISTEMA Y RED"
set "T_AYU3_10=systeminfo / ipconfig /all   ficha técnica y de red"
set "T_AYU3_11=ping / nslookup / netstat -an  conectividad y puertos"
set "T_AYU3_12=reg load-add-unload           edita el registro fuera de línea"
set "T_AYU3_13=COMANDOS NATIVOS DE CMD (incorporados)"
set "T_AYU3_14=dir copy move del type ren md rd ver set exit cls"
set "T_BIEN_01=Bienvenido, técnico."
set "T_BIEN_02=Esta herramienta centraliza las operaciones más usadas del taller"
set "T_BIEN_03=para dar soporte a equipos Windows y preparar discos de forma"
set "T_BIEN_04=(rápida, repetible y sin sorpresas)."
set "T_BIEN_05=REGLAS DE ORO antes de tocar un disco:"
set "T_BIEN_06=1. Identifica SIEMPRE el disco correcto antes de borrar nada."
set "T_BIEN_07=Las opciones 1 y 2 listan los discos antes de preguntar."
set "T_BIEN_08=2. Las opciones 1 y 2 son DESTRUCTIVAS: borran la tabla de"
set "T_BIEN_09=particiones (y en la opción 2, todo el contenido del disco)."
set "T_BIEN_10=Ninguna actúa sin que tú confirmes DOS veces seguidas (S/N)."
set "T_BIEN_11=3. Ante la duda, consulta primero la opción 5 (Ayuda) y no"
set "T_BIEN_12=improvises con comandos que no conoces."
set "T_BIEN_13=Forma de uso: teclea el número de la opción que aparece en el"
set "T_BIEN_14=menú. Según el entorno bastará con la tecla o con pulsar ENTER."
set "T_BIEN_15=Pulsa cualquier tecla para entrar en el menú principal..."
set "T_CFM_01=[i] Confirmación no reconocida: NO se ha ejecutado nada."
set "T_CFM_02=   ¿Confirmar operación? [S/N]:  "
set "T_CFM_03=Atención: ¿Está completamente seguro de ejecutar esta acción? [S/N]: "
set "T_CFM_04=RESUMEN DE LOS COMANDOS QUE SE VAN A EJECUTAR"
set "T_CFM_05=PASO 2 de 2 - escribe 'S' y pulsa ENTER para ejecutar; 'N' u otra tecla cancela."
set "T_CFM_06=Aún no hay guion generado: los comandos salen en el resumen de arriba."
set "T_COM_01=[!] Entrada no válida. Usa solo una de las opciones indicadas."
set "T_COM_02=[!] Entrada no válida: introduce SOLO el número de disco (por"
set "T_COM_03=ejemplo: 0, 1, 2, 10), sin ceros a la izquierda; A vuelve al paso"
set "T_COM_04=anterior y M al menú principal."
set "T_COM_05=[!] Esta consola NO parece tener permisos de administrador."
set "T_COM_06=diskpart podrá listar los discos, pero NO podrá modificarlos"
set "T_COM_07=(devolverá acceso denegado en 'clean')."
set "T_COM_08=   Continuar de todos modos? [S/N]:  "
set "T_COM_09=[!] No he podido crear ficheros de trabajo en:"
set "T_COM_10=Sin una carpeta escribible no puedo generar el guion de"
set "T_COM_11=diskpart, y sin guion no se ejecuta nada. ABORTAMOS sin"
set "T_COM_12=tocar ningún disco (la seguridad primero)."
set "T_COM_13=[!] No encuentro diskpart.exe en esta imagen."
set "T_COM_14=¿Es un WinPE muy recortado? Este módulo no puede continuar."
set "T_COM_15=Teclea el NUMERO de disco sobre el que quieres trabajar."
set "T_COM_16=Ese numero es la PRIMERA columna del listado de arriba"
set "T_COM_17=(Disk 0 / Disco 0, Disk 1 / Disco 1...). Nunca es una letra."
set "T_COM_18=Vuelve al menú principal con M; al paso anterior con A (o ENTER)."
set "T_COM_19=   Número de disco (A = anterior, M = menú):  "
set "T_COM_24=   ¿Qué hacemos? [1=Corregir / 2=Continuar / 3=Cancelar]:  "
set "T_COM_25=VERIFICACIÓN FINAL: este es el estado ACTUAL del equipo."
set "T_COM_26=[Ayuda] Cómo comprobar el resultado:"
set "T_COM_27=en 'list volume', un volumen SISTEMA en NTFS con su letra."
set "T_COM_28=(sin particiones ni volúmenes). Eso es lo correcto."
set "T_COM_29=- Si el disco no muestra el resultado esperado, revisa el aviso"
set "T_COM_30=que dio diskpart antes de repetir cualquier operación."
set "T_COM_31=Consultando los discos del equipo con diskpart (solo lectura)..."
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
set "T_COM_52=   Recibido: "
set "T_COM_53=Teclas directas: M = menú principal, S = confirmar si el número es correcto (sin ENTER)."
set "T_COM_54=      [C] Continuar      [M] Menú principal"
set "T_COM_55=   Teclea tu opción:  "
set "T_COM_56= [A] Paso anterior   ^|   [M] Menú principal (Pulsar Enter)"
set "T_COM_57=[i] Volviendo al paso anterior."
set "T_CONS_01=[4] CONSOLA AVANZADA"
set "T_CONS_02=Abriendo una consola CMD interactiva en la MISMA ventana."
set "T_CONS_03=- Escribe 'exit' para volver al menú principal."
set "T_CONS_04=- Heredas el entorno actual (unidad de trabajo, variables)."
set "T_CONS_05=- OJO: los cambios que hagas en variables NO afectan al menú."
set "T_CONS_06=Recuerda: primero mira, después actúa. Para discos:"
set "T_CONS_07=diskpart  -^>  list disk  -^>  detail disk  -^>  exit"
set "T_D1_01=[1] OPERACIONES SOBRE DISCOS Y PARTICIONES"
set "T_D1_09=Orden de comandos:"
set "T_D1_10=  1) clean"
set "T_D1_11=  2) convert gpt / mbr (GPT en UEFI, MBR en Legacy)"
set "T_D1_12=RECUERDA: 'clean' borra la tabla de particiones del disco elegido."
set "T_D1_13=Todo lo que hubiera en él dejará de ser visible de inmediato."
set "T_D1_14=Siguiente: se carga el listado de discos con diskpart (solo lectura)..."
set "T_D1_15=[1] OPERACIONES SOBRE DISCOS Y PARTICIONES - RESUMEN Y CONFIRMACIÓN"
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
set "T_D1_27=  3) create partition primary"
set "T_D1_28=  4) format fs=ntfs quick label=SISTEMA"
set "T_D1_29=  5) assign (letra libre que Windows elija)"
set "T_D2_01=[2] BORRADO SEGURO / SANITIZACIÓN"
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
set "T_D2_32=Antes de ejecutar se te pedirán DOS confirmaciones (S/N) seguidas."
set "T_D2_33=- Borrado seguro (opción 2): el Disco"
set "T_D2_34=ejecución. La protección de arranque bloquea el disco del sistema"
set "T_D2_35=aparecerá EN BRUTO"
set "T_NIV_01=Elige el nivel de borrado ([0] o M para volver al menú):"
set "T_NIV_02=  [1] Limpieza rápida (Solo Estructura)"
set "T_NIV_03=      Borra solo la tabla de particiones (MBR/GPT) y la firma del"
set "T_NIV_04=      disco: al instante y sin desgaste en las celdas de almacenamiento."
set "T_NIV_05=  [2] Reset SSD / NVMe (Optimización TRIM / Deallocate)"
set "T_NIV_06=      Formatea un volumen temporal y fuerza TRIM masivo: el"
set "T_NIV_07=      controlador limpia los bloques (GC), rápido y sin ceros."
set "T_NIV_08=  [3] Limpieza profunda / Sobrescritura de ceros (Solo HDDs)"
set "T_NIV_09=      'clean all': sobrescribe TODOS los sectores con ceros."
set "T_NIV_10=      Lento. NO recomendado en SSD o NVMe (desgaste NAND)."
set "T_NIV_11=  [0] Salir / Cancelar"
set "T_NIV_12=   Su nivel [0-3]:  "
set "T_NIV_13=Acción:         clean     (solo estructura, sin sobrescritura)"
set "T_NIV_14=Acción:         TRIM + clean  (reset SSD/NVMe, sin ceros)"
set "T_NIV_15=Duración:       instantánea (sin sobrescritura de sectores)"
set "T_NIV_16=Duración:       segundos (TRIM + limpieza de estructura)"
set "T_NIV_17=- NO se sobrescribe ningún sector con ceros en este nivel."
set "T_NIV_18=- Los datos anteriores dejan de ser visibles para el sistema,"
set "T_NIV_19=  pero esto no recupera discos con fallos físicos."
set "T_NIV_20=- El TRIM a nivel de controlador SÍ destruye la recuperación"
set "T_NIV_21=  de datos a nivel de bloques: el controlador recicla las"
set "T_NIV_40=  celdas liberadas (Garbage Collection) y no escribe ceros,"
set "T_NIV_41=  así que es rápido, seguro y sin desgaste de celdas (TBW)."
set "T_NIV_42=TRIM aplicado solo en parte de los volúmenes. Detalle de los fallos:"
set "T_NIV_43=[i] TRIM no aplicable en este entorno (disco virtual o sin soporte"
set "T_NIV_44=del hipervisor): el paso se OMITE y se continúa con la limpieza."
set "T_NIV_45=[i] Volumen sin letra asignada: no admite -DriveLetter, se omite."
set "T_NIV_22=[!] PowerShell no disponible: el paso TRIM se omitirá y solo"
set "T_NIV_23=se aplicará la limpieza de estructura (como el nivel [1])."
set "T_NIV_24=- Este disco es HDD: el TRIM no aplicará; solo limpieza de"
set "T_NIV_25=  estructura. Para sobrescribir contenido usa el nivel [3]."
set "T_NIV_26=[AVISO CRÍTICO] Esta opción sobrescribe todos los sectores del disco con ceros."
set "T_NIV_27=Está diseñada exclusivamente para discos duros mecánicos (HDD). NO"
set "T_NIV_28=RECOMENDADA en unidades SSD o NVMe ya que acorta severamente su vida"
set "T_NIV_29=útil por desgaste de celdas NAND Flash."
set "T_NIV_30=[i] Este disco es SSD/NVMe: valora el nivel [2] antes de seguir."
set "T_NIV_31=TRIM completado: bloques libres desasignados (ReTrim)."
set "T_NIV_32=TRIM: el disco no expone volúmenes; no hay nada que desasignar."
set "T_NIV_33=TRIM no completado. Código de salida de PowerShell:"
set "T_NIV_34=PowerShell no disponible: se omite el TRIM (solo limpieza de estructura)."
set "T_NIV_35=Salida de PowerShell:"
set "T_NIV_36=Enviando órdenes TRIM / Deallocate al Disco"
set "T_NIV_37=FASE 1/3  diskpart: crea un volumen temporal y lo formatea"
set "T_NIV_38=FASE 2/3  PowerShell: ordena TRIM / Deallocate a los volúmenes"
set "T_NIV_39=FASE 3/3  diskpart: 'clean' final, deja el disco EN BRUTO"
set "T_EST_01=ADVERTENCIA: TIEMPO ESTIMADO DEL BORRADO SEGURO (clean all)"
set "T_EST_02=Disco número"
set "T_EST_03=Tamaño real detectado:"
set "T_EST_04=Tipo de disco:"
set "T_EST_05=GB"
set "T_EST_06=HDD (disco duro mecánico)"
set "T_EST_07=SSD (unidad de estado sólido)"
set "T_EST_08=sin determinar"
set "T_EST_09=Tiempo estimado:"
set "T_EST_10=de"
set "T_EST_11=a"
set "T_EST_12=h"
set "T_EST_13=min"
set "T_EST_14=Cifra ORIENTATIVA: depende del disco, del bus (USB/SATA) y de su salud."
set "T_EST_15=NO interrumpas el proceso una vez iniciado (ni teclas, ni reinicio)."
set "T_EST_16=En SSD el borrado físico NO queda garantizado (mira los avisos)."
set "T_EST_17=Tamaño no legible: se usa la tabla de referencia de abajo."
set "T_INV_01=[3] DIAGNÓSTICO / INVENTARIO - SOLO LECTURA"
set "T_INV_02=Este módulo NO modifica discos ni particiones: solo informa."
set "T_INV_03=EQUIPO Y SISTEMA"
set "T_INV_04=PROCESADOR"
set "T_INV_05=MEMORIA RAM (total / disponible / módulos)"
set "T_INV_06=PLACA BASE"
set "T_INV_07=DISCOS FÍSICOS (índice, tamaño y estado)"
set "T_INV_08=Modelos de disco:"
set "T_INV_09=Pulsa cualquier tecla para volver al menú..."
set "T_INV_10=[i] Dato no disponible en esta imagen (falta el comando)."
set "T_INV_11=Total:"
set "T_INV_12=Disponible:"
set "T_INV_13=Procesadores lógicos:"
set "T_INV_14=Sistema (ver):"
set "T_INV_15=MB"
set "T_INV_16=GB"
set "T_INV_17=No legible aquí: prueba 'systeminfo' en la Consola (opción 4)."
set "T_INV_18=Slots ocupados:"
set "T_INV_19=Detalle por módulo (ranura / tamaño / velocidad):"
set "T_INV_20=MHz"
set "T_DIAG_01=[3] DIAGNÓSTICO Y SALUD DEL HARDWARE"
set "T_DIAG_02=Consulta el equipo y permite comprobar sus unidades (chkdsk, SMART)."
set "T_DIAG_03=  [1] Hardware completo       CPU, RAM, placa base y discos"
set "T_DIAG_04=  [2] Comprobar unidad        chkdsk: /scan, /f o /f /r"
set "T_DIAG_05=  [3] Salud SMART             estado OK / Pre-fail de los discos"
set "T_DIAG_07=   Su opción [1-3] (A = atrás, M = menú):  "
set "T_DIAG_08=Fin del inventario de hardware."
set "T_DIAG_10=[2] CHKDSK - COMPROBACIÓN DE UNA UNIDAD"
set "T_DIAG_11=Comprueba la unidad que elijas; no borra archivos."
set "T_DIAG_12=No uses X: (unidad RAM de WinPE)."
set "T_DIAG_13=La letra debe ser una unidad montada (C:, D:, E:...)."
set "T_DIAG_14=   Letra de unidad (ej. C) (A = atrás, M = menú):  "
set "T_DIAG_15=Unidad seleccionada:"
set "T_DIAG_16=  [1] Análisis rápido (/scan)      no desmonta la unidad"
set "T_DIAG_17=  [2] Reparar errores (/f)         puede pedir reinicio"
set "T_DIAG_18=  [3] Reparar + sectores (/f /r)   muy lento, para HDD"
set "T_DIAG_19=  [0] Paso anterior: elegir OTRA letra"
set "T_DIAG_20=   Modo [0-3] (A = atrás, M = menú):  "
set "T_DIAG_21=   ¿Ejecutar chkdsk con estas opciones? [S/N]:  "
set "T_DIAG_22=Comando:"
set "T_DIAG_23=Ejecutando chkdsk. No cierres la ventana ni apagues el equipo..."
set "T_DIAG_24=[OK] chkdsk terminó sin errores (código 0)."
set "T_DIAG_25=[OK] chkdsk encontró y corrigió errores (código 1)."
set "T_DIAG_26=[!] chkdsk pide una limpieza adicional (código 2)."
set "T_DIAG_27=[!] chkdsk no pudo comprobar la unidad (código 3)."
set "T_DIAG_28=[i] Código de salida de chkdsk:"
set "T_DIAG_29=Fin de la comprobación."
set "T_DIAG_30=[!] Letra no válida: escribe UNA letra de unidad (A-Z)."
set "T_DIAG_31=[!] X: es la unidad RAM de WinPE: no se comprueba con chkdsk."
set "T_DIAG_32=[!] La unidad no existe o no está montada:"
set "T_DIAG_33=Comprobación cancelada: no se ha ejecutado chkdsk."
set "T_DIAG_34=Fin de la comprobación."
set "T_DIAG_35=Unidades lógicas detectadas (letra, etiqueta, FS, total, libre, disco):"
set "T_DIAG_36=Nota: X: es la unidad RAM de WinPE; no ejecutes chkdsk sobre ella."
set "T_DIAG_37=[!] No encuentro chkdsk.exe en esta imagen."
set "T_DIAG_40=[3] SALUD SMART DE LOS DISCOS"
set "T_DIAG_41=Consultando el estado SMART y la salud general de los discos..."
set "T_DIAG_42=[OK] Todos los discos declaran un estado saludable."
set "T_DIAG_43=[!] ALERTA: hay un disco con aviso SMART (Pre-fail/Warning). Copia los datos."
set "T_DIAG_44=[i] El estado SMART no se puede leer en esta imagen."
set "T_DIAG_45=Fin de la consulta SMART."
set "T_DIAG_46=Formato: [índice] modelo (tipo) salud / estado tamaño"
set "T_MED_01=TIPO DE DISCO NO DETECTADO"
set "T_MED_02=No he podido saber si el Disco"
set "T_MED_03=es un HDD (mecánico) o un SSD (sólido):"
set "T_MED_04=   ¿Qué tipo de disco es? [1=HDD / 2=SSD]:  "
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
set "T_MENU_02=[1]  Operaciones sobre discos y particiones   limpieza y formato"
set "T_MENU_03=[2]  Sanitización y borrado seguro            3 niveles (estructura/TRIM/ceros)"
set "T_MENU_04=[3]  Diagnóstico y salud de hardware          consulta sin modificar nada"
set "T_MENU_05=[4]  Consola de comandos                      CMD interactivo"
set "T_MENU_06=[5]  Ayuda y documentación técnica            manual y guía del técnico"
set "T_MENU_15=[6]  Herramientas y utilidades de terceros    sección en desarrollo"
set "T_MENU_16=[7]  Apagar o reiniciar el equipo"
set "T_MENU_07=Aviso: [1] y [2] modifican DISCOS de verdad y piden DOS confirmaciones"
set "T_MENU_08=seguidas con una tecla S/N. Las opciones [3] a [7] no tocan el hardware solas."
set "T_MENU_09=(Si la consola no reacciona a una sola tecla, teclea el número"
set "T_MENU_10=y termina con ENTER.)"
set "T_MENU_11=   Su opción [1-7]:  "
set "T_MENU_12=Fecha y hora:"
set "T_MENU_13=Modo de entrada:"
set "T_MENU_14=Firmware:"
set "T_TER_01=[6] HERRAMIENTAS Y UTILIDADES DE TERCEROS"
set "T_TER_02=En desarrollo: se integrarán herramientas portables en una próxima versión."
set "T_TER_03=  - Recuperación de datos: rescatar archivos de discos dañados o formateados."
set "T_TER_04=  - Gestión BCD: reparar o reconstruir el arranque de Windows."
set "T_TER_05=  - Análisis avanzado: clonado, particionado y diagnóstico de discos."
set "T_TER_06=De momento no se ejecuta ninguna herramienta: esta pantalla es solo informativa."
set "T_TER_07=   Su opción [A/M]:  "
set "T_LOG_01=Registro (log): PERSISTENTE en"
set "T_LOG_02=Registro (log): solo en RAM (se perdera al reiniciar):"
set "T_SAL_01=[7] APAGAR O REINICIAR EL EQUIPO"
set "T_SAL_02=[1]  Apagar el equipo"
set "T_SAL_03=[2]  Salir de la herramienta (en WinPE reinicia el equipo)"
set "T_SAL_04=[3]  Volver al menú principal (me he equivocado)"
set "T_SAL_05=   Su opción [1-3]:  "
set "T_SAL_06=!!!  ATENCIÓN  !!!"
set "T_SAL_07=Vas a apagar el equipo. Se interrumpirá cualquier trabajo en"
set "T_SAL_08=curso y, si arrancaste desde WinPE, terminará la sesión de"
set "T_SAL_09=recuperación actual (los cambios ya guardados en el arranque RAM"
set "T_SAL_10=no se conservan)."
set "T_SAL_11=   Confirmar apagado? [S/N]:  "
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
set "T_SEG_15=Para seguir tendrás que confirmar DOS veces con S (en inglés Y): N cancela."
set "T_SEG_16=Protección de arranque: ACTIVA (este disco NO es el de arranque)."
set "T_SEG_17=Protección de arranque: SIN VERIFICAR (podría ser el de arranque)."
set "T_SEG_18=Protección de arranque: no aplica (WinPE en memoria RAM)."
set "T_SEG_19=[!] El disco número"
set "T_SEG_20=no aparece en el listado de discos."
set "T_SEG_21=Puede ser que el número esté mal, o que tu Windows"
set "T_SEG_22=traduzca la salida de diskpart con otras palabras."
set "T_SEG_23=Si eliges 'Continuar' tendrás que confirmarlo con la tecla S."
exit /b 0

REM ---------------------------------------------------------------------
REM  IDIOMA_EN - ingles (%LANG%=EN).
REM  Mismos nombres de variable que el bloque anterior, uno a uno.
REM ---------------------------------------------------------------------
:IDIOMA_EN
set "T_AYU_01=[5] HELP AND TECHNICAL DOCUMENTATION"
set "T_AYU_02=Choose one section of the manual:"
set "T_AYU_03=  [1] Useful commands and tools available in WinPE"
set "T_AYU_04=  [2] Step-by-step guide: Option 1 (disks and partitions) and Option 2 (wipe)"
set "T_AYU_05=  [3] Navigation codes and quick shortcuts"
set "T_AYU_06=   Your option [1-3] (A = back, M = menu):  "
set "T_AYU_07=   [Enter] Continue   [A] Back   [M] Menu:  "
set "T_GUIA_01=[5] STEP-BY-STEP GUIDE - Page 1 of 2: Option 1 (disks and partitions)"
set "T_GUIA_02=OPTION 1 - DISK AND PARTITION OPERATIONS"
set "T_GUIA_03=1) Choose option [1] in the main menu."
set "T_GUIA_04=2) The physical disks are listed with diskpart (read only)."
set "T_GUIA_05=3) Type the disk NUMBER (Disk / Disco column)."
set "T_GUIA_06=4) Choose the scheme: GPT for UEFI, MBR for BIOS Legacy."
set "T_GUIA_07=5) Review the diskpart script shown on screen."
set "T_GUIA_08=6) Confirm TWICE with Y."
set "T_GUIA_09=7) clean, convert, create, format and assign are executed."
set "T_GUIA_10=8) At the end the machine is listed again to verify."
set "T_GUIA_11=PROTECTION: the running system disk and the WinPE boot disk"
set "T_GUIA_12=are blocked: the tool will not touch them."
set "T_GUIA_14=[5] STEP-BY-STEP GUIDE - Page 2 of 2: Option 2 and diagnostics"
set "T_GUIA_15=OPTION 2 - SECURE ERASE / SANITIZATION"
set "T_GUIA_16=Level [1] clean: wipes the partition table. The data stays"
set "T_GUIA_17=on the disk and can be recovered. It is the fastest level."
set "T_GUIA_18=Level [2] TRIM + clean: for SSD/NVMe. Frees the free blocks"
set "T_GUIA_19=and the controller wipes them. Unrecoverable data."
set "T_GUIA_20=A VM may not support TRIM: the tool warns and carries on"
set "T_GUIA_21=without breaking (it never fakes a success)."
set "T_GUIA_22=Level [3] clean all: zeros over the whole disk (hours); on HDD unrecoverable."
set "T_GUIA_23=DIAGNOSTICS (Section 3, read only)"
set "T_GUIA_24=[1] Inventory: CPU, RAM, motherboard and disks."
set "T_GUIA_25=[2] CHKDSK: checks a drive with /scan, /f or /f /r."
set "T_GUIA_26=[3] SMART: OK / Pre-fail status of the physical disks."
set "T_NAV_01=[5] NAVIGATION CODES AND QUICK SHORTCUTS"
set "T_NAV_02=NAVIGATION"
set "T_NAV_03=M      returns to the main menu (no pause)"
set "T_NAV_04=A      returns to the previous step (no pause)"
set "T_NAV_05=ENTER  cancels the input or goes back one step"
set "T_NAV_06=0      exit / cancel in the submenus that show it"
set "T_NAV_07=1-7    choose an option in the main menu"
set "T_NAV_08=CONFIRMATIONS"
set "T_NAV_09=Destructive operations ask for TWO confirmations: the first"
set "T_NAV_10=Y/N question and then the SAFETY question."
set "T_NAV_11=Only the Y key confirms; any other key cancels."
set "T_NAV_12=SECURITY"
set "T_NAV_13=The running system disk and the WinPE boot disk are protected:"
set "T_NAV_14=they cannot be prepared or wiped."
set "T_AYU1_01=[5] SYSTEM HELP - Page 1 of 2: disks and storage"
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
set "T_AYU1_33=Continues to page 2 of the help..."
set "T_AYU2_01=[5] SYSTEM HELP - Page 2 of 2: system, network and tools"
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
set "T_AYU2_28=If a command is missing, it is not there: try it in option 4."
set "T_AYU2_29=- Before formatting a disk, check its SMART status with the"
set "T_AYU2_30=command above: a disk with 'Pred Fail' does not deserve a new"
set "T_AYU2_31=install (the work would be lost in weeks, not in years)."
set "T_AYU2_32=   Show the list of commands available in this image? [Y/N]:  "
set "T_AYU2_33=--- NATIVE CMD AND WINPE COMMANDS (use the mouse wheel to scroll) ---"
set "T_AYU3_01=End of the command list for this image."
set "T_AYU3_02=DISK AND BOOT"
set "T_AYU3_03=diskpart                  list / select / clean / convert"
set "T_AYU3_04=wmic diskdrive get status . SMART status (OK or Pred Fail)"
set "T_AYU3_05=chkdsk X: /f /r           repairs and scans bad sectors"
set "T_AYU3_06=bootrec /fixmbr /fixboot  repair bootloader (MBR/Boot)"
set "T_AYU3_07=bcdboot C:\\Windows /s S: writes the boot manager"
set "T_AYU3_08=dism /image:C:\\ /add-driver  injects drivers into Windows"
set "T_AYU3_09=SYSTEM AND NETWORK"
set "T_AYU3_10=systeminfo / ipconfig /all   system and network info"
set "T_AYU3_11=ping / nslookup / netstat -an  connectivity and ports"
set "T_AYU3_12=reg load-add-unload           edit the offline registry"
set "T_AYU3_13=NATIVE CMD COMMANDS (built-in)"
set "T_AYU3_14=dir copy move del type ren md rd ver set exit cls"
set "T_BIEN_01=Welcome, technician."
set "T_BIEN_02=This tool brings together the workshop's most common"
set "T_BIEN_03=operations to service Windows machines and prepare disks"
set "T_BIEN_04=in a fast, repeatable and surprise-free way."
set "T_BIEN_05=GOLDEN RULES before touching any disk:"
set "T_BIEN_06=1. ALWAYS identify the right disk before erasing anything."
set "T_BIEN_07=Options 1 and 2 list the disks before asking."
set "T_BIEN_08=2. Options 1 and 2 are DESTRUCTIVE: they erase the partition"
set "T_BIEN_09=table (and in option 2, all the data on the disk)."
set "T_BIEN_10=None of them acts unless you confirm TWICE in a row (Y/N)."
set "T_BIEN_11=3. When in doubt, read option 5 (Help) first and do not"
set "T_BIEN_12=improvise with commands you do not know."
set "T_BIEN_13=How to use it: type the number of the option shown in the"
set "T_BIEN_14=menu. Depending on the environment the key alone or ENTER will do."
set "T_BIEN_15=Press any key to enter the main menu..."
set "T_CFM_01=[i] Confirmation not recognised: NOTHING has been executed."
set "T_CFM_02=   Confirm operation? [Y/N]:  "
set "T_CFM_03=Attention: Are you completely sure you want to run this action? [Y/N]: "
set "T_CFM_04=SUMMARY OF THE COMMANDS ABOUT TO BE RUN"
set "T_CFM_05=STEP 2 of 2 - type 'Y' and press ENTER to run; 'N' or any other key cancels."
set "T_CFM_06=No script generated yet: the commands are in the summary above."
set "T_COM_01=[!] Invalid input. Use only one of the options shown."
set "T_COM_02=[!] Invalid input: enter ONLY the disk number (for"
set "T_COM_03=example: 0, 1, 2, 10), no leading zeros; A goes one step"
set "T_COM_04=back and M to the main menu."
set "T_COM_05=[!] This console does NOT seem to have administrator rights."
set "T_COM_06=diskpart will be able to list the disks, but NOT to modify them"
set "T_COM_07=(it will return access denied on 'clean')."
set "T_COM_08=   Continue anyway? [Y/N]:  "
set "T_COM_09=[!] I could not create working files in:"
set "T_COM_10=Without a writable folder I cannot build the diskpart"
set "T_COM_11=script, and without a script nothing runs. WE ABORT without"
set "T_COM_12=touching any disk (safety first)."
set "T_COM_13=[!] I cannot find diskpart.exe in this image."
set "T_COM_14=Is it a very trimmed WinPE? This module cannot continue."
set "T_COM_15=Type the disk NUMBER you want to work on."
set "T_COM_16=That number is the FIRST column of the listing above"
set "T_COM_17=(Disk 0, Disk 1...). It is never a drive letter."
set "T_COM_18=Back to the main menu with M; one step back with A (or ENTER)."
set "T_COM_19=   Disk number (A = back, M = menu):  "
set "T_COM_24=   What do we do? [1=Fix / 2=Continue / 3=Cancel]:  "
set "T_COM_25=FINAL CHECK: this is the CURRENT state of the machine."
set "T_COM_26=[Help] How to check the result:"
set "T_COM_27=in 'list volume', a SISTEMA volume in NTFS with its letter."
set "T_COM_28=(with no partitions or volumes). That is correct."
set "T_COM_29=- If the disk does not show the expected result, check the"
set "T_COM_30=warning diskpart gave before repeating any operation."
set "T_COM_31=Reading the machine disks with diskpart (read only)..."
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
set "T_COM_52=   Received: "
set "T_COM_53=Direct keys: M = main menu, S = confirm if the number is already correct (no ENTER)."
set "T_COM_54=      [C] Continue       [M] Main menu"
set "T_COM_55=   Type your choice:  "
set "T_COM_56= [A] Previous step   ^|   [M] Main menu (Press Enter)"
set "T_COM_57=[i] Going back to the previous step."
set "T_CONS_01=[4] ADVANCED CONSOLE"
set "T_CONS_02=Opening an interactive CMD console in the SAME window."
set "T_CONS_03=- Type 'exit' to return to the main menu."
set "T_CONS_04=- You inherit the current environment (work drive, variables)."
set "T_CONS_05=- NOTE: any variable change you make does NOT affect the menu."
set "T_CONS_06=Remember: look first, act later. For disks:"
set "T_CONS_07=diskpart  -^>  list disk  -^>  detail disk  -^>  exit"
set "T_D1_01=[1] DISK AND PARTITION OPERATIONS"
set "T_D1_09=Command order:"
set "T_D1_10=  1) clean"
set "T_D1_11=  2) convert gpt / mbr (GPT on UEFI, MBR on Legacy)"
set "T_D1_12=REMEMBER: 'clean' erases the partition table of the chosen disk."
set "T_D1_13=Everything on it stops being visible immediately."
set "T_D1_14=Next: the disk listing is loaded with diskpart (read only)..."
set "T_D1_15=[1] DISK AND PARTITION OPERATIONS - SUMMARY AND CONFIRMATION"
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
set "T_D1_27=  3) create partition primary"
set "T_D1_28=  4) format fs=ntfs quick label=SISTEMA"
set "T_D1_29=  5) assign (free letter chosen by Windows)"
set "T_D2_01=[2] SECURE ERASE / SANITIZATION"
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
set "T_D2_32=Before running it asks for TWO confirmations (Y/N) in a row."
set "T_D2_33=- Secure erase (option 2): Disk"
set "T_D2_34=here. The boot protection blocks the system disk when it"
set "T_D2_35=will appear RAW"
set "T_NIV_01=Choose the erase level ([0] or M to return to the menu):"
set "T_NIV_02=  [1] Quick clean (Structure only)"
set "T_NIV_03=      Deletes only the partition table (MBR/GPT) and the disk"
set "T_NIV_04=      signature: instant, with zero wear on storage cells."
set "T_NIV_05=  [2] SSD / NVMe reset (TRIM / Deallocate optimization)"
set "T_NIV_06=      Formats a temporary volume and forces massive TRIM:"
set "T_NIV_07=      the controller wipes the blocks (GC), fast and no zeros."
set "T_NIV_08=  [3] Deep clean / Zero overwrite (HDDs only)"
set "T_NIV_09=      'clean all': overwrites EVERY sector with zeros."
set "T_NIV_10=      Slow. NOT recommended on SSD or NVMe (NAND wear)."
set "T_NIV_11=  [0] Exit / Cancel"
set "T_NIV_12=   Your level [0-3]:  "
set "T_NIV_13=Action:         clean     (structure only, no overwrite)"
set "T_NIV_14=Action:         TRIM + clean  (SSD/NVMe reset, no zeros)"
set "T_NIV_15=Duration:       instant (no sector overwrite)"
set "T_NIV_16=Duration:       seconds (TRIM + structure clean)"
set "T_NIV_17=- NO sector is overwritten with zeros at this level."
set "T_NIV_18=- Previous data becomes invisible to the system, but this"
set "T_NIV_19=  does not repair disks with physical faults."
set "T_NIV_20=- Controller-level TRIM DOES destroy block-level data"
set "T_NIV_21=  recovery: the controller recycles the freed cells"
set "T_NIV_40=  (Garbage Collection) without writing zeros, so it is"
set "T_NIV_41=  fast, safe and causes no cell wear (TBW)."
set "T_NIV_42=TRIM applied only to part of the volumes. Failure detail:"
set "T_NIV_43=[i] TRIM not applicable here (virtual disk or no support from"
set "T_NIV_44=the hypervisor): the step is SKIPPED and the clean continues."
set "T_NIV_45=[i] Volume without a drive letter: -DriveLetter not possible, skipped."
set "T_NIV_22=[!] PowerShell not available: the TRIM step will be skipped"
set "T_NIV_23=and only the structure clean will run (like level [1])."
set "T_NIV_24=- This disk is an HDD: TRIM will not apply; structure clean"
set "T_NIV_25=  only. To overwrite content use level [3]."
set "T_NIV_26=[CRITICAL WARNING] This option overwrites every sector of the disk with zeros."
set "T_NIV_27=It is designed exclusively for mechanical hard drives (HDD). NOT"
set "T_NIV_28=RECOMMENDED on SSD or NVMe units as it shortens their useful life"
set "T_NIV_29=severely through NAND cell wear."
set "T_NIV_30=[i] This disk is SSD/NVMe: consider level [2] before proceeding."
set "T_NIV_31=TRIM completed: free blocks deallocated (ReTrim)."
set "T_NIV_32=TRIM: the disk exposes no volumes; nothing to deallocate."
set "T_NIV_33=TRIM not completed. PowerShell exit code:"
set "T_NIV_34=PowerShell not available: TRIM skipped (structure clean only)."
set "T_NIV_35=PowerShell output:"
set "T_NIV_36=Sending TRIM / Deallocate orders to Disk"
set "T_NIV_37=PHASE 1/3  diskpart: creates a temporary volume and formats it"
set "T_NIV_38=PHASE 2/3  PowerShell: issues TRIM / Deallocate on the volumes"
set "T_NIV_39=PHASE 3/3  diskpart: final 'clean', leaves the disk RAW"
set "T_EST_01=WARNING: ESTIMATED TIME FOR THE SECURE ERASE (clean all)"
set "T_EST_02=Disk number"
set "T_EST_03=Actual size detected:"
set "T_EST_04=Disk type:"
set "T_EST_05=GB"
set "T_EST_06=HDD (mechanical hard drive)"
set "T_EST_07=SSD (solid state drive)"
set "T_EST_08=undetermined"
set "T_EST_09=Estimated time:"
set "T_EST_10=from"
set "T_EST_11=to"
set "T_EST_12=h"
set "T_EST_13=min"
set "T_EST_14=ROUGH figure: it depends on the disk, the bus (USB/SATA) and its health."
set "T_EST_15=Do NOT interrupt the process once started (no keys, no reboot)."
set "T_EST_16=On SSD the physical erase is NOT guaranteed (see the warnings)."
set "T_EST_17=Size not readable: the reference table below is used."
set "T_INV_01=[3] DIAGNOSTICS / INVENTORY - READ ONLY"
set "T_INV_02=This module does NOT modify disks or partitions: it only reports."
set "T_INV_03=MACHINE AND SYSTEM"
set "T_INV_04=PROCESSOR"
set "T_INV_05=RAM MEMORY (total / available / modules)"
set "T_INV_06=MOTHERBOARD"
set "T_INV_07=PHYSICAL DISKS (index, size and status)"
set "T_INV_08=Disk models:"
set "T_INV_09=Press any key to return to the menu..."
set "T_INV_10=[i] Data not available in this image (command missing)."
set "T_INV_11=Total:"
set "T_INV_12=Available:"
set "T_INV_13=Logical processors:"
set "T_INV_14=System (ver):"
set "T_INV_15=MB"
set "T_INV_16=GB"
set "T_INV_17=Not readable here: try 'systeminfo' in the Console (option 4)."
set "T_INV_18=Populated slots:"
set "T_INV_19=Detail per module (slot / size / speed):"
set "T_INV_20=MHz"
set "T_DIAG_01=[3] HARDWARE DIAGNOSTICS AND HEALTH"
set "T_DIAG_02=Inspects the machine and lets you check its drives (chkdsk, SMART)."
set "T_DIAG_03=  [1] Full hardware           CPU, RAM, motherboard and disks"
set "T_DIAG_04=  [2] Check a drive           chkdsk: /scan, /f or /f /r"
set "T_DIAG_05=  [3] SMART health            OK / Pre-fail status of the disks"
set "T_DIAG_07=   Your option [1-3] (A = back, M = menu):  "
set "T_DIAG_08=End of the hardware inventory."
set "T_DIAG_10=[2] CHKDSK - CHECK A DRIVE"
set "T_DIAG_11=Checks the drive you choose; it does not delete files."
set "T_DIAG_12=Do not use X: (WinPE RAM drive)."
set "T_DIAG_13=The letter must be a mounted drive (C:, D:, E:...)."
set "T_DIAG_14=   Drive letter (e.g. C) (A = back, M = menu):  "
set "T_DIAG_15=Selected drive:"
set "T_DIAG_16=  [1] Quick scan (/scan)          does not dismount the drive"
set "T_DIAG_17=  [2] Repair errors (/f)          may ask for a restart"
set "T_DIAG_18=  [3] Repair + sectors (/f /r)    very slow, for HDD"
set "T_DIAG_19=  [0] Previous step: pick ANOTHER letter"
set "T_DIAG_20=   Mode [0-3] (A = back, M = menu):  "
set "T_DIAG_21=   Run chkdsk with these options? [Y/N]:  "
set "T_DIAG_22=Command:"
set "T_DIAG_23=Running chkdsk. Do not close the window or power off the machine..."
set "T_DIAG_24=[OK] chkdsk finished with no errors (code 0)."
set "T_DIAG_25=[OK] chkdsk found and fixed errors (code 1)."
set "T_DIAG_26=[!] chkdsk asks for extra cleanup (code 2)."
set "T_DIAG_27=[!] chkdsk could not check the drive (code 3)."
set "T_DIAG_28=[i] chkdsk exit code:"
set "T_DIAG_29=End of the check."
set "T_DIAG_30=[!] Invalid letter: type ONE drive letter (A-Z)."
set "T_DIAG_31=[!] X: is the WinPE RAM drive: chkdsk is not run on it."
set "T_DIAG_32=[!] The drive does not exist or is not mounted:"
set "T_DIAG_33=Check cancelled: chkdsk was not run."
set "T_DIAG_34=End of the check."
set "T_DIAG_35=Logical drives found (letter, label, FS, total, free, disk):"
set "T_DIAG_36=Note: X: is the WinPE RAM drive; do not run chkdsk on it."
set "T_DIAG_37=[!] I cannot find chkdsk.exe in this image."
set "T_DIAG_40=[3] SMART HEALTH OF THE DISKS"
set "T_DIAG_41=Checking SMART status and overall disk health..."
set "T_DIAG_42=[OK] All disks report a healthy status."
set "T_DIAG_43=[!] WARNING: a disk has a SMART alert (Pre-fail/Warning). Back up the data."
set "T_DIAG_44=[i] SMART status cannot be read in this image."
set "T_DIAG_45=End of the SMART check."
set "T_DIAG_46=Format: [index] model (type) health / status size"
set "T_MED_01=DISK TYPE NOT DETECTED"
set "T_MED_02=I could not tell whether Disk"
set "T_MED_03=is an HDD (mechanical) or an SSD (solid):"
set "T_MED_04=   What type of disk is it? [1=HDD / 2=SSD]:  "
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
set "T_MENU_02=[1]  Disk and partition operations            wipe table and format"
set "T_MENU_03=[2]  Sanitization and secure erase            3 levels (structure/TRIM/zeros)"
set "T_MENU_04=[3]  Hardware diagnostics and health          read-only machine info"
set "T_MENU_05=[4]  Command console                          interactive CMD"
set "T_MENU_06=[5]  Help and technical documentation         manual and technician guide"
set "T_MENU_15=[6]  Third-party tools and utilities          work in progress"
set "T_MENU_16=[7]  Shut down or restart the computer"
set "T_MENU_07=Warning: [1] and [2] really modify DISKS and ask for TWO"
set "T_MENU_08=confirmations in a row with a single key (Y/N). Options [3] to [7] touch no hardware alone."
set "T_MENU_09=(If the console does not react to a single key, type the number"
set "T_MENU_10=and finish with ENTER.)"
set "T_MENU_11=   Your option [1-7]:  "
set "T_MENU_12=Date and time:"
set "T_MENU_13=Input mode:"
set "T_MENU_14=Firmware:"
set "T_TER_01=[6] THIRD-PARTY TOOLS AND UTILITIES"
set "T_TER_02=Work in progress: portable tools will be integrated in a future version."
set "T_TER_03=  - Data recovery: rescue files from damaged or formatted disks."
set "T_TER_04=  - BCD management: repair or rebuild the Windows boot."
set "T_TER_05=  - Advanced analysis: cloning, partitioning and disk diagnostics."
set "T_TER_06=No tool is executed yet: this screen is informative only."
set "T_TER_07=   Your option [A/M]:  "
set "T_LOG_01=Activity log: PERSISTENT at"
set "T_LOG_02=Activity log: RAM only (lost on reboot):"
set "T_SAL_01=[7] SHUT DOWN OR RESTART THE COMPUTER"
set "T_SAL_02=[1]  Shut down the computer"
set "T_SAL_03=[2]  Exit the tool (in WinPE it restarts the computer)"
set "T_SAL_04=[3]  Return to the main menu (my mistake)"
set "T_SAL_05=   Your option [1-3]:  "
set "T_SAL_06=!!!  WARNING  !!!"
set "T_SAL_07=You are about to shut down the computer. Any work in progress"
set "T_SAL_08=will be interrupted and, if you booted from WinPE, the current"
set "T_SAL_09=recovery session will end (changes already saved in the RAM boot"
set "T_SAL_10=are not kept)."
set "T_SAL_11=   Confirm shutdown? [Y/N]:  "
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
set "T_SEG_15=To continue you will have to confirm TWICE with the Y key: N cancels."
set "T_SEG_16=Boot protection: ACTIVE (this disk is NOT the boot disk)."
set "T_SEG_17=Boot protection: UNVERIFIED (it might be the boot disk)."
set "T_SEG_18=Boot protection: not applicable (WinPE in RAM memory)."
set "T_SEG_19=[!] Disk number"
set "T_SEG_20=does not appear in the disk listing."
set "T_SEG_21=The number may be wrong, or your Windows"
set "T_SEG_22=translates the diskpart output with different words."
set "T_SEG_23=If you pick 'Continue' you will have to confirm with the Y key."
exit /b 0
