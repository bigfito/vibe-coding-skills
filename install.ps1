<#
  Arranque de agent-skills para Windows (PowerShell 5.1 o superior).

    irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex

  No depende de Node. Su trabajo es:
    1. detectar Windows y su gestor de paquetes (winget, Chocolatey o Scoop),
    2. comprobar que estén Node.js (>=18), npm, npx y git,
    3. si falta algo, PEDIR PERMISO e instalarlo,
    4. y solo entonces ejecutar el instalador real con npx.

  Opciones:
    --check        solo comprueba el sistema y no instala ni cambia nada
                   (con `irm ... | iex`, que no admite argumentos, usa en su
                    lugar la variable de entorno AGENT_SKILLS_CHECK=1)
    -y, --yes      instala los requisitos que falten sin preguntar
    --no-install   nunca instala nada: solo dice qué falta y cómo instalarlo
  Cualquier otra opción se pasa tal cual al instalador (--all, --envs=..., etc.).
#>

$ErrorActionPreference = 'Stop'
$NodeMinimo = 18
$Repo = if ($env:AGENT_SKILLS_REPO) { $env:AGENT_SKILLS_REPO } else { 'github:bigfito/vibe-coding-skills' }

$AsumirSi = ($env:AGENT_SKILLS_ASSUME_YES -eq '1')
$SinInstalar = ($env:AGENT_SKILLS_NO_INSTALL -eq '1')
$SoloComprobar = ($env:AGENT_SKILLS_CHECK -eq '1')
$ArgsInstalador = @()
foreach ($a in $args) {
    switch -Regex ($a) {
        '^(-y|--yes)$'      { $AsumirSi = $true; $ArgsInstalador += $a }
        '^--no-install$'    { $SinInstalar = $true }
        # Comprobar es mirar, no tocar: --check nunca instala nada.
        '^(--check|--doctor)$' { $SoloComprobar = $true; $ArgsInstalador += $a }
        default             { $ArgsInstalador += $a }
    }
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

Escribe-Titulo "agent-skills - comprobando el entorno"
Write-Host "  Sistema: Windows $([System.Environment]::OSVersion.Version.ToString())"
if ($Gestor) { Write-Host "  Gestor:  $($Gestor.Nombre)" }
else { Write-Host "  Gestor:  ninguno conocido" -ForegroundColor Yellow }

$estado = Comprueba-Requisitos

if ($estado.Faltantes.Count -gt 0) {
    Escribe-Aviso "  Faltan requisitos para poder continuar:"
    foreach ($f in $estado.Faltantes) { Write-Host "   - $f" }

    if (-not $Gestor) {
        Escribe-Error "  No encontre winget, Chocolatey ni Scoop, asi que no puedo instalarlos por ti."
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
