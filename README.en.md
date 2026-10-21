# JAH-WinPe · Console-based IT support tool

**🌐 Language / Idioma:** **English** · [Español](README.md)

> *Maintenance note:* if you edit this document, update the Spanish version
> (`README.md`) as well so they don't drift apart.

A command-line (Batch) utility for the IT workshop technician. It bundles the
most common operations on Windows machines into a single console interface
that is simple, repeatable and "typo-proof".

It runs **both on full Windows and on Windows PE** (the recovery environment
that boots from USB/ISO). No installation and no external dependencies:
just the `src/menu.bat` file.

Since **Phase 3** the project can also be **built as a bootable ISO**
(UEFI x64 + BIOS Legacy) that launches the tool **automatically**; see
[`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).

```
+--------------------------------------------------------------+
|   Elige idioma / Choose language:  [1] Español   [2] English |
+--------------------------------------------------------------+
|   JAH-WinPe  -  IT Support Tool                              |
|   Version 1.0.0  -  Environment: Windows / WinPE             |
+--------------------------------------------------------------+
|   [1]  Disk and partition operations                         |
|   [2]  Sanitization and secure erase                         |
|   [3]  Hardware diagnostics and health                       |
|   [4]  Command console                                       |
|   [5]  Help and technical documentation                      |
|   [6]  Third-party tools and utilities                       |
|   [7]  Shut down or restart the computer                     |
+--------------------------------------------------------------+
|   Firmware: UEFI  ->  GPT     |   Log: persistente / RAM     |
+--------------------------------------------------------------+
```

> *Note:* the on-screen UI text is available in **Spanish and English**;
> pick the language on the first screen when the tool starts.

---

## Project status

> **Current executable version:** `1.0.0`. The main menu has **7 options**;
> option **[6]** is an informational container for third-party tools, still
> under development. The table below keeps the history of functional phases.

| Phase | Content | Status |
|-------|---------|--------|
| **1** | Interface: welcome screen, menu, help, command console, shutdown | ✅ Done |
| **2** | `diskpart` disk modules: preparation and secure erase | ✅ Done |
| **2.5** | **Multilingual** UI (Español / English) + bilingual README | ✅ Done |
| **2.8** | **Security shield**: boot-disk lock + double S/N confirmation | ✅ Done |
| **3** | **WinPE environment**: automatic start-up (`startnet.cmd`) + **bootable ISO**, dual (UEFI/BIOS) | ✅ Done |
| **4** | **UEFI/Legacy firmware** (automatic GPT/MBR layout) + **activity log** (`jah-winpe.log`) | ✅ Done |
| **4.5** | **Diagnostics** of hardware (RAM, disks, SMART and `chkdsk`) + **erase-time estimate** | ✅ Done |
| **5** | More languages; remember the language; integrate portable third-party tools (option 6) | ⏳ Pending |

> **Important:** options **[1]** and **[2]** perform **real destructive
> operations** on the selected disk. Nothing runs without a **double S/N
> confirmation**: first the confirmation question and then, after the
> summary, the safety question. Only `Y` (or `S` in Spanish) continues; `N`,
> `SI`, `YES`, Enter or any other answer cancels. Before confirming, the
> program **shows the `diskpart` script** it is about to run, and it
> **automatically identifies the boot disk**: if you pick that disk, the
> operation is **blocked** and no script is generated at all.
>
> If you only want to inspect the machine, use **[3] Hardware diagnostics
> and health**: it includes a read-only inventory, drive checks with
> `chkdsk` and SMART health.
>
> Since **Phase 4**, the tool **detects the firmware** (UEFI or Legacy BIOS)
> and picks the right partition layout on its own (**GPT** for UEFI, **MBR**
> for Legacy). If it cannot verify the firmware, it **does not guess**: it
> asks the technician which layout to use. Every relevant action is written
> with date and time to an **activity log** (`jah-winpe.log`) that survives a
> reboot whenever a persistent disk is connected.
>
> Since **Phase 4.5**, before a `clean all` (level [3] of option [2]) the
> tool **reads the real disk size** and shows a **rough estimate of the erase
> time** (depending on HDD or SSD and on capacity) in a yellow warning
> **before** the double confirmation.

---

## Requirements

- **Windows 10/11** or **WinPE** (image built with Windows ADK 10/11).
- **No installation**: just copy `src\menu.bat` to your working folder or USB
  drive (or boot the ISO built in Phase 3).
- **Administrator rights** for disk operations
  (in WinPE you already run with SYSTEM privileges).
- Only to **build the ISO** (not to use it): Windows ADK + WinPE add-on.
  Details in [`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).
- The build script automatically adds the **WinPE-WMI**, **WinPE-Scripting**,
  **WinPE-NetFx**, **WinPE-PowerShell** and **WinPE-StorageWMI** components.
  They are required for the inventory, SMART health and the PowerShell volume
  listing.
- Optional: `choice.exe` in `%SystemRoot%\System32`.
  If it is missing (some minimal WinPE images), the script detects it and
  automatically falls back to `set /p` with a whitelist.

---

## Quick start

1. Copy `src\menu.bat` to the root of your working folder or boot USB drive.
   You can also build the **bootable ISO** (see below).
2. Run it:
   - double-click `src\menu.bat`, or
   - from a console: `src\menu.bat`
3. **Pick a language** on the first screen (`[1] Español` / `[2] English`).
   If you don't, the tool continues in Spanish.
4. Navigate the menus by typing the option number
   (if your console does not react to a single key, press `ENTER` afterwards).
5. From **[4] Command console** you can run any command;
   type `exit` to return to the main menu.
6. **[6] Third-party tools and utilities** is currently an informational
   screen; **[7]** shuts the machine down or exits the tool.

### Build the bootable ISO (Phase 3)

If you want a **bootable** rescue medium (instead of copying `src\menu.bat`
by hand), build the ISO on a Windows machine **as Administrator**:

```bat
build\build_iso.bat
```

It produces `JAH-WinPe.iso` with dual boot **UEFI x64 + BIOS Legacy** and
`menu.bat` integrated: when it boots from the ISO, the menu **comes up on
its own**. Requirements (Windows ADK + WinPE add-on), the script parameters
and the **QEMU** test instructions are in
[`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md).

---

## Menu options

| Option | Name | What it does | Status |
|--------|------|--------------|--------|
| `[1]` | Disk and partition operations | `clean` + `convert gpt/mbr` + primary NTFS partition (`SISTEMA`) + drive letter; guided module with boot-disk protection | Working |
| `[2]` | Sanitization and secure erase | Three levels: structure (`clean`), TRIM/Deallocate for SSD/NVMe and zero overwrite (`clean all`) for HDD; double confirmation and prior estimate | Working |
| `[3]` | Hardware diagnostics and health | Submenu: inventory (CPU/RAM/motherboard/disks), per-drive `chkdsk` and SMART health | Working |
| `[4]` | Command console | Interactive `cmd`; `exit` returns to the menu | Working |
| `[5]` | Help and technical documentation | Three sections (commands, step-by-step guide and navigation) with Enter/A/M paging | Working |
| `[6]` | Third-party tools and utilities | Informational container; data recovery, BCD management and advanced analysis will be integrated | In development |
| `[7]` | Shut down or restart the computer | Power off or exit the tool (restarts in WinPE) with confirmation | Working |

### Diagnostics, health and estimate

Option **[3]** opens a diagnostics submenu to inspect the machine:

- **[1] Full hardware:** operating system and model, CPU (physical and
  logical cores), total and available RAM, motherboard and physical disks
  with size and status. It uses PowerShell/WMI and falls back to `wmic` or
  `diskpart` when they are missing.
- **[2] Check a drive:** asks for a real drive letter, shows the command and
  offers `chkdsk /scan`, `/f` or `/f /r`. It never runs on `X:` (the WinPE RAM
  drive).
- **[3] SMART health:** queries `Get-PhysicalDisk`, `Win32_DiskDrive` and
  `MSStorageDriver_FailurePredictStatus`; it shows OK, Pre-fail or “no data”
  and warns when the disk is at risk.

The inventory writes nothing. `chkdsk /f` and `/f /r` can repair the drive,
so they ask for S/N confirmation before running. The SMART query is light and
does not modify the disk.

Option **[2]** has **three erase levels**: `[1]` structure, `[2]`
TRIM/Deallocate for SSD/NVMe and `[3]` zeros (`clean all`) for HDD. Before
level [3] the tool reads the **real disk size** and tries to tell whether it
is **HDD or SSD**; if it cannot, it **asks**. It shows a **yellow warning**
with a **rough** time range (`from X to Y`), recalling that it depends on the
bus (USB/SATA) and on the disk health.

---

## UI language (Español / English)

On start-up the tool shows a language selection screen:

```
  Selecciona el idioma / Select the language:

     [1]  Español
     [2]  English
```

- All **visible text** (menus, help, warnings and confirmations) switches
  language. **Code comments** stay in Spanish: they are project
  documentation, not interface.
- The **logic is single**: disk modules, validations and confirmations behave
  exactly the same in both languages (only the text changes). Translating
  cannot introduce behavioural differences.
- The language is **not remembered** between runs: it is always asked. This
  is intentional (a workshop USB drive is used by several people).
- To **add or fix texts**, edit the `:IDIOMA_ES` or `:IDIOMA_EN` block at the
  end of `src/menu.bat` (see "Technical notes", item 12).

---

## How the disk options work (design)

`diskpart` does not listen to the keyboard when it runs a script: it takes a
**list of commands** from a text file (`diskpart /s script.txt`) and executes
them in order. `src\menu.bat` leverages that and always does the same:

1. **Lists** the disks with `list disk` and `list volume` (read-only) and
   shows the result on screen.
2. **Asks for the disk number** and validates it character by character
   (digits only, no leading zeros). It also tries to cross-check it against
   the listing and, if it cannot confirm it, **asks you** instead of guessing.
3. **Generates the script** in the system temp folder (`_jah_diskpart.txt`).
4. **Prints the script on screen** so you can read it before it runs.
5. **Asks for two S/N confirmations**: first the confirmation question and,
   after the summary, the safety question. Only `Y` (or `S` in Spanish)
   continues; `N`, `SI`, `YES`, Enter or any other answer cancels. If the
   boot-disk shield could not verify which disk is protected, it shows a
   yellow risk warning first.
6. **Runs** `diskpart /s` without capturing the output, so you can see the
   progress (the `clean all` zero level can take hours).
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
├─ src/             Content that goes into the WinPE image
│  ├─ menu.bat      Main workshop interface (Batch, fully commented).
│  │                It contains both language dictionaries at the end
│  │                (:IDIOMA_ES and :IDIOMA_EN). At runtime it writes an
│  │                activity log 'jah-winpe.log' next to itself.
│  └─ startnet.cmd  Automatic start-up inside WinPE (Phase 3):
│                   wpeinit + menu.bat search + launch.
├─ build/           Build utilities (they do not go into the ISO)
│  ├─ build_iso.ps1 Builds the ISO with the ADK (oscdimg + DISM).
│  ├─ build_iso.bat Convenient launcher (checks admin, calls the .ps1).
│  └─ work/         (generated) WinPE media + mount point.
├─ docs/            Technical documentation
│  └─ BUILD_GUIDE.md WinPE boot architecture + QEMU testing.
├─ README.md        Documentation (Español, default)
├─ README.en.md     Documentation (English)
├─ .gitignore       What must NOT be versioned (junk, images, logs…)
└─ .gitattributes   Forces CRLF on .bat/.cmd/.ps1 (critical for cmd.exe)
```

> **Why do the READMEs stay at the root?** GitHub only renders the root
> `README.md` as the landing page; the actual **technical** documentation
> (this build guide) does live in `docs/`.

> **Want a different default language?** GitHub always renders `README.md`.
> If you prefer English as the main one, rename `README.en.md` → `README.md`
> and this file → `README.es.md` (and update the links in the header).

---

## Technical notes (read before editing)

These conventions are explained in detail inside `src\menu.bat`:

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
11. **Before any destructive action** you must pass **two S/N
    confirmations**: the first question and, after the summary, the safety
    question. Only `S` (or `Y` in English) continues; `N`, `SI`, `YES`, Enter
    or any other input cancels. When the boot disk cannot be verified, a risk
    warning is shown first and the same double confirmation applies.
12. **Multilingual UI (i18n) through variable dictionaries.** There are no
    translation files: the language is resolved with **two blocks of text
    variables** (`:IDIOMA_ES` and `:IDIOMA_EN`) that define **the same names**
    (`T_MENU_01`, `T_D2_21`…) with different values. On start-up the
    `:CARGAR_IDIOMA` subroutine runs the block of the active language using a
    **label built on the fly** (`goto IDIOMA_%LANG%`), and from then on the
    whole program prints `%T_xxx%`. The logic is not duplicated: if a new text
    is missing in one language, it only shows up blank there. When editing the
    blocks, remember they **cannot contain** double quotes `"` or the `%`
    sign inside the value, and arrows are still written `-^>`.
13. **Layered firmware detection (Phase 4).** To tell whether the machine
    booted in **UEFI** or **Legacy BIOS** the script tries, in order:
    (1) the registry value
    `HKLM\...\Control\SystemInformation\SystemFirmwareType`
    (`0x2` = UEFI, `0x1` = Legacy; in WinPE it is filled in first with
    `wpeutil UpdateBootInfo`); (2) `bcdedit /enum {current}`, looking for
    `winload.efi` (UEFI) versus `winload.exe` (Legacy). The result sets
    `FIRMWARE` and `FIRMWARE_FORMATO` (`GPT`/`MBR`) and is **applied
    automatically** to the `diskpart` script (`convert %FIRMWARE_FORMATO%`).
    If no method works, it **does not guess**: it asks the technician.
14. **Activity log (`jah-winpe.log`, Phase 4).** Every relevant action calls
    `:REGISTRAR TYPE "detail" "result"`, which **appends** (with `>>`) one
    line `date time | TYPE | detail | result`. The file is opened and closed
    on every entry, so it is never left locked (important while a disk is
    being wiped). Because WinPE lives in RAM (`X:`), the script looks
    **first next to itself**, then for **any writable disk** and, failing
    that, keeps the log **in RAM** warning that it will be lost on reboot.
    It never stores text typed by the technician: only already-validated
    data (disk numbers, error codes, results).
15. **Diagnostics and health (Phase 4.5).** Option `[3]` opens a submenu:
    `[1]` hardware inventory, `[2]` drive check with `chkdsk` and `[3]` SMART
    health. The inventory is read-only; `chkdsk` with `/f` or `/f /r` can
    repair the drive and therefore asks for S/N confirmation. It uses
    PowerShell/WMI (`Get-Volume`, `Get-PhysicalDisk`, `Win32_*`) and, when
    they are missing, `wmic` or `diskpart`. RAM is read in **kilobytes** and
    converted to MB/GB with `set /a`, because `set /a` cannot handle the byte
    counts of a large disk (32-bit overflow).
16. **Erase-time estimate (Phase 4.5).** It applies to level `[3]` of option
    `[2]` (`clean all`). Before that level it reads the **exact size in
    bytes** (`wmic diskdrive ... size`) and converts it to GB **as text**
    (the last 9 digits are dropped), not with arithmetic, for the same
    overflow reason. The disk type (HDD/SSD) is detected with WMI
    (`MSFT_PhysicalDisk`: `3`=HDD, `4`=SSD) and, if that fails, it is asked.
    The time is computed from two reference speeds (HDD 60–150 MB/s;
    SSD 100–300 MB/s) and shown as a **range** `from X to Y`, always labelled
    **approximate**: a USB 2.0 disk can take ten times longer. The warning
    appears **after** showing the script and **before** the double
    confirmation, in yellow.

---

## Safety

- **Boot-disk shield (Phase 2.8):** before asking for the disk number, the
  script identifies the **physical disk WinPE / the tool itself runs from**
  (drive letters of `SystemDrive` and of the script, converted to a disk
  index with PowerShell or, if unavailable, with `diskpart detail volume`).
  If the chosen disk matches that protected disk, the operation is
  **blocked** with a red screen and **no script is generated or run**.
- **Verification impossible = risk warning:** if the environment does not
  allow identifying the boot disk (heavily trimmed WinPE without PowerShell,
  `diskpart` in an unrecognised language), the script says so with a yellow
  warning and applies the same double S/N confirmation. It never claims to be
  safe when it is not.
- **Double S/N confirmation:** every destructive action asks for two answers:
  the confirmation question and, after the summary, the safety question. Only
  `S` (or `Y` in English) continues; `N`, `SI`, `YES`, Enter or any other
  input cancels and the script **does nothing**. The second answer is read
  with `set /p`, so press Enter after the letter.
- **Validated input:** the typed disk number is cross-checked against the
  real listing (`list disk`); empty input, letters or non-existent numbers
  are rejected without generating any script.
- **Golden rule:** always verify the correct disk
  (`diskpart` → `list disk` → `detail disk` / `list volume`) before touching
  anything. Compare its size against the label on the physical disk.
- Level `[1]` (`clean`) erases only the partition table (data is still
  there); level `[2]` uses TRIM/Deallocate for SSD/NVMe; level `[3]`
  (`clean all`) overwrites the media with zeros and is slow. Understand the
  difference before using them.
- On **SSD/NVMe**, `clean all` does **not** guarantee physical erasure and
  wears the cells: use level `[2]` (TRIM) or the vendor tool / ATA Secure
  Erase.
- **Auditing (Phase 4):** every relevant action (session start, chosen disk,
  preparation, `clean all`, `diskpart` error codes, blocks and exit) is
  recorded with date and time in `jah-winpe.log`, so an intervention can be
  reconstructed afterwards.
- **Risk-free diagnostics (Phase 4.5):** the inventory and SMART query in
  `[3]` are **read-only** (they generate no script and write to no disk) and
  are logged as `DIAGNOSTICO`. `chkdsk /f` and `/f /r` can repair the drive
  and ask for S/N confirmation before running. The **time warning** in level
  `[3]` of `[2]` does not change the erase: it only informs before the
  confirmation, warning not to interrupt the process once started.

---

## Manual test checklist

- [ ] The language screen appears before the welcome screen and `[1] Español`
      / `[2] English` switches every text (menu, help, warnings).
- [ ] In English, the second confirmation asks for `Y` and only `Y`/`y`
      continues.
- [ ] The menu footer shows `Modo de entrada: CHOICE` (or `SETP` on WinPE
      without `choice.exe`).
- [ ] Pressing an invalid key: just a *beep*, the script does **not** close.
- [ ] Pressing `ENTER` on an empty prompt: `[!]` message and it asks again.
- [ ] `Ctrl+C`: the script is not left in a broken state.
- [ ] `[4]` opens the console; `exit` returns to the main menu.
- [ ] `[5]` shows the three sections (commands, guide and navigation) and
      advances with Enter, `A` or `M` without typing numbers.
- [ ] `[6]` shows the third-party container; `A` and `M` go back to the menu.
- [ ] `[7]` → `[3]` (go back) shuts nothing down; `[1]` asks for confirmation.
- [ ] Accents render correctly (no mojibake).
- [ ] On WinPE: `[7]` → shutdown uses `wpeutil`; on Windows, `shutdown`.
- [ ] `[1]`: typing `A` at the disk number returns to the menu untouched.
- [ ] `[1]`: letters, symbols or leading zeros are rejected and re-prompted
      (the script does not close).
- [ ] `[1]`: the script is shown before running and only `S` (or `Y` in
      English) in both confirmations runs the operation.
- [ ] `[2]`: asks for two S/N confirmations; `SI`, `YES`, Enter or any other
      input cancels.
- [ ] `[1]`/`[2]`: picking the boot disk (the running Windows disk or the
      WinPE media) shows the **red block screen** and generates no script.
- [ ] `[1]`/`[2]`: if the number is not in the listing, a doubt screen with
      three options appears; option 2 shows the risk warning and applies the
      same double confirmation.
- [ ] On WinPE without PowerShell (or `diskpart` in another language), the
      summary shows "Boot protection: UNVERIFIED", the risk warning appears
      and both S/N confirmations are requested.
- [ ] `[1]`/`[2]`: after finishing, the verification listing shows the
      expected result.
- [ ] After leaving a module, the `_jah_*.txt` files are gone from the temp
      folder.

### Bootable ISO (Phase 3)

- [ ] `build\build_iso.bat` ends with "COMPILACION TERMINADA" and prints the
      ISO SHA-256.
- [ ] The **same** `JAH-WinPe.iso` boots in **BIOS Legacy** and in **UEFI**
      (QEMU + OVMF; commands in `docs/BUILD_GUIDE.md`).
- [ ] With the default boot mode (`_noprompt`), the ISO boots **without
      pressing a key**.
- [ ] On entering WinPE it prints `JAH-WinPe: arrancando el menu desde …` and
      opens the menu **automatically** (no typing).
- [ ] If there is no `menu.bat` on any drive, the `[!]` warning and an
      emergency console appear instead of a black screen.

### Firmware and activity log (Phase 4)

- [ ] The menu shows a `Firmware: UEFI -> GPT` line (or `LEGACY -> MBR`) and
      another with the `jah-winpe.log` path.
- [ ] The `[1]` script contains `convert gpt` on UEFI and `convert mbr` on
      Legacy (read the script line shown before running).
- [ ] If the firmware cannot be detected, `[1]` **asks** `[1=GPT / 2=MBR]`
      before generating the script (it does not guess).
- [ ] After an operation, `jah-winpe.log` contains `INICIO`, `IDIOMA`,
      `FIRMWARE`, `DISCO`, `GUION_GENERADO`, `DISKPART` (with the exit code)
      and `SALIDA` lines, each with date and time.
- [ ] Booting from a USB (or with another disk attached), the log is written
      to that disk and **survives** a reboot.
- [ ] With no persistent disk, the menu warns `Activity log: RAM only`.

### Diagnostics, health and estimate (Phase 4.5)

- [ ] `[3]` opens the submenu with `[1]` hardware, `[2]` `chkdsk` and `[3]`
      SMART.
- [ ] `[3]` → `[1]` shows system, CPU, RAM (total and available), motherboard
      and physical disks with their size, and changes **nothing**.
- [ ] `[3]` → `[2]` lists the drives with a letter, lets you choose one and
      offers `chkdsk /scan`, `/f` or `/f /r`; it rejects `X:` and asks for
      S/N confirmation.
- [ ] `[3]` → `[3]` shows SMART health and distinguishes OK, Pre-fail and
      "no data" without inventing a verdict.
- [ ] After the inventory or SMART query, `jah-winpe.log` contains a
      `DIAGNOSTICO` line.
- [ ] If the image lacks PowerShell or `wmic`, `[3]` warns in the affected
      blocks and still lists the drives with `diskpart`.
- [ ] `[2]`: level `[1]` cleans only the structure, `[2]` applies
      TRIM/Deallocate and `[3]` overwrites with zeros.
- [ ] `[2]`: after showing the script, level `[3]` shows the **yellow
      warning** with the real disk size and a rough time range.
- [ ] If the disk type cannot be detected, `[2]` **asks** `[1=HDD / 2=SSD]`
      before estimating (it does not guess).
- [ ] `jah-winpe.log` records the estimate (`... media=HDD ...`) after
      choosing the disk in `[2]`.

---

## Roadmap (next phases)

- [x] Guided `diskpart` module for **[1]** (list, select, `clean`,
      `convert gpt`, primary partition, quick NTFS, drive letter).
- [x] **Secure erase** flow for **[2]** with three levels (structure, TRIM
      and zeros) + verification.
- [x] **Double S/N confirmation** before every destructive action.
- [x] **Multilingual** UI Español / English (dictionaries inside
      `src/menu.bat` + language selector on start-up).
- [x] **Security shield** (Phase 2.8): boot-disk lock, disk-existence
      validation, risk warning and double S/N confirmation.
- [x] **WinPE environment** (Phase 3): automatic start-up with
      `src/startnet.cmd` (wpeinit + `menu.bat` search).
- [x] **Bootable ISO**, dual (UEFI x64 + BIOS Legacy), built with `oscdimg`,
      plus a build and QEMU test guide (`docs/BUILD_GUIDE.md`).
- [x] **BIOS/UEFI** firmware detection (Phase 4) to choose the **MBR/GPT**
      scheme automatically, asking the technician when it cannot be verified.
- [x] **Activity log** (Phase 4): `jah-winpe.log` with date, time, event type
      and result; persistent when a writable disk is present.
- [x] **Read the real disk size** (Phase 4.5) to estimate `clean all`
      duration (HDD/SSD, with a rough warning before confirming).
- [x] **Diagnostics and health** (Phase 4.5): inventory, `chkdsk` and SMART
      health.
- [x] **7-option menu** with paged help and a third-party tools container
      (option 6).
- [ ] Integrate portable tools into option **[6]** (data recovery, BCD
      management and advanced analysis).
- [ ] Remember the chosen language between runs (file next to the script).
- [ ] More languages: add an `:IDIOMA_xx` block and its option in the selector.

---

## Reporting an issue

Include: which option you pressed, the exact text shown, your environment
(Windows 10/11 or WinPE and its build) and a screenshot if possible.

---

## License

To be defined by the author.

## Author

JAH
