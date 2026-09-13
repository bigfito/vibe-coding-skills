#!/usr/bin/env bash
# Modo sin Node: instala las skills copiando archivos, sin Node, npm ni git.
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
  # Si ya hay una copia local (repositorio clonado, o AGENT_SKILLS_SRC), se usa
  # esa y no se descarga nada.
  local local_dir="${AGENT_SKILLS_SRC:-}"
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
  tmp="$(mktemp -d 2>/dev/null || mktemp -d -t agent-skills)" || return 1
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

# Instala una skill en un entorno, con el mismo reparto de carpetas que usa el
# instalador de Node.
sn_instalar_skill() {
  local base="$1" skill="$2" entorno="$3" destino="$4" archivo nombre

  case "$entorno" in
    claude)
      sn_copiar "$base/SKILL.md" "$destino/.claude/skills/$skill/SKILL.md"
      for extra in references assets; do
        sn_copiar_arbol "$base/$extra" "$destino/.claude/skills/$skill/$extra"
      done
      if [ -d "$base/agents" ]; then
        for archivo in "$base"/agents/*; do
          [ -f "$archivo" ] || continue
          sn_copiar "$archivo" "$destino/.claude/agents/$(basename "$archivo")"
        done
      fi
      ;;
    cursor|junie)
      local origen="$base/dist/$entorno" carpeta
      [ "$entorno" = "cursor" ] && carpeta="$destino/.cursor/rules" || carpeta="$destino/.junie/rules"
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
      local origen="$base/dist/antigravity"
      [ -d "$origen" ] || return 0
      for archivo in "$origen"/*; do
        [ -f "$archivo" ] || continue
        sn_copiar "$archivo" "$destino/.agents/rules/$(basename "$archivo")"
      done
      if [ -d "$origen/workflows" ]; then
        for archivo in "$origen"/workflows/*; do
          [ -f "$archivo" ] || continue
          sn_copiar "$archivo" "$destino/.agents/workflows/$(basename "$archivo")"
        done
      fi
      for extra in references assets; do
        sn_copiar_arbol "$base/$extra" "$destino/.agents/rules/$skill/$extra"
      done
      ;;
  esac
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
  SN_TARBALL="${AGENT_SKILLS_TARBALL:-https://codeload.github.com/bigfito/vibe-coding-skills/tar.gz/refs/heads/main}"
  SN_FORZAR="${SN_FORZAR:-0}"
  SN_COPIADOS=0
  SN_OMITIDOS=0
  SN_TEMPORAL=""
  SN_DESTINO="${1:-}"
  ORIGEN_SKILLS=""

  titulo "agent-skills — instalación sin Node"
  printf '  Se copiarán todas las skills; no hace falta Node, npm ni git.\n'

  sn_obtener_fuente || return 1

  if [ -z "$SN_DESTINO" ]; then
    if hay_terminal; then sn_preguntar_carpeta; else SN_DESTINO="$PWD"; fi
  fi
  if hay_terminal && [ -z "${SN_ENTORNOS:-}" ]; then sn_preguntar_entornos; fi
  SN_ENTORNOS="${SN_ENTORNOS:-claude cursor junie antigravity}"

  printf '\n  %sSe instalarán%s\n' "$B" "$N"
  printf '    Carpeta:     %s\n' "$SN_DESTINO"
  printf '    Herramientas:%s\n' "$(printf ' %s' $SN_ENTORNOS)"

  SN_LISTA="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/agent-skills-lista")"

  local skill base entorno
  for base in "$ORIGEN_SKILLS"/skills/*; do
    [ -d "$base" ] || continue
    skill="$(basename "$base")"
    for entorno in $SN_ENTORNOS; do
      sn_instalar_skill "$base" "$skill" "$entorno" "$SN_DESTINO"
    done
  done

  rm -f "$SN_LISTA"
  [ -n "$SN_TEMPORAL" ] && rm -rf "$SN_TEMPORAL"

  printf '\n  %s✓%s %s archivo(s) instalados en %s\n' "$G" "$N" "$SN_COPIADOS" "$SN_DESTINO"
  if [ "$SN_OMITIDOS" -gt 0 ]; then
    printf '  %s! %s ya existían y no se tocaron.%s\n' "$Y" "$SN_OMITIDOS" "$N"
  fi
  printf '  %sVersiona estas carpetas en git para que el equipo comparta el mismo comportamiento.%s\n\n' "$D" "$N"
  return 0
}
