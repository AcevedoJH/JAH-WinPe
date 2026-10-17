# JAH-WinPe · Console-based IT support tool

**🌐 Language / Idioma:** **English** · [Español](README.md)

> *Maintenance note:* if you edit this document, update the Spanish version
> (`README.md`) as well so they don't drift apart.

A command-line (Batch) utility for the IT workshop technician. It bundles the
most common operations on Windows machines into a single console interface
that is simple, repeatable and "typo-proof".

It runs **both on full Windows and on Windows PE** (the recovery environment
that boots from USB/ISO). No installation and no external dependencies:
just the `menu.bat` file.

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

> *Note:* the on-screen UI text is currently in **Spanish**. The UI itself is
> a separate concern from this documentation; localization is planned on the
> roadmap below.

---

## Project status

| Phase | Content | Status |
|-------|---------|--------|
| **1** | Interface: welcome screen, menu, help, advanced console, shutdown | ✅ Done |
| **2** | Guided `diskpart` flows: disk preparation and secure erase | ⏳ Pending |

> **Important:** in Phase 1, options **[1]** and **[2]** are *stubs*
> (informational screens). **They do not perform any destructive operation on
> disks yet.** In the meantime, use option **[3] Advanced Console** to work
> manually.

---

## Requirements

- **Windows 10/11** or **WinPE** (image built with Windows ADK 10/11).
- **No installation**: just copy `menu.bat` to your working folder or USB drive.
- **Administrator rights** for disk operations
  (in WinPE you already run with SYSTEM privileges).
- Optional: `choice.exe` in `%SystemRoot%\System32`.
  If it is missing (some minimal WinPE images), the script detects it and
  automatically falls back to `set /p` with a whitelist.

---

## Quick start

1. Copy `menu.bat` to the root of your working folder or boot USB drive.
2. Run it:
   - double-click `menu.bat`, or
   - from a console: `menu.bat`
3. Navigate the menus by typing the option number
   (if your console does not react to a single key, press `ENTER` afterwards).
4. From **[3] Advanced Console** you can run any command;
   type `exit` to return to the main menu.

---

## Menu options

| Option | Name | What it does | Status |
|--------|------|--------------|--------|
| `[1]` | Quick disk preparation | Clean + partition + basic NTFS format | Stub (Phase 2) |
| `[2]` | Secure erase / Sanitization | Logical data destruction (NIST SP 800-88) | Stub (Phase 2) |
| `[3]` | Advanced Console | Opens an interactive `cmd`; `exit` returns to the menu | Working |
| `[4]` | System help | Quick guide to `diskpart`, `chkdsk`, `wmic`, networking… + native `help` | Working |
| `[5]` | Exit / Shut down | Leave the script or power off (with confirmation) | Working |

---

## Repository structure

```
JAH-WinPe/
├─ menu.bat        Main workshop interface (Batch, fully commented)
├─ README.md       Documentation (Español, default)
├─ README.en.md    Documentation (English)
├─ .gitignore      What must NOT be versioned (junk, images, logs…)
└─ .gitattributes  Forces CRLF on .bat files (critical for cmd.exe)
```

> **Want a different default language?** GitHub always renders `README.md`.
> If you prefer English as the main one, rename `README.en.md` → `README.md`
> and this file → `README.es.md` (and update the links in the header).

---

## Technical notes (read before editing)

These conventions are explained in detail inside `menu.bat`:

1. **Encoding: UTF-8 WITHOUT BOM.** The script runs `chcp 65001` so accents
   display correctly. Never save the `.bat` with a BOM: it would break the
   first line. *Documented fallback:* if you ever see garbled characters,
   save the file as ANSI (Windows-1252) and comment out the `chcp` line.
2. **CRLF line endings** (pinned in `.gitattributes`). `cmd.exe` is sensitive
   to this; don't let Git convert the `.bat` files to LF.
3. **Comments with `REM`, never `::`.** `::` is an empty label that breaks
   inside `( ... )` blocks.
4. **Beware of `>` inside comments and text.** `cmd.exe` processes
   redirection before it even knows the line is a comment: a stray `>` creates
   junk files. That is why arrows are written as **`-^>`**
   (the caret neutralizes the `>`; on screen it still prints `->`).
5. **Labels and variables in ASCII**; visible text does carry accents.
6. **Menus use digits `1..N` only.** That way the index returned by `choice`
   matches the chosen digit and no delayed expansion is needed.
7. **No `DelayedExpansion` and no `( )` blocks** to dispatch the menu:
   less error surface for the batch parser.
8. **Input capture is centralized** in the `:LEER_OPCION` subroutine
   (`choice.exe` when available; otherwise `set /p` with a whitelist).

---

## Safety

- Every irreversible action asks for **double confirmation**; on any doubtful
  answer the script **does nothing** and goes back to the menu.
- **Golden rule:** always verify the correct disk
  (`diskpart` → `list disk` → `detail disk`) before touching anything.
- `clean` erases only the partition table (data is still there);
  `clean all` overwrites the media and is slow. Understand the difference
  before using them.

---

## Manual test checklist

- [ ] The menu footer shows `Modo de entrada: CHOICE` (or `SETP` on WinPE
      without `choice.exe`).
- [ ] Pressing an invalid key: just a *beep*, the script does **not** close.
- [ ] Pressing `ENTER` on an empty prompt: `[!]` message and it asks again.
- [ ] `Ctrl+C`: the script is not left in a broken state.
- [ ] `[3]` opens the console; `exit` returns to the main menu.
- [ ] `[4]` shows both pages and the native `help`.
- [ ] `[5]` → `[3]` (go back) shuts nothing down; `[1]` asks for confirmation.
- [ ] Accents render correctly (no mojibake).
- [ ] On WinPE: `[5]` → shutdown uses `wpeutil`; on Windows, `shutdown`.

---

## Roadmap (Phase 2 and beyond)

- [ ] Guided `diskpart` submenu for **[1]** (list, select, `clean`, primary
      partition, `format fs=ntfs quick`, drive letter).
- [ ] **Secure erase** flow for **[2]** (`clean all`, verification).
- [ ] **BIOS/UEFI** firmware detection to choose **MBR/GPT** scheme.
- [ ] Activity **log** (on the boot volume or `%TEMP%`).
- [ ] Read-only mode / machine inventory (`systeminfo`, `wmic`).
- [ ] **UI localization** (Español / English) via a language file.

---

## Reporting an issue

Include: which option you pressed, the exact text shown, your environment
(Windows 10/11 or WinPE and its build) and a screenshot if possible.

---

## License

To be defined by the author.

## Author

JAH
