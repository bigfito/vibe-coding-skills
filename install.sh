#!/usr/bin/env bash
# Arranque de agent-skills para macOS, Linux y WSL.
#
#   curl -fsSL https://raw.githubusercontent.com/<usuario>/agent-skills/main/install.sh | bash
#
# No depende de Node: su trabajo es comprobar que Node y npx existan y, si no,
# decirte exactamente cómo instalarlos en TU sistema. Solo entonces ejecuta npx.

set -u

REPO="${AGENT_SKILLS_REPO:-github:<usuario>/agent-skills}"
NODE_MINIMO=18

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'
else B=""; D=""; R=""; G=""; Y=""; N=""; fi

titulo() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
error()  { printf '\n%s%s%s\n' "$R" "$1" "$N"; }
cmd()    { printf '      %s%s%s\n' "$G" "$1" "$N"; }

# ---------------------------------------------------------- detectar sistema
SO="desconocido"; FAMILIA="desconocida"; WSL="no"
case "$(uname -s)" in
  Darwin) SO="macOS" ;;
  Linux)
    SO="Linux"
    grep -qi microsoft /proc/version 2>/dev/null && { WSL="si"; SO="WSL (Linux sobre Windows)"; }
    if [ -r /etc/os-release ]; then
      . /etc/os-release
      TODO="$(printf '%s %s' "${ID:-}" "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
      case "$TODO" in
        *debian*|*ubuntu*|*mint*|*pop*) FAMILIA="debian" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*alma*) FAMILIA="fedora" ;;
        *arch*|*manjaro*) FAMILIA="arch" ;;
        *alpine*) FAMILIA="alpine" ;;
        *suse*) FAMILIA="suse" ;;
      esac
    fi ;;
  CYGWIN*|MINGW*|MSYS*) SO="Windows (entorno tipo Unix)" ;;
esac

# ------------------------------------------------------- instrucciones Node
instrucciones_node() {
  printf '\n  %sCómo instalar Node.js en %s:%s\n' "$B" "$SO" "$N"
  if [ "$SO" = "macOS" ]; then
    if command -v brew >/dev/null 2>&1; then
      printf '\n   1) %sHomebrew (ya lo tienes)%s\n' "$B" "$N"; cmd "brew install node"
    else
      printf '\n   1) %sHomebrew (recomendado)%s\n' "$B" "$N"
      cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      cmd "brew install node"
    fi
    printf '\n   2) %sInstalador oficial%s\n' "$B" "$N"
    cmd "Descarga el .pkg LTS de https://nodejs.org/es/download"
  else
    local i=1
    case "$FAMILIA" in
      debian)
        printf '\n   %d) %sDebian, Ubuntu o derivadas%s\n' "$i" "$B" "$N"
        cmd "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
        cmd "sudo apt-get install -y nodejs"; i=$((i+1)) ;;
      fedora)
        printf '\n   %d) %sFedora, RHEL, Rocky o Alma%s\n' "$i" "$B" "$N"
        cmd "sudo dnf install -y nodejs npm"; i=$((i+1)) ;;
      arch)
        printf '\n   %d) %sArch o Manjaro%s\n' "$i" "$B" "$N"
        cmd "sudo pacman -S --noconfirm nodejs npm"; i=$((i+1)) ;;
      alpine)
        printf '\n   %d) %sAlpine%s\n' "$i" "$B" "$N"
        cmd "sudo apk add nodejs npm"; i=$((i+1)) ;;
      suse)
        printf '\n   %d) %sopenSUSE%s\n' "$i" "$B" "$N"
        cmd "sudo zypper install -y nodejs npm"; i=$((i+1)) ;;
    esac
    printf '\n   %d) %snvm (cualquier distribución, sin sudo)%s\n' "$i" "$B" "$N"
    cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
    cmd "nvm install --lts"
    [ "$WSL" = "si" ] && printf '\n   %sEstás en WSL:%s instala Node dentro de WSL. La instalación de Windows no sirve aquí.\n' "$Y" "$N"
  fi
  printf '\n  Cuando termines, vuelve a ejecutar este mismo comando.\n'
  printf '  Comprueba con: %snode --version%s y %snpx --version%s\n\n' "$G" "$N" "$G" "$N"
}

# ------------------------------------------------------------ comprobaciones
titulo "agent-skills — comprobando el entorno"
printf '  Sistema: %s\n' "$SO"

if ! command -v node >/dev/null 2>&1; then
  error "  No se encontró Node.js."
  instrucciones_node
  exit 1
fi

VERSION="$(node --version 2>/dev/null | sed 's/^v//')"
MAYOR="${VERSION%%.*}"
printf '  Node.js: %s\n' "$VERSION"

if ! [ "$MAYOR" -ge "$NODE_MINIMO" ] 2>/dev/null; then
  error "  Tu Node.js ($VERSION) es demasiado antiguo. Hace falta $NODE_MINIMO o superior."
  instrucciones_node
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  error "  Tienes Node.js pero no npx (viene con npm)."
  printf '\n  %sInstala npm:%s\n' "$B" "$N"
  case "$FAMILIA" in
    debian) cmd "sudo apt-get install -y npm" ;;
    fedora) cmd "sudo dnf install -y npm" ;;
    arch)   cmd "sudo pacman -S --noconfirm npm" ;;
    alpine) cmd "sudo apk add npm" ;;
    suse)   cmd "sudo zypper install -y npm" ;;
    *)      cmd "Reinstala Node.js desde https://nodejs.org/es/download (incluye npm y npx)" ;;
  esac
  printf '\n  Cuando termines, vuelve a ejecutar este mismo comando.\n\n'
  exit 1
fi
printf '  npx:     %s\n' "$(npx --version 2>/dev/null || echo disponible)"

if ! command -v git >/dev/null 2>&1; then
  error "  No se encontró git, y npx lo necesita para instalar desde GitHub."
  printf '\n  %sInstala git:%s\n' "$B" "$N"
  case "$FAMILIA" in
    debian) cmd "sudo apt-get install -y git" ;;
    fedora) cmd "sudo dnf install -y git" ;;
    arch)   cmd "sudo pacman -S --noconfirm git" ;;
    alpine) cmd "sudo apk add git" ;;
    suse)   cmd "sudo zypper install -y git" ;;
    *)      [ "$SO" = "macOS" ] && cmd "xcode-select --install" || cmd "https://git-scm.com/downloads" ;;
  esac
  printf '\n'
  exit 1
fi
printf '  git:     disponible\n'

printf '\n  %sTodo listo. Iniciando el instalador…%s\n' "$G" "$N"
exec npx -y "$REPO" "$@"
