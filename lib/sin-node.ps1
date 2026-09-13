# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raiz del repositorio.

<#
  Modo sin Node de Vibe Coding Skills para Windows: instala las skills
  copiando archivos, sin Node, npm ni git.

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
    # Una copia local (repositorio clonado o VIBE_SKILLS_SRC) evita descargar.
    $local = $env:VIBE_SKILLS_SRC
    if (-not $local) { $local = $env:AGENT_SKILLS_SRC }
    if (-not $local -and $global:SnAqui -and (Test-Path (Join-Path $global:SnAqui 'skills'))) {
        $local = $global:SnAqui
    }
    if ($local -and (Test-Path (Join-Path $local 'skills'))) {
        Write-Host "  Usando la copia local: $local" -ForegroundColor DarkGray
        return $local
    }

    $zip = if ($env:VIBE_SKILLS_ZIP) { $env:VIBE_SKILLS_ZIP }
           elseif ($env:AGENT_SKILLS_ZIP) { $env:AGENT_SKILLS_ZIP }
           else { 'https://codeload.github.com/bigfito/vibe-coding-skills/zip/refs/heads/main' }
    $temporal = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-coding-skills-" + [guid]::NewGuid().ToString('N'))
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
    # En simulacion se cuenta lo que se copiaria, pero no se escribe nada.
    if ($global:SnSimular) {
        $global:SnCopiados++
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

# Carpeta base de cada herramienta segun el ambito:
#   global   - la carpeta personal, para todos los proyectos.
#   proyecto - dentro del proyecto elegido.
function global:Get-SnBase($entorno, $ambito, $destino) {
    if ($ambito -eq 'global') {
        switch ($entorno) {
            'claude' { if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR } else { return (Join-Path $HOME '.claude') } }
            'cursor' { return (Join-Path $HOME '.cursor') }
            'junie'  { return (Join-Path $HOME '.junie') }
            'antigravity' { return (Join-Path $HOME '.gemini\antigravity') }
        }
    }
    switch ($entorno) {
        'claude' { return (Join-Path $destino '.claude') }
        'cursor' { return (Join-Path $destino '.cursor') }
        'junie'  { return (Join-Path $destino '.junie') }
        'antigravity' { return (Join-Path $destino '.agents') }
    }
}

# Hay rastro de que la herramienta este instalada en este computador?
function global:Test-SnInstalada($entorno) {
    # Join-Path revienta si la base es nula, y las variables de entorno de
    # Windows no existen en macOS ni en Linux: se unen solo cuando hay algo.
    $unir = { param($base, $hijo) if ($base) { Join-Path $base $hijo } else { $null } }
    $pistas = switch ($entorno) {
        'claude' { @((& $unir $HOME '.claude'), (& $unir $HOME '.claude.json')) }
        'cursor' { @((& $unir $HOME '.cursor'), (& $unir $env:LOCALAPPDATA 'Programs\cursor'), (& $unir $env:APPDATA 'Cursor')) }
        'junie'  { @((& $unir $HOME '.junie'), (& $unir $env:APPDATA 'JetBrains')) }
        'antigravity' { @((& $unir $HOME '.gemini'), (& $unir $HOME '.antigravity'), (& $unir $env:APPDATA 'Antigravity')) }
        default { @() }
    }
    foreach ($p in $pistas) { if ($p -and (Test-Path $p)) { return $true } }
    return $false
}

function global:Install-SnSkill($base, $skill, $entorno, $ambito, $destino) {
    $raiz = Get-SnBase $entorno $ambito $destino
    switch ($entorno) {
        'claude' {
            Copy-SnArchivo (Join-Path $base 'SKILL.md') (Join-Path $raiz "skills\$skill\SKILL.md")
            foreach ($extra in @('references', 'assets')) {
                Copy-SnArbol (Join-Path $base $extra) (Join-Path $raiz "skills\$skill\$extra")
            }
            $agentes = Join-Path $base 'agents'
            if (Test-Path $agentes) {
                foreach ($a in Get-ChildItem -Path $agentes -File) {
                    Copy-SnArchivo $a.FullName (Join-Path $raiz "agents\$($a.Name)")
                }
            }
        }
        { $_ -in @('cursor', 'junie') } {
            $origen = Join-Path $base "dist\$entorno"
            $carpeta = Join-Path $raiz 'rules'
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
            $carpeta = Join-Path $raiz 'rules'
            $destinoFlujos = if ($ambito -eq 'global') { Join-Path $raiz 'global_workflows' } else { Join-Path $raiz 'workflows' }
            if (-not (Test-Path $origen)) { return }
            foreach ($f in Get-ChildItem -Path $origen -File) {
                Copy-SnArchivo $f.FullName (Join-Path $carpeta $f.Name)
            }
            $flujos = Join-Path $origen 'workflows'
            if (Test-Path $flujos) {
                foreach ($f in Get-ChildItem -Path $flujos -File) {
                    Copy-SnArchivo $f.FullName (Join-Path $destinoFlujos $f.Name)
                }
            }
            foreach ($extra in @('references', 'assets')) {
                Copy-SnArbol (Join-Path $base $extra) (Join-Path $carpeta "$skill\$extra")
            }
        }
    }
}

# Junie y Antigravity leen sus guias globales de un unico archivo: se les anade
# un bloque con la lista de lo instalado, entre marcas, sin tocar lo demas.
function global:Write-SnIndice($entorno, $origen, $skills = @()) {
    if ($global:SnSimular) { return $null }
    $archivo = switch ($entorno) {
        'junie' { Join-Path $HOME '.junie\AGENTS.md' }
        'antigravity' { Join-Path $HOME '.gemini\AGENTS.md' }
        default { $null }
    }
    if (-not $archivo) { return $null }

    $carpeta = Join-Path (Get-SnBase $entorno 'global' '') 'rules'
    if (-not (Test-Path $carpeta)) { return $null }

    $lineas = @(
        $global:SnMarcaInicio,
        '## Skills de Vibe Coding Skills instaladas globalmente',
        '',
        "Estas guias estan en ``$carpeta``. Cuando la tarea encaje con alguna,",
        'lee sus archivos antes de responder:',
        ''
    )
    foreach ($dir in Get-ChildItem -Path (Join-Path $origen 'skills') -Directory) {
        if ($skills -and $skills.Count -and ($dir.Name -notin $skills)) { continue }
        $archivos = Get-ChildItem -Path $carpeta -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name.StartsWith($dir.Name) -and ($_.Extension -in @('.md', '.mdc')) } |
                    ForEach-Object { "``$($_.FullName)``" }
        if ($archivos) { $lineas += "- **$($dir.Name)**: $($archivos -join ', ')" }
    }
    $lineas += $global:SnMarcaFin
    $bloque = $lineas -join "`n"

    $contenido = ''
    if (Test-Path $archivo) { $contenido = Get-Content -Raw $archivo }
    # Se busca el bloque con las marcas actuales y, si no esta, con las antiguas.
    $inicio = $contenido.IndexOf($global:SnMarcaInicio)
    $fin = $contenido.IndexOf($global:SnMarcaFin)
    $largoFin = $global:SnMarcaFin.Length
    if ($inicio -lt 0) {
        $inicio = $contenido.IndexOf($global:SnMarcaInicioVieja)
        $fin = $contenido.IndexOf($global:SnMarcaFinVieja)
        $largoFin = $global:SnMarcaFinVieja.Length
    }
    if ($inicio -ge 0 -and $fin -gt $inicio) {
        $nuevo = $contenido.Substring(0, $inicio) + $bloque + $contenido.Substring($fin + $largoFin)
    } elseif ($contenido.Trim()) {
        $nuevo = $contenido.TrimEnd() + "`n`n" + $bloque + "`n"
    } else {
        $nuevo = $bloque + "`n"
    }

    $carpetaArchivo = Split-Path -Parent $archivo
    if (-not (Test-Path $carpetaArchivo)) { New-Item -ItemType Directory -Path $carpetaArchivo -Force | Out-Null }
    Set-Content -Path $archivo -Value $nuevo -NoNewline
    return $archivo
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

function global:Read-SnAmbitos {
    Write-Host "`n  Donde quieres instalarlas?"
    Write-Host "    1. Global - en tu carpeta personal, disponibles en todos tus proyectos"
    Write-Host "    2. Solo en este proyecto"
    Write-Host "    3. En los dos sitios"
    Write-Host "`n  Elige 1, 2 o 3 (Enter para 1): " -NoNewline
    $r = ''
    try { $r = [System.Console]::ReadLine() } catch { return @('global') }
    switch (($r + '').Trim()) {
        '2' { return @('proyecto') }
        '3' { return @('global', 'proyecto') }
        default { return @('global') }
    }
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
    param([string]$Destino = '', [string[]]$Entornos = @(), [string[]]$Ambitos = @(),
          [string[]]$Skills = @(), [switch]$Forzar, [switch]$Asumir, [switch]$Simular)

    $global:SnForzar = [bool]$Forzar
    $global:SnSimular = [bool]$Simular
    $global:SnCopiados = 0
    $global:SnOmitidos = 0
    $global:SnMarcaInicio = '<!-- vibe-coding-skills: inicio (bloque generado, no editar) -->'
    $global:SnMarcaFin = '<!-- vibe-coding-skills: fin -->'
    # Marcas de versiones anteriores: se reconocen al reescribir el bloque, para
    # no dejar dos indices en el archivo de quien ya lo tenia instalado.
    $global:SnMarcaInicioVieja = '<!-- agent-skills: inicio (bloque generado, no editar) -->'
    $global:SnMarcaFinVieja = '<!-- agent-skills: fin -->'

    Escribe-Titulo "Vibe Coding Skills - instalacion sin Node"
    Write-Host "  Se copiaran las skills; no hace falta Node, npm ni git."
    if ($Simular) { Write-Host "  Modo simulacion: no se escribira ningun archivo." -ForegroundColor Yellow }

    $origen = Get-SnFuente
    if (-not $origen) { return $false }

    # Validacion previa: que herramientas hay en este computador.
    Write-Host "`n  Herramientas detectadas en este computador"
    foreach ($e in @('claude', 'cursor', 'junie', 'antigravity')) {
        if (Test-SnInstalada $e) { Write-Host ("    {0,-14} detectada" -f $e) -ForegroundColor Green }
        else { Write-Host ("    {0,-14} no detectada" -f $e) -ForegroundColor Yellow }
    }

    # Con -Asumir no se pregunta nada: se usan los valores por defecto.
    $preguntar = (Hay-Terminal) -and (-not $Asumir)
    if (-not $Ambitos.Count) {
        $Ambitos = if ($preguntar) { Read-SnAmbitos } else { @('global') }
    }
    if ($Ambitos -contains 'proyecto' -and -not $Destino) {
        $Destino = if ($preguntar) { Read-SnCarpeta } else { "$PWD" }
    }
    if (-not $Destino) { $Destino = "$PWD" }
    if (-not $Entornos.Count) {
        $Entornos = if ($preguntar) { Read-SnEntornos } else { @('claude', 'cursor', 'junie', 'antigravity') }
    }

    Write-Host "`n  Se instalaran"
    Write-Host "    Ambito:       $($Ambitos -join ' ')"
    if ($Ambitos -contains 'proyecto') { Write-Host "    Carpeta:      $Destino" }
    Write-Host "    Herramientas: $($Entornos -join ' ')"
    if ($Skills.Count) { Write-Host "    Skills:       $($Skills -join ' ')" }

    foreach ($ambito in $Ambitos) {
        foreach ($base in Get-ChildItem -Path (Join-Path $origen 'skills') -Directory) {
            # Con -Skills solo se instalan las pedidas; sin ellas, todas.
            if ($Skills.Count -and ($base.Name -notin $Skills)) { continue }
            foreach ($entorno in $Entornos) {
                Install-SnSkill $base.FullName $base.Name $entorno $ambito $Destino
            }
        }
    }

    $indices = @()
    if ($Ambitos -contains 'global') {
        foreach ($entorno in $Entornos) {
            $archivo = Write-SnIndice $entorno $origen $Skills
            if ($archivo) { $indices += $archivo }
        }
    }

    if ($global:SnTemporal -and (Test-Path $global:SnTemporal)) {
        Remove-Item $global:SnTemporal -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($global:SnSimular) {
        Write-Host "`n  $($global:SnCopiados) archivo(s) se copiarian. Modo simulacion: no se escribio nada." -ForegroundColor Green
    } else {
        Write-Host "`n  $($global:SnCopiados) archivo(s) instalados." -ForegroundColor Green
    }
    if ($global:SnOmitidos -gt 0) {
        Write-Host "  $($global:SnOmitidos) ya existian y no se tocaron." -ForegroundColor Yellow
    }
    if ($indices.Count) {
        Write-Host "  Se anadio un indice de las skills en:" -ForegroundColor DarkGray
        foreach ($i in $indices) { Write-Host "    $i" -ForegroundColor DarkGray }
    }
    if ($Ambitos -contains 'proyecto') {
        Write-Host "  Versiona las carpetas del proyecto en git para compartirlas con tu equipo.`n" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
    return $true
}
