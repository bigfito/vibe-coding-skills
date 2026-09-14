# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
#
# Instala las skills como Skills nativas de Google Antigravity, desde una copia
# local del repositorio.
#
#   pwsh scripts/instalar-antigravity.ps1                  global: ~/.gemini/config/skills
#   pwsh scripts/instalar-antigravity.ps1 -Dir proyecto    proyecto: <proyecto>/.agents/skills
#
# A diferencia del instalador principal, que instala reglas y flujos partidos
# en archivos numerados, aquí cada skill se copia completa (SKILL.md y sus
# carpetas de apoyo), que es el formato que Antigravity documenta para Skills.
# Reemplaza lo que ya hubiera de estas skills en el destino.

param(
    [string]$Dir
)

$ErrorActionPreference = 'Stop'

$Raiz = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $Raiz 'skills'
$Casa = if ($env:HOME) { $env:HOME } else { $HOME }
$Destino = Join-Path (Join-Path (Join-Path $Casa '.gemini') 'config') 'skills'
$Ambito = 'global'

if ($Dir) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        Write-Host "La carpeta indicada en -Dir no existe: $Dir" -ForegroundColor Red
        exit 1
    }
    $Destino = Join-Path (Join-Path (Resolve-Path -LiteralPath $Dir).Path '.agents') 'skills'
    $Ambito = 'proyecto'
}

Write-Host "`nInstalando Vibe Coding Skills en Google Antigravity ($Ambito)..." -ForegroundColor Cyan
Write-Host "Destino: $Destino" -ForegroundColor DarkGray

New-Item -ItemType Directory -Path $Destino -Force | Out-Null
$total = 0

foreach ($carpeta in Get-ChildItem -LiteralPath $SkillsDir -Directory | Sort-Object Name) {
    $skillMd = Join-Path $carpeta.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd)) { continue }

    $dest = Join-Path $Destino $carpeta.Name
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -LiteralPath $skillMd -Destination (Join-Path $dest 'SKILL.md') -Force
    Write-Host "  [OK] $($carpeta.Name)" -ForegroundColor Green

    # Carpetas que el SKILL.md referencia por ruta relativa. agents/ trae las
    # definiciones de roles que prototype-kickoff carga en cada turno. Se borra
    # la copia anterior para que Copy-Item no la anide dentro de sí misma.
    foreach ($sub in 'references', 'assets', 'agents') {
        $origen = Join-Path $carpeta.FullName $sub
        if (Test-Path -LiteralPath $origen -PathType Container) {
            $destSub = Join-Path $dest $sub
            if (Test-Path -LiteralPath $destSub) { Remove-Item -LiteralPath $destSub -Recurse -Force }
            Copy-Item -LiteralPath $origen -Destination $destSub -Recurse -Force
            Write-Host "       + $sub/" -ForegroundColor DarkGray
        }
    }
    $total++
}

Write-Host "`n$total skill(s) instaladas en $Destino." -ForegroundColor Green
Write-Host "Si Antigravity ya estaba abierto, ciérralo y vuelve a abrirlo para que las cargue.`n"
