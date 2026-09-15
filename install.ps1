# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raiz del repositorio.

<#
  Arranque de Vibe Coding Skills para Windows (PowerShell 5.1 o superior).

    irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex

  No depende de Node. Su trabajo es:
    1. detectar Windows y su gestor de paquetes (winget, Chocolatey o Scoop),
    2. comprobar que estén Node.js (>=18), npm, npx y git,
    3. si falta algo, PEDIR PERMISO e instalarlo,
    4. y solo entonces ejecutar el instalador real con npx.

  Opciones:
    -v, --version  muestra la version y termina
    --check        solo comprueba el sistema y no instala ni cambia nada
    --sin-node     copia las skills sin Node, sin instalar nada en el sistema
    --global       instala en la carpeta personal: sirve para todos los proyectos
    --local        instala solo en el proyecto actual
    -y, --yes      instala los requisitos que falten sin preguntar
    --no-install   nunca instala nada: solo dice qué falta y cómo instalarlo

  Con `irm ... | iex`, que no admite argumentos, usa las variables de entorno
  equivalentes: VIBE_SKILLS_CHECK, VIBE_SKILLS_SIN_NODE, VIBE_SKILLS_AMBITO,
  VIBE_SKILLS_ASSUME_YES y VIBE_SKILLS_NO_INSTALL.
  Cualquier otra opción se pasa tal cual al instalador (--all, --envs=..., etc.).
#>

$ErrorActionPreference = 'Stop'
$NodeMinimo = 18

# Version de este arranque. Se descarga suelto (irm ... | iex), asi que no puede
# leer package.json: el script scripts/version.sh la mantiene al dia y una
# prueba comprueba que coincida con la del paquete.
$Version = '2.3.0'
# Las variables se llaman VIBE_SKILLS_*; los nombres antiguos AGENT_SKILLS_*
# se siguen aceptando para no romper a quien ya los tenga en un script.
function Get-VarEntorno($nombre, $porDefecto = '') {
    $valor = [System.Environment]::GetEnvironmentVariable("VIBE_SKILLS_$nombre")
    if (-not $valor) { $valor = [System.Environment]::GetEnvironmentVariable("AGENT_SKILLS_$nombre") }
    if ($valor) { return $valor }
    return $porDefecto
}

$Repo = Get-VarEntorno 'REPO' 'github:bigfito/vibe-coding-skills'

$AsumirSi = ((Get-VarEntorno 'ASSUME_YES') -eq '1')
$SinInstalar = ((Get-VarEntorno 'NO_INSTALL') -eq '1')
$SoloComprobar = ((Get-VarEntorno 'CHECK') -eq '1')
$SinNode = ((Get-VarEntorno 'SIN_NODE') -eq '1')
$SnAmbitos = @()
$SnEntornos = @()
$SnSkills = @()
$SnDestino = ''
$SnForzar = $false
$SnSimular = $false
$Ambito = Get-VarEntorno 'AMBITO'
if ($Ambito) { $SnAmbitos = $Ambito -split '[ ,]+' | Where-Object { $_ } }
$RawBase = Get-VarEntorno 'RAW' 'https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main'
$global:SnAqui = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
$ArgsInstalador = @()
foreach ($a in $args) {
    switch -Regex ($a) {
        '^(-v|--version)$' { Write-Host "Vibe Coding Skills v$Version"; exit 0 }
        '^(-y|--yes)$'      { $AsumirSi = $true; $ArgsInstalador += $a }
        '^--no-install$'    { $SinInstalar = $true }
        # Copia las skills sin Node: no instala nada en el sistema.
        '^(--sin-node|--no-node)$' { $SinNode = $true }
        # Ambito de instalacion, tambien para el modo sin Node.
        '^--global$' { $SnAmbitos += 'global'; $ArgsInstalador += $a }
        '^(--local|--proyecto)$' { $SnAmbitos += 'proyecto'; $ArgsInstalador += $a }
        # Estas banderas las entienden los dos caminos: el instalador con Node
        # las recibe tal cual, y el modo sin Node necesita que se traduzcan.
        '^--force$' { $SnForzar = $true; $ArgsInstalador += $a }
        '^--envs=' { $SnEntornos = ($a -replace '^--envs=', '') -split ','; $ArgsInstalador += $a }
        '^--skills=' { $SnSkills = ($a -replace '^--skills=', '') -split ','; $ArgsInstalador += $a }
        '^--dir=' { $SnDestino = ($a -replace '^--dir=', ''); $ArgsInstalador += $a }
        '^--dry-run$' { $SnSimular = $true; $ArgsInstalador += $a }
        '^(--scope=|--ambito=)' {
            $SnAmbitos = ($a -replace '^--(scope|ambito)=', '') -split ',' |
                         ForEach-Object { if ($_ -in @('local', 'project')) { 'proyecto' } else { $_ } }
            $ArgsInstalador += $a
        }
        # Comprobar es mirar, no tocar: --check nunca instala nada.
        '^(--check|--doctor)$' { $SoloComprobar = $true; $ArgsInstalador += $a }
        default             { $ArgsInstalador += $a }
    }
}

# El ambito pedido por variable de entorno se convierte en bandera, para que
# llegue tambien al instalador con Node y no solo al modo sin Node.
if ($Ambito) {
    if ($SnAmbitos -contains 'global' -and -not ($ArgsInstalador -contains '--global')) { $ArgsInstalador += '--global' }
    if ($SnAmbitos -contains 'proyecto' -and -not ($ArgsInstalador -contains '--local')) { $ArgsInstalador += '--local' }
}

# Si la comprobacion se pidio por variable de entorno, el instalador tambien
# tiene que enterarse: sin esto instalaria las skills en vez de solo mirar.
if ($SoloComprobar -and -not ($ArgsInstalador -contains '--check') -and -not ($ArgsInstalador -contains '--doctor')) {
    $ArgsInstalador += '--check'
}

function Escribe-Titulo($t) { Write-Host "`n$t" -ForegroundColor White }
function Escribe-Aviso($t)  { Write-Host "`n$t" -ForegroundColor Yellow }
function Escribe-Error($t)  { Write-Host "`n$t" -ForegroundColor Red }
function Escribe-Cmd($t)    { Write-Host "      $t" -ForegroundColor Green }
function Hay-Comando($c) { $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

# ------------------------------------------------------------------- PATH
# Tras instalar, el PATH del proceso actual sigue siendo el viejo. Lo
# recargamos del registro para no obligar a reabrir la terminal.
function Actualiza-Path {
    try {
        $maquina = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $usuario = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $nuevo = (@($maquina, $usuario) | Where-Object { $_ }) -join ';'
        # Nunca vaciar el PATH: si el registro no da nada, vale más el actual.
        if ($nuevo) { $env:Path = $nuevo }
    } catch {
        # Si no se puede leer el registro, seguimos con el PATH actual.
    }
}

# --------------------------------------------------------- gestor de paquetes

$Gestor = $null
if (Hay-Comando 'winget') {
    $Gestor = @{
        Nombre = 'winget'; Bin = 'winget'
        Instalar = @('install', '-e', '--accept-package-agreements', '--accept-source-agreements', '--id')
        UnoPorUno = $true
        PaqueteNode = 'OpenJS.NodeJS.LTS'; PaqueteGit = 'Git.Git'
    }
} elseif (Hay-Comando 'choco') {
    $Gestor = @{
        Nombre = 'Chocolatey'; Bin = 'choco'; Instalar = @('install', '-y'); UnoPorUno = $false
        PaqueteNode = 'nodejs-lts'; PaqueteGit = 'git'
    }
} elseif (Hay-Comando 'scoop') {
    $Gestor = @{
        Nombre = 'Scoop'; Bin = 'scoop'; Instalar = @('install'); UnoPorUno = $false
        PaqueteNode = 'nodejs-lts'; PaqueteGit = 'git'
    }
}

function Instrucciones-Manuales {
    Write-Host "`n  Instalalo a mano y vuelve a ejecutar este mismo comando:" -ForegroundColor White
    Write-Host "`n   1) Node.js"
    Escribe-Cmd 'winget install OpenJS.NodeJS.LTS'
    Write-Host "      o descarga el .msi LTS desde https://nodejs.org/es/download"
    Write-Host "`n   2) git"
    Escribe-Cmd 'winget install Git.Git'
    Write-Host "      o descargalo de https://git-scm.com/downloads"
    Write-Host "`n   Si winget no existe, instala 'Instalador de aplicaciones' desde Microsoft Store."
    Write-Host "`n  Importante: cierra y vuelve a abrir PowerShell despues de instalar," -ForegroundColor Yellow
    Write-Host "  para que el PATH se actualice.`n" -ForegroundColor Yellow
}

# ------------------------------------------------------------- modo sin Node
#
# Las skills son archivos de texto: Node solo hace falta para el menu. La
# logica vive en lib/sin-node.ps1, que se usa del disco si hay una copia del
# repositorio y, si no, se descarga.

function Import-SinNode {
    if ($global:SnAqui) {
        $local = Join-Path $global:SnAqui 'lib\sin-node.ps1'
        if (Test-Path $local) { . $local; return $true }
    }
    $temporal = Join-Path ([System.IO.Path]::GetTempPath()) 'vibe-coding-skills-sin-node.ps1'
    try {
        Invoke-WebRequest -UseBasicParsing "$RawBase/lib/sin-node.ps1" -OutFile $temporal
        . $temporal
        return $true
    } catch {
        return $false
    }
}

# Propone el modo sin Node como salida a un callejon sin salida.
function Invoke-OfrecerSinNode {
    if ($SoloComprobar) { return $false }

    Write-Host "`n  Hay otra salida: puedo instalar las skills sin Node."
    Write-Host "  Son archivos de texto; las copio en tu proyecto y no instalo nada en el sistema."

    if (-not $SinNode -and -not $AsumirSi) {
        if (-not (Hay-Terminal)) { return $false }
        if (-not (Confirmar 'Las instalo asi?')) { return $false }
    }

    if (-not (Import-SinNode)) {
        Escribe-Error "  No se pudo cargar el modo sin Node."
        return $false
    }
    return (Invoke-ModoSinNode -Ambitos $SnAmbitos -Entornos $SnEntornos -Skills $SnSkills -Destino $SnDestino -Forzar:$SnForzar -Asumir:$AsumirSi -Simular:$SnSimular)
}

# ------------------------------------------------------- comprobar requisitos

function Comprueba-Requisitos {
    $faltantes = @()
    $paquetes = @()

    if (-not (Hay-Comando 'node')) {
        $faltantes += 'Node.js: no esta instalado'
        if ($Gestor) { $paquetes += $Gestor.PaqueteNode }
    } else {
        $version = (node --version) -replace '^v', ''
        $mayor = 0
        [void][int]::TryParse(($version -split '\.')[0], [ref]$mayor)
        if ($mayor -lt $NodeMinimo) {
            $faltantes += "Node.js: version $version, hace falta $NodeMinimo o superior"
            if ($Gestor) { $paquetes += $Gestor.PaqueteNode }
        }
    }
    if (-not (Hay-Comando 'npm')) {
        $faltantes += 'npm: no esta instalado'
        if ($Gestor) { $paquetes += $Gestor.PaqueteNode }
    }
    if (-not (Hay-Comando 'npx')) {
        $faltantes += 'npx: no esta instalado (viene con npm)'
        if ($Gestor) { $paquetes += $Gestor.PaqueteNode }
    }
    if (-not (Hay-Comando 'git')) {
        $faltantes += 'git: no esta instalado (npx lo necesita para descargar desde GitHub)'
        if ($Gestor) { $paquetes += $Gestor.PaqueteGit }
    }

    return @{ Faltantes = $faltantes; Paquetes = ($paquetes | Select-Object -Unique) }
}

# ------------------------------------------------------------ consentimiento
# Con `irm ... | iex` no hay stdin utilizable: se pregunta por la consola real.

function Hay-Terminal {
    try { return -not [System.Console]::IsInputRedirected } catch { return $false }
}

function Confirmar($pregunta) {
    Write-Host "`n  $pregunta " -NoNewline
    Write-Host "[S/n] " -NoNewline -ForegroundColor DarkGray
    $r = ''
    try { $r = [System.Console]::ReadLine() } catch { return $false }
    if ($null -eq $r) { return $false }
    return ($r.Trim().ToLower() -in @('', 's', 'si', 'sí', 'y', 'yes'))
}

# -------------------------------------------------------------------- arranque

Escribe-Titulo "Vibe Coding Skills - comprobando el entorno"
Write-Host "  Sistema: Windows $([System.Environment]::OSVersion.Version.ToString())"
if ($Gestor) { Write-Host "  Gestor:  $($Gestor.Nombre)" }
else { Write-Host "  Gestor:  ninguno conocido" -ForegroundColor Yellow }

# Si se pidio explicitamente, ni siquiera se miran los requisitos.
if ($SinNode) {
    if (-not (Import-SinNode)) { Escribe-Error "  No se pudo cargar el modo sin Node."; exit 1 }
    if (Invoke-ModoSinNode -Ambitos $SnAmbitos -Entornos $SnEntornos -Skills $SnSkills -Destino $SnDestino -Forzar:$SnForzar -Asumir:$AsumirSi -Simular:$SnSimular) { exit 0 } else { exit 1 }
}

$estado = Comprueba-Requisitos

if ($estado.Faltantes.Count -gt 0) {
    Escribe-Aviso "  Faltan requisitos para poder continuar:"
    foreach ($f in $estado.Faltantes) { Write-Host "   - $f" }

    if (-not $Gestor) {
        Escribe-Error "  No encontre winget, Chocolatey ni Scoop, asi que no puedo instalarlos por ti."
        if (Invoke-OfrecerSinNode) { exit 0 }
        Instrucciones-Manuales
        exit 1
    }

    $ordenes = @()
    if ($Gestor.UnoPorUno) {
        foreach ($p in $estado.Paquetes) { $ordenes += ,($Gestor.Instalar + $p) }
    } else {
        $ordenes += ,($Gestor.Instalar + $estado.Paquetes)
    }

    Write-Host "`n  Puedo instalarlos con $($Gestor.Nombre):"
    foreach ($o in $ordenes) { Escribe-Cmd "$($Gestor.Bin) $($o -join ' ')" }

    if ($SoloComprobar) {
        Escribe-Aviso "  Esto era solo una comprobacion: no se instalo nada."
        Write-Host "  Para que los instale, repite el comando sin --check.`n"
        exit 1
    }

    if ($SinInstalar) {
        Escribe-Aviso "  Instalacion automatica desactivada (--no-install)."
        Instrucciones-Manuales
        exit 1
    }

    if (-not $AsumirSi) {
        if (-not (Hay-Terminal)) {
            Escribe-Error "  No hay terminal interactiva para pedirte permiso."
            Write-Host "  Vuelve a ejecutarlo anadiendo " -NoNewline
            Write-Host "--yes" -NoNewline -ForegroundColor Green
            Write-Host " para autorizar la instalacion."
            Instrucciones-Manuales
            exit 1
        }
        if (-not (Confirmar 'Los instalo ahora?')) {
            Escribe-Aviso "  No se instalo nada."
            if (Invoke-OfrecerSinNode) { exit 0 }
            Instrucciones-Manuales
            exit 1
        }
    }

    Write-Host "`n  Instalando..." -ForegroundColor White
    foreach ($o in $ordenes) {
        Write-Host "    $ $($Gestor.Bin) $($o -join ' ')" -ForegroundColor DarkGray
        & $Gestor.Bin @o
        if ($LASTEXITCODE -ne 0) {
            Escribe-Error "  La instalacion fallo (codigo $LASTEXITCODE)."
            if (Invoke-OfrecerSinNode) { exit 0 }
            Instrucciones-Manuales
            exit 1
        }
    }

    Actualiza-Path

    # Lo que vale no es que el gestor dijera "ok", sino que ahora existan de verdad.
    $estado = Comprueba-Requisitos
    if ($estado.Faltantes.Count -gt 0) {
        Escribe-Error "  Se instalo, pero todavia falta:"
        foreach ($f in $estado.Faltantes) { Write-Host "   - $f" }
        Write-Host "`n  Cierra y vuelve a abrir PowerShell para que el PATH se actualice," -ForegroundColor Yellow
        Write-Host "  y repite este mismo comando.`n" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "`n  Listo: todos los requisitos estan instalados." -ForegroundColor Green
}

Write-Host "  Node.js: $((node --version) -replace '^v','')"
Write-Host "  npx:     $(npx --version 2>$null)"
Write-Host "  git:     $((git --version) -replace '^git version ','')"

Write-Host "`n  Todo listo. Iniciando el instalador..." -ForegroundColor Green
& npx -y $Repo @ArgsInstalador
exit $LASTEXITCODE
