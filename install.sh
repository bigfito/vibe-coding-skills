#!/usr/bin/env bash
# Arranque de agent-skills para macOS, Linux y WSL.
#
#   curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash
#
# No depende de Node. Su trabajo es:
#   1. detectar el sistema operativo y su gestor de paquetes,
#   2. comprobar que estén Node.js (>=18), npm, npx y git,
#   3. si falta algo, PEDIR PERMISO e instalarlo,
#   4. y solo entonces ejecutar el instalador real con npx.
#
# Opciones:
#   --yes, -y      instala los requisitos que falten sin preguntar
#   --no-install   nunca instala nada: solo dice qué falta y cómo instalarlo
# Cualquier otra opción se pasa tal cual al instalador (--all, --envs=…, etc.).

set -u

REPO="${AGENT_SKILLS_REPO:-github:bigfito/vibe-coding-skills}"
NODE_MINIMO=18

ASUMIR_SI="${AGENT_SKILLS_ASSUME_YES:-0}"
SIN_INSTALAR="${AGENT_SKILLS_NO_INSTALL:-0}"
ARGS_INSTALADOR=()

for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASUMIR_SI=1; ARGS_INSTALADOR+=("$arg") ;;
    --no-install) SIN_INSTALAR=1 ;;
    *) ARGS_INSTALADOR+=("$arg") ;;
  esac
done

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'
else B=""; D=""; R=""; G=""; Y=""; N=""; fi

titulo() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
aviso()  { printf '\n%s%s%s\n' "$Y" "$1" "$N"; }
error()  { printf '\n%s%s%s\n' "$R" "$1" "$N"; }
cmd()    { printf '      %s%s%s\n' "$G" "$1" "$N"; }
hay()    { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------- detectar sistema

SO="desconocido"; FAMILIA="desconocida"; WSL="no"
case "$(uname -s)" in
  Darwin) SO="macOS"; FAMILIA="macos" ;;
  Linux)
    SO="Linux"
    grep -qi microsoft /proc/version 2>/dev/null && { WSL="si"; SO="Linux sobre WSL"; }
    if [ -r /etc/os-release ]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      SO="${PRETTY_NAME:-Linux}"
      [ "$WSL" = "si" ] && SO="$SO sobre WSL"
      TODO="$(printf '%s %s' "${ID:-}" "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
      case "$TODO" in
        *debian*|*ubuntu*|*mint*|*pop*) FAMILIA="debian" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*alma*|*amzn*) FAMILIA="fedora" ;;
        *arch*|*manjaro*) FAMILIA="arch" ;;
        *alpine*) FAMILIA="alpine" ;;
        *suse*) FAMILIA="suse" ;;
      esac
    fi ;;
  CYGWIN*|MINGW*|MSYS*) SO="Windows (entorno tipo Unix)" ;;
esac

# ------------------------------------------------- detectar gestor de paquetes
#
# GESTOR queda vacío si no hay ninguno conocido. PAQUETE_NODE y PAQUETE_NPM
# guardan cómo se llama cada cosa en ese gestor.

GESTOR=""; GESTOR_NOMBRE=""; GESTOR_BIN=""; GESTOR_INSTALAR=""; GESTOR_REFRESCAR=""
GESTOR_SUDO="si"; PAQUETE_NODE=""; PAQUETE_NPM=""; PAQUETE_GIT="git"

elegir_gestor() {
  if [ "$FAMILIA" = "macos" ]; then
    if hay brew; then
      GESTOR="brew"; GESTOR_NOMBRE="Homebrew"; GESTOR_BIN="brew"
      GESTOR_INSTALAR="install"; GESTOR_REFRESCAR=""; GESTOR_SUDO="no"
      PAQUETE_NODE="node"; PAQUETE_NPM="node"
    fi
    return
  fi
  if hay apt-get; then
    GESTOR="apt"; GESTOR_NOMBRE="APT"; GESTOR_BIN="apt-get"
    GESTOR_INSTALAR="install -y"; GESTOR_REFRESCAR="update"
    PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay dnf; then
    GESTOR="dnf"; GESTOR_NOMBRE="DNF"; GESTOR_BIN="dnf"
    GESTOR_INSTALAR="install -y"; PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay yum; then
    GESTOR="yum"; GESTOR_NOMBRE="YUM"; GESTOR_BIN="yum"
    GESTOR_INSTALAR="install -y"; PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay pacman; then
    GESTOR="pacman"; GESTOR_NOMBRE="pacman"; GESTOR_BIN="pacman"
    GESTOR_INSTALAR="-S --noconfirm --needed"; GESTOR_REFRESCAR="-Sy"
    PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay apk; then
    GESTOR="apk"; GESTOR_NOMBRE="apk"; GESTOR_BIN="apk"
    GESTOR_INSTALAR="add"; GESTOR_REFRESCAR="update"
    PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay zypper; then
    GESTOR="zypper"; GESTOR_NOMBRE="zypper"; GESTOR_BIN="zypper"
    GESTOR_INSTALAR="install -y"; GESTOR_REFRESCAR="refresh"
    PAQUETE_NODE="nodejs"; PAQUETE_NPM="npm"
  elif hay brew; then
    GESTOR="brew"; GESTOR_NOMBRE="Homebrew"; GESTOR_BIN="brew"
    GESTOR_INSTALAR="install"; GESTOR_SUDO="no"
    PAQUETE_NODE="node"; PAQUETE_NPM="node"
  fi
}

# Prefijo sudo: vacío si ya somos root o si el gestor no lo quiere (Homebrew).
prefijo_sudo() {
  [ "$GESTOR_SUDO" = "no" ] && return 0
  [ "$(id -u 2>/dev/null || echo 0)" = "0" ] && return 0
  printf 'sudo'
}

# ------------------------------------------------------- instrucciones manuales

instrucciones_manuales() {
  printf '\n  %sInstálalo a mano y vuelve a ejecutar este mismo comando:%s\n' "$B" "$N"
  case "$FAMILIA" in
    macos)
      if hay brew; then cmd "brew install node git"
      else
        printf '\n   1) %sInstala Homebrew%s\n' "$B" "$N"
        cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        printf '\n   2) %sLuego%s\n' "$B" "$N"
        cmd "brew install node git"
      fi
      printf '\n   %sInstalador oficial:%s ' "$B" "$N"; printf 'descarga el .pkg LTS de https://nodejs.org/es/download\n' ;;
    debian) cmd "sudo apt-get update && sudo apt-get install -y nodejs npm git" ;;
    fedora) cmd "sudo dnf install -y nodejs npm git" ;;
    arch)   cmd "sudo pacman -S --noconfirm nodejs npm git" ;;
    alpine) cmd "sudo apk add nodejs npm git" ;;
    suse)   cmd "sudo zypper install -y nodejs npm git" ;;
    *)      cmd "Descarga Node.js de https://nodejs.org/es/download y git de https://git-scm.com/downloads" ;;
  esac
  printf '\n  %sSin permisos de administrador, con nvm:%s\n' "$B" "$N"
  cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
  cmd "nvm install --lts"
  [ "$WSL" = "si" ] && printf '\n  %sEstás en WSL:%s instala Node dentro de WSL. La instalación de Windows no sirve aquí.\n' "$Y" "$N"
  printf '\n  Comprueba con: %snode --version%s y %snpx --version%s\n\n' "$G" "$N" "$G" "$N"
}

# --------------------------------------------------------- comprobar requisitos
#
# Rellena FALTANTES (descripciones legibles) y PAQUETES (qué instalar).

FALTANTES=()
PAQUETES=()

anadir_paquete() {
  local p="$1"
  [ -z "$p" ] && return 0
  for existente in ${PAQUETES[@]+"${PAQUETES[@]}"}; do
    [ "$existente" = "$p" ] && return 0
  done
  PAQUETES+=("$p")
}

comprobar_requisitos() {
  FALTANTES=(); PAQUETES=()

  if ! hay node; then
    FALTANTES+=("Node.js: no está instalado")
    anadir_paquete "$PAQUETE_NODE"
  else
    local version mayor
    version="$(node --version 2>/dev/null | sed 's/^v//')"
    mayor="${version%%.*}"
    if ! [ "${mayor:-0}" -ge "$NODE_MINIMO" ] 2>/dev/null; then
      FALTANTES+=("Node.js: versión ${version:-desconocida}, hace falta $NODE_MINIMO o superior")
      anadir_paquete "$PAQUETE_NODE"
    fi
  fi

  if ! hay npm; then
    FALTANTES+=("npm: no está instalado")
    anadir_paquete "$PAQUETE_NPM"
  fi
  if ! hay npx; then
    FALTANTES+=("npx: no está instalado (viene con npm)")
    anadir_paquete "$PAQUETE_NPM"
  fi
  if ! hay git; then
    FALTANTES+=("git: no está instalado (npx lo necesita para descargar desde GitHub)")
    anadir_paquete "$PAQUETE_GIT"
  fi
}

# ---------------------------------------------------------------- consentimiento
#
# Se lee de /dev/tty y no de stdin: cuando el script llega por una tubería
# (curl … | bash) stdin es el propio script, no la persona.

# Se comprueba abriendo /dev/tty de verdad: que el archivo exista no significa
# que haya una persona al otro lado (procesos sin terminal de control).
hay_terminal() { ( : < /dev/tty ) 2>/dev/null; }

confirmar() {
  local respuesta=""
  printf '\n  %s %s[S/n]%s ' "$1" "$D" "$N"
  if ! read -r respuesta < /dev/tty 2>/dev/null; then
    printf '\n'
    return 1
  fi
  case "$(printf '%s' "$respuesta" | tr '[:upper:]' '[:lower:]')" in
    ''|s|si|sí|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

# -------------------------------------------------------------------- arranque

titulo "agent-skills — comprobando el entorno"
printf '  Sistema: %s\n' "$SO"

elegir_gestor
if [ -n "$GESTOR" ]; then printf '  Gestor:  %s\n' "$GESTOR_NOMBRE"
else printf '  Gestor:  %sninguno conocido%s\n' "$Y" "$N"; fi

comprobar_requisitos

if [ "${#FALTANTES[@]}" -gt 0 ]; then
  aviso "  Faltan requisitos para poder continuar:"
  for f in "${FALTANTES[@]}"; do printf '   • %s\n' "$f"; done

  if [ -z "$GESTOR" ]; then
    error "  No encontré un gestor de paquetes conocido, así que no puedo instalarlos por ti."
    instrucciones_manuales
    exit 1
  fi

  SUDO="$(prefijo_sudo)"
  if [ -n "$SUDO" ] && ! hay sudo; then
    error "  Hace falta sudo para instalar con $GESTOR_NOMBRE, y no está disponible."
    printf '  Ejecuta este script como root, o instala los requisitos a mano.\n'
    instrucciones_manuales
    exit 1
  fi

  ORDEN_REFRESCAR=""
  [ -n "$GESTOR_REFRESCAR" ] && ORDEN_REFRESCAR="${SUDO:+$SUDO }$GESTOR_BIN $GESTOR_REFRESCAR"
  # La expansión lleva guarda para que un array vacío no reviente con `set -u`
  # en las versiones antiguas de bash (macOS trae bash 3.2).
  ORDEN_INSTALAR="${SUDO:+$SUDO }$GESTOR_BIN $GESTOR_INSTALAR ${PAQUETES[*]+${PAQUETES[*]}}"

  printf '\n  Puedo instalarlos con %s%s%s:\n' "$B" "$GESTOR_NOMBRE" "$N"
  [ -n "$ORDEN_REFRESCAR" ] && cmd "$ORDEN_REFRESCAR"
  cmd "$ORDEN_INSTALAR"
  [ -n "$SUDO" ] && printf '  %ssudo puede pedirte la contraseña de tu usuario.%s\n' "$D" "$N"

  if [ "$SIN_INSTALAR" = "1" ]; then
    aviso "  Instalación automática desactivada (--no-install)."
    instrucciones_manuales
    exit 1
  fi

  if [ "$ASUMIR_SI" != "1" ]; then
    if ! hay_terminal; then
      error "  No hay terminal interactiva para pedirte permiso."
      printf '  Vuelve a ejecutarlo añadiendo %s--yes%s para autorizar la instalación.\n' "$G" "$N"
      instrucciones_manuales
      exit 1
    fi
    if ! confirmar "¿Los instalo ahora?"; then
      aviso "  No se instaló nada."
      instrucciones_manuales
      exit 1
    fi
  fi

  printf '\n  %sInstalando…%s\n' "$B" "$N"
  if [ -n "$ORDEN_REFRESCAR" ]; then
    printf '    %s$ %s%s\n' "$D" "$ORDEN_REFRESCAR" "$N"
    # Un índice desactualizado no es fatal: puede instalarse desde la caché.
    eval "$ORDEN_REFRESCAR" || aviso "  No se pudo actualizar el índice de paquetes; sigo con la instalación."
  fi
  printf '    %s$ %s%s\n' "$D" "$ORDEN_INSTALAR" "$N"
  if ! eval "$ORDEN_INSTALAR"; then
    error "  La instalación falló."
    instrucciones_manuales
    exit 1
  fi

  # El binario recién instalado puede vivir en una carpeta que este shell aún no
  # tiene en el PATH (Homebrew en Apple Silicon, /usr/local/bin, ~/.local/bin…).
  for extra in /usr/local/bin /opt/homebrew/bin /home/linuxbrew/.linuxbrew/bin "$HOME/.local/bin"; do
    [ -d "$extra" ] && case ":$PATH:" in *":$extra:"*) ;; *) PATH="$PATH:$extra" ;; esac
  done
  export PATH
  hash -r 2>/dev/null || true

  # Lo que vale no es que el gestor dijera "ok", sino que ahora existan de verdad.
  comprobar_requisitos
  if [ "${#FALTANTES[@]}" -gt 0 ]; then
    error "  Se instaló, pero todavía falta:"
    for f in "${FALTANTES[@]}"; do printf '   • %s\n' "$f"; done
    printf '\n  Si tu distribución trae una versión antigua de Node, instala una moderna con nvm:\n'
    cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
    cmd "nvm install --lts"
    printf '\n  Después cierra y vuelve a abrir la terminal, y repite este comando.\n\n'
    exit 1
  fi
  printf '\n  %sListo: todos los requisitos están instalados.%s\n' "$G" "$N"
fi

printf '  Node.js: %s\n' "$(node --version 2>/dev/null | sed 's/^v//')"
printf '  npx:     %s\n' "$(npx --version 2>/dev/null || echo disponible)"
printf '  git:     %s\n' "$(git --version 2>/dev/null | awk '{print $3}' || echo disponible)"

printf '\n  %sTodo listo. Iniciando el instalador…%s\n' "$G" "$N"

# Con `curl … | bash`, stdin es el propio script y el menú no podría leerse.
# Reconectamos la entrada al terminal real para que el menú funcione igual.
if [ ! -t 0 ] && [ -r /dev/tty ]; then
  exec npx -y "$REPO" ${ARGS_INSTALADOR[@]+"${ARGS_INSTALADOR[@]}"} < /dev/tty
fi
exec npx -y "$REPO" ${ARGS_INSTALADOR[@]+"${ARGS_INSTALADOR[@]}"}
