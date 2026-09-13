#!/usr/bin/env bash
# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
#
# Modo sin Node de Vibe Coding Skills: instala las skills copiando archivos,
# sin Node, npm ni git.
#
# Las skills son archivos de texto; Node solo hace falta para el menú. Cuando
# alguien no puede o no quiere instalar Node, este camino descarga el
# repositorio y copia lo mismo que copiaría el instalador normal, a cambio de
# un menú más sencillo: todas las skills, en los entornos que elijas.
#
# Se carga con `.` desde install.sh y expone una única función: modo_sin_node.
# Necesita las herramientas básicas de cualquier Unix (cp, find, basename,
# mktemp) y, solo si hay que descargar, curl o wget y tar.

# Descarga y descomprime el repositorio en una carpeta temporal. Escribe la
# ruta de la copia en la variable ORIGEN_SKILLS.
sn_obtener_fuente() {
  # Si ya hay una copia local (repositorio clonado, o VIBE_SKILLS_SRC), se usa
  # esa y no se descarga nada.
  local local_dir="${VIBE_SKILLS_SRC:-${AGENT_SKILLS_SRC:-}}"
  if [ -z "$local_dir" ] && [ -d "$SN_AQUI/skills" ]; then local_dir="$SN_AQUI"; fi
  if [ -n "$local_dir" ] && [ -d "$local_dir/skills" ]; then
    ORIGEN_SKILLS="$local_dir"
    printf '  Usando la copia local: %s%s%s\n' "$D" "$local_dir" "$N"
    return 0
  fi

  if ! hay tar; then
    error "  Hace falta tar para descomprimir la descarga, y no está disponible."
    return 1
  fi

  local tmp archivo
  tmp="$(mktemp -d 2>/dev/null || mktemp -d -t vibe-coding-skills)" || return 1
  archivo="$tmp/repo.tar.gz"

  printf '\n  Descargando las skills…\n'
  if hay curl; then
    curl -fsSL "$SN_TARBALL" -o "$archivo" || { error "  No se pudo descargar."; return 1; }
  elif hay wget; then
    wget -qO "$archivo" "$SN_TARBALL" || { error "  No se pudo descargar."; return 1; }
  else
    error "  Hace falta curl o wget para descargar las skills, y no hay ninguno."
    return 1
  fi

  tar -xzf "$archivo" -C "$tmp" || { error "  El archivo descargado no se pudo abrir."; return 1; }

  # El tarball de GitHub trae una única carpeta raíz con el nombre del commit.
  local raiz
  raiz="$(find "$tmp" -maxdepth 2 -type d -name skills 2>/dev/null | head -1)"
  if [ -z "$raiz" ]; then
    error "  La descarga no contiene las skills."
    return 1
  fi
  ORIGEN_SKILLS="$(dirname "$raiz")"
  SN_TEMPORAL="$tmp"
  return 0
}

# Copia un archivo respetando lo que ya exista (salvo --force) y llevando la
# cuenta de lo copiado y lo omitido.
sn_copiar() {
  local origen="$1" destino="$2"
  if [ -e "$destino" ] && [ "$SN_FORZAR" != "1" ]; then
    SN_OMITIDOS=$((SN_OMITIDOS + 1))
    return 0
  fi
  # En simulación se cuenta lo que se copiaría, pero no se escribe nada.
  if [ "$SN_SIMULAR" = "1" ]; then
    SN_COPIADOS=$((SN_COPIADOS + 1))
    return 0
  fi
  mkdir -p "$(dirname "$destino")" || return 1
  cp "$origen" "$destino" || return 1
  SN_COPIADOS=$((SN_COPIADOS + 1))
}

# Copia un árbol completo archivo a archivo, para respetar lo ya existente.
sn_copiar_arbol() {
  local origen="$1" destino="$2" rel
  [ -d "$origen" ] || return 0
  find "$origen" -type f | while IFS= read -r archivo; do
    rel="${archivo#"$origen"/}"
    printf '%s\n' "$rel"
  done > "$SN_LISTA"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    sn_copiar "$origen/$rel" "$destino/$rel"
  done < "$SN_LISTA"
}

# Carpeta base de cada herramienta según el ámbito:
#   global   — la carpeta personal, para todos los proyectos.
#   proyecto — dentro del proyecto elegido.
sn_base() {
  local entorno="$1" ambito="$2"
  if [ "$ambito" = "global" ]; then
    case "$entorno" in
      claude) printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
      cursor) printf '%s' "$HOME/.cursor" ;;
      junie) printf '%s' "$HOME/.junie" ;;
      antigravity) printf '%s' "$HOME/.gemini/antigravity" ;;
    esac
  else
    case "$entorno" in
      claude) printf '%s' "$SN_DESTINO/.claude" ;;
      cursor) printf '%s' "$SN_DESTINO/.cursor" ;;
      junie) printf '%s' "$SN_DESTINO/.junie" ;;
      antigravity) printf '%s' "$SN_DESTINO/.agents" ;;
    esac
  fi
}

# ¿Hay rastro de que la herramienta esté instalada en este computador?
sn_detectar() {
  local entorno="$1"
  case "$entorno" in
    claude) [ -d "$HOME/.claude" ] || [ -f "$HOME/.claude.json" ] || hay claude ;;
    cursor) [ -d "$HOME/.cursor" ] || [ -d "/Applications/Cursor.app" ] \
            || [ -d "$HOME/Library/Application Support/Cursor" ] || [ -d "$HOME/.config/Cursor" ] ;;
    junie)  [ -d "$HOME/.junie" ] || [ -d "$HOME/Library/Application Support/JetBrains" ] \
            || [ -d "$HOME/.config/JetBrains" ] ;;
    antigravity) [ -d "$HOME/.gemini" ] || [ -d "$HOME/.antigravity" ] \
            || [ -d "/Applications/Antigravity.app" ] || [ -d "$HOME/.config/Antigravity" ] ;;
    *) return 1 ;;
  esac
}

# Instala una skill en un entorno y ámbito, con el mismo reparto de carpetas que
# usa el instalador de Node.
sn_instalar_skill() {
  local base="$1" skill="$2" entorno="$3" ambito="$4" archivo raiz origen carpeta flujos
  raiz="$(sn_base "$entorno" "$ambito")"

  case "$entorno" in
    claude)
      sn_copiar "$base/SKILL.md" "$raiz/skills/$skill/SKILL.md"
      for extra in references assets; do
        sn_copiar_arbol "$base/$extra" "$raiz/skills/$skill/$extra"
      done
      if [ -d "$base/agents" ]; then
        for archivo in "$base"/agents/*; do
          [ -f "$archivo" ] || continue
          sn_copiar "$archivo" "$raiz/agents/$(basename "$archivo")"
        done
      fi
      ;;
    cursor|junie)
      origen="$base/dist/$entorno"
      carpeta="$raiz/rules"
      [ -d "$origen" ] || return 0
      for archivo in "$origen"/*; do
        [ -f "$archivo" ] || continue
        sn_copiar "$archivo" "$carpeta/$(basename "$archivo")"
      done
      for extra in references assets; do
        sn_copiar_arbol "$base/$extra" "$carpeta/$skill/$extra"
      done
      ;;
    antigravity)
      origen="$base/dist/antigravity"
      carpeta="$raiz/rules"
      [ "$ambito" = "global" ] && flujos="$raiz/global_workflows" || flujos="$raiz/workflows"
      [ -d "$origen" ] || return 0
      for archivo in "$origen"/*; do
        [ -f "$archivo" ] || continue
        sn_copiar "$archivo" "$carpeta/$(basename "$archivo")"
      done
      if [ -d "$origen/workflows" ]; then
        for archivo in "$origen"/workflows/*; do
          [ -f "$archivo" ] || continue
          sn_copiar "$archivo" "$flujos/$(basename "$archivo")"
        done
      fi
      for extra in references assets; do
        sn_copiar_arbol "$base/$extra" "$carpeta/$skill/$extra"
      done
      ;;
  esac
}

# Junie y Antigravity leen sus guías globales de un único archivo: se les añade
# un bloque con la lista de lo instalado, entre marcas, sin tocar lo demás.
sn_indice() {
  local entorno="$1" archivo carpeta temporal
  [ "$SN_SIMULAR" = "1" ] && return 0
  case "$entorno" in
    junie) archivo="$HOME/.junie/AGENTS.md" ;;
    antigravity) archivo="$HOME/.gemini/AGENTS.md" ;;
    *) return 0 ;;
  esac
  carpeta="$(sn_base "$entorno" global)/rules"
  [ -d "$carpeta" ] || return 0

  temporal="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/vibe-coding-skills-indice")"
  {
    printf '%s\n' "$SN_MARCA_INICIO"
    printf '## Skills de Vibe Coding Skills instaladas globalmente\n\n'
    printf 'Estas guías están en `%s`. Cuando la tarea encaje con alguna,\n' "$carpeta"
    printf 'lee sus archivos antes de responder:\n\n'
    # Se agrupa por skill, igual que el instalador de Node, para que el índice
    # diga a qué corresponde cada archivo.
    for skill_dir in "$ORIGEN_SKILLS"/skills/*; do
      [ -d "$skill_dir" ] || continue
      skill_nombre="$(basename "$skill_dir")"
      if [ -n "$SN_SKILLS" ] && ! printf ' %s ' "$SN_SKILLS" | grep -qF " $skill_nombre "; then continue; fi
      archivos=""
      for archivo_regla in "$carpeta/$skill_nombre"*.md "$carpeta/$skill_nombre"*.mdc; do
        [ -f "$archivo_regla" ] || continue
        archivos="${archivos:+$archivos, }\`$archivo_regla\`"
      done
      [ -n "$archivos" ] && printf -- '- **%s**: %s\n' "$skill_nombre" "$archivos"
    done
    printf '%s\n' "$SN_MARCA_FIN"
  } > "$temporal"

  # Se busca el bloque con las marcas actuales y, si no está, con las antiguas.
  local marca_ini="$SN_MARCA_INICIO" marca_fin="$SN_MARCA_FIN"
  if [ -f "$archivo" ] && ! grep -qF "$SN_MARCA_INICIO" "$archivo" \
     && grep -qF "$SN_MARCA_INICIO_VIEJA" "$archivo"; then
    marca_ini="$SN_MARCA_INICIO_VIEJA"
    marca_fin="$SN_MARCA_FIN_VIEJA"
  fi

  if [ -f "$archivo" ] && grep -qF "$marca_ini" "$archivo"; then
    # Reemplaza el bloque anterior conservando el resto del archivo.
    awk -v inicio="$marca_ini" -v fin="$marca_fin" -v nuevo="$temporal" '
      $0 == inicio { while ((getline linea < nuevo) > 0) print linea; saltando = 1; next }
      $0 == fin { saltando = 0; next }
      !saltando { print }
    ' "$archivo" > "$temporal.nuevo" && mv "$temporal.nuevo" "$archivo"
  else
    mkdir -p "$(dirname "$archivo")"
    [ -f "$archivo" ] && printf '\n' >> "$archivo"
    cat "$temporal" >> "$archivo"
  fi
  rm -f "$temporal"
  SN_INDICES="$SN_INDICES $archivo"
}

# Pregunta la carpeta del proyecto, aceptando que se arrastre hasta la ventana.
sn_preguntar_carpeta() {
  local respuesta ruta
  printf '\n  %s¿En qué carpeta instalo las skills?%s\n' "$B" "$N"
  printf '  %sArrastra la carpeta de tu proyecto hasta esta ventana y pulsa Enter,%s\n' "$D" "$N"
  printf '  %so pulsa Enter a secas para usar esta: %s%s\n' "$D" "$PWD" "$N"
  printf '\n  Carpeta: '
  if ! read -r respuesta < /dev/tty 2>/dev/null; then
    printf '\n'
    SN_DESTINO="$PWD"
    return 0
  fi

  respuesta="${respuesta#"${respuesta%%[![:space:]]*}"}"
  respuesta="${respuesta%"${respuesta##*[![:space:]]}"}"
  if [ -z "$respuesta" ]; then SN_DESTINO="$PWD"; return 0; fi

  # Quitar comillas y espacios escapados: es lo que deja arrastrar una carpeta.
  case "$respuesta" in
    \"*\") respuesta="${respuesta%\"}"; respuesta="${respuesta#\"}" ;;
    \'*\') respuesta="${respuesta%\'}"; respuesta="${respuesta#\'}" ;;
  esac
  ruta="$(printf '%s' "$respuesta" | sed 's/\\\(.\)/\1/g')"
  # shellcheck disable=SC2088  # aquí "~" es un patrón de case, no una expansión
  case "$ruta" in "~") ruta="$HOME" ;; "~/"*) ruta="$HOME/${ruta#\~/}" ;; esac

  if [ ! -d "$ruta" ]; then
    if confirmar "La carpeta \"$ruta\" no existe. ¿La creo?"; then
      mkdir -p "$ruta" || { error "  No se pudo crear."; SN_DESTINO="$PWD"; return 0; }
    else
      SN_DESTINO="$PWD"
      return 0
    fi
  fi
  # Ruta absoluta: así el resumen final dice exactamente dónde quedó todo.
  SN_DESTINO="$(cd "$ruta" 2>/dev/null && pwd || printf '%s' "$ruta")"
}

# Pregunta el ámbito: global (todos los proyectos) o solo este proyecto.
sn_preguntar_ambito() {
  local respuesta
  printf '\n  %s¿Dónde quieres instalarlas?%s\n' "$B" "$N"
  printf '    1. Global — en tu carpeta personal, disponibles en todos tus proyectos\n'
  printf '    2. Solo en este proyecto\n'
  printf '    3. En los dos sitios\n'
  printf '\n  %sElige 1, 2 o 3 (Enter para 1): %s' "$D" "$N"
  if ! read -r respuesta < /dev/tty 2>/dev/null; then printf '\n'; SN_AMBITOS="global"; return 0; fi
  case "$(printf '%s' "$respuesta" | tr -d '[:space:]')" in
    2) SN_AMBITOS="proyecto" ;;
    3) SN_AMBITOS="global proyecto" ;;
    *) SN_AMBITOS="global" ;;
  esac
}

# Pregunta los entornos. Enter = todos.
sn_preguntar_entornos() {
  local respuesta
  SN_ENTORNOS="claude cursor junie antigravity"
  printf '\n  %s¿En qué herramientas las instalo?%s\n' "$B" "$N"
  printf '    1. Claude Code\n    2. Cursor\n    3. IntelliJ IDEA Ultimate (Junie)\n    4. Google Antigravity\n'
  printf '\n  %sNúmeros separados por coma, o Enter para todas: %s' "$D" "$N"
  if ! read -r respuesta < /dev/tty 2>/dev/null; then printf '\n'; return 0; fi
  [ -z "${respuesta// /}" ] && return 0

  local elegidos=""
  case "$respuesta" in *1*) elegidos="$elegidos claude" ;; esac
  case "$respuesta" in *2*) elegidos="$elegidos cursor" ;; esac
  case "$respuesta" in *3*) elegidos="$elegidos junie" ;; esac
  case "$respuesta" in *4*) elegidos="$elegidos antigravity" ;; esac
  [ -n "$elegidos" ] && SN_ENTORNOS="$elegidos"
  return 0
}

# ------------------------------------------------------------------ principal

# modo_sin_node [carpeta]
# Devuelve 0 si instaló las skills.
modo_sin_node() {
  SN_AQUI="${SN_AQUI:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}"
  SN_TARBALL="${VIBE_SKILLS_TARBALL:-${AGENT_SKILLS_TARBALL:-https://codeload.github.com/bigfito/vibe-coding-skills/tar.gz/refs/heads/main}}"
  SN_FORZAR="${SN_FORZAR:-0}"
  SN_ASUMIR="${SN_ASUMIR:-0}"
  SN_SIMULAR="${SN_SIMULAR:-0}"
  SN_SKILLS="${SN_SKILLS:-}"
  SN_MARCA_INICIO="<!-- vibe-coding-skills: inicio (bloque generado, no editar) -->"
  SN_MARCA_FIN="<!-- vibe-coding-skills: fin -->"
  # Marcas de versiones anteriores: se reconocen al reescribir el bloque, para
  # no dejar dos índices en el archivo de quien ya lo tenía instalado.
  SN_MARCA_INICIO_VIEJA="<!-- agent-skills: inicio (bloque generado, no editar) -->"
  SN_MARCA_FIN_VIEJA="<!-- agent-skills: fin -->"
  SN_COPIADOS=0
  SN_OMITIDOS=0
  SN_TEMPORAL=""
  SN_INDICES=""
  # El argumento manda si se pasa; si no, vale lo que haya puesto --dir=.
  SN_DESTINO="${1:-${SN_DESTINO:-}}"
  ORIGEN_SKILLS=""

  titulo "Vibe Coding Skills — instalación sin Node"
  printf '  Se copiarán las skills; no hace falta Node, npm ni git.\n'
  [ "$SN_SIMULAR" = "1" ] && printf '  %sModo simulación: no se escribirá ningún archivo.%s\n' "$Y" "$N"

  sn_obtener_fuente || return 1

  # Validación previa: qué herramientas hay en este computador.
  printf '\n  %sHerramientas detectadas en este computador%s\n' "$B" "$N"
  for entorno in claude cursor junie antigravity; do
    if sn_detectar "$entorno"; then printf '    %-14s %sdetectada%s\n' "$entorno" "$G" "$N"
    else printf '    %-14s %sno detectada%s\n' "$entorno" "$Y" "$N"; fi
  done

  if [ -z "${SN_AMBITOS:-}" ]; then
    if hay_terminal && [ "$SN_ASUMIR" != "1" ]; then sn_preguntar_ambito; else SN_AMBITOS="global"; fi
  fi

  # La carpeta del proyecto solo hace falta si se instala en el proyecto.
  case " $SN_AMBITOS " in
    *" proyecto "*)
      if [ -z "$SN_DESTINO" ]; then
        if hay_terminal && [ "$SN_ASUMIR" != "1" ]; then sn_preguntar_carpeta; else SN_DESTINO="$PWD"; fi
      fi ;;
    *) SN_DESTINO="${SN_DESTINO:-$PWD}" ;;
  esac

  if hay_terminal && [ "$SN_ASUMIR" != "1" ] && [ -z "${SN_ENTORNOS:-}" ]; then sn_preguntar_entornos; fi
  SN_ENTORNOS="${SN_ENTORNOS:-claude cursor junie antigravity}"

  printf '\n  %sSe instalarán%s\n' "$B" "$N"
  printf '    Ámbito:       %s\n' "$SN_AMBITOS"
  case " $SN_AMBITOS " in *" proyecto "*) printf '    Carpeta:      %s\n' "$SN_DESTINO" ;; esac
  printf '    Herramientas:%s\n' "$(printf ' %s' $SN_ENTORNOS)"
  [ -n "$SN_SKILLS" ] && printf '    Skills:      %s\n' "$SN_SKILLS"

  SN_LISTA="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/vibe-coding-skills-lista")"

  local skill base entorno ambito
  for ambito in $SN_AMBITOS; do
    for base in "$ORIGEN_SKILLS"/skills/*; do
      [ -d "$base" ] || continue
      skill="$(basename "$base")"
      # Con --skills= solo se instalan las pedidas; sin la bandera, todas.
      if [ -n "$SN_SKILLS" ] && ! printf ' %s ' "$SN_SKILLS" | grep -qF " $skill "; then continue; fi
      for entorno in $SN_ENTORNOS; do
        sn_instalar_skill "$base" "$skill" "$entorno" "$ambito"
      done
    done
  done

  # Índices para las herramientas que leen sus guías globales de un archivo.
  case " $SN_AMBITOS " in
    *" global "*)
      for entorno in $SN_ENTORNOS; do sn_indice "$entorno"; done ;;
  esac

  rm -f "$SN_LISTA"
  [ -n "$SN_TEMPORAL" ] && rm -rf "$SN_TEMPORAL"

  if [ "$SN_SIMULAR" = "1" ]; then
    printf '\n  %s✓%s %s archivo(s) se copiarían. %sModo simulación: no se escribió nada.%s\n' \
      "$G" "$N" "$SN_COPIADOS" "$Y" "$N"
  else
    printf '\n  %s✓%s %s archivo(s) instalados.\n' "$G" "$N" "$SN_COPIADOS"
  fi
  if [ "$SN_OMITIDOS" -gt 0 ]; then
    printf '  %s! %s ya existían y no se tocaron.%s\n' "$Y" "$SN_OMITIDOS" "$N"
  fi
  if [ -n "$SN_INDICES" ]; then
    printf '  %sSe añadió un índice de las skills en:%s\n' "$D" "$N"
    for archivo in $SN_INDICES; do printf '    %s%s%s\n' "$D" "$archivo" "$N"; done
  fi
  case " $SN_AMBITOS " in
    *" proyecto "*) printf '  %sVersiona las carpetas del proyecto en git para compartirlas con tu equipo.%s\n' "$D" "$N" ;;
  esac
  printf '\n'
  return 0
}
