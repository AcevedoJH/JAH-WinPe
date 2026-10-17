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
|   JAH-WinPe  -  Herramienta de Soporte Técnico               |
|   Versión 1.0.0  -  Fase 1  -  Entorno: Windows / WinPE      |
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
| **2** | Flujos guiados de `diskpart`: preparación de disco y borrado seguro | ⏳ Pendiente |

> **Importante:** en la Fase 1 las opciones **[1]** y **[2]** son *stubs*
> (pantallas informativas). **No ejecutan todavía ninguna operación
> destructiva sobre discos.** Mientras tanto, para trabajar a mano se usa
> la opción **[3] Consola Avanzada**.

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
3. Muévete por los menús tecleando el número de la opción
   (si tu consola no reacciona a una sola tecla, termina con `ENTER`).
4. Desde **[3] Consola Avanzada** puedes ejecutar cualquier comando;
   escribe `exit` para volver al menú principal.

---

## Opciones del menú

| Opción | Nombre | Qué hace | Estado |
|--------|--------|----------|--------|
| `[1]` | Preparación rápida de disco | Limpieza + partición + formateo NTFS básico | Stub (Fase 2) |
| `[2]` | Borrado seguro / Sanitización | Destrucción lógica de datos (NIST SP 800-88) | Stub (Fase 2) |
| `[3]` | Consola Avanzada | Abre un `cmd` interactivo y vuelve al menú con `exit` | Operativa |
| `[4]` | Ayuda del sistema | Guía rápida de `diskpart`, `chkdsk`, `wmic`, red… + `help` nativo | Operativa |
| `[5]` | Salir / Apagar equipo | Salir del script o apagar (con confirmación) | Operativa |

---

## Estructura del repositorio

```
JAH-WinPe/
├─ menu.bat        Interfaz principal del taller (Batch, comentado)
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

---

## Seguridad

- Toda acción irreversible pide **doble confirmación**; ante cualquier
  respuesta dudosa, el script **no ejecuta nada** y vuelve al menú.
- **Regla de oro:** verifica siempre el disco correcto
  (`diskpart` → `list disk` → `detail disk`) antes de tocar nada.
- `clean` borra solo la tabla de particiones (los datos siguen ahí);
  `clean all` sobrescribe el medio y es lento. Entiende la diferencia antes
  de usarlos.

---

## Cómo probar (checklist manual)

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

---

## Roadmap (Fase 2 y siguientes)

- [ ] Submenú guiado de `diskpart` para **[1]** (listar, seleccionar,
      `clean`, partición primaria, `format fs=ntfs quick`, letra).
- [ ] Flujo de **borrado seguro** para **[2]** (`clean all`, verificación).
- [ ] Detección de firmware **BIOS/UEFI** para elegir esquema **MBR/GPT**.
- [ ] **Log** de actividad (en la unidad de arranque o `%TEMP%`).
- [ ] Modo "solo lectura" / inventario del equipo (`systeminfo`, `wmic`).
- [ ] **Localización de la interfaz** (Español / English) por archivo de idioma.

---

## Cómo reportar un problema

Incluye: qué opción pulsaste, el texto exacto que apareció, el entorno
(Windows 10/11 o WinPE y su build) y una captura si es posible.

---

## Licencia

Pendiente de definir por el autor.

## Autor

JAH
