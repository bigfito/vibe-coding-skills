<#
  Arranque de agent-skills para Windows (PowerShell 5.1 o superior).

    irm https://raw.githubusercontent.com/<usuario>/agent-skills/main/install.ps1 | iex

  No depende de Node: comprueba que Node, npx y git existan y, si falta alguno,
  te dice exactamente cómo instalarlo en Windows. Solo entonces ejecuta npx.
#>

$ErrorActionPreference = 'Stop'
$NodeMinimo = 18
$Repo = if ($env:AGENT_SKILLS_REPO) { $env:AGENT_SKILLS_REPO } else { 'github:<usuario>/agent-skills' }

function Escribe-Titulo($t) { Write-Host "`n$t" -ForegroundColor White }
function Escribe-Error($t)  { Write-Host "`n$t" -ForegroundColor Red }
function Escribe-Cmd($t)    { Write-Host "      $t" -ForegroundColor Green }
function Hay-Comando($c) { $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

function Instrucciones-Node {
    Write-Host "`n  Cómo instalar Node.js en Windows:" -ForegroundColor White
    $i = 1
    if (Hay-Comando 'winget') {
        Write-Host "`n   $i) winget (ya lo tienes)"
        Escribe-Cmd 'winget install OpenJS.NodeJS.LTS'
        $i++
    } else {
        Write-Host "`n   $i) winget"
        Escribe-Cmd 'winget install OpenJS.NodeJS.LTS'
        Write-Host "      (si winget no existe, instala 'Instalador de aplicaciones' desde Microsoft Store)"
        $i++
    }
    if (Hay-Comando 'choco') {
        Write-Host "`n   $i) Chocolatey (ya lo tienes)"
        Escribe-Cmd 'choco install nodejs-lts -y'
        $i++
    }
    Write-Host "`n   $i) Instalador oficial"
    Escribe-Cmd 'Descarga el .msi LTS desde https://nodejs.org/es/download'
    Write-Host "`n  Importante: cierra y vuelve a abrir PowerShell despues de instalar," -ForegroundColor Yellow
    Write-Host "  para que el PATH se actualice." -ForegroundColor Yellow
    Write-Host "`n  Cuando termines, vuelve a ejecutar este mismo comando."
    Write-Host "  Comprueba con: " -NoNewline; Write-Host "node --version" -ForegroundColor Green
    Write-Host ""
}

Escribe-Titulo "agent-skills - comprobando el entorno"
$esWindows = $true
Write-Host "  Sistema: Windows $([System.Environment]::OSVersion.Version.ToString())"

if (-not (Hay-Comando 'node')) {
    Escribe-Error "  No se encontro Node.js."
    Instrucciones-Node
    exit 1
}

$version = (node --version) -replace '^v',''
$mayor = [int]($version -split '\.')[0]
Write-Host "  Node.js: $version"

if ($mayor -lt $NodeMinimo) {
    Escribe-Error "  Tu Node.js ($version) es demasiado antiguo. Hace falta $NodeMinimo o superior."
    Instrucciones-Node
    exit 1
}

if (-not (Hay-Comando 'npx')) {
    Escribe-Error "  Tienes Node.js pero no npx (viene con npm)."
    Write-Host "`n  Reinstala Node.js, que incluye npm y npx:" -ForegroundColor White
    Escribe-Cmd 'winget install OpenJS.NodeJS.LTS'
    Write-Host "`n  Cierra y vuelve a abrir PowerShell, y ejecuta de nuevo este comando.`n"
    exit 1
}
Write-Host "  npx:     $(npx --version 2>$null)"

if (-not (Hay-Comando 'git')) {
    Escribe-Error "  No se encontro git, y npx lo necesita para instalar desde GitHub."
    Write-Host "`n  Instala git:" -ForegroundColor White
    Escribe-Cmd 'winget install Git.Git'
    Write-Host "      o descargalo de https://git-scm.com/downloads"
    Write-Host "`n  Cierra y vuelve a abrir PowerShell, y ejecuta de nuevo este comando.`n"
    exit 1
}
Write-Host "  git:     disponible"

Write-Host "`n  Todo listo. Iniciando el instalador..." -ForegroundColor Green
& npx -y $Repo @args
exit $LASTEXITCODE
