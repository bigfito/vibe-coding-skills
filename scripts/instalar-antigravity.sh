#!/usr/bin/env bash
# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
#
# Instala las skills como Skills nativas de Google Antigravity, desde una copia
# local del repositorio.
#
#   bash scripts/instalar-antigravity.sh                  global: ~/.gemini/config/skills
#   bash scripts/instalar-antigravity.sh --dir=proyecto   proyecto: <proyecto>/.agents/skills
#
# A diferencia del instalador principal, que instala reglas y flujos partidos
# en archivos numerados, aquí cada skill se copia completa (SKILL.md y sus
# carpetas de apoyo), que es el formato que Antigravity documenta para Skills.
# Reemplaza lo que ya hubiera de estas skills en el destino.

set -eu

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$RAIZ/skills"
DESTINO="$HOME/.gemini/config/skills"
AMBITO="global"

for arg in "$@"; do
  case "$arg" in
    --dir=*)
      proyecto="${arg#--dir=}"
      if [ ! -d "$proyecto" ]; then
        printf 'La carpeta indicada en --dir no existe: %s\n' "$proyecto" >&2
        exit 1
      fi
      DESTINO="$(cd "$proyecto" && pwd)/.agents/skills"
      AMBITO="proyecto"
      ;;
    --help|-h)
      sed -n '6,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'Opción desconocida: %s (usa --dir=ruta o --help)\n' "$arg" >&2
      exit 2
      ;;
  esac
done

printf '\nInstalando Vibe Coding Skills en Google Antigravity (%s)...\n' "$AMBITO"
printf 'Destino: %s\n' "$DESTINO"

mkdir -p "$DESTINO"
total=0

for carpeta in "$SKILLS_DIR"/*/; do
  carpeta="${carpeta%/}"
  skill="$(basename "$carpeta")"
  [ -f "$carpeta/SKILL.md" ] || continue
  dest="$DESTINO/$skill"
  mkdir -p "$dest"
  cp -f "$carpeta/SKILL.md" "$dest/SKILL.md"
  printf '  [OK] %s\n' "$skill"

  # Carpetas que el SKILL.md referencia por ruta relativa. agents/ trae las
  # definiciones de roles que prototype-kickoff carga en cada turno.
  for sub in references assets agents; do
    if [ -d "$carpeta/$sub" ]; then
      rm -rf "${dest:?}/$sub"
      cp -R "$carpeta/$sub" "$dest/$sub"
      printf '       + %s/\n' "$sub"
    fi
  done
  total=$((total + 1))
done

printf '\n%d skill(s) instaladas en %s.\n' "$total" "$DESTINO"
printf 'Si Antigravity ya estaba abierto, ciérralo y vuelve a abrirlo para que las cargue.\n\n'
