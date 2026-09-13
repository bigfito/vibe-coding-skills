#!/bin/bash
# Lanzador de doble clic de Vibe Coding Skills para macOS.
#
# Descarga este archivo y haz doble clic. macOS abre la Terminal y ejecuta el
# instalador: no hace falta escribir ningún comando.
#
# La primera vez macOS puede avisar de que el archivo viene de internet. En ese
# caso: clic derecho sobre el archivo → Abrir → Abrir.

# Trabajar en la carpeta donde está el lanzador y no en la que abra Finder.
cd "$(dirname "$0")" || exit 1

REPO_RAW="${VIBE_SKILLS_RAW:-${AGENT_SKILLS_RAW:-https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main}}"

printf '\n  Vibe Coding Skills — instalador para macOS\n'
printf '  Se abrirá un menú para elegir las skills y la carpeta de tu proyecto.\n\n'

if ! command -v curl >/dev/null 2>&1; then
  printf '  No se encontró curl, que hace falta para descargar el instalador.\n'
  printf '  Instálalo con: xcode-select --install\n\n'
  printf '  Pulsa una tecla para cerrar esta ventana.'
  read -r -n 1 -s
  exit 1
fi

# El instalador se ejecuta con bash y con la entrada conectada al terminal, para
# que sus preguntas (permiso de instalación, menús) funcionen con normalidad.
TEMPORAL="${TMPDIR:-/tmp}/vibe-coding-skills-install.sh"
curl -fsSL "$REPO_RAW/install.sh" -o "$TEMPORAL"
estado=$?

if [ $estado -ne 0 ]; then
  printf '\n  No se pudo descargar el instalador (¿hay conexión a internet?).\n\n'
  printf '  Pulsa una tecla para cerrar esta ventana.'
  read -r -n 1 -s
  exit 1
fi

bash "$TEMPORAL" "$@"
estado=$?
rm -f "$TEMPORAL"

printf '\n  Pulsa una tecla para cerrar esta ventana.'
read -r -n 1 -s
printf '\n'
exit $estado
