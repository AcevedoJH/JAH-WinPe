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
|   Versión 1.1.0  -  Fase 2  -  Entorno: Windows / WinPE      |
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
| **2** | `diskpart` disk modules: quick preparation and secure erase | ✅ Done |
| **3** | Activity log, BIOS/UEFI detection, ES/EN localization | ⏳ Pending |

> **Important:** options **[1]** and **[2]** now perform **real destructive
> operations** on the selected disk. Nothing runs unless you type a
> confirmation word (`PREPARAR` or `BORRAR`), and the secure erase also asks
> you to retype the disk number. Before confirming, the program **shows the
> `diskpart` script** it is about to run.
>
> If you only want to inspect the machine without changing anything, use
> option **[3] Advanced Console**.

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
| `[1]` | Quick disk preparation | `clean` + `convert gpt` + primary partition + quick NTFS (`SISTEMA`) + drive letter | Working |
| `[2]` | Secure erase / Sanitization | `clean all` (zero overwrite, NIST SP 800-88 Purge level) | Working |
| `[3]` | Advanced Console | Opens an interactive `cmd`; `exit` returns to the menu | Working |
| `[4]` | System help | Quick guide to `diskpart`, `chkdsk`, `format`, `wmic`… + native `help` | Working |
| `[5]` | Exit / Shut down | Leave the script or power off (with confirmation) | Working |

---

## How the disk options work (design)

`diskpart` does not listen to the keyboard when it runs a script: it takes a
**list of commands** from a text file (`diskpart /s script.txt`) and executes
them in order. `menu.bat` leverages that and always does the same:

1. **Lists** the disks with `list disk` and `list volume` (read-only) and
   shows the result on screen.
2. **Asks for the disk number** and validates it character by character
   (digits only, no leading zeros). It also tries to cross-check it against
   the listing and, if it cannot confirm it, **asks you** instead of guessing.
3. **Generates the script** in the system temp folder (`_jah_diskpart.txt`).
4. **Prints the script on screen** so you can read it before it runs.
5. **Asks for written confirmation**: the word `PREPARAR` or `BORRAR`
   (for the secure erase, plus retyping the disk number).
6. **Runs** `diskpart /s` without capturing the output, so you can see the
   progress (`clean all` can take hours).
7. **Verifies** by listing disks and volumes again.
8. **Deletes the temp files** (including the script: we do not leave a
   reusable "erase recipe" lying around).

Benefits: no typos at the critical moment, a trace of what was executed, and
repeatable results.

### Known limitation (technical honesty)

`diskpart` translates its messages into the system language (on Spanish
Windows disks show up as `Disco 0`, not `Disk 0`). The automatic listing
check understands both spellings and, when it finds neither, **asks the
technician** instead of deciding. Likewise, if `diskpart`'s native text ever
looks garbled, fix it with `chcp 850` (and `chcp 65001` to return to the
menu's UTF-8).

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
9. **Disk numbers use their own subroutine** `:LEER_NUMERO`, which validates
   digit by digit (`choice` cannot be used because the number is not a closed
   list). The letter `A` cancels.
10. **`diskpart` scripts live in temp files.** They are written with `echo`
    (`_jah_diskpart.txt`), shown before running, and deleted afterwards.
    Lines written into that file must not contain redirection symbols, because
    `cmd.exe` would interpret them.
11. **Before any destructive action** you must type a literal word
    (`PREPARAR` / `BORRAR`): one extra `ENTER` deletes nothing.

---

## Safety

- Every irreversible action asks for **double confirmation**; on any doubtful
  answer the script **does nothing** and goes back to the menu. Specifically:
  you type the word `PREPARAR`/`BORRAR` and, for the secure erase, also retype
  the disk number.
- **Golden rule:** always verify the correct disk
  (`diskpart` → `list disk` → `detail disk` / `list volume`) before touching
  anything. Compare its size against the label on the physical disk.
- `clean` erases only the partition table (data is still there);
  `clean all` overwrites the media and is slow. Understand the difference
  before using them.
- On **full Windows**, the disk holding the running system (drive `C:`)
  **must not be touched**: the module warns you, and on any doubt you should
  cancel.
- On **SSDs**, `clean all` does **not** guarantee physical erasure (the
  controller spreads the writes): use the vendor tool or ATA Secure Erase.

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
- [ ] `[1]`: typing `A` at the disk number returns to the menu untouched.
- [ ] `[1]`: letters, symbols or leading zeros are rejected and re-prompted
      (the script does not close).
- [ ] `[1]`: the script is shown before running and any word other than
      `PREPARAR` cancels the operation.
- [ ] `[2]`: asks for `BORRAR` **and** the disk number again; a mismatch
      cancels.
- [ ] `[1]`/`[2]`: after finishing, the verification listing shows the
      expected result.
- [ ] After leaving a module, the `_jah_*.txt` files are gone from the temp
      folder.

---

## Roadmap (next phases)

- [x] Guided `diskpart` module for **[1]** (list, select, `clean`,
      `convert gpt`, primary partition, quick NTFS, drive letter).
- [x] **Secure erase** flow for **[2]** (`clean all` + verification).
- [x] Written confirmation (keyword) before every destructive action.
- [ ] **BIOS/UEFI** firmware detection to choose the **MBR/GPT** scheme alone.
- [ ] Activity **log** (on the boot volume or `%TEMP%`).
- [ ] Read the real disk size to estimate `clean all` duration.
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
