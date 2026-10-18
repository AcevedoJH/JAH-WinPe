# JAH-WinPe · Guía de construcción de la ISO

> **Fase 3** — Entorno WinPE, arranque automático y compilación de la ISO
> arrancable (UEFI x64 + BIOS Legacy).
>
> Documento pensado para un **técnico junior**: primero explica *cómo
> arranca* WinPE y *qué hace* cada pieza; después, cómo se compila y cómo se
> prueba en un laboratorio virtual.

---

## Índice

1. [Arquitectura de arranque de WinPE](#1-arquitectura-de-arranque-de-winpe)
2. [Estructura del repositorio](#2-estructura-del-repositorio)
3. [Requisitos de compilación](#3-requisitos-de-compilación)
4. [Cómo compilar la ISO](#4-cómo-compilar-la-iso)
5. [Probar la ISO con QEMU en Linux (KVM + OVMF)](#5-probar-la-iso-con-qemu-en-linux-kvm--ovmf)
6. [Referencia de parámetros de oscdimg](#6-referencia-de-parámetros-de-oscdimg)
7. [Solución de problemas](#7-solución-de-problemas)

---

## 1. Arquitectura de arranque de WinPE

### 1.1 El recorrido completo, de la BIOS a `menu.bat`

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  FIRMWARE (UEFI o BIOS Legacy) lee la unidad de arranque          │
  └───────────────┬──────────────────────────────┬───────────────────┘
                  │ (BIOS Legacy)                │ (UEFI x64)
                  ▼                              ▼
        boot\etfsboot.com                efi\microsoft\boot\efisys*.bin
        (cargador 16 bits)               (imagen FAT con bootx64.efi)
                  │                              │
                  └──────────────┬───────────────┘
                                 ▼
                        ┌──────────────────┐
                        │     bootmgr      │  Lee el BCD (boot\BCD)
                        │ (Administrador   │  y localiza la entrada de
                        │    de arranque)  │  arranque del "ramdisk".
                        └────────┬─────────┘
                                 ▼
                ┌────────────────────────────────────┐
                │  boot\boot.sdi  +  sources\boot.wim │
                │  Se crea un disco VIRTUAL EN RAM    │
                │  y se monta dentro el contenido de  │
                │  boot.wim  ->  aparece como  X:      │
                └────────┬───────────────────────────┘
                         ▼
                ┌──────────────────┐
                │    winload       │  Carga el nucleo y arranca el
                │ (carga Windows PE)│  "mini-Windows" desde X:
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │   winpeshl.exe   │  Primer proceso de usuario.
                │                  │  Busca X:\Windows\System32\
                │                  │  startnet.cmd  <- ¡NUESTRO SCRIPT!
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │  startnet.cmd    │  1) wpeinit      (inicializa PnP/red)
                │                  │  2) busca menu.bat en las unidades
                │                  │  3) lo ejecuta (call)
                └────────┬─────────┘
                         ▼
                ┌──────────────────┐
                │    menu.bat      │  La interfaz del taller (Fase 1/2/2.8/4/4.5)
                └──────────────────┘
```

### 1.2 Qué es cada pieza (y por qué importa)

**`bootmgr` — Administrador de arranque de Windows.**
Es el primer programa "de Windows" que corre. Su trabajo es leer el fichero
`boot\BCD` (Boot Configuration Data, la "base de datos" de arranque) y
averiguar **qué** hay que arrancar y **desde dónde**. En WinPE, la entrada
del BCD apunta a un **ramdisk**: una imagen de disco que se carga en memoria.

**`boot.sdi` — plantilla del disco RAM.**
Define la estructura (tamaño y tipo de sistema de ficheros) del disco virtual
que `bootmgr` crea en memoria. No contiene datos: es el "molde".

**`boot.wim` — la imagen con el sistema de ficheros de WinPE.**
WIM = *Windows Imaging Format*. Es un contenedor comprimido que guarda un
sistema de ficheros completo (el "mini-Windows" de rescate). Al arrancar,
`bootmgr` monta su contenido sobre el disco RAM definido por `boot.sdi`, y
el resultado es la unidad **`X:`**.
> **Clave para entender el taller:** `X:` es **volátil**. Vive en la RAM y
> desaparece al reiniciar. Por eso todo lo que queramos que exista *dentro* de
> WinPE (como `startnet.cmd` y `menu.bat`) debe viajar **dentro de
> `boot.wim`**, no simplemente "al lado" en la ISO.

**`winpeshl.exe` — el intérprete de WinPE.**
Es el primer proceso de usuario. Por defecto, si no encuentra un
`winpeshl.ini` personalizado, ejecuta `%SystemRoot%\System32\startnet.cmd`,
es decir, **`X:\Windows\System32\startnet.cmd`**.

**`startnet.cmd` — el guion de arranque (el nuestro).**
Es el punto de entrada del taller. El de serie solo llama a `wpeinit`. El
nuestro (`src\startnet.cmd`) hace cuatro cosas: inicializa el entorno,
espera un poco, **busca `menu.bat` en todas las unidades** y lo ejecuta.
Como sustituimos el original dentro de `boot.wim`, el arranque es automático.

**`wpeinit` — inicialización del entorno.**
Hace el trabajo que en una instalación normal haría la fase *MiniSetup*:
detecta hardware (discos, USB), arranca Plug and Play y levanta la red por
DHCP. Deja su registro en `X:\Windows\System32\wpeinit.log`.

**`oscdimg.exe` — el maestro de la ISO.**
Es la herramienta del Windows ADK que **fabrica la imagen ISO**. Además de
empaquetar los ficheros, graba el **catálogo de arranque El Torito**, que es
lo que permite que una **misma ISO** arranque en equipos antiguos (BIOS
Legacy) y modernos (UEFI). Ver [§6](#6-referencia-de-parámetros-de-oscdimg).

**`etfsboot.com` y `efisys*.bin` — los dos cargadores.**
- `boot\etfsboot.com`: cargador de 16 bits para **BIOS Legacy**.
- `efi\microsoft\boot\efisys*.bin`: imagen FAT que contiene `bootx64.efi`,
  el cargador para **UEFI x64**. La variante `_noprompt` evita el aviso
  *"Press any key to boot from CD or DVD..."* (cómodo en taller).
oscdimg los inserta como **dos entradas** del catálogo El Torito.

### 1.3 Arranque dual en una sola ISO

| Entorno del equipo | Cargador que usa la ISO | Resultado |
|--------------------|-------------------------|-----------|
| BIOS Legacy        | `boot\etfsboot.com`     | `bootmgr` → ramdisk → WinPE |
| UEFI x64           | `efi\...\efisys*.bin`   | `bootmgr`(EFI) → ramdisk → WinPE |

`oscdimg` recibe ambos con un solo parámetro: `-bootdata:2` seguido de las
dos entradas. Eso es lo que hace que no necesitemos **dos ISOs distintas**.

---

## 2. Estructura del repositorio

```
JAH-WinPe/
├─ src/                     Contenido que entra en la imagen WinPE
│  ├─ menu.bat              Interfaz principal (Batch) + diccionarios ES/EN.
│  └─ startnet.cmd          Arranque automático dentro de WinPE.
│
├─ build/                   Utilidades de construcción (no van al ISO)
│  ├─ build_iso.ps1         Compila la ISO con el ADK (oscdimg + DISM).
│  ├─ build_iso.bat         Lanzador cómodo (busca PowerShell, eleva aviso).
│  └─ work/                 (generado) soporte WinPE + punto de montaje.
│
├─ docs/                    Documentación técnica
│  └─ BUILD_GUIDE.md        Este documento (arquitectura + QEMU).
│
├─ README.md                Documentación general (Español, por defecto).
├─ README.en.md             Documentation (English).
├─ .gitignore               Qué NO versionar (ISO, work/, artefactos…).
└─ .gitattributes           Fuerza CRLF en .bat/.cmd/.ps1.
```

> **Nota de diseño:** los README siguen en la **raíz** a propósito: GitHub
> solo renderiza como portada el `README.md` de la raíz. La documentación
> técnica "de verdad" (esta guía) vive en `docs/`.

**Qué acaba dentro de la ISO** (tras la personalización de `boot.wim`):

```
ISO:/ (soporte WinPE)
├─ sources\boot.wim     (modificado)
│  └─ ... X: al arrancar
│     ├─ Windows\System32\startnet.cmd   <- el nuestro (arranque auto)
│     └─ JAH\menu.bat                     <- el nuestro (la herramienta)
├─ boot\                (etfsboot.com, BCD, boot.sdi…)
└─ efi\                 (cargadores UEFI)
```

---

## 3. Requisitos de compilación

Solo para **construir** la ISO (el equipo de destino no necesita nada):

| Requisito | Para qué | Notas |
|-----------|----------|-------|
| **Windows 10/11 (x64)** | Compilar | Linux también puede, pero con otras herramientas (`wimlib`, `xorriso`); fuera del alcance de este script. |
| **Windows ADK** | `oscdimg.exe` | Descarga: <https://learn.microsoft.com/windows-hardware/get-started/adk-install> |
| **Complemento WinPE del ADK** | `copype.cmd` + `winpe.wim` | Se instala **aparte** del ADK (a veces se olvida). |
| **Permisos de Administrador** | Montar `boot.wim` con DISM | Sin elevación, DISM no puede montar. |
| **~2 GB libres** | media + montaje + ISO | El script lo comprueba. |

> **Ojo con el orden de instalación:** instala primero el **ADK** y después
> el **complemento WinPE**. Si haces lo contrario, el instalador del
> complemento puede no encontrar el ADK.

---

## 4. Cómo compilar la ISO

Desde una consola **como Administrador**, en la raíz del repositorio:

```bat
build\build_iso.bat
```

o directamente con PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File build\build_iso.ps1
```

> **Autonomía de entorno (sin "Deployment and Imaging Tools Environment"):**
> `build_iso.ps1` localiza el Windows ADK instalado y carga sus variables
> de entorno (`WinPERoot`, `DISMRoot`, `OSCDImgRoot`) en la
> sesión actual, así que basta con **cualquier consola elevada** (CMD,
> PowerShell o la terminal integrada de VS Code). Además, todas las rutas
> de trabajo (`build\work\`, `media\`, `mount\`) y la ISO de salida se
> resuelven con respecto a la ubicación del repositorio (`$PSScriptRoot` /
> `%~dp0`), sin ninguna ruta fija al Escritorio ni a `C:\Users`. Las
> rutas resueltas se muestran al arrancar el build.

### 4.1 Parámetros de `build_iso.ps1`

| Parámetro | Por defecto | Qué hace |
|-----------|-------------|----------|
| `-Arch` | `amd64` | Arquitectura de la imagen (`amd64` o `arm64`). |
| `-AdkRoot` | autodetectado | Ruta raíz del ADK, si está en un sitio raro. |
| `-WorkRoot` | `build\work` | Carpeta de trabajo (soporte + montaje). |
| `-OutputIso` | `JAH-WinPe.iso` (raíz) | Ruta del ISO final. |
| `-PromptKey` | (desactivado) | UEFI **con** aviso de tecla en vez de arrancar solo. |
| `-Force` | (desactivado) | Borra y regenera `WorkRoot` si ya existía. |

### 4.2 Qué hace por dentro (los 4 PASOS)

1. **Comprobaciones previas:** Windows, Administrador, fuentes presentes,
   ADK (`oscdimg`), complemento WinPE (`copype`), DISM y espacio libre.
   *Si algo falta, **no se toca nada** y se explica qué instalar.*
2. **`copype`:** crea el soporte WinPE limpio en `build\work\media`.
3. **Personalización de `boot.wim` (DISM):** monta la imagen, copia
   `src\startnet.cmd` a `Windows\System32` y `src\menu.bat` a la carpeta
   `JAH\`, y desmonta **guardando** los cambios (*commit*).
4. **`oscdimg`:** maqueta `JAH-WinPe.iso` con **arranque dual** y muestra
   tamaño y **SHA-256**.

### 4.3 Resultado

- `JAH-WinPe.iso` (en la raíz o donde indiques con `-OutputIso`).
- `build\work\media\` — el soporte WinPE ya personalizado (reutilizable).
- `build\work\oscdimg_temp.cmd` — la orden exacta que se usó para el ISO
  (útil para depurar).

---

## 5. Probar la ISO con QEMU en Linux (KVM + OVMF)

Así comprobamos el arranque **sin gastar un equipo ni un pendrive**. QEMU
emula el hardware; **KVM** acelera con virtualización por hardware; **OVMF**
es el firmware **UEFI** de código abierto que usaremos para probar ese modo.

### 5.1 Instalar lo necesario (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install qemu-system-x86 ovmf
# KVM necesita que tu usuario esté en el grupo 'kvm' (repite login después):
sudo usermod -aG kvm "$USER"
```

Localiza los ficheros de OVMF (la ruta cambia según la distribución):

```bash
ls /usr/share/OVMF/ 2>/dev/null
ls /usr/share/edk2/ovmf/ 2>/dev/null   # Fedora, openSUSE…
ls /usr/share/OVMF/OVMF_CODE*.fd /usr/share/OVMF/OVMF_VARS*.fd 2>/dev/null
```

Suelen aparecer dos pares:
- `OVMF_CODE.fd` / `OVMF_VARS.fd` (2 MB).
- `OVMF_CODE_4M.fd` / `OVMF_VARS_4M.fd` (4 MB, más moderno y recomendable).

> **`CODE` vs `VARS`:** `CODE` es el firmware de solo lectura (no se
> modifica). `VARS` guarda las variables UEFI (arranque, Secure Boot…) y por
> eso **debe copiarse** a una ruta escribible antes de arrancar.

### 5.2 Prueba en **BIOS Legacy**

```bash
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4096 \
  -cdrom JAH-WinPe.iso \
  -boot order=d
```

- `-enable-kvm -cpu host`: usa la CPU real (rápido). Si da error, comprueba
  `/dev/kvm` y el grupo `kvm`.
- `-m 4096`: 4 GB de RAM (WinPE vive en RAM; con 2 GB suele bastar, 4 GB
  va cómodo).
- `-cdrom` + `-boot order=d`: arranca desde el lector de DVD virtual.

### 5.3 Prueba en **UEFI** (con OVMF)

```bash
# 1) Copiamos las variables UEFI: se modificarán durante el arranque.
cp /usr/share/OVMF/OVMF_VARS.fd /tmp/OVMF_VARS.fd

# 2) Arrancamos con el firmware UEFI  (ajusta las rutas si usas *_4M.fd)
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd \
  -cdrom JAH-WinPe.iso \
  -boot order=d
```

Si en tu distribución solo hay `*_4M.fd`, cambia ambos ficheros por ellos.
Con `_noprompt` (por defecto del build) la ISO **arranca sola**; si
compilaste con `-PromptKey`, pulsa una tecla en el aviso de UEFI.

### 5.4 Probar la búsqueda de `menu.bat` con un "pendrive" virtual

Para comprobar el paso *"buscar `menu.bat` en cualquier unidad"*, crea una
imagen de disco y pásala como USB:

```bash
# Imagen de 64 MB formateada en FAT32 con menu.bat en su raíz
dd if=/dev/zero of=/tmp/pendrive.img bs=1M count=64
mkfs.vfat -n TALLER /tmp/pendrive.img
# (opcional) copiar menu.bat dentro usando mtools:
sudo apt install mtools
mcopy -i /tmp/pendrive.img src/menu.bat ::/menu.bat
```

Y añade el dispositivo a cualquiera de las órdenes de QEMU:

```bash
  -drive file=/tmp/pendrive.img,format=raw,if=none,id=pendrive \
  -device usb-storage,drive=pendrive
```

Al arrancar, `startnet.cmd` debería encontrar `E:\menu.bat` (o la letra que
asigne) y lanzar la herramienta. **Este es el escenario de taller real.**

### 5.5 Checklist de la prueba

- [ ] La ISO arranca en **BIOS Legacy** y en **UEFI** (misma ISO).
- [ ] Con `_noprompt`, no hay que pulsar tecla en UEFI.
- [ ] Aparece en pantalla `JAH-WinPe: arrancando el menu desde ...`.
- [ ] Se abre `menu.bat` (pantalla de idioma y menú principal).
- [ ] `[1]`/`[2]` listan los discos virtuales de QEMU.
- [ ] Con un pendrive virtual preparado, se lanza desde esa unidad.
- [ ] Sin `menu.bat` en ninguna unidad, aparece el mensaje `[!]` y una
      consola de emergencia.

---

## 6. Referencia de parámetros de oscdimg

La orden que genera `build_iso.ps1` (guardada en `build\work\oscdimg_temp.cmd`):

```bat
"…\oscdimg.exe" -n -lJAHWINPE -m -o -bootdata:2#p0,e,b"…\etfsboot.com"#p0,e,b"…\efisys_noprompt.bin" "…\media" "…\JAH-WinPe.iso"
```

| Parámetro | Significado |
|-----------|-------------|
| `-n` | Permite **nombres de archivo largos** (más allá del formato DOS 8.3) en ISO 9660. |
| `-lJAHWINPE` | **Etiqueta de volumen** de la ISO (lo que se ve como nombre del medio), según la sintaxis `-l<volumeLabel>` de oscdimg. |
| `-m` | Permite imágenes **mayores** de lo que el estándar ISO9660 "clásico" admite. |
| `-o` | **Optimiza** almacenamiento: si hay ficheros repetidos, los guarda una sola vez (típico en WIMs grandes). |
| `-bootdata:…` | Define las **entradas de arranque** (El Torito). Ver desglose abajo. |

### Desglose de `-bootdata:2#p0,e,b"…"#p0,e,b"…"`

```
-bootdata:  2            -> DOS entradas de arranque en el catálogo
            #p0           -> partición 0 de la imagen
               ,e         -> sin emulación de disquete (arranque "nativo")
                 ,b"…"    -> 'b' = boot image; entre comillas, el fichero cargador
```

1.ª entrada → `boot\etfsboot.com` (BIOS Legacy)
2.ª entrada → `efi\microsoft\boot\efisys_noprompt.bin` (UEFI x64, sin aviso)

> Para UEFI **con** aviso de tecla, se usa `efisys.bin`. El script elige la
> variante `_noprompt` salvo que se pase `-PromptKey`.

---

## 7. Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `No encuentro oscdimg.exe` | Falta el **ADK** (Deployment Tools) | Instala el Windows ADK completo. |
| `Te falta el COMPLEMENTO WinPE` | Falta el *WinPE add-on* | Instálalo **después** del ADK. |
| `Se necesita una consola como Administrador` | Consola no elevada | Abre CMD/PowerShell como Administrador. |
| `La carpeta de trabajo ya existe` | Compilación anterior | Añade `-Force` (borra y regenera). |
| `DISM /Mount-Wim fallo` | Imagen ya montada por un fallo previo | Ejecuta `dism /Cleanup-Wim` y reintenta. |
| `No encuentro efisys*.bin` | Deployment Tools incompletas | Reinstala el ADK. |
| La ISO no arranca en UEFI | QEMU sin OVMF, o elegiste arranque BIOS | Usa las órdenes de [§5.3](#53-prueba-en-uefi-con-ovmf). |
| La ISO arranca pero no aparece `menu.bat` | `menu.bat` no se empaquetó | Revisa que existe `src\menu.bat` y recompila. |
| UEFI pide pulsar tecla | `efisys.bin` en vez de `_noprompt` | Recompila sin `-PromptKey`. |

---

> **Recordatorio:** para que el arranque sea automático, `startnet.cmd` debe
> estar **dentro** de `boot.wim` (lo hace el PASO 3). Copiarlo "al lado" en
> la ISO **no funciona**, porque `winpeshl.exe` lo busca en
> `X:\Windows\System32\` — y `X:` sale del `boot.wim`.
