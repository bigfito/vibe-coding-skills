<#
  Modo sin Node para Windows: instala las skills copiando archivos, sin Node,
  npm ni git.

  Las skills son archivos de texto; Node solo hace falta para el menú. Cuando
  alguien no puede o no quiere instalar Node, este camino descarga el
  repositorio y copia lo mismo que copiaría el instalador normal, a cambio de
  un menú más sencillo: todas las skills, en las herramientas que elijas.

  install.ps1 lo carga con dot-sourcing y llama a Invoke-ModoSinNode. Las
  funciones se declaran en ambito global a proposito: la carga ocurre dentro de
  una funcion de install.ps1, y unas funciones de ambito normal desaparecerian
  al salir de ella.
#>

$global:SnCopiados = 0
$global:SnOmitidos = 0

function global:Get-SnFuente {
    # Una copia local (repositorio clonado o AGENT_SKILLS_SRC) evita descargar.
    $local = $env:AGENT_SKILLS_SRC
    if (-not $local -and $global:SnAqui -and (Test-Path (Join-Path $global:SnAqui 'skills'))) {
        $local = $global:SnAqui
    }
    if ($local -and (Test-Path (Join-Path $local 'skills'))) {
        Write-Host "  Usando la copia local: $local" -ForegroundColor DarkGray
        return $local
    }

    $zip = if ($env:AGENT_SKILLS_ZIP) { $env:AGENT_SKILLS_ZIP }
           else { 'https://codeload.github.com/bigfito/vibe-coding-skills/zip/refs/heads/main' }
    $temporal = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-skills-" + [guid]::NewGuid().ToString('N'))
    $archivo = "$temporal.zip"

    Write-Host "`n  Descargando las skills..."
    try {
        Invoke-WebRequest -UseBasicParsing $zip -OutFile $archivo
        Expand-Archive -Path $archivo -DestinationPath $temporal -Force
    } catch {
        Escribe-Error "  No se pudo descargar las skills: $($_.Exception.Message)"
        return $null
    } finally {
        if (Test-Path $archivo) { Remove-Item $archivo -Force -ErrorAction SilentlyContinue }
    }

    # El zip de GitHub trae una única carpeta raíz.
    $raiz = Get-ChildItem -Path $temporal -Directory -Recurse -Filter 'skills' |
            Where-Object { $_.Parent.FullName -ne $temporal -or $true } |
            Select-Object -First 1
    if (-not $raiz) {
        Escribe-Error "  La descarga no contiene las skills."
        return $null
    }
    $global:SnTemporal = $temporal
    return $raiz.Parent.FullName
}

function global:Copy-SnArchivo($origen, $destino) {
    if ((Test-Path $destino) -and -not $global:SnForzar) {
        $global:SnOmitidos++
        return
    }
    $carpeta = Split-Path -Parent $destino
    if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null }
    Copy-Item -Path $origen -Destination $destino -Force
    $global:SnCopiados++
}

function global:Copy-SnArbol($origen, $destino) {
    if (-not (Test-Path $origen)) { return }
    foreach ($archivo in Get-ChildItem -Path $origen -File -Recurse) {
        $rel = $archivo.FullName.Substring($origen.Length).TrimStart('\', '/')
        Copy-SnArchivo $archivo.FullName (Join-Path $destino $rel)
    }
}

function global:Install-SnSkill($base, $skill, $entorno, $destino) {
    switch ($entorno) {
        'claude' {
            Copy-SnArchivo (Join-Path $base 'SKILL.md') (Join-Path $destino ".claude\skills\$skill\SKILL.md")
            foreach ($extra in @('references', 'assets')) {
                Copy-SnArbol (Join-Path $base $extra) (Join-Path $destino ".claude\skills\$skill\$extra")
            }
            $agentes = Join-Path $base 'agents'
            if (Test-Path $agentes) {
                foreach ($a in Get-ChildItem -Path $agentes -File) {
                    Copy-SnArchivo $a.FullName (Join-Path $destino ".claude\agents\$($a.Name)")
                }
            }
        }
        { $_ -in @('cursor', 'junie') } {
            $origen = Join-Path $base "dist\$entorno"
            $carpeta = if ($entorno -eq 'cursor') { Join-Path $destino '.cursor\rules' } else { Join-Path $destino '.junie\rules' }
            if (-not (Test-Path $origen)) { return }
            foreach ($f in Get-ChildItem -Path $origen -File) {
                Copy-SnArchivo $f.FullName (Join-Path $carpeta $f.Name)
            }
            foreach ($extra in @('references', 'assets')) {
                Copy-SnArbol (Join-Path $base $extra) (Join-Path $carpeta "$skill\$extra")
            }
        }
        'antigravity' {
            $origen = Join-Path $base 'dist\antigravity'
            if (-not (Test-Path $origen)) { return }
            foreach ($f in Get-ChildItem -Path $origen -File) {
                Copy-SnArchivo $f.FullName (Join-Path $destino ".agents\rules\$($f.Name)")
            }
            $flujos = Join-Path $origen 'workflows'
            if (Test-Path $flujos) {
                foreach ($f in Get-ChildItem -Path $flujos -File) {
                    Copy-SnArchivo $f.FullName (Join-Path $destino ".agents\workflows\$($f.Name)")
                }
            }
            foreach ($extra in @('references', 'assets')) {
                Copy-SnArbol (Join-Path $base $extra) (Join-Path $destino ".agents\rules\$skill\$extra")
            }
        }
    }
}

function global:Read-SnCarpeta {
    Write-Host "`n  En que carpeta instalo las skills?"
    Write-Host "  Arrastra la carpeta de tu proyecto hasta esta ventana y pulsa Enter," -ForegroundColor DarkGray
    Write-Host "  o pulsa Enter a secas para usar esta: $PWD" -ForegroundColor DarkGray
    Write-Host "`n  Carpeta: " -NoNewline

    $respuesta = ''
    try { $respuesta = [System.Console]::ReadLine() } catch { return "$PWD" }
    if ([string]::IsNullOrWhiteSpace($respuesta)) { return "$PWD" }

    $ruta = $respuesta.Trim().Trim('"').Trim("'")
    if ($ruta.StartsWith('~')) { $ruta = Join-Path $HOME $ruta.TrimStart('~', '\', '/') }

    if (-not (Test-Path $ruta -PathType Container)) {
        if (Confirmar "La carpeta `"$ruta`" no existe. La creo?") {
            try { New-Item -ItemType Directory -Path $ruta -Force | Out-Null }
            catch { Escribe-Error "  No se pudo crear."; return "$PWD" }
        } else {
            return "$PWD"
        }
    }
    return (Resolve-Path $ruta).Path
}

function global:Read-SnEntornos {
    Write-Host "`n  En que herramientas las instalo?"
    Write-Host "    1. Claude Code"
    Write-Host "    2. Cursor"
    Write-Host "    3. IntelliJ IDEA Ultimate (Junie)"
    Write-Host "    4. Google Antigravity"
    Write-Host "`n  Numeros separados por coma, o Enter para todas: " -NoNewline

    $respuesta = ''
    try { $respuesta = [System.Console]::ReadLine() } catch { $respuesta = '' }
    if ([string]::IsNullOrWhiteSpace($respuesta)) { return @('claude', 'cursor', 'junie', 'antigravity') }

    $elegidos = @()
    if ($respuesta -match '1') { $elegidos += 'claude' }
    if ($respuesta -match '2') { $elegidos += 'cursor' }
    if ($respuesta -match '3') { $elegidos += 'junie' }
    if ($respuesta -match '4') { $elegidos += 'antigravity' }
    if (-not $elegidos.Count) { return @('claude', 'cursor', 'junie', 'antigravity') }
    return $elegidos
}

function global:Invoke-ModoSinNode {
    param([string]$Destino = '', [string[]]$Entornos = @(), [switch]$Forzar)

    $global:SnForzar = [bool]$Forzar
    $global:SnCopiados = 0
    $global:SnOmitidos = 0

    Escribe-Titulo "agent-skills - instalacion sin Node"
    Write-Host "  Se copiaran todas las skills; no hace falta Node, npm ni git."

    $origen = Get-SnFuente
    if (-not $origen) { return $false }

    if (-not $Destino) {
        $Destino = if (Hay-Terminal) { Read-SnCarpeta } else { "$PWD" }
    }
    if (-not $Entornos.Count) {
        $Entornos = if (Hay-Terminal) { Read-SnEntornos } else { @('claude', 'cursor', 'junie', 'antigravity') }
    }

    Write-Host "`n  Se instalaran"
    Write-Host "    Carpeta:      $Destino"
    Write-Host "    Herramientas: $($Entornos -join ' ')"

    foreach ($base in Get-ChildItem -Path (Join-Path $origen 'skills') -Directory) {
        foreach ($entorno in $Entornos) {
            Install-SnSkill $base.FullName $base.Name $entorno $Destino
        }
    }

    if ($global:SnTemporal -and (Test-Path $global:SnTemporal)) {
        Remove-Item $global:SnTemporal -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n  $($global:SnCopiados) archivo(s) instalados en $Destino" -ForegroundColor Green
    if ($global:SnOmitidos -gt 0) {
        Write-Host "  $($global:SnOmitidos) ya existian y no se tocaron." -ForegroundColor Yellow
    }
    Write-Host "  Versiona estas carpetas en git para que el equipo comparta el mismo comportamiento.`n" -ForegroundColor DarkGray
    return $true
}
