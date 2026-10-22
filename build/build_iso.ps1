#Requires -Version 5.1
<#
.SYNOPSIS
    JAH-WinPe - Compila la ISO de arranque (Fase 3).

.DESCRIPTION
    Automatiza la construccion de 'JAH-WinPe.iso': una imagen que arranca
    en UEFI x64 y en BIOS Legacy (ARRANQUE DUAL) y que ejecuta 'menu.bat'
    automaticamente al entrar en Windows PE (WinPE).

    QUE HACE, EN ORDEN:
      PASO 1  Comprueba el terreno antes de tocar nada:
                - que estamos en Windows y como Administrador,
                - que existe el Windows ADK (oscdimg.exe),
                - que existe el complemento WinPE (copype.cmd),
                - que existen las fuentes del proyecto (src\*.bat/cmd).
      PASO 2  Crea un soporte WinPE LIMPIO con 'copype' (carpeta media).
      PASO 3  Personaliza 'boot.wim' (hay que MONTARLO con DISM):
                - inyecta los componentes opcionales de WinPE (WMI, .NET,
                  Scripting, PowerShell y StorageWMI),
                - mete src\startnet.cmd en Windows\System32 -> arranque auto,
                - mete src\menu.bat en la carpeta JAH\ -> X:\JAH\menu.bat.
      PASO 4  Maqueta la ISO con 'oscdimg' en modo arranque dual.

    POR QUE HAY QUE MONTAR boot.wim:
      El disco X: de WinPE NO es un disco fisico: es un disco VIRTUAL en
      RAM que se rellena con el contenido de 'sources\boot.wim'. Por eso,
      para que startnet.cmd y menu.bat existan en X:, deben estar DENTRO
      de boot.wim. Se mete contenido en un WIM montandolo con DISM.

.PARAMETER Arch
    Arquitectura de la imagen: 'amd64' (x64, lo habitual) o 'arm64'.

.PARAMETER AdkRoot
    Carpeta raiz del Windows ADK. Normalmente NO hace falta indicarla:
    el script la busca en las rutas de instalacion tipicas. Usalo solo si
    instalaste el ADK en una ruta poco habitual.

.PARAMETER WorkRoot
    Carpeta de trabajo (soporte WinPE + punto de montaje). Por defecto:
    'build\work'. Se puede borrar sin miedo: se regenera entera.

.PARAMETER OutputIso
    Ruta del ISO final. Por defecto: 'JAH-WinPe.iso' en la raiz del
    repositorio (facil de encontrar y de arrancar en QEMU).

.PARAMETER PromptKey
    Fuerza el arranque UEFI CON aviso ("Press any key to boot..."). Por
    defecto se usa la variante SIN aviso ('efisys_noprompt.bin'), que es
    lo comodo en el taller: enciende y arranca solo.

.PARAMETER Force
    Borra y regenera la carpeta de trabajo si ya existia (evita el error
    de 'ya existe'). Sin este parametro, el script se detiene y avisa,
    para no destruir nunca una compilacion a medias sin permiso.

.EXAMPLE
    .\build_iso.bat
    Compila con los valores por defecto (amd64, arranque sin tecla).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build_iso.ps1 -Force
    Regenera la carpeta de trabajo desde cero.

.EXAMPLE
    .\build_iso.ps1 -Arch amd64 -OutputIso D:\isos\JAH-WinPe.iso -PromptKey
    ISO en otra ruta y con aviso de tecla en UEFI.

.NOTES
    Requisitos en el equipo de compilacion (no en el equipo de destino):
      - Windows 10 / 11 (64 bits).
      - Windows ADK  -> aporta oscdimg.exe (Deployment Tools).
      - Complemento WinPE del ADK -> aporta copype.cmd y winpe.wim.
      - Permisos de Administrador (DISM monta imagenes; es obligatorio).
    Documentacion ampliada: docs\BUILD_GUIDE.md

    AUTONOMIA DE ENTORNO: no hace falta abrir la consola "Deployment and
    Imaging Tools Environment" del ADK. El script localiza el ADK
    instalado y el mismo carga sus variables de entorno (WinPERoot,
    DISMRoot, OSCDImgRoot) en la sesion actual, asi que funciona
    desde cualquier terminal elevada (CMD, PowerShell o la terminal
    integrada de VS Code).

    SOBRE LOS ACENTOS: este script y build_iso.bat estan escritos en ASCII
    puro (sin tildes) a proposito, para funcionar igual bajo cualquier
    pagina de codigos y sin depender del BOM. Es una decision de
    portabilidad, no un olvido: el texto imprimible de la herramienta
    (menu.bat) si lleva acentos porque controla el suyo con 'chcp'.
#>

[CmdletBinding()]
param(
    [ValidateSet('amd64', 'arm64')]
    [string]$Arch = 'amd64',

    [string]$AdkRoot,
    [string]$WorkRoot,
    [string]$OutputIso,
    [switch]$PromptKey,
    [switch]$Force
)

# =====================================================================
#  CONFIGURACION GENERAL Y RUTAS
# =====================================================================
#  $ErrorActionPreference = 'Stop' hace que cualquier error de PowerShell
#  detenga el script inmediatamente. Es lo contrario de lo que queremos
#  en menu.bat (que jamas se cierra solo), pero aqui es correcto: si algo
#  falla en una compilacion, preferimos parar antes de generar un ISO a
#  medias que parezca bueno.
$ErrorActionPreference = 'Stop'

#  Etiqueta de volumen de la ISO. Limite practico: sin espacios y corta
#  (ISO9660 admite 32 caracteres, pero los grabadores antiguos prefieren
#  pocos y en mayusculas). Se ve en 'dir' de la unidad y en las propiedades.
$NombreVolumen = 'JAHWINPE'

#  Fuentes del proyecto. $PSScriptRoot es la carpeta de ESTE script
#  (build\), asi que un nivel arriba esta la raiz del repositorio.
$DirProyecto  = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$FuenteMenu   = Join-Path $DirProyecto 'src\menu.bat'
$FuenteStart  = Join-Path $DirProyecto 'src\startnet.cmd'

#  Valores por defecto si el usuario no pasa parametros.
if (-not $WorkRoot)  { $WorkRoot  = Join-Path $PSScriptRoot 'work' }
if (-not $OutputIso) { $OutputIso = Join-Path $DirProyecto 'JAH-WinPe.iso' }

#  Normalizamos a rutas absolutas (por si el usuario uso rutas relativas).
$WorkRoot  = [IO.Path]::GetFullPath($WorkRoot)
$OutputIso = [IO.Path]::GetFullPath($OutputIso)

#  Subcarpetas de trabajo que crea copype y que usaremos despues.
$DirMedia = Join-Path $WorkRoot 'media'   # soporte WinPE (lo que va al ISO)
$DirMount = Join-Path $WorkRoot 'mount'   # punto de montaje temporal de DISM
$RutaWim  = Join-Path $DirMedia 'sources\boot.wim'

# ---------------------------------------------------------------------
#  Ayudantes de salida por pantalla.
#  Se separan en funciones para que el flujo principal se lea como una
#  lista de PASOS y no como un muro de Write-Host.
#
#  NOTA PSScriptAnalyzer: la regla PSUseApprovedVerbs avisa que
#  'Escribir' no es un verbo de la lista oficial (Get-Verb, inglesa).
#  Se silencia a proposito en cada funcion con SuppressMessageAttribute
#  porque la convencion de nombres ES/EN de toda la suite (menu.bat,
#  build_iso.ps1...) es intencionada y se mantiene en espanol.
# ---------------------------------------------------------------------
function Escribir-Paso {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Verbo en espanol intencionado: convencion ES/EN del proyecto.')]
    param([int]$Numero, [int]$Total, [string]$Texto)
    Write-Host ''
    Write-Host ('=== PASO {0}/{1} : {2} ===' -f $Numero, $Total, $Texto) -ForegroundColor Cyan
}
function Escribir-Ok {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Verbo en espanol intencionado: convencion ES/EN del proyecto.')]
    param([string]$T)
    Write-Host "  [OK] $T" -ForegroundColor Green
}
function Escribir-Info {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Verbo en espanol intencionado: convencion ES/EN del proyecto.')]
    param([string]$T)
    Write-Host "  [..] $T" -ForegroundColor Gray
}
function Escribir-Aviso {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Verbo en espanol intencionado: convencion ES/EN del proyecto.')]
    param([string]$T)
    Write-Host "  [!]  $T" -ForegroundColor Yellow
}
function Fallar {
    param([string]$Texto)
    Write-Host ''
    Write-Host "ERROR: $Texto" -ForegroundColor Red
    Write-Host ''
    exit 1
}

# ---------------------------------------------------------------------
#  BLINDAJE ANTE RUTAS FANTASMA (regla anti hardcode del proyecto)
#  REGLA: work, media, mount y el ISO final nacen SIEMPRE de
#  $PSScriptRoot (la carpeta de ESTE script), no de ninguna variable de
#  entorno heredada, del Escritorio ni de 'C:\Users\...'. Las UNICAS
#  rutas que pueden salirse del repositorio son las que el usuario pasa
#  a mano con -WorkRoot o -OutputIso; este aviso existe para que una
#  ruta "fantasma" jamas pase inadvertida en la primera pantalla.
# ---------------------------------------------------------------------
if (-not $WorkRoot.StartsWith($DirProyecto, [StringComparison]::OrdinalIgnoreCase)) {
    Escribir-Aviso "WorkRoot queda fuera del repositorio (valor explicito del usuario): $WorkRoot"
}
if (-not $OutputIso.StartsWith($DirProyecto, [StringComparison]::OrdinalIgnoreCase)) {
    Escribir-Aviso "OutputIso queda fuera del repositorio (valor explicito del usuario): $OutputIso"
}

# =====================================================================
#  PASO 1/4 - COMPROBACIONES PREVIAS (nada se toca todavia)
# =====================================================================
Escribir-Paso 1 4 'Comprobaciones previas (permisos, ADK y fuentes)'

#  1.a) Sistema operativo.
if ($env:OS -ne 'Windows_NT') {
    Fallar 'Este script solo funciona en Windows (necesita el ADK de Microsoft).'
}
Escribir-Ok 'Sistema operativo: Windows.'

#  1.b) Permisos de Administrador. DISM no puede montar imagenes sin
#       privilegios elevados, y montar a medias dejaria ficheros sueltos.
$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
$esAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Fallar ('Se necesita una consola como Administrador. Cierra esta ventana y ' +
            'abre "Simbolo del sistema (Administrador)" o "Windows PowerShell (Administrador)".')
}
Escribir-Ok 'Permisos: Administrador.'

#  1.c) Fuentes del proyecto. Sin ellas no hay nada que empaquetar.
foreach ($f in @($FuenteMenu, $FuenteStart)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Fallar "Falta un fichero fuente obligatorio: $f"
    }
}
Escribir-Ok 'Fuentes encontradas (src\menu.bat y src\startnet.cmd).'

#  Rutas RESUELTAS en pantalla desde el principio: si alguna vez
#  apareciera aqui una ruta inesperada (Escritorio, C:\Users\...), se
#  veria de inmediato. Todas nacen de $PSScriptRoot.
Escribir-Info "Raiz del repositorio : $DirProyecto"
Escribir-Info "Carpeta de trabajo   : $WorkRoot"
Escribir-Info "ISO de salida        : $OutputIso"

#  1.d) Localizar el Windows ADK. El ADK se instala, por defecto, en
#       '%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit'.
#       Probamos varias raices porque no todos los equipos son iguales.
$RaicesAdk = @()
if ($AdkRoot) { $RaicesAdk += $AdkRoot }
if (${env:ProgramFiles(x86)}) { $RaicesAdk += (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Assessment and Deployment Kit') }
if ($env:ProgramFiles)       { $RaicesAdk += (Join-Path $env:ProgramFiles       'Windows Kits\10\Assessment and Deployment Kit') }

$RutaOscdimg = $null
$RutaCopype  = $null
#  Raiz del ADK de la que salga el hallazgo: luego nos servira para
#  cargar las variables de entorno del ADK en esta sesion (ver 1.g).
$RaizAdkActiva = $null
foreach ($raiz in $RaicesAdk) {
    if (-not (Test-Path -LiteralPath $raiz)) { continue }
    #  oscdimg.exe vive en 'Deployment Tools\<arch>\Oscdimg'. Si no esta
    #  para nuestra arquitectura, probamos la version x86 del kit, que
    #  genera exactamente el mismo ISO.
    if (-not $RutaOscdimg) {
        $p = Join-Path $raiz "Deployment Tools\$Arch\Oscdimg\oscdimg.exe"
        if (Test-Path -LiteralPath $p) { $RutaOscdimg = $p }
    }
    if (-not $RutaOscdimg) {
        $p = Join-Path $raiz 'Deployment Tools\x86\Oscdimg\oscdimg.exe'
        if (Test-Path -LiteralPath $p) { $RutaOscdimg = $p }
    }
    #  copype.cmd vive en la raiz del complemento WinPE del ADK.
    if (-not $RutaCopype) {
        $p = Join-Path $raiz 'Windows Preinstallation Environment\copype.cmd'
        if (Test-Path -LiteralPath $p) { $RutaCopype = $p }
    }
    if (-not $RaizAdkActiva) { if ($RutaOscdimg -or $RutaCopype) { $RaizAdkActiva = $raiz } }
    if ($RutaOscdimg -and $RutaCopype) { break }
}

if (-not $RutaOscdimg) {
    Fallar ('No encuentro oscdimg.exe. Instala el "Windows ADK" (incluye las ' +
            'Deployment Tools) o indica la ruta con -AdkRoot. Descarga: ' +
            'https://learn.microsoft.com/windows-hardware/get-started/adk-install')
}
Escribir-Ok "oscdimg: $RutaOscdimg"

if (-not $RutaCopype) {
    Fallar ('No encuentro copype.cmd. Te falta el COMPLEMENTO WinPE del ADK ' +
            '(se instala aparte del ADK: "Windows PE add-on for the ADK").')
}
Escribir-Ok "copype : $RutaCopype"

#  1.e) DISM (viene con Windows; tambien con el ADK). Sirve para montar
#       boot.wim y copiarle dentro nuestros ficheros.
$RutaDism = Join-Path $env:SystemRoot 'System32\dism.exe'
if (-not (Test-Path -LiteralPath $RutaDism)) {
    $cmd = Get-Command dism.exe -ErrorAction SilentlyContinue
    if ($cmd) { $RutaDism = $cmd.Source } else { Fallar 'No encuentro dism.exe.' }
}
Escribir-Ok "dism   : $RutaDism"

#  1.f) Espacio libre. Necesitamos: soporte WinPE (~600 MB) + copia de la
#       imagen montada (~600 MB) + el ISO final (~600 MB). Pedimos 2 GB
#       de margen para no quedarnos a medias.
$letraTrabajo = [IO.Path]::GetPathRoot($WorkRoot)
try {
    $unidad  = New-Object IO.DriveInfo($letraTrabajo)
    $libreGB = [math]::Round($unidad.AvailableFreeSpace / 1GB, 1)
    if ($libreGB -lt 2) {
        Fallar "Poco espacio libre en $letraTrabajo ($libreGB GB). Se necesitan al menos 2 GB."
    }
    Escribir-Ok "Espacio libre en $letraTrabajo : $libreGB GB."
} catch {
    Escribir-Aviso "No he podido comprobar el espacio libre en $letraTrabajo."
}

# =====================================================================
#  1.g) ENTORNO DEL ADK EN ESTA SESION (autonomia desde cualquier terminal)
# =====================================================================
#  POR QUE EXISTE ESTE BLOQUE (y por que NO se llama a DandISetEnv.bat):
#
#  La "Deployment and Imaging Tools Environment" del ADK no es mas que
#  un atajo de Windows que ejecuta 'DandISetEnv.bat', un .bat que define
#  las variables WinPERoot, DandIRoot, DISMRoot y OSCDImgRoot, y antepone
#  las carpetas de oscdimg al PATH... pero lo hace en la SESION de cmd
#  que lo ejecuta. En PowerShell, invocar un .bat (incluso con '&') o
#  lanzarlo "en segundo plano" lanza un cmd.exe HIJO: cuando ese hijo
#  termina, su entorno se descarta y no llega a una sola linea de este
#  proceso. Es decir: llamarlo no sirve de nada.
#
#  LA SOLUCION CORRECTA EN POWERSHELL: detectar la raiz del ADK (paso
#  1.d) y asignar las MISMAS variables directamente en el ambito '$env:'
#  de ESTE proceso. Todos los procesos que lancemos a continuacion
#  (copype.cmd, oscdimg.exe, dism.exe) HEREDAN ese entorno, porque en
#  Windows un proceso hijo hereda las variables de su padre.
#
#  VENTAJA DOBLE: al fijarlas nosotros desde la instalacion detectada,
#  el build funciona desde cualquier terminal (CMD, PowerShell, VS
#  Code...) Y queda INMUNE a valores fantasma heredados de sesiones
#  anteriores (por ejemplo un 'WinPERoot' viejo que apuntara a una copia
#  del kit en el Escritorio): se sobrescriben SIEMPRE con la ruta
#  correcta del ADK instalado en este equipo.
#
#  NOTA SOBRE 'WinPERoot' (fallo corregido): esta variable NO apunta a
#  la raiz del ADK ('...\Assessment and Deployment Kit') sino estricta-
#  mente a la subcarpeta del complemento de WinPE:
#      ...\Assessment and Deployment Kit\Windows Preinstallation Environment
#  Motivo (verificado leyendo el 'copype.cmd' del ADK instalado):
#    linea 21 : set SOURCE=%WinPERoot%\%WINPE_ARCH%
#               -> si 'WinPERoot' fuera la raiz del ADK, copype
#               buscaria '...\Assessment and Deployment Kit\amd64'
#               (inexistente) y abortaria con "architecture was not
#               found". Con este valor resuelve
#               '...\Windows Preinstallation Environment\amd64'.
#    linea 22 : set FWFILESROOT=%OSCDImgRoot%\..\..\%WINPE_ARCH%\Oscdimg
#               -> exige que 'OSCDImgRoot' este definida.
#    linea 123: "%DISMRoot%\Dism.exe" /Mount-Image ...
#               -> exige que 'DISMRoot' este definida.
#  Por eso se replican AQUI las variables canonicas que define el
#  'DandISetEnv.bat' oficial del ADK (leido en este equipo), con los
#  mismos valores:
#      WinPERoot   = <ADK>\Windows Preinstallation Environment
#      DandIRoot   = <ADK>\Deployment Tools
#      DISMRoot    = DandIRoot\<arquitectura nativa>\DISM
#      OSCDImgRoot = DandIRoot\<arquitectura nativa>\Oscdimg
# ---------------------------------------------------------------------
if (-not $RaizAdkActiva) {
    Fallar 'No se pudo determinar la raiz del ADK para cargar su entorno.'
}

#  Carpeta del complemento WinPE dentro del ADK detectado (madre de la
#  estructura amd64/x86 que consume copype).
$DirWinPEAdk = Join-Path $RaizAdkActiva 'Windows Preinstallation Environment'
$DirToolsAdk = Join-Path $RaizAdkActiva 'Deployment Tools'

#  Arquitectura nativa del equipo. Misma logica que DandISetEnv.bat: si
#  este proceso PowerShell corriera en 32 bits sobre Windows de 64 bits,
#  se usa la arquitectura REAL (PROCESSOR_ARCHITEW6432) para no
#  apuntar a la carpeta x86 de las herramientas por equivocacion.
$ArqNat = $env:PROCESSOR_ARCHITECTURE
if ($ArqNat -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432) { $ArqNat = $env:PROCESSOR_ARCHITEW6432 }

#  WinPERoot -> subcarpeta del complemento WinPE (VER NOTA ARRIBA).
$env:WinPERoot   = $DirWinPEAdk
$env:DandIRoot   = $DirToolsAdk
$env:DISMRoot    = Join-Path $DirToolsAdk "$ArqNat\DISM"
$env:OSCDImgRoot = Join-Path $DirToolsAdk "$ArqNat\Oscdimg"

#  Verificacion temprana: si falta el Dism.exe del ADK que invocara
#  copype (linea 123), es mejor parar aqui con un mensaje claro que
#  dejar que copype falle despues con un error criptico de montaje.
if (-not (Test-Path -LiteralPath (Join-Path $env:DISMRoot 'Dism.exe'))) {
    Fallar ('No encuentro el Dism.exe del ADK en: ' + $env:DISMRoot +
            '. Revisa la instalacion del Windows ADK (Deployment Tools).')
}

#  PATH: se antepanan las herramientas que usa este build (DISM,
#  Oscdimg, BCDBoot) y la carpeta WinPE (donde vive copype.cmd), tal
#  como hace DandISetEnv.bat, para que sean invocables por nombre desde
#  esta sesion sin necesitar el lanzador del ADK. Solo se incluyen
#  carpetas que EXISTAN, y se antepenan (no se anaden al final) para
#  que ganen sobre cualquier copia antigua que hubiera en el PATH.
$dirsPath = @(
    $env:DISMRoot
    $env:OSCDImgRoot
    (Join-Path $DirToolsAdk "$ArqNat\BCDBoot")
    $DirWinPEAdk
    (Split-Path -Parent $RutaOscdimg)   # cubre el caso de oscdimg x86
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
$env:PATH = ($dirsPath -join ';') + ';' + $env:PATH

Escribir-Ok 'Entorno del ADK cargado en esta sesion (sin DandISetEnv.bat):'
Escribir-Info "  WinPERoot   = $env:WinPERoot"
Escribir-Info "  DISMRoot    = $env:DISMRoot"
Escribir-Info "  OSCDImgRoot = $env:OSCDImgRoot"

# =====================================================================
#  1.h) COMPONENTES OPCIONALES DEL ADK (OBLIGATORIOS PARA JAH-WinPe)
# =====================================================================
#  WinPE nace sin WMI, sin .NET y sin PowerShell. menu.bat necesita
#  StorageWMI (Get-Volume, Get-PhysicalDisk, Optimize-Volume) para la
#  Opcion 2; por eso estos CABs deben entrar en boot.wim durante ESTE
#  build. Si faltan, la ISO se generaria con la Opcion 2 bloqueada.
#
#  Nombres reales del ADK: no existe un unico 'WinPE-Scripting-PowerShell.cab'.
#  El motor de PowerShell se reparte en DOS paquetes (WinPE-Scripting.cab
#  y WinPE-PowerShell.cab) y ambos son obligatorios. Se instalan en orden
#  de dependencias: WMI -> .NET -> Scripting -> PowerShell -> StorageWMI.
$PaquetesWinPE = @(
    'WinPE-WMI'
    'WinPE-NetFX'
    'WinPE-Scripting'
    'WinPE-PowerShell'
    'WinPE-StorageWMI'
)

#  Busqueda dinamica de WinPE_OCs. La ruta estandar del ADK es:
#    <ADK>\Windows Preinstallation Environment\<arch>\WinPE_OCs
#  Se anaden las raices ya detectadas y KITSROOT (si el ADK la define),
#  para no depender de una unica instalacion ni de una ruta fija.
$CandidatosOcs = @(
    (Join-Path $DirWinPEAdk "$Arch\WinPE_OCs")
)
foreach ($raiz in $RaicesAdk) {
    $CandidatosOcs += (Join-Path $raiz "Windows Preinstallation Environment\$Arch\WinPE_OCs")
}
if ($env:KITSROOT) {
    $CandidatosOcs += (Join-Path $env:KITSROOT "Assessment and Deployment Kit\Windows Preinstallation Environment\$Arch\WinPE_OCs")
    $CandidatosOcs += (Join-Path $env:KITSROOT "Windows Preinstallation Environment\$Arch\WinPE_OCs")
}
$CandidatosOcs = $CandidatosOcs | Select-Object -Unique
$DirOcs = $CandidatosOcs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $DirOcs) {
    Escribir-Aviso 'No encuentro la carpeta WinPE_OCs del complemento WinPE del ADK.'
    Escribir-Aviso 'Rutas comprobadas:'
    foreach ($candidato in $CandidatosOcs) {
        Escribir-Aviso "  $candidato"
    }
    Fallar ('Sin WinPE_OCs no se pueden inyectar los CABs de WMI, .NET, ' +
            'Scripting, PowerShell y StorageWMI. La ISO arrancaria, pero la ' +
            'Opcion 2 (sanitizacion PowerShell/StorageWMI) quedaria bloqueada. ' +
            'Instala el complemento WinPE completo del ADK o indica su raiz con -AdkRoot.')
}

#  Comprobacion temprana de los CABs: mejor abortar antes de copype que
#  montar boot.wim, fallar a mitad y dejar una compilacion a medias.
$CabsFaltantes = @()
foreach ($paq in $PaquetesWinPE) {
    $cab = Join-Path $DirOcs ($paq + '.cab')
    if (-not (Test-Path -LiteralPath $cab)) {
        $CabsFaltantes += $cab
    }
}
if ($CabsFaltantes.Count -gt 0) {
    Escribir-Aviso 'La carpeta WinPE_OCs existe, pero faltan CABs obligatorios:'
    foreach ($cab in $CabsFaltantes) {
        Escribir-Aviso "  $cab"
    }
    Fallar ('El complemento WinPE del ADK esta incompleto. Reinstalalo con ' +
            'los componentes opcionales o usa una instalacion completa. Sin ' +
            'estos CABs, la Opcion 2 no puede ejecutar PowerShell/StorageWMI.')
}

Escribir-Ok "WinPE_OCs: $DirOcs"
Escribir-Info ("CABs para la ISO: " + ($PaquetesWinPE -join ', '))

# =====================================================================
#  PASO 2/4 - CREAR EL SOPORTE WinPE LIMPIO (copype)
# =====================================================================
Escribir-Paso 2 4 'Crear el soporte WinPE (copype)'

#  copype.cmd genera una copia "en blanco" del entorno WinPE: la carpeta
#  'media' con boot\, efi\, sources\boot.wim, etc. Partir siempre de cero
#  garantiza que no se cuelan restos de una compilacion anterior.
if (Test-Path -LiteralPath $WorkRoot) {
    if ($Force) {
        Escribir-Aviso "Borrando la carpeta de trabajo anterior: $WorkRoot"
        Remove-Item -LiteralPath $WorkRoot -Recurse -Force
    } else {
        Fallar ("La carpeta de trabajo ya existe: $WorkRoot`n" +
                '         Usa -Force para borrarla y regenerar (o borrala a mano).')
    }
}
#  NO se pre-crea $WorkRoot aqui: 'copype <arch> <raiz>' exige que su
#  destino NO exista (la linea 59 de copype.cmd aborta con "Destination
#  directory exists") y el propio copype crea la raiz con su estructura
#  interior: <raiz>\media, <raiz>\mount y <raiz>\bootbins.
#  Antes se pasaba $DirMedia como raiz y todo quedaba anidado un nivel
#  de mas (work\media\media\sources\boot.wim); el script buscaba en
#  work\media\sources\boot.wim y abortaba con "no ha creado boot.wim".

Escribir-Info "Ejecutando: copype $Arch `"$WorkRoot`""
& $RutaCopype $Arch $WorkRoot
if ($LASTEXITCODE -ne 0) {
    Fallar "copype ha devuelto el codigo de error $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $RutaWim)) {
    Fallar "copype termino pero no ha creado boot.wim: $RutaWim"
}
Escribir-Ok 'Soporte WinPE creado (media\sources\boot.wim).'

# =====================================================================
#  PASO 3/4 - PERSONALIZAR boot.wim (startnet.cmd + menu.bat)
# =====================================================================
Escribir-Paso 3 4 'Personalizar boot.wim (startnet.cmd + menu.bat)'

New-Item -ItemType Directory -Path $DirMount -Force | Out-Null

$montado       = $false   # marca si DISM dejo la imagen montada
$okCopias      = $false   # marca si las copias salieron bien
$mensajeError  = $null

try {
    #  Montar = "abrir" el WIM como si fuese una carpeta normal. A partir
    #  de aqui, copiar a $DirMount es copiar DENTRO de la imagen.
    #  Indice 1: el soporte WinPE de copype tiene UNA sola imagen dentro.
    Escribir-Info 'Montando boot.wim (indice 1)...'
    & $RutaDism /Mount-Wim /WimFile:$RutaWim /Index:1 /MountDir:$DirMount
    if ($LASTEXITCODE -ne 0) { throw "DISM /Mount-Wim fallo con el codigo $LASTEXITCODE." }
    $montado = $true

    #  3.0) Componentes opcionales de WinPE que necesita el diagnostico.
    #       Sin WinPE-WMI no funcionan wmic ni las clases Win32_*; sin
    #       WinPE-NetFX/WinPE-PowerShell no se puede ejecutar la RAM/SMART
    #       embebidas, y sin WinPE-StorageWMI no existen Get-Volume,
    #       Get-PhysicalDisk ni Optimize-Volume.
    #       $DirOcs y $PaquetesWinPE se resolvieron y validaron en el paso
    #       1.h, ANTES de crear el soporte y de montar boot.wim.
    $totalPaquetes = $PaquetesWinPE.Count
    $numPaquete    = 0
    foreach ($paq in $PaquetesWinPE) {
        $numPaquete++
        $cab = Join-Path $DirOcs ($paq + '.cab')
        Escribir-Info ("Anadiendo componente WinPE {0}/{1}: {2}..." -f $numPaquete, $totalPaquetes, $paq)
        & $RutaDism /Image:$DirMount /Add-Package /PackagePath:$cab
        if ($LASTEXITCODE -ne 0) {
            throw "DISM /Add-Package $paq fallo con el codigo $LASTEXITCODE."
        }
    }
    Escribir-Ok 'Componentes WinPE-WMI/NetFX/Scripting/PowerShell/StorageWMI anadidos.'

    #  3.a) startnet.cmd: sustituye al de serie. winpeshl.exe lo ejecuta
    #       al arrancar, y es lo que lanza menu.bat automaticamente.
    $destinoStart = Join-Path $DirMount 'Windows\System32\startnet.cmd'
    Copy-Item -LiteralPath $FuenteStart -Destination $destinoStart -Force
    Escribir-Ok 'startnet.cmd -> Windows\System32 (arranque automatico).'

    #  3.b) menu.bat dentro de la carpeta JAH del disco X:.
    $dirJah = Join-Path $DirMount 'JAH'
    New-Item -ItemType Directory -Path $dirJah -Force | Out-Null
    Copy-Item -LiteralPath $FuenteMenu -Destination (Join-Path $dirJah 'menu.bat') -Force
    Escribir-Ok 'menu.bat -> carpeta JAH (en ejecucion: X:\JAH\menu.bat).'

    $okCopias = $true
} catch {
    $mensajeError = $_.Exception.Message
} finally {
    #  Pase lo que pase, NUNCA dejamos la imagen montada: si se quedase
    #  a medias, el siguiente montaje fallaria con "ya esta en uso".
    if ($montado) {
        if ($okCopias) {
            Escribir-Info 'Guardando cambios en boot.wim (commit)...'
            & $RutaDism /Unmount-Wim /MountDir:$DirMount /Commit
            if ($LASTEXITCODE -ne 0) {
                Escribir-Aviso 'El desmontaje con guardado fallo. Prueba:  dism /Cleanup-Wim'
                exit 1
            }
            Escribir-Ok 'boot.wim actualizado.'
        } else {
            Escribir-Aviso 'Descartando cambios (las copias fallaron)...'
            & $RutaDism /Unmount-Wim /MountDir:$DirMount /Discard
        }
    }
}

if (-not $okCopias) {
    Fallar "No se pudo personalizar boot.wim: $mensajeError"
}

# =====================================================================
#  PASO 4/4 - MAQUETAR LA ISO (oscdimg, arranque dual BIOS + UEFI)
# =====================================================================
Escribir-Paso 4 4 'Maquetar la ISO (oscdimg, arranque dual BIOS + UEFI)'

#  Para que la MISMA ISO arranque en equipos modernos (UEFI) y antiguos
#  (BIOS Legacy) hay que grabar DOS entradas de arranque en el catalogo
#  El Torito. oscdimg lo hace con el parametro -bootdata:2 y DOS ficheros:
#    - boot\etfsboot.com ....... cargador de BIOS Legacy (16 bits).
#    - efi\...\efisys*.bin ..... imagen FAT con el cargador UEFI (bootx64.efi).
#  Buscamos esos ficheros primero junto a oscdimg.exe (asi vienen en el
#  ADK) y, si no, dentro del propio soporte WinPE.
$DirOscdimg = Split-Path -Parent $RutaOscdimg

$candidatosEtf = @(
    (Join-Path $DirOscdimg 'etfsboot.com')
    (Join-Path $DirMedia   'boot\etfsboot.com')
)
#  La variante '_noprompt' evita el "Press any key to boot from CD..." en
#  UEFI. En un taller queremos que arranque solo; con -PromptKey pedimos
#  la variante con aviso, y si no existe caemos a la normal.
$candidatosEfi = @()
if ($PromptKey) {
    $candidatosEfi += (Join-Path $DirOscdimg 'efisys.bin')
    $candidatosEfi += (Join-Path $DirMedia   'efi\microsoft\boot\efisys.bin')
} else {
    $candidatosEfi += (Join-Path $DirOscdimg 'efisys_noprompt.bin')
    $candidatosEfi += (Join-Path $DirMedia   'efi\microsoft\boot\efisys_noprompt.bin')
    $candidatosEfi += (Join-Path $DirOscdimg 'efisys.bin')
    $candidatosEfi += (Join-Path $DirMedia   'efi\microsoft\boot\efisys.bin')
}

$Etfsboot = $candidatosEtf | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$Efisys   = $candidatosEfi | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $Etfsboot) {
    Fallar ('No encuentro etfsboot.com (cargador BIOS). Reinstala el ADK con ' +
            'las "Deployment Tools".')
}
if (-not $Efisys) {
    Fallar ('No encuentro efisys*.bin (cargador UEFI). Reinstala el ADK con ' +
            'las "Deployment Tools".')
}
Escribir-Ok "BIOS Legacy: $Etfsboot"
Escribir-Ok "UEFI x64   : $Efisys"
if ((-not $PromptKey) -and ((Split-Path -Leaf $Efisys) -eq 'efisys.bin')) {
    Escribir-Aviso 'No habia efisys_noprompt.bin: uso efisys.bin (UEFI pedira pulsar una tecla).'
}

#  Cadena -bootdata. Se lee asi:
#    2                  -> hay DOS entradas de arranque en el catalogo
#    #p0,e,b"fichero"   -> entrada: particion 0 (p0), sin emulacion (e),
#                          imagen de arranque indicada por b (boot image).
#  Primero BIOS (etfsboot.com) y luego UEFI (efisys*.bin): el orden no
#  cambia el resultado, pero deja el catalogo legible.
$bootdata = '2#p0,e,b"{0}"#p0,e,b"{1}"' -f $Etfsboot, $Efisys

#  --- POR QUE GENERAMOS UN .CMD TEMPORAL -----------------------------
#  oscdimg es un .exe nativo y el parametro -bootdata lleva COMILLAS
#  DENTRO y rutas CON espacios ("...Program Files (x86)..."). PowerShell
#  5.1 no escapa bien las comillas embebidas al llamar a programas
#  nativos (las pasa tal cual y cmd.exe las malinterpreta). La forma mas
#  robusta y predecible es escribir la orden exacta en un .cmd temporal y
#  dejar que cmd.exe la ejecute tal cual. Ventaja extra: si algo falla,
#  el .cmd queda en disco y puedes ver/editar la orden real.
$RutaCmdOscdimg = Join-Path $WorkRoot 'oscdimg_temp.cmd'
$lineaOscdimg = '"{0}" -n -l{1} -m -o -bootdata:{2} "{3}" "{4}"' -f `
                $RutaOscdimg, $NombreVolumen, $bootdata, $DirMedia, $OutputIso
$contenidoCmd = @(
    '@echo off',
    'REM Fichero generado por build_iso.ps1 - NO editar a mano.',
    'REM Orden real que maqueta la ISO con arranque dual (BIOS + UEFI):',
    $lineaOscdimg
)
#  -Encoding OEM: en un .cmd NO queremos el BOM de UTF-8 (romperia la
#  primera linea); la pagina de codigos OEM del sistema es lo correcto.
Set-Content -LiteralPath $RutaCmdOscdimg -Value $contenidoCmd -Encoding OEM

Escribir-Info 'Ejecutando oscdimg (esto tarda unos segundos)...'
& $RutaCmdOscdimg
if ($LASTEXITCODE -ne 0) {
    Fallar ("oscdimg fallo con el codigo $LASTEXITCODE. Orden guardada en: " +
            "$RutaCmdOscdimg")
}

if (-not (Test-Path -LiteralPath $OutputIso)) {
    Fallar "oscdimg termino sin errores pero no aparece el ISO: $OutputIso"
}

# =====================================================================
#  RESUMEN FINAL
# =====================================================================
$infoIso = Get-Item -LiteralPath $OutputIso
$hashIso = (Get-FileHash -LiteralPath $OutputIso -Algorithm SHA256).Hash
$tamMB   = [math]::Round($infoIso.Length / 1MB, 1)

Write-Host ''
Write-Host '==================== COMPILACION TERMINADA ====================' -ForegroundColor Green
Write-Host ("  ISO      : {0}" -f $infoIso.FullName)
Write-Host ("  Tamano   : {0} MB" -f $tamMB)
Write-Host ("  Etiqueta : {0}" -f $NombreVolumen)
Write-Host ("  Arranque : BIOS Legacy + UEFI x64 (dual)")
Write-Host ("  SHA-256  : {0}" -f $hashIso)
Write-Host ''
Write-Host '  Siguiente paso: probarlo en una maquina virtual. En Linux, con' -ForegroundColor Gray
Write-Host '  QEMU + OVMF, tienes los comandos en docs\BUILD_GUIDE.md.'      -ForegroundColor Gray
Write-Host ''
exit 0
