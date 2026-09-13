#!/bin/bash
# Lanzador de Vibe Coding Skills para Linux.
#
# Descarga este archivo y ábrelo desde tu explorador de archivos con "Ejecutar
# como programa" (o "Ejecutar en un terminal"). Si tu escritorio no ofrece esa
# opción, dale permiso de ejecución y ábrelo desde una terminal:
#
#   chmod +x instalar-linux.sh
#   ./instalar-linux.sh

cd "$(dirname "$0")" || exit 1

REPO_RAW="${VIBE_SKILLS_RAW:-${AGENT_SKILLS_RAW:-https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main}}"

# Si el escritorio lo abre sin terminal, no habría dónde mostrar el menú ni
# dónde responder: lo relanzamos dentro de un emulador de terminal.
if [ ! -t 0 ] || [ ! -t 1 ]; then
  for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal mate-terminal kitty alacritty xterm; do
    if command -v "$term" >/dev/null 2>&1; then
      case "$term" in
        gnome-terminal|mate-terminal|xfce4-terminal) exec "$term" -- bash "$0" "$@" ;;
        konsole|kitty|alacritty|xterm|x-terminal-emulator) exec "$term" -e bash "$0" "$@" ;;
      esac
    fi
  done
  # Sin terminal disponible seguimos igualmente: al menos el mensaje de error
  # quedará registrado si alguien mira la salida.
fi

printf '\n  Vibe Coding Skills — instalador para Linux\n'
printf '  Se abrirá un menú para elegir las skills y la carpeta de tu proyecto.\n\n'

descargar() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"; return $?; fi
  if command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"; return $?; fi
  return 127
}

TEMPORAL="${TMPDIR:-/tmp}/vibe-coding-skills-install.sh"

if ! descargar "$REPO_RAW/install.sh" "$TEMPORAL"; then
  printf '\n  No se pudo descargar el instalador.\n'
  printf '  Comprueba tu conexión a internet, o instala curl:\n'
  printf '      sudo apt-get install -y curl\n\n'
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
