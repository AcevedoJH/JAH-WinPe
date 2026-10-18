# JAH-WinPe · Herramienta de soporte técnico en consola

**🌐 Idioma / Language:** **Español** · [English](README.en.md)

> *Nota de mantenimiento:* si editas este documento, actualiza también la
> versión en inglés (`README.en.md`) para que no se desincronicen.

Utilidad de línea de comandos (Batch) para el técnico de un taller de IT.
Reúne las operaciones más habituales sobre equipos Windows en una interfaz
de consola simple, repetible y "a prueba de errores de tecleo".

Funciona **tanto en Windows completo como en Windows PE** (entorno de
recuperación que arranca desde USB/ISO). No requiere instalación ni
dependencias externas: solo el archivo `menu.bat`.

```
+--------------------------------------------------------------+
|   Elige idioma / Choose language:  [1] Español   [2] English |
+--------------------------------------------------------------+
|   JAH-WinPe  -  Herramienta de Soporte Técnico               |
|   Versión 1.3.0  -  Fase 2.8  -  Entorno: Windows / WinPE    |
+--------------------------------------------------------------+
|   [1]  Preparación rápida de disco   limpieza y formato      |
|   [2]  Borrado seguro / Sanitización destrucción lógica      |
|   [3]  Consola Avanzada              salir a CMD interactivo |
|   [4]  Ayuda del sistema             guía rápida del técnico |
|   [5]  Salir / Apagar equipo                                 |
+--------------------------------------------------------------+
```

---

## Estado del proyecto

| Fase | Contenido | Estado |
|------|-----------|--------|
| **1** | Interfaz: bienvenida, menú, ayuda, consola avanzada, apagado | ✅ Completada |
| **2** | Módulos de disco con `diskpart`: maquetación rápida y borrado seguro | ✅ Completada |
| **2.5** | Interfaz **multilenguaje** (Español / English) + README bilingüe | ✅ Completada |
| **2.8** | **Escudo de seguridad**: bloqueo del disco de arranque + confirmación por palabra | ✅ Completada |
| **3** | Log de actividad, detección BIOS/UEFI, más idiomas | ⏳ Pendiente |

> **Importante:** las opciones **[1]** y **[2]** ya ejecutan operaciones
> **destructivas reales** sobre el disco elegido. Ninguna actúa sin que
> teclees la palabra de confirmación `CONFIRMAR` (o `CONFIRM` en English) y,
> además, repitas el número de disco. Antes de confirmar, el programa
> **muestra el guion de `diskpart`** que va a ejecutar, e **identifica
> automáticamente el disco de arranque**: si eliges ese disco, la operación
> se **bloquea** y no se genera ningún guion.
>
> Si solo quieres mirar el equipo sin modificar nada, usa la opción
> **[3] Consola Avanzada**.

---

## Requisitos

- **Windows 10/11** o **WinPE** (imagen creada con Windows ADK 10/11).
- **Sin instalación**: basta copiar `menu.bat` a la carpeta o USB de trabajo.
- **Permisos de administrador** para las operaciones de disco
  (en WinPE se ejecuta ya con privilegios de SYSTEM).
- Opcional: `choice.exe` en `%SystemRoot%\System32`.
  Si no existe (algunas imágenes WinPE minimalistas), el script detecta la
  ausencia y usa automáticamente su respaldo con `set /p` + lista blanca.

---

## Uso rápido

1. Copia `menu.bat` a la raíz de tu carpeta de trabajo o del USB de arranque.
2. Ejecútalo:
   - Doble clic sobre `menu.bat`, o
   - desde una consola: `menu.bat`
3. **Elige idioma** en la primera pantalla (`[1] Español` / `[2] English`).
   Si no eliges, el programa continúa en Español.
4. Muévete por los menús tecleando el número de la opción
   (si tu consola no reacciona a una sola tecla, termina con `ENTER`).
5. Desde **[3] Consola Avanzada** puedes ejecutar cualquier comando;
   escribe `exit` para volver al menú principal.

---

## Opciones del menú

| Opción | Nombre | Qué hace | Estado |
|--------|--------|----------|--------|
| `[1]` | Preparación rápida de disco | `clean` + `convert gpt` + partición primaria + NTFS rápido (`SISTEMA`) + letra | Operativa |
| `[2]` | Borrado seguro / Sanitización | `clean all` (sobrescritura con ceros, NIST SP 800-88 nivel Purge) | Operativa |
| `[3]` | Consola Avanzada | Abre un `cmd` interactivo y vuelve al menú con `exit` | Operativa |
| `[4]` | Ayuda del sistema | Guía rápida de `diskpart`, `chkdsk`, `format`, `wmic`… + `help` nativo | Operativa |
| `[5]` | Salir / Apagar equipo | Salir del script o apagar (con confirmación) | Operativa |

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
  `:IDIOMA_EN` al final de `menu.bat` (ver "Notas técnicas", punto 12).

---

## Cómo funcionan las opciones de disco (diseño)

`diskpart` no atiende al teclado cuando trabaja con un guion: recibe una
**lista de comandos** en un fichero de texto (`diskpart /s guion.txt`) y los
ejecuta en orden. `menu.bat` aprovecha eso y hace lo siguiente, siempre
igual:

1. **Lista** los discos con `list disk` y `list volume` (solo lectura) y
   muestra el resultado en pantalla.
2. **Pide el número de disco** y lo valida carácter a carácter (solo
   dígitos, sin ceros a la izquierda). Además intenta contrastarlo con el
   listado y, si no puede confirmarlo, te pregunta en lugar de suponer.
3. **Genera el guion** en la carpeta temporal del sistema (`_jah_diskpart.txt`).
4. **Muestra el guion en pantalla** para que lo leas antes de ejecutarlo.
5. **Pide confirmación escrita**: la palabra `CONFIRMAR` (`CONFIRM` si la
   interfaz está en English) **y además** repetir el número de disco. Si el
   escudo de arranque no pudo verificar qué disco está protegido, exige
   antes la palabra `RIESGO` (`RISK`).
6. **Ejecuta** `diskpart /s` sin capturar la salida, para que veas el avance
   (en `clean all` puede tardar horas).
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
├─ menu.bat        Interfaz principal del taller (Batch, comentado).
│                  Incluye, al final, los dos diccionarios de idioma
│                  (:IDIOMA_ES y :IDIOMA_EN).
├─ README.md       Documentación (Español, por defecto)
├─ README.en.md    Documentación (English)
├─ .gitignore      Qué NO debe versionarse (basura, imágenes, logs…)
└─ .gitattributes  Fuerza CRLF en los .bat (clave para que cmd.exe funcione)
```

> **¿Quieres otro idioma por defecto?** GitHub renderiza siempre
> `README.md`. Si prefieres que el inglés sea el principal, renombra
> `README.en.md` → `README.md` y este archivo → `README.es.md`
> (y actualiza los enlaces del encabezado).

---

## Notas técnicas (leer antes de editar)

Estas convenciones están explicadas en detalle dentro de `menu.bat`:

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
11. **Antes de toda acción destructiva** hay que teclear una palabra
    literal (`CONFIRMAR`, o `CONFIRM` en English) **y** el número de disco:
    un `ENTER` de más no borra nada. Si no se pudo verificar el disco de
    arranque, se exige antes una palabra extra `RIESGO`/`RISK`.
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
  amarillo y exige teclear además la palabra `RIESGO` (`RISK` en English)
  antes de la confirmación normal. Nunca afirma estar seguro cuando no lo
  está.
- **Doble confirmación escrita:** toda acción destructiva pide teclear
  `CONFIRMAR` (o `CONFIRM` en English) **y** repetir el número de disco;
  ante cualquier respuesta dudosa, el script **no ejecuta nada** y vuelve
  al menú. La palabra se compara sin distinguir mayúsculas (`if /i`).
- **Entrada validada:** el número de disco tecleado se contrasta con el
  listado real (`list disk`); entradas vacías, letras o números
  inexistentes se rechazan sin generar guiones.
- **Regla de oro:** verifica siempre el disco correcto
  (`diskpart` → `list disk` → `detail disk` / `list volume`) antes de tocar
  nada. Compara el tamaño con la etiqueta física del disco.
- `clean` borra solo la tabla de particiones (los datos siguen ahí);
  `clean all` sobrescribe el medio y es lento. Entiende la diferencia antes
  de usarlos.
- En **SSD**, `clean all` **no** garantiza el borrado físico (el
  controlador reparte las escrituras): usa la herramienta del fabricante o
  el ATA Secure Erase.

---

## Cómo probar (checklist manual)

- [ ] La pantalla de idioma aparece antes de la bienvenida y `[1] Español`
      / `[2] English` cambia todos los textos (menú, ayuda, avisos).
- [ ] Con English, la confirmación destructiva pide `CONFIRM`.
- [ ] El pie del menú muestra `Modo de entrada: CHOICE` (o `SETP` en WinPE
      sin `choice.exe`).
- [ ] Pulsar una tecla no válida: solo *beep*, el script **no** se cierra.
- [ ] Pulsar `ENTER` en vacío: mensaje `[!] Entrada no válida` y vuelve a pedir.
- [ ] `Ctrl+C`: el script no queda en un estado roto.
- [ ] `[3]` abre consola; `exit` devuelve al menú principal.
- [ ] `[4]` muestra las dos páginas y el `help` nativo.
- [ ] `[5]` → `[3]` (volver) no apaga nada; `[1]` pide confirmación.
- [ ] Los acentos se ven correctamente (sin "runas").
- [ ] En WinPE: `[5]` → apagar usa `wpeutil`; en Windows, `shutdown`.
- [ ] `[1]`: al teclear `A` en el número de disco vuelve al menú sin tocar nada.
- [ ] `[1]`: al teclear letras, símbolos o ceros a la izquierda avisa y
      vuelve a pedir el número (no se cierra).
- [ ] `[1]`: antes de ejecutar, el guion aparece en pantalla y una palabra
      distinta de `CONFIRMAR` cancela la operación.
- [ ] `[2]`: pide `CONFIRMAR` **y** repetir el número de disco; si el número
      no coincide, cancela.
- [ ] `[1]`/`[2]`: si eliges el disco de arranque (el de Windows en marcha
      o el medio WinPE), aparece la **pantalla roja de bloqueo** y no se
      genera guion.
- [ ] `[1]`/`[2]`: si el número no aparece en el listado, sale una pantalla
      de duda con tres opciones y la opción 2 exige la palabra `RIESGO`.
- [ ] En WinPE sin PowerShell (o `diskpart` en otro idioma), el resumen
      muestra "Protección de arranque: SIN VERIFICADA" y pide `RIESGO`
      antes de `CONFIRMAR`.
- [ ] `[1]`/`[2]`: al terminar, la verificación (nuevo listado) muestra el
      resultado esperado.
- [ ] Al salir de un módulo, los ficheros `_jah_*.txt` ya no están en la
      carpeta temporal.

---

## Roadmap (Fases siguientes)

- [x] Módulo guiado de `diskpart` para **[1]** (listar, seleccionar,
      `clean`, `convert gpt`, partición primaria, NTFS rápido, letra).
- [x] Flujo de **borrado seguro** para **[2]** (`clean all` + verificación).
- [x] Confirmación escrita (palabra clave) antes de toda acción destructiva.
- [x] Interfaz **multilenguaje** Español / English (diccionarios dentro de
      `menu.bat` + selector de idioma al arrancar).
- [x] **Escudo de seguridad** (Fase 2.8): bloqueo del disco de arranque,
      validación de existencia del disco y confirmación con palabra clave
      (`CONFIRMAR`/`CONFIRM` y `RIESGO`/`RISK`).
- [ ] Detección de firmware **BIOS/UEFI** para elegir esquema **MBR/GPT** solo.
- [ ] **Log** de actividad (en la unidad de arranque o `%TEMP%`).
- [ ] Lectura del tamaño real del disco para estimar el tiempo de `clean all`.
- [ ] Modo "solo lectura" / inventario del equipo (`systeminfo`, `wmic`).
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
