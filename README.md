# JAH-WinPe · Herramienta de soporte técnico en consola

**🌐 Idioma / Language:** **Español** · [English](README.en.md)

> *Nota de mantenimiento:* si editas este documento, actualiza también la
> versión en inglés (`README.en.md`) para que no se desincronicen.

Utilidad de línea de comandos (Batch) para el técnico de un taller de IT.
Reúne las operaciones más habituales sobre equipos Windows en una interfaz
de consola simple, repetible y "a prueba de errores de tecleo".

Funciona **tanto en Windows completo como en Windows PE** (entorno de
recuperación que arranca desde USB/ISO). No requiere instalación ni
dependencias externas: solo el archivo `src/menu.bat`.

Desde la **Fase 3** el proyecto además **se compila como ISO arrancable**
(UEFI x64 + BIOS Legacy) con **arranque automático** de la herramienta; ver
[`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).

```
+--------------------------------------------------------------+
|   Elige idioma / Choose language:  [1] Español   [2] English |
+--------------------------------------------------------------+
|   JAH-WinPe  -  Herramienta de Soporte Técnico               |
|   Versión 1.0.0  -  Entorno: Windows / WinPE                 |
+--------------------------------------------------------------+
|   [1]  Operaciones sobre discos y particiones                |
|   [2]  Sanitización y borrado seguro                         |
|   [3]  Diagnóstico y salud de hardware                       |
|   [4]  Consola de comandos                                   |
|   [5]  Ayuda y documentación técnica                         |
|   [6]  Herramientas y utilidades de terceros                 |
|   [7]  Apagar o reiniciar el equipo                          |
+--------------------------------------------------------------+
|   Firmware: UEFI  ->  GPT     |   Log: persistente / RAM     |
+--------------------------------------------------------------+
```

---

## Estado del proyecto

> **Versión actual del ejecutable:** `1.0.0`. El menú principal tiene **7
> opciones**; la opción **[6]** es un contenedor informativo de herramientas
> de terceros, todavía en desarrollo. La tabla siguiente conserva el
> histórico de fases funcionales.

| Fase | Contenido | Estado |
|------|-----------|--------|
| **1** | Interfaz: bienvenida, menú, ayuda, consola de comandos, apagado | ✅ Completada |
| **2** | Módulos de disco con `diskpart`: preparación y borrado seguro | ✅ Completada |
| **2.5** | Interfaz **multilenguaje** (Español / English) + README bilingüe | ✅ Completada |
| **2.8** | **Escudo de seguridad**: bloqueo del disco de arranque + doble confirmación S/N | ✅ Completada |
| **3** | **Entorno WinPE**: arranque automático (`startnet.cmd`) + **ISO arrancable** doble (UEFI/BIOS) | ✅ Completada |
| **4** | **Firmware UEFI/Legacy** (esquema GPT/MBR automático) + **registro de actividad** (`jah-winpe.log`) | ✅ Completada |
| **4.5** | **Diagnóstico** de hardware (RAM, discos, SMART y `chkdsk`) + **estimación de tiempo** del borrado | ✅ Completada |
| **5** | Más idiomas; recordar el idioma; integrar herramientas portables de terceros (opción 6) | ⏳ Pendiente |

> **Importante:** las opciones **[1]** y **[2]** ejecutan operaciones
> **destructivas reales** sobre el disco elegido. Ninguna actúa sin una
> **doble confirmación S/N**: primero la pregunta de confirmación y, tras
> mostrar el resumen, la pregunta de seguridad. Solo `S` (o `Y` en English)
> continúa; `N`, `SI`, `YES`, Enter o cualquier otra respuesta cancela. Antes
> de confirmar, el programa **muestra el guion de `diskpart`** e **identifica
> automáticamente el disco de arranque**: si eliges ese disco, la operación
> se **bloquea** y no se genera ningún guion.
>
> Si solo quieres mirar el equipo, usa **[3] Diagnóstico y salud de
> hardware**: incluye inventario de solo lectura, comprobación de unidades
> con `chkdsk` y consulta SMART.
>
> Desde la **Fase 4**, el programa **detecta el firmware** (UEFI o BIOS
> Legacy) y elige solo el esquema de particionado correcto (**GPT** en UEFI,
> **MBR** en Legacy). Si no puede verificar el firmware, **no adivina**:
> pregunta al técnico qué esquema aplicar. Cada operación relevante queda
> anotada con fecha y hora en un **registro de actividad** (`jah-winpe.log`)
> que, cuando existe un disco persistente conectado, sobrevive al reinicio.
>
> Desde la **Fase 4.5**, antes de un `clean all` (nivel [3] de la opción [2])
> el programa **lee el tamaño real del disco** y muestra una **estimación
> orientativa del tiempo** de borrado (según sea HDD o SSD y su capacidad) en
> un aviso amarillo, **antes** de la doble confirmación.

---

## Requisitos

- **Windows 10/11** o **WinPE** (imagen creada con Windows ADK 10/11).
- **Sin instalación**: basta copiar `src\menu.bat` a la carpeta o USB de
  trabajo (o arrancar la ISO generada en la Fase 3).
- **Permisos de administrador** para las operaciones de disco
  (en WinPE se ejecuta ya con privilegios de SYSTEM).
- Solo para **compilar la ISO** (no para usarla): Windows ADK + complemento
  WinPE. Detalles en [`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).
- El script de compilación añade automáticamente los componentes
  **WinPE-WMI**, **WinPE-Scripting**, **WinPE-NetFx**,
  **WinPE-PowerShell** y **WinPE-StorageWMI**. Son necesarios para el
  inventario, la salud SMART y el listado de volúmenes con PowerShell.
- Opcional: `choice.exe` en `%SystemRoot%\System32`.
  Si no existe (algunas imágenes WinPE minimalistas), el script detecta la
  ausencia y usa automáticamente su respaldo con `set /p` + lista blanca.

---

## Uso rápido

1. Copia `src\menu.bat` a la raíz de tu carpeta de trabajo o del USB de
   arranque. También puedes generar la **ISO arrancable** (ver más abajo).
2. Ejecútalo:
   - Doble clic sobre `src\menu.bat`, o
   - desde una consola: `src\menu.bat`
3. **Elige idioma** en la primera pantalla (`[1] Español` / `[2] English`).
   Si no eliges, el programa continúa en Español.
4. Muévete por los menús tecleando el número de la opción
   (si tu consola no reacciona a una sola tecla, termina con `ENTER`).
5. Desde **[4] Consola de comandos** puedes ejecutar cualquier comando;
   escribe `exit` para volver al menú principal.
6. **[6] Herramientas y utilidades de terceros** es por ahora una pantalla
   informativa; **[7]** apaga el equipo o sale de la herramienta.

### Compilar la ISO arrancable (Fase 3)

Si quieres un medio de rescate **arrancable** (en lugar de copiar
`src\menu.bat` a mano), compila la ISO desde un equipo Windows **como
Administrador**:

```bat
build\build_iso.bat
```

Genera `JAH-WinPe.iso` con arranque **UEFI x64 + BIOS Legacy** y
`menu.bat` integrado: al arrancar de la ISO, el menú **aparece solo**.
Los requisitos (Windows ADK + complemento WinPE), los parámetros del script
y las instrucciones para **probarla en QEMU** están en
[`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).

---

## Opciones del menú

| Opción | Nombre | Qué hace | Estado |
|--------|--------|----------|--------|
| `[1]` | Operaciones sobre discos y particiones | `clean` + `convert gpt/mbr` + partición primaria NTFS (`SISTEMA`) + letra; módulo guiado con protección de arranque | Operativa |
| `[2]` | Sanitización y borrado seguro | Tres niveles: estructura (`clean`), TRIM/Deallocate para SSD/NVMe y ceros (`clean all`) para HDD; doble confirmación y estimación previa | Operativa |
| `[3]` | Diagnóstico y salud de hardware | Submenú: inventario (CPU/RAM/placa/discos), `chkdsk` por unidad y salud SMART | Operativa |
| `[4]` | Consola de comandos | `cmd` interactivo; `exit` vuelve al menú | Operativa |
| `[5]` | Ayuda y documentación técnica | Tres apartados (comandos, guía paso a paso y navegación) con paginación Enter/A/M | Operativa |
| `[6]` | Herramientas y utilidades de terceros | Contenedor informativo; se integrarán recuperación de datos, gestión BCD y análisis avanzado | En desarrollo |
| `[7]` | Apagar o reiniciar el equipo | Apagar o salir de la herramienta (en WinPE reinicia) con confirmación | Operativa |

### Diagnóstico, salud y estimación

La opción **[3]** abre un submenú de diagnóstico para revisar el equipo:

- **[1] Hardware completo:** sistema operativo y modelo, CPU (núcleos
  físicos y lógicos), RAM total y disponible, placa base y discos físicos con
  tamaño y estado. Usa PowerShell/WMI y cae a `wmic` o `diskpart` si faltan.
- **[2] Comprobar unidad:** pide una letra real, muestra el comando y permite
  `chkdsk /scan`, `/f` o `/f /r`. Nunca se ejecuta sobre `X:` (RAM de WinPE).
- **[3] Salud SMART:** consulta `Get-PhysicalDisk`, `Win32_DiskDrive` y
  `MSStorageDriver_FailurePredictStatus`; muestra OK, Pre-fail o “sin datos”
  y avisa si el disco está en riesgo.

El inventario no escribe nada. `chkdsk /f` y `/f /r` sí pueden reparar la
unidad, por eso piden confirmación S/N antes de ejecutarse. La consulta SMART
es ligera y no modifica el disco.

En la opción **[2]** hay **tres niveles** de borrado: `[1]` estructura,
`[2]` TRIM/Deallocate para SSD/NVMe y `[3]` ceros (`clean all`) para HDD.
Antes del nivel [3] el programa lee el **tamaño real** del disco e intenta
saber si es **HDD o SSD**; si no puede, **pregunta**. Muestra un **aviso
amarillo** con un rango de tiempo **orientativo** (`de X a Y`), recordando
que depende del bus (USB/SATA) y del estado del disco.

---

## Idioma de la interfaz (Español / English)

Al arrancar, el programa muestra una pantalla de selección de idioma:

```
  Selecciona el idioma / Select the language:

     [1]  Español
     [2]  English
```

- Todo el **texto visible** (menús, ayuda, avisos y confirmaciones) cambia de
  idioma. Los **comentarios del código** se quedan en Español: son
  documentación del proyecto, no interfaz.
- La **lógica es única**: los módulos de disco, las validaciones y las
  confirmaciones se ejecutan exactamente igual en los dos idiomas (solo
  cambia el texto). Traducir no puede introducir diferencias de
  comportamiento.
- El idioma **no se recuerda** entre ejecuciones: se pregunta siempre. Es
  intencionado (un USB de taller lo usan varias personas).
- Para **añadir o corregir textos**, edita el bloque `:IDIOMA_ES` o
  `:IDIOMA_EN` al final de `src/menu.bat` (ver "Notas técnicas", punto 12).

---

## Cómo funcionan las opciones de disco (diseño)

`diskpart` no atiende al teclado cuando trabaja con un guion: recibe una
**lista de comandos** en un fichero de texto (`diskpart /s guion.txt`) y los
ejecuta en orden. `src\menu.bat` aprovecha eso y hace lo siguiente, siempre
igual:

1. **Lista** los discos con `list disk` y `list volume` (solo lectura) y
   muestra el resultado en pantalla.
2. **Pide el número de disco** y lo valida carácter a carácter (solo
   dígitos, sin ceros a la izquierda). Además intenta contrastarlo con el
   listado y, si no puede confirmarlo, te pregunta en lugar de suponer.
3. **Genera el guion** en la carpeta temporal del sistema (`_jah_diskpart.txt`).
4. **Muestra el guion en pantalla** para que lo leas antes de ejecutarlo.
5. **Pide dos confirmaciones S/N**: primero la pregunta de confirmación y,
   tras mostrar el resumen, la pregunta de seguridad. Solo `S` (o `Y` en
   English) continúa; `N`, `SI`, `YES`, Enter o cualquier otra respuesta
   cancela. Si el escudo no pudo verificar qué disco está protegido, muestra
   antes un aviso amarillo de riesgo.
6. **Ejecuta** `diskpart /s` sin capturar la salida, para que veas el avance
   (el nivel de ceros `clean all` puede tardar horas).
7. **Verifica** volviendo a listar discos y volúmenes.
8. **Borra los ficheros temporales** (incluido el guion: no dejamos por ahí
   una "receta de borrado" reutilizable por error).

Ventajas: cero errores de tecleo en el momento crítico, trazabilidad de lo
que se ha ejecutado y resultados repetibles.

### Límite conocido (honestidad técnica)

`diskpart` traduce sus mensajes al idioma del sistema (en español los discos
aparecen como `Disco 0`, no `Disk 0`). La comprobación automática del
listado reconoce las dos formas y, si no encuentra ninguna, **pregunta al
técnico** en vez de decidir. Asimismo, si el texto nativo de `diskpart` se
viera con caracteres raros en la consola, puede corregirse con
`chcp 850` (y `chcp 65001` para volver al UTF-8 del menú).

---

## Estructura del repositorio

```
JAH-WinPe/
├─ src/             Contenido que entra en la imagen WinPE
│  ├─ menu.bat      Interfaz principal del taller (Batch, comentado).
│  │                Incluye, al final, los dos diccionarios de idioma
│  │                (:IDIOMA_ES y :IDIOMA_EN). En ejecución genera, junto
│  │                a sí mismo, el registro de actividad 'jah-winpe.log'.
│  └─ startnet.cmd  Arranque automático dentro de WinPE (Fase 3):
│                   wpeinit + búsqueda de menu.bat + lanzamiento.
├─ build/           Utilidades de construcción (no van al ISO)
│  ├─ build_iso.ps1 Compila la ISO con el ADK (oscdimg + DISM).
│  ├─ build_iso.bat Lanzador cómodo (comprueba admin y llama al .ps1).
│  └─ work/         (generado) soporte WinPE + punto de montaje.
├─ docs/            Documentación técnica
│  └─ BUILD_GUIDE.md Arquitectura de arranque WinPE + pruebas con QEMU.
├─ README.md        Documentación (Español, por defecto)
├─ README.en.md     Documentación (English)
├─ .gitignore       Qué NO debe versionarse (basura, imágenes, logs…)
└─ .gitattributes   Fuerza CRLF en .bat/.cmd/.ps1 (clave para cmd.exe)
```

> **¿Por qué los README siguen en la raíz?** GitHub solo renderiza como
> portada el `README.md` de la raíz; la documentación **técnica** (esta
> guía de construcción) sí vive en `docs/`.

> **¿Quieres otro idioma por defecto?** GitHub renderiza siempre
> `README.md`. Si prefieres que el inglés sea el principal, renombra
> `README.en.md` → `README.md` y este archivo → `README.es.md`
> (y actualiza los enlaces del encabezado).

---

## Notas técnicas (leer antes de editar)

Estas convenciones están explicadas en detalle dentro de `src\menu.bat`:

1. **Codificación: UTF-8 SIN BOM.** El script ejecuta `chcp 65001` para que
   los acentos se vean bien. Nunca guardes el `.bat` con BOM: rompería la
   primera línea. *Fallback documentado:* si vieras caracteres raros, guarda
   el archivo en ANSI (Windows-1252) y comenta la línea `chcp`.
2. **Finales de línea CRLF** (fijados en `.gitattributes`). `cmd.exe` es
   sensible a esto; no dejemos que Git convierta los `.bat` a LF.
3. **Comentarios con `REM`, nunca con `::`.** `::` es una etiqueta vacía que
   se rompe dentro de bloques `( ... )`.
4. **Cuidado con `>` en comentarios y textos.** `cmd.exe` procesa la
   redirección antes de saber que la línea es un comentario: un `>` "suelto"
   crea archivos basura. Por eso las flechas se escriben **`-^>`**
   (el caret neutraliza el `>`; en pantalla se ve igual: `->`).
5. **Etiquetas y variables en ASCII**; el texto visible sí lleva acentos.
6. **Menús solo con dígitos `1..N`.** Así el índice que devuelve `choice`
   coincide con el dígito elegido y no hace falta expansion retrasada.
7. **Sin `DelayedExpansion` y sin bloques `( )`** para despachar el menú:
   menos superficie de error en el parser de batch.
8. **Captura de entrada centralizada** en la subrutina `:LEER_OPCION`
   (`choice.exe` si existe; si no, `set /p` con lista blanca y saneado).
9. **Números de disco: subrutina propia** `:LEER_NUMERO`, que valida
   dígito a dígito (no se puede usar `choice` porque el número no es una
   lista cerrada). La letra `A` cancela.
10. **Guiones de `diskpart` en ficheros temporales.** Se escriben con
    `echo` (`_jah_diskpart.txt`), se muestran antes de ejecutar y se borran
    al terminar. En las líneas que se escriben hacia el fichero no puede
    haber símbolos de redirección, porque `cmd.exe` los interpretaría.
11. **Antes de toda acción destructiva** hay que superar **dos
    confirmaciones S/N**: la primera pregunta y, tras el resumen, la pregunta
    de seguridad. Solo `S` (o `Y` en English) continúa; `N`, `SI`, `YES`,
    Enter o cualquier otra entrada cancela. Si no se pudo verificar el disco
    de arranque, se muestra antes un aviso de riesgo y se aplica la misma
    doble confirmación.
12. **Multilenguaje (i18n) con diccionarios de variables.** No hay ficheros
    de traducción: el idioma se resuelve con **dos bloques de variables de
    texto** (`:IDIOMA_ES` y `:IDIOMA_EN`) que definen **los mismos nombres**
    (`T_MENU_01`, `T_D2_21`…) con distinto valor. Al arrancar, la subrutina
    `:CARGAR_IDIOMA` ejecuta el bloque del idioma activo mediante una
    **etiqueta construida al vuelo** (`goto IDIOMA_%LANG%`), y a partir de
    ahí todo el programa imprime `%T_xxx%`. La lógica no se duplica: si un
    texto nuevo falta en un idioma, solo sale en blanco ahí. Al editar los
    bloques, recuerda que **no pueden contener** comillas dobles `"` ni el
    signo `%` dentro del valor, y que las flechas se siguen escribiendo
    `-^>`.
13. **Detección de firmware por capas (Fase 4).** Para saber si el equipo
    arrancó en **UEFI** o en **BIOS Legacy** el script prueba, por orden:
    (1) el registro `HKLM\...\Control\SystemInformation\SystemFirmwareType`
    (`0x2` = UEFI, `0x1` = Legacy; en WinPE se rellena antes con
    `wpeutil UpdateBootInfo`); (2) `bcdedit /enum {current}`, buscando
    `winload.efi` (UEFI) frente a `winload.exe` (Legacy). El resultado deja
    listas `FIRMWARE` y `FIRMWARE_FORMATO` (`GPT`/`MBR`) y **se aplica solo**
    al guion de `diskpart` (`convert %FIRMWARE_FORMATO%`). Si ningún método
    funciona, **no se adivina**: se pregunta al técnico qué esquema usar.
14. **Registro de actividad (`jah-winpe.log`, Fase 4).** Cada acción
    relevante llama a `:REGISTRAR TIPO "detalle" "resultado"`, que **anexa**
    (con `>>`) una línea `fecha hora | TIPO | detalle | resultado`. El
    fichero se abre y se cierra en cada anotación, así nunca queda bloqueado
    (importante mientras se está borrando un disco). Como WinPE vive en RAM
    (`X:`), el script busca **primero junto a sí mismo**, después **cualquier
    disco escribible** y, si no hay, deja el log **en RAM** avisando de que
    se perderá al reiniciar. Nunca guarda texto tecleado por el técnico:
    solo datos ya validados (números de disco, códigos de error, resultados).
15. **Diagnóstico y salud (Fase 4.5).** La opción `[3]` abre un submenú:
    `[1]` inventario de hardware, `[2]` comprobación de una unidad con
    `chkdsk` y `[3]` salud SMART. El inventario es de solo lectura; `chkdsk`
    con `/f` o `/f /r` puede reparar la unidad y por eso pide confirmación
    S/N. Se usan PowerShell/WMI (`Get-Volume`, `Get-PhysicalDisk`,
    `Win32_*`) y, si faltan, `wmic` o `diskpart`. La RAM se lee en
    **kilobytes** y se convierte a MB/GB con `set /a`, porque `set /a` no
    maneja los bytes de un disco grande (se desbordarían los 32 bits).
16. **Estimación del tiempo de borrado (Fase 4.5).** Se aplica al nivel `[3]`
    de la opción `[2]` (`clean all`). Antes de ese nivel se lee el **tamaño
    exacto en bytes** (`wmic diskdrive ... size`) y se convierte a GB **por
    texto** (se recortan los últimos 9 dígitos), no con aritmética, por el
    mismo motivo de desbordamiento. El tipo de disco (HDD/SSD) se detecta con
    WMI (`MSFT_PhysicalDisk`: `3`=HDD, `4`=SSD) y, si no se puede, se
    pregunta. El tiempo se calcula con dos velocidades de referencia
    (HDD 60–150 MB/s; SSD 100–300 MB/s) y se muestra como un **rango**
    `de X a Y`, siempre con la etiqueta **orientativa**: un disco por USB 2.0
    puede tardar diez veces más. El aviso aparece **después** de mostrar el
    guion y **antes** de la doble confirmación, en amarillo.

---

## Seguridad

- **Escudo de disco de arranque (Fase 2.8):** antes de pedir el número de
  disco, el script identifica el **disco físico desde el que arranca
  WinPE / se ejecuta la herramienta** (por la letra de `SystemDrive` y la
  del propio script, convertidas a índice de disco con PowerShell o, si
  falta, con `diskpart detail volume`). Si el disco elegido coincide con
  ese disco protegido, la operación se **bloquea** con una pantalla roja y
  **no se genera ni se ejecuta ningún guion**.
- **Verificación imposible = aviso de riesgo:** si el entorno no permite
  identificar el disco de arranque (WinPE muy recortado sin PowerShell,
  `diskpart` en un idioma no reconocido), el script lo dice con un aviso
  amarillo y aplica la misma doble confirmación S/N. Nunca afirma estar
  seguro cuando no lo está.
- **Doble confirmación S/N:** toda acción destructiva pide dos respuestas:
  la pregunta de confirmación y, tras el resumen, la pregunta de seguridad.
  Solo `S` (o `Y` en English) continúa; `N`, `SI`, `YES`, Enter o cualquier
  otra entrada cancela y el script **no ejecuta nada**. La segunda respuesta
  se lee con `set /p`, así que hay que pulsar Enter después de la letra.
- **Entrada validada:** el número de disco tecleado se contrasta con el
  listado real (`list disk`); entradas vacías, letras o números
  inexistentes se rechazan sin generar guiones.
- **Regla de oro:** verifica siempre el disco correcto
  (`diskpart` → `list disk` → `detail disk` / `list volume`) antes de tocar
  nada. Compara el tamaño con la etiqueta física del disco.
- El nivel `[1]` (`clean`) borra solo la tabla de particiones (los datos
  siguen ahí); el nivel `[2]` usa TRIM/Deallocate para SSD/NVMe; el nivel
  `[3]` (`clean all`) sobrescribe el medio con ceros y es lento. Entiende la
  diferencia antes de usarlos.
- En **SSD/NVMe**, `clean all` **no** garantiza el borrado físico y desgasta
  las celdas: usa el nivel `[2]` (TRIM) o la herramienta del fabricante /
  ATA Secure Erase.
- **Auditoría (Fase 4):** todas las operaciones relevantes (inicio de sesión,
  disco elegido, limpieza, `clean all`, códigos de error de `diskpart`,
  bloqueos y salida) quedan registradas con fecha y hora en `jah-winpe.log`,
  de modo que una intervención se puede reconstruir después.
- **Diagnóstico sin riesgo (Fase 4.5):** el inventario y la consulta SMART de
  `[3]` son de **solo lectura** y quedan registrados en el log como
  `DIAGNOSTICO`. `chkdsk /f` y `/f /r` sí pueden reparar la unidad y piden
  confirmación S/N antes de ejecutarse. El **aviso de tiempo** del nivel `[3]`
  de `[2]` no cambia el borrado: solo informa antes de la confirmación, con
  la advertencia de no interrumpir el proceso una vez iniciado.

---

## Cómo probar (checklist manual)

- [ ] La pantalla de idioma aparece antes de la bienvenida y `[1] Español`
      / `[2] English` cambia todos los textos (menú, ayuda, avisos).
- [ ] Con English, la segunda confirmación pide `Y` y solo `Y`/`y` continúa.
- [ ] El pie del menú muestra `Modo de entrada: CHOICE` (o `SETP` en WinPE
      sin `choice.exe`).
- [ ] Pulsar una tecla no válida: solo *beep*, el script **no** se cierra.
- [ ] Pulsar `ENTER` en vacío: mensaje `[!] Entrada no válida` y vuelve a pedir.
- [ ] `Ctrl+C`: el script no queda en un estado roto.
- [ ] `[4]` abre consola; `exit` devuelve al menú principal.
- [ ] `[5]` muestra los tres apartados (comandos, guía y navegación) y
      avanza con Enter, `A` o `M` sin teclear números.
- [ ] `[6]` muestra el contenedor de terceros; `A` y `M` vuelven al menú.
- [ ] `[7]` → `[3]` (volver) no apaga nada; `[1]` pide confirmación.
- [ ] Los acentos se ven correctamente (sin "runas").
- [ ] En WinPE: `[7]` → apagar usa `wpeutil`; en Windows, `shutdown`.
- [ ] `[1]`: al teclear `A` en el número de disco vuelve al menú sin tocar nada.
- [ ] `[1]`: al teclear letras, símbolos o ceros a la izquierda avisa y
      vuelve a pedir el número (no se cierra).
- [ ] `[1]`: antes de ejecutar, el guion aparece en pantalla y solo `S`
      (o `Y` en English) en las dos confirmaciones ejecuta la operación.
- [ ] `[2]`: pide dos confirmaciones S/N; `SI`, `YES`, Enter o cualquier
      otra entrada cancela.
- [ ] `[1]`/`[2]`: si eliges el disco de arranque (el de Windows en marcha
      o el medio WinPE), aparece la **pantalla roja de bloqueo** y no se
      genera guion.
- [ ] `[1]`/`[2]`: si el número no aparece en el listado, sale una pantalla
      de duda con tres opciones; la opción 2 muestra el aviso de riesgo y
      aplica la misma doble confirmación.
- [ ] En WinPE sin PowerShell (o `diskpart` en otro idioma), el resumen
      muestra "Protección de arranque: SIN VERIFICADA", aparece el aviso de
      riesgo y se piden las dos confirmaciones S/N.
- [ ] `[1]`/`[2]`: al terminar, la verificación (nuevo listado) muestra el
      resultado esperado.
- [ ] Al salir de un módulo, los ficheros `_jah_*.txt` ya no están en la
      carpeta temporal.

### ISO arrancable (Fase 3)

- [ ] `build\build_iso.bat` termina con "COMPILACION TERMINADA" y muestra
      el SHA-256 del ISO.
- [ ] La **misma** `JAH-WinPe.iso` arranca en **BIOS Legacy** y en **UEFI**
      (QEMU + OVMF; comandos en `docs/BUILD_GUIDE.md`).
- [ ] Con el arranque por defecto (`_noprompt`), la ISO arranca **sin pulsar
      tecla**.
- [ ] Al entrar en WinPE aparece `JAH-WinPe: arrancando el menu desde …` y se
      abre el menú **automáticamente** (sin teclear nada).
- [ ] Si no hay `menu.bat` en ninguna unidad, sale el aviso `[!]` y una
      consola de emergencia en vez de una pantalla negra.

### Firmware y registro de actividad (Fase 4)

- [ ] El menú muestra una línea `Firmware: UEFI -> GPT` (o `LEGACY -> MBR`)
      y otra con la ruta del `jah-winpe.log`.
- [ ] El guion de `[1]` contiene `convert gpt` en UEFI y `convert mbr` en
      Legacy (mira la línea del guion que se muestra antes de ejecutar).
- [ ] Si no se puede detectar el firmware, `[1]` **pregunta** `[1=GPT / 2=MBR]`
      antes de generar el guion (no adivina).
- [ ] Tras una operación, `jah-winpe.log` contiene las líneas `INICIO`,
      `IDIOMA`, `FIRMWARE`, `DISCO`, `GUION_GENERADO`, `DISKPART` (con el
      código de salida) y `SALIDA`, cada una con fecha y hora.
- [ ] Si arrancas desde un USB (o hay otro disco conectado), el log aparece
      en ese disco y **sobrevive** al reinicio.
- [ ] Sin disco persistente, el menú avisa `Registro (log): solo en RAM`.

### Diagnóstico, salud y estimación (Fase 4.5)

- [ ] `[3]` abre el submenú con `[1]` hardware, `[2]` `chkdsk` y `[3]` SMART.
- [ ] `[3]` → `[1]` muestra sistema, CPU, RAM (total y disponible), placa
      base y discos físicos con su tamaño, y **no** modifica nada.
- [ ] `[3]` → `[2]` lista las unidades con letra, permite elegir una y ofrece
      `chkdsk /scan`, `/f` o `/f /r`; rechaza `X:` y pide confirmación S/N.
- [ ] `[3]` → `[3]` muestra la salud SMART y distingue OK, Pre-fail y
      “sin datos” sin inventar un veredicto.
- [ ] Tras el inventario o SMART, `jah-winpe.log` contiene una línea
      `DIAGNOSTICO`.
- [ ] Si la imagen no tiene PowerShell o `wmic`, `[3]` avisa en los bloques
      afectados y, aun así, lista las unidades con `diskpart`.
- [ ] `[2]`: el nivel `[1]` limpia solo estructura, el `[2]` aplica
      TRIM/Deallocate y el `[3]` sobrescribe con ceros.
- [ ] `[2]`: tras mostrar el guion, el nivel `[3]` muestra el **aviso
      amarillo** con el tamaño real del disco y un rango de tiempo estimado.
- [ ] Si el tipo de disco no se puede detectar, `[2]` **pregunta**
      `[1=HDD / 2=SSD]` antes de estimar (no adivina).
- [ ] `jah-winpe.log` registra la estimación (`... media=HDD ...`) tras elegir
      el disco en `[2]`.

---

## Roadmap (Fases siguientes)

- [x] Módulo guiado de `diskpart` para **[1]** (listar, seleccionar,
      `clean`, `convert gpt`, partición primaria, NTFS rápido, letra).
- [x] Flujo de **borrado seguro** para **[2]** con tres niveles
      (estructura, TRIM y ceros) + verificación.
- [x] **Doble confirmación S/N** antes de toda acción destructiva.
- [x] Interfaz **multilenguaje** Español / English (diccionarios dentro de
      `src/menu.bat` + selector de idioma al arrancar).
- [x] **Escudo de seguridad** (Fase 2.8): bloqueo del disco de arranque,
      validación de existencia del disco, aviso de riesgo y doble
      confirmación S/N.
- [x] **Entorno WinPE** (Fase 3): arranque automático con
      `src/startnet.cmd` (wpeinit + búsqueda de `menu.bat`).
- [x] **ISO arrancable** doble (UEFI x64 + BIOS Legacy) con `oscdimg` y
      guía de compilación y prueba en QEMU (`docs/BUILD_GUIDE.md`).
- [x] **Detección de firmware** BIOS/UEFI (Fase 4) para elegir el esquema
      **MBR/GPT** automáticamente, con pregunta al técnico si no se puede
      verificar.
- [x] **Registro de actividad** (Fase 4): `jah-winpe.log` con fecha, hora,
      tipo de evento y resultado; persistente si hay un disco escribible.
- [x] **Lectura del tamaño real del disco** (Fase 4.5) para estimar el
      tiempo de `clean all` (HDD/SSD, con aviso orientativo antes de
      confirmar).
- [x] **Diagnóstico y salud** del equipo (Fase 4.5): inventario, `chkdsk` y
      salud SMART.
- [x] **Menú de 7 opciones** con ayuda paginada y contenedor de herramientas
      de terceros (opción 6).
- [ ] Integrar herramientas portables en la opción **[6]** (recuperación de
      datos, gestión BCD y análisis avanzado).
- [ ] Guardar el idioma elegido entre ejecuciones (fichero junto al script).
- [ ] Más idiomas: añadir un bloque `:IDIOMA_xx` y su opción en el selector.

---

## Cómo reportar un problema

Incluye: qué opción pulsaste, el texto exacto que apareció, el entorno
(Windows 10/11 o WinPE y su build) y una captura si es posible.

---

## Licencia

Pendiente de definir por el autor.

## Autor

JAH
