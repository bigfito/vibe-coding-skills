#!/usr/bin/env bash
# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
#
# Pruebas de extremo a extremo de Vibe Coding Skills.
#
#   bash tests/run-tests.sh
#
# Cubren tres cosas:
#   1. que el código esté sintácticamente sano en Bash, Node y PowerShell,
#   2. que la comprobación de requisitos detecte, pida permiso e instale,
#   3. que la instalación de skills deje los archivos donde corresponde.
#
# Las pruebas que "instalan paquetes" usan un gestor de paquetes falso: nunca
# tocan el sistema real. Se ejecutan en carpetas temporales que se borran al
# terminar.

set -u

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# La instalación global escribe en la carpeta personal, así que las pruebas
# corren con un HOME de mentira: nunca deben tocar la del usuario.
CASA_REAL="$HOME"
export HOME="$TMP/casa"
mkdir -p "$HOME"

OK=0
FALLOS=0

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; D=$'\033[2m'; N=$'\033[0m'
else G=""; R=""; Y=""; D=""; N=""; fi

pasa()  { OK=$((OK+1)); printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
falla() { FALLOS=$((FALLOS+1)); printf '  %s✗%s %s\n' "$R" "$N" "$1"; [ $# -gt 1 ] && printf '%s%s%s\n' "$D" "$2" "$N"; }
salta() { printf '  %s–%s %s\n' "$Y" "$N" "$1"; }
titulo(){ printf '\n%s\n' "$1"; }

# Comprueba que una salida contenga un texto.
contiene() {
  local salida="$1" esperado="$2" nombre="$3"
  if printf '%s' "$salida" | grep -qF -- "$esperado"; then pasa "$nombre"
  else falla "$nombre" "esperaba encontrar: $esperado"$'\n'"salida:"$'\n'"$salida"; fi
}

no_contiene() {
  local salida="$1" prohibido="$2" nombre="$3"
  if printf '%s' "$salida" | grep -qF -- "$prohibido"; then falla "$nombre" "no esperaba: $prohibido"
  else pasa "$nombre"; fi
}

igual() {
  local obtenido="$1" esperado="$2" nombre="$3"
  if [ "$obtenido" = "$esperado" ]; then pasa "$nombre"
  else falla "$nombre" "esperaba [$esperado], obtuve [$obtenido]"; fi
}

# Crea un ejecutable de mentira leyendo su contenido de la entrada estándar.
# Borra antes el destino: si fuera un symlink a la herramienta real, `cat >`
# escribiría en ella y estropearía el sistema.
crear_stub() {
  local destino="$1"
  rm -f "$destino"
  cat > "$destino"
  chmod +x "$destino"
}

# PowerShell puede no estar instalado: las pruebas que lo necesitan se saltan.
PWSH="$(command -v pwsh 2>/dev/null || true)"
[ -z "$PWSH" ] && [ -x /opt/pwsh/pwsh ] && PWSH=/opt/pwsh/pwsh

# ---------------------------------------------------------------- 1. sintaxis

titulo "1. Sintaxis"

if node --check "$RAIZ/bin/vibe-coding-skills.cjs" 2>/dev/null; then pasa "bin/vibe-coding-skills.cjs parsea"
else falla "bin/vibe-coding-skills.cjs parsea"; fi

if node --check "$RAIZ/lib/preflight.cjs" 2>/dev/null; then pasa "lib/preflight.cjs parsea"
else falla "lib/preflight.cjs parsea"; fi

if node --input-type=module --eval "$(cat "$RAIZ/lib/install.mjs" | sed 's/^main()/\/\/main()/')" --check 2>/dev/null \
   || node --check "$RAIZ/lib/install.mjs" 2>/dev/null; then pasa "lib/install.mjs parsea"
else falla "lib/install.mjs parsea"; fi

if bash -n "$RAIZ/install.sh"; then pasa "install.sh parsea"; else falla "install.sh parsea"; fi

if [ -n "$PWSH" ]; then
  if "$PWSH" -NoProfile -Command "
      \$e=\$null
      foreach (\$f in @('$RAIZ/install.ps1', '$RAIZ/lib/sin-node.ps1')) {
        [System.Management.Automation.Language.Parser]::ParseFile(\$f,[ref]\$null,[ref]\$e) > \$null
        if (\$e.Count -gt 0) { \$e | ForEach-Object { \$_.Message }; exit 1 }
      }" >/dev/null 2>&1
  then pasa "install.ps1 y lib/sin-node.ps1 parsean"; else falla "install.ps1 y lib/sin-node.ps1 parsean"; fi
else
  salta "sintaxis de PowerShell (pwsh no está instalado en esta máquina)"
fi

# --------------------------------------------- 2. lógica de preflight (unidad)

titulo "2. Detección de sistema y plan de instalación"

salida="$(node -e "
  var pre = require('$RAIZ/lib/preflight.cjs');
  var plat = pre.detectarPlataforma();
  console.log('so=' + plat.so);
  console.log('familia=' + plat.familia);
  var g = pre.detectarGestor(plat);
  console.log('gestor=' + (g ? g.id : 'ninguno'));
" 2>&1)"
contiene "$salida" "so=linux" "detecta Linux"
contiene "$salida" "familia=debian" "detecta la familia Debian/Ubuntu"
contiene "$salida" "gestor=apt" "elige APT como gestor"

# Sin privilegios de root, el plan tiene que anteponer sudo; con root, no.
salida="$(node -e "
  process.getuid = function () { return 1000; };
  var pre = require('$RAIZ/lib/preflight.cjs');
  var g = pre.detectarGestor({ so: 'linux', familia: 'debian' });
  var ordenes = pre.ordenesInstalacion(g, ['nodejs', 'npm', 'git']);
  ordenes.forEach(function (o) { console.log(pre.textoOrden(o)); });
" 2>&1)"
contiene "$salida" "sudo apt-get update" "usuario normal: refresca índices con sudo"
contiene "$salida" "sudo apt-get install -y nodejs npm git" "usuario normal: instala con sudo"

salida="$(node -e "
  process.getuid = function () { return 0; };
  var pre = require('$RAIZ/lib/preflight.cjs');
  var g = pre.detectarGestor({ so: 'linux', familia: 'debian' });
  console.log(pre.textoOrden(pre.ordenesInstalacion(g, ['git'])[1]));
" 2>&1)"
no_contiene "$salida" "sudo" "root: no antepone sudo"

# Homebrew nunca debe ejecutarse con sudo, ni siquiera como usuario normal.
salida="$(node -e "
  process.getuid = function () { return 1000; };
  var pre = require('$RAIZ/lib/preflight.cjs');
  var g = JSON.parse(JSON.stringify(pre.GESTORES.brew)); g.id = 'brew';
  console.log(pre.textoOrden(pre.ordenesInstalacion(g, ['node'])[0]));
" 2>&1)"
igual "$salida" "brew install node" "Homebrew se invoca sin sudo"

# winget instala un paquete por orden.
salida="$(node -e "
  var pre = require('$RAIZ/lib/preflight.cjs');
  var g = JSON.parse(JSON.stringify(pre.GESTORES.winget)); g.id = 'winget';
  console.log(pre.ordenesInstalacion(g, ['OpenJS.NodeJS.LTS', 'Git.Git']).length);
" 2>&1)"
igual "$salida" "2" "winget genera una orden por paquete"

# Cada requisito conoce su paquete en cada gestor: sin huecos.
salida="$(node -e "
  var pre = require('$RAIZ/lib/preflight.cjs');
  var faltan = [];
  pre.REQUISITOS.forEach(function (r) {
    Object.keys(pre.GESTORES).forEach(function (g) {
      if (!r.paquetes[g]) faltan.push(r.clave + '/' + g);
    });
  });
  console.log(faltan.length ? 'HUECOS: ' + faltan.join(', ') : 'completo');
" 2>&1)"
igual "$salida" "completo" "todo requisito tiene paquete en todo gestor"

# ------------------------------------------- 3. entorno simulado sin requisitos

titulo "3. Requisitos faltantes: consentimiento e instalación"

# Un PATH mínimo donde git no existe, con un apt-get falso que registra lo que
# se le pide y "instala" creando el ejecutable correspondiente.
STUB="$TMP/bin"
LOG="$TMP/apt.log"
mkdir -p "$STUB"
# node y las herramientas de shell que install.sh usa; git queda fuera a propósito.
for real in node npm npx bash sh env uname grep sed awk tr id cat setsid chmod curl wget dirname basename rm mkdir cp find tar gzip mktemp head; do
  ruta="$(command -v "$real" 2>/dev/null)" && ln -sf "$ruta" "$STUB/$real"
done

crear_stub "$STUB/apt-get" <<STUBEOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "$LOG"
if [ "\${1:-}" = "install" ]; then
  for p in "\$@"; do
    [ "\$p" = "install" ] && continue
    [ "\$p" = "-y" ] && continue
    if [ "\$p" = "git" ]; then
      printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' > "$STUB/git"
      chmod +x "$STUB/git"
    fi
  done
fi
exit 0
STUBEOF

# 3a. Sin instalar: informa y se detiene.
# Un proyecto de usar y tirar: el camino normal instala requisitos Y skills.
PROY_REQ="$TMP/proyecto-requisitos"
mkdir -p "$PROY_REQ"
sin_git() { PATH="$STUB" "$@"; }

salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/vibe-coding-skills.cjs" --check 2>&1)"
codigo=$?
contiene "$salida" "git" "detecta que falta git"
contiene "$salida" "apt-get install -y git" "muestra la orden exacta que usaría"
contiene "$salida" "solo una comprobación" "--check avisa de que no instala nada"
igual "$codigo" "1" "sale con error cuando falta un requisito"
[ ! -f "$LOG" ] && pasa "--check no ejecuta el gestor" || falla "--check no ejecuta el gestor" "$(cat "$LOG")"

# Comprobar nunca instala, ni aunque se autorice de antemano con --yes.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/vibe-coding-skills.cjs" --check --yes < /dev/null 2>&1)"
contiene "$salida" "solo una comprobación" "--check gana sobre --yes"
[ ! -f "$LOG" ] && pasa "--check --yes sigue sin instalar" || falla "--check --yes sigue sin instalar" "$(cat "$LOG")"

# 3b. Con --no-install: informa, da instrucciones manuales y no toca nada.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/vibe-coding-skills.cjs" --all --envs=claude --no-install --local < /dev/null 2>&1)"
contiene "$salida" "--no-install" "respeta --no-install"
contiene "$salida" "Instálalo a mano" "con --no-install da instrucciones manuales"
[ ! -f "$LOG" ] && pasa "con --no-install no ejecuta el gestor" || falla "con --no-install no ejecuta el gestor" "$(cat "$LOG")"

# 3c. Sin terminal y sin --yes: no instala nada a espaldas del usuario.
salida="$(cd "$PROY_REQ" && PATH="$STUB" setsid node "$RAIZ/bin/vibe-coding-skills.cjs" --all --envs=claude --local < /dev/null 2>&1)"
contiene "$salida" "No hay terminal interactiva" "sin TTY pide --yes en lugar de instalar"
[ ! -f "$LOG" ] && pasa "sin TTY no ejecuta el gestor" || falla "sin TTY no ejecuta el gestor" "$(cat "$LOG")"

# 3d. Diálogo real: `script` presta un terminal (pty) al proceso, que es lo que
# hace falta para ejercitar el consentimiento tal como lo ve una persona.
en_terminal() {
  local respuesta="$1" transcripcion="$TMP/pty.txt"
  rm -f "$transcripcion"
  printf '%s' "$respuesta" | script -q -c "cd '$PROY_REQ' && env PATH='$STUB' node '$RAIZ/bin/vibe-coding-skills.cjs' --skills=java-developer --envs=claude --local" "$transcripcion" >/dev/null 2>&1
  cat "$transcripcion"
}

if command -v script >/dev/null 2>&1; then
  salida="$(en_terminal 'n
')"
  contiene "$salida" "Los instalo ahora" "pregunta antes de instalar"
  contiene "$salida" "No se instaló nada" "responder 'n' cancela la instalación"
  [ ! -f "$LOG" ] && pasa "al cancelar no ejecuta el gestor" || falla "al cancelar no ejecuta el gestor" "$(cat "$LOG")"
  [ ! -d "$PROY_REQ/.claude" ] && pasa "al cancelar tampoco instala skills" || falla "al cancelar tampoco instala skills"

  # Enter = sí: instala los requisitos, reverifica y sigue con las skills.
  salida="$(en_terminal '

')"
  contiene "$salida" "Instalando" "Enter acepta la instalación"
  contiene "$salida" "todos los requisitos están instalados" "reverifica después de instalar"
  [ -f "$LOG" ] && contiene "$(cat "$LOG")" "apt-get install -y git" "ejecutó la instalación del paquete que faltaba" \
                || falla "ejecutó la instalación del paquete que faltaba" "no se registró ninguna llamada"
  [ -f "$PROY_REQ/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "tras instalar los requisitos, instala las skills" || falla "tras instalar los requisitos, instala las skills"
  rm -rf "$PROY_REQ/.claude"
  rm -f "$STUB/git" "$LOG"
else
  salta "prueba del diálogo de consentimiento (falta el comando 'script')"
fi

# 3e. Con --yes instala sin preguntar.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --local < /dev/null 2>&1)"
contiene "$salida" "Instalando" "--yes instala sin preguntar"
contiene "$salida" "todos los requisitos están instalados" "--yes deja el entorno completo"
[ -f "$LOG" ] && contiene "$(cat "$LOG")" "apt-get update" "refresca el índice antes de instalar" \
              || falla "refresca el índice antes de instalar" "no se registró ninguna llamada"
rm -rf "$PROY_REQ/.claude"
rm -f "$STUB/git" "$LOG"

# 3f. Simulación: muestra el plan pero no toca nada.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/vibe-coding-skills.cjs" --all --dry-run --local < /dev/null 2>&1)"
contiene "$salida" "Modo simulación" "--dry-run no instala"
[ ! -f "$LOG" ] && pasa "--dry-run no ejecuta el gestor" || falla "--dry-run no ejecuta el gestor" "$(cat "$LOG")"

# 3g. Sin gestor de paquetes conocido: explica cómo hacerlo a mano.
SOLO_NODE="$TMP/solo-node"
mkdir -p "$SOLO_NODE"
for real in node npm npx; do ln -sf "$(command -v "$real")" "$SOLO_NODE/$real"; done
salida="$(cd "$PROY_REQ" && PATH="$SOLO_NODE" node "$RAIZ/bin/vibe-coding-skills.cjs" --all --envs=claude --yes --local < /dev/null 2>&1)"
contiene "$salida" "gestor de paquetes" "sin gestor, lo dice claramente"
contiene "$salida" "Instálalo a mano" "sin gestor, da instrucciones manuales"

# ------------------------------------------------- 4. instalación de las skills

titulo "4. Instalación de skills en un proyecto"

PROY="$TMP/proyecto"
mkdir -p "$PROY"

salida="$(cd "$PROY" && node "$RAIZ/bin/vibe-coding-skills.cjs" --all --envs=claude,cursor --yes --local 2>&1)"
contiene "$salida" "instalados" "instala con --all --yes"
[ -f "$PROY/.claude/skills/solution-architect/SKILL.md" ] \
  && pasa "copia SKILL.md a .claude/skills/" || falla "copia SKILL.md a .claude/skills/"
[ -f "$PROY/.claude/skills/solution-architect/assets/PLAN-template.md" ] \
  && pasa "copia los assets de la skill" || falla "copia los assets de la skill"
[ -f "$PROY/.claude/agents/solution-architect.md" ] \
  && pasa "copia los subagentes a .claude/agents/" || falla "copia los subagentes a .claude/agents/"
[ -f "$PROY/.cursor/rules/java-developer.mdc" ] \
  && pasa "copia las reglas de Cursor" || falla "copia las reglas de Cursor"
[ ! -d "$PROY/.junie" ] && pasa "no toca entornos no pedidos" || falla "no toca entornos no pedidos"

# Segunda pasada: no pisa lo que ya existe.
salida="$(cd "$PROY" && node "$RAIZ/bin/vibe-coding-skills.cjs" --all --envs=claude,cursor --yes --local 2>&1)"
contiene "$salida" "ya existían y no se tocaron" "es idempotente sin --force"

# Con --force sí sobrescribe.
echo "modificado" > "$PROY/.cursor/rules/java-developer.mdc"
salida="$(cd "$PROY" && node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=cursor --yes --force --local 2>&1)"
if grep -q "modificado" "$PROY/.cursor/rules/java-developer.mdc"; then falla "--force sobrescribe"
else pasa "--force sobrescribe"; fi

# Simulación: no escribe nada.
PROY2="$TMP/proyecto-seco"
mkdir -p "$PROY2"
salida="$(cd "$PROY2" && node "$RAIZ/bin/vibe-coding-skills.cjs" --all --dry-run --local 2>&1)"
contiene "$salida" "se copiarían" "--dry-run informa sin escribir"
[ -z "$(ls -A "$PROY2")" ] && pasa "--dry-run deja la carpeta intacta" || falla "--dry-run deja la carpeta intacta"

# Antigravity: reglas y flujos van a carpetas distintas.
PROY3="$TMP/proyecto-antigravity"
mkdir -p "$PROY3"
(cd "$PROY3" && node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=solution-architect --envs=antigravity,junie --yes --local >/dev/null 2>&1)
[ -f "$PROY3/.agents/rules/solution-architect-01.md" ] \
  && pasa "instala las reglas de Antigravity" || falla "instala las reglas de Antigravity"
[ -f "$PROY3/.agents/workflows/solution-architect.md" ] \
  && pasa "separa los flujos de Antigravity" || falla "separa los flujos de Antigravity"
[ -f "$PROY3/.junie/rules/solution-architect.md" ] \
  && pasa "instala las reglas de Junie" || falla "instala las reglas de Junie"

# Skill inexistente: avisa y no revienta.
salida="$(cd "$TMP" && node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=no-existe --envs=claude --yes --local 2>&1)"
contiene "$salida" "No hay skills válidas" "rechaza skills desconocidas"

# --------------------------------------------------------- 5. arranque install.sh

titulo "5. Arranque install.sh"

# npx falso: el script debe llegar hasta aquí y pasarle los argumentos.
NPX_LOG="$TMP/npx.log"
crear_stub "$STUB/npx" <<STUBEOF
#!/usr/bin/env bash
echo "npx \$*" >> "$NPX_LOG"
exit 0
STUBEOF

salida="$(PATH="$STUB" bash "$RAIZ/install.sh" --all --yes < /dev/null 2>&1)"
contiene "$salida" "comprobando el entorno" "install.sh arranca"
contiene "$salida" "Faltan requisitos" "install.sh detecta que falta git"
contiene "$salida" "Instalando" "install.sh instala tras autorizar con --yes"
contiene "$salida" "Todo listo" "install.sh llega al instalador"
[ -f "$NPX_LOG" ] && contiene "$(cat "$NPX_LOG")" "--all --yes" "install.sh pasa los argumentos a npx" \
                  || falla "install.sh pasa los argumentos a npx" "npx no se ejecutó"
rm -f "$STUB/git" "$LOG" "$NPX_LOG"

# La comprobación por variable de entorno (la forma que funciona con `irm | iex`)
# tiene que llegar hasta el instalador como --check, no como una instalación.
rm -f "$NPX_LOG"
printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$STUB/git"
salida="$(PATH="$STUB" VIBE_SKILLS_CHECK=1 bash "$RAIZ/install.sh" < /dev/null 2>&1)"
[ -f "$NPX_LOG" ] && contiene "$(cat "$NPX_LOG")" "--check" "VIBE_SKILLS_CHECK reenvía --check al instalador" \
                  || falla "VIBE_SKILLS_CHECK reenvía --check al instalador" "npx no se ejecutó"
no_contiene "$salida" "No such device" "install.sh no falla al reconectar el terminal"
rm -f "$STUB/git" "$NPX_LOG"

salida="$(PATH="$STUB" bash "$RAIZ/install.sh" --check --yes < /dev/null 2>&1)"
contiene "$salida" "solo una comprobación" "install.sh con --check no instala nada"
[ ! -f "$LOG" ] && pasa "install.sh con --check no ejecuta el gestor" || falla "install.sh con --check no ejecuta el gestor" "$(cat "$LOG")"
[ ! -f "$NPX_LOG" ] && pasa "install.sh con --check no arranca el instalador" || falla "install.sh con --check no arranca el instalador"

salida="$(PATH="$STUB" bash "$RAIZ/install.sh" --no-install < /dev/null 2>&1)"
contiene "$salida" "Instalación automática desactivada" "install.sh respeta --no-install"
[ ! -f "$NPX_LOG" ] && pasa "install.sh no arranca el instalador si falta algo" \
                    || falla "install.sh no arranca el instalador si falta algo"

salida="$(PATH="$STUB" setsid bash "$RAIZ/install.sh" < /dev/null 2>&1)"
contiene "$salida" "No hay terminal interactiva" "install.sh sin TTY pide --yes"
[ ! -f "$LOG" ] && pasa "install.sh sin TTY no instala nada" || falla "install.sh sin TTY no instala nada"

# Entorno completo: va directo al instalador, sin preguntar nada.
printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$STUB/git"
salida="$(PATH="$STUB" bash "$RAIZ/install.sh" --check < /dev/null 2>&1)"
no_contiene "$salida" "Faltan requisitos" "install.sh no molesta si no falta nada"
contiene "$salida" "Todo listo" "install.sh arranca el instalador directamente"

# ------------------------------------------------------ 6. Arranque install.ps1
#
# install.ps1 se ejecuta tal cual en PowerShell, aunque el PowerShell sea el de
# Linux o macOS: lo que se comprueba es su lógica (detectar, pedir permiso,
# instalar, reverificar), con un winget falso.

titulo "6. Arranque install.ps1"

if [ -z "${PWSH:-}" ]; then
  salta "pruebas de install.ps1 (PowerShell no está instalado en esta máquina)"
else
  PS_STUB="$TMP/psbin"
  PS_LOG="$TMP/winget.log"
  PS_NPX_LOG="$TMP/npx-ps.log"
  mkdir -p "$PS_STUB"
  for real in node npm bash sh env setsid; do
    ruta="$(command -v "$real" 2>/dev/null)" && ln -sf "$ruta" "$PS_STUB/$real"
  done

  crear_stub "$PS_STUB/winget" <<STUBEOF
#!/usr/bin/env bash
echo "winget \$*" >> "$PS_LOG"
for a in "\$@"; do
  if [ "\$a" = "Git.Git" ]; then
    printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' > "$PS_STUB/git"
    $(command -v chmod) +x "$PS_STUB/git"
  fi
done
exit 0
STUBEOF
  crear_stub "$PS_STUB/npx" <<STUBEOF
#!/usr/bin/env bash
echo "npx \$*" >> "$PS_NPX_LOG"
exit 0
STUBEOF

  salida="$(PATH="$PS_STUB" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --all --yes < /dev/null 2>&1)"
  contiene "$salida" "Faltan requisitos" "install.ps1 detecta que falta git"
  contiene "$salida" "winget install" "install.ps1 planea la orden de winget"
  contiene "$salida" "todos los requisitos estan instalados" "install.ps1 reverifica tras instalar"
  [ -f "$PS_NPX_LOG" ] && contiene "$(cat "$PS_NPX_LOG")" "--all --yes" "install.ps1 pasa los argumentos a npx" \
                       || falla "install.ps1 pasa los argumentos a npx" "npx no se ejecutó"
  rm -f "$PS_STUB/git" "$PS_LOG" "$PS_NPX_LOG"

  rm -f "$PS_NPX_LOG"
  printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$PS_STUB/git"
  salida="$(PATH="$PS_STUB" VIBE_SKILLS_CHECK=1 "$PWSH" -NoProfile -File "$RAIZ/install.ps1" < /dev/null 2>&1)"
  [ -f "$PS_NPX_LOG" ] && contiene "$(cat "$PS_NPX_LOG")" "--check" "install.ps1 reenvía --check con VIBE_SKILLS_CHECK" \
                       || falla "install.ps1 reenvía --check con VIBE_SKILLS_CHECK" "npx no se ejecutó"
  rm -f "$PS_STUB/git" "$PS_NPX_LOG"

  salida="$(PATH="$PS_STUB" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --check --yes < /dev/null 2>&1)"
  contiene "$salida" "solo una comprobacion" "install.ps1 con --check no instala nada"
  [ ! -f "$PS_LOG" ] && pasa "install.ps1 con --check no ejecuta winget" || falla "install.ps1 con --check no ejecuta winget"

  salida="$(PATH="$PS_STUB" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --no-install < /dev/null 2>&1)"
  contiene "$salida" "desactivada" "install.ps1 respeta --no-install"
  [ ! -f "$PS_LOG" ] && pasa "install.ps1 con --no-install no ejecuta winget" \
                     || falla "install.ps1 con --no-install no ejecuta winget"

  salida="$(PATH="$PS_STUB" setsid "$PWSH" -NoProfile -File "$RAIZ/install.ps1" < /dev/null 2>&1)"
  contiene "$salida" "No hay terminal interactiva" "install.ps1 sin TTY pide --yes"
  [ ! -f "$PS_LOG" ] && pasa "install.ps1 sin TTY no instala nada" || falla "install.ps1 sin TTY no instala nada"

  if command -v script >/dev/null 2>&1; then
    rm -f "$TMP/pty-ps.txt"
    printf 'n\n' | script -q -c "env PATH='$PS_STUB' '$PWSH' -NoProfile -File '$RAIZ/install.ps1'" "$TMP/pty-ps.txt" >/dev/null 2>&1
    salida="$(cat "$TMP/pty-ps.txt")"
    contiene "$salida" "Los instalo ahora" "install.ps1 pregunta antes de instalar"
    contiene "$salida" "No se instalo nada" "install.ps1 acepta un 'n' como cancelación"
    [ ! -f "$PS_LOG" ] && pasa "install.ps1 al cancelar no ejecuta winget" || falla "install.ps1 al cancelar no ejecuta winget"
  else
    salta "diálogo de consentimiento de install.ps1 (falta el comando 'script')"
  fi

  PS_SIN_GESTOR="$TMP/psbin-sin-gestor"
  mkdir -p "$PS_SIN_GESTOR"
  for real in node npm npx; do ln -sf "$(command -v "$real")" "$PS_SIN_GESTOR/$real"; done
  salida="$(PATH="$PS_SIN_GESTOR" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --yes < /dev/null 2>&1)"
  contiene "$salida" "No encontre winget" "install.ps1 sin gestor da instrucciones manuales"
fi

# ------------------------------------------------- 7. Elección de carpeta

titulo "7. Elegir la carpeta del proyecto"

# Alimenta un proceso en un terminal real, dejando tiempo entre respuestas para
# que cada pregunta se lea por separado.
en_pty_dir() {
  local dir="$1" argumentos="$2"; shift 2
  local transcripcion="$TMP/pty-dir.txt"
  rm -f "$transcripcion"
  {
    # Un respiro inicial: si se escribe antes de que el programa arranque, el
    # terminal se traga la primera línea y la prueba mide otra cosa.
    sleep 1
    for linea in "$@"; do printf '%s\n' "$linea"; sleep 0.6; done
  } | script -q -c "cd '$dir' && node '$RAIZ/bin/vibe-coding-skills.cjs' $argumentos" "$transcripcion" >/dev/null 2>&1
  cat "$transcripcion"
}

DESTINO_DIR="$TMP/otro proyecto"
SIN_MARCAS="$TMP/carpeta-suelta"
CON_MARCAS="$TMP/proyecto-marcado"
mkdir -p "$DESTINO_DIR" "$SIN_MARCAS" "$CON_MARCAS"
: > "$CON_MARCAS/package.json"

# 7a. --dir= instala en otra carpeta, aunque tenga espacios.
salida="$(cd "$SIN_MARCAS" && node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --local --dir="$DESTINO_DIR" 2>&1)"
contiene "$salida" "instalados" "--dir instala sin preguntar"
[ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
  && pasa "--dir instala en la carpeta indicada" || falla "--dir instala en la carpeta indicada"
[ ! -d "$SIN_MARCAS/.claude" ] && pasa "--dir no toca la carpeta actual" || falla "--dir no toca la carpeta actual"
rm -rf "$DESTINO_DIR/.claude"

# 7b. Una ruta escrita como la deja arrastrar la carpeta (espacios escapados).
salida="$(cd "$SIN_MARCAS" && node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --local --dir="${DESTINO_DIR// /\\ }" 2>&1)"
[ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
  && pasa "--dir entiende los espacios escapados de arrastrar" || falla "--dir entiende los espacios escapados de arrastrar"
rm -rf "$DESTINO_DIR/.claude"

# 7c. --dir con una carpeta que no existe: lo dice y no inventa nada.
salida="$(node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --local --dir="$TMP/no-existe" 2>&1)"
codigo=$?
contiene "$salida" "no existe" "--dir inexistente avisa con claridad"
igual "$codigo" "1" "--dir inexistente termina con error"

if command -v script >/dev/null 2>&1; then
  # 7d. Carpeta que no parece proyecto: pregunta y usa la ruta indicada.
  salida="$(en_pty_dir "$SIN_MARCAS" "" "$DESTINO_DIR" "3" "1" "2" "")"
  contiene "$salida" "no parece un proyecto" "pregunta cuando la carpeta no parece un proyecto"
  contiene "$salida" "Se instalará en" "confirma la carpeta elegida"
  [ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "instala en la carpeta que responde el usuario" || falla "instala en la carpeta que responde el usuario"
  [ ! -d "$SIN_MARCAS/.claude" ] && pasa "no instala en la carpeta actual si eligió otra" || falla "no instala en la carpeta actual si eligió otra"
  rm -rf "$DESTINO_DIR/.claude"

  # 7e. Enter a secas: se queda en la carpeta actual.
  salida="$(en_pty_dir "$SIN_MARCAS" "" "" "3" "1" "2" "")"
  [ -f "$SIN_MARCAS/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "Enter a secas usa la carpeta actual" || falla "Enter a secas usa la carpeta actual"
  rm -rf "$SIN_MARCAS/.claude"

  # 7f. Dentro de un proyecto de verdad, no molesta con la pregunta.
  salida="$(en_pty_dir "$CON_MARCAS" "" "3" "1" "2" "")"
  no_contiene "$salida" "no parece un proyecto" "no pregunta si ya estás en un proyecto"
  [ -f "$CON_MARCAS/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "instala en el proyecto detectado" || falla "instala en el proyecto detectado"
  rm -rf "$CON_MARCAS/.claude"

  # 7g. Ruta que no existe: ofrece crearla.
  NUEVA="$TMP/carpeta-nueva"
  rm -rf "$NUEVA"
  salida="$(en_pty_dir "$SIN_MARCAS" "" "$NUEVA" "s" "3" "1" "2" "")"
  contiene "$salida" "¿La creo?" "ofrece crear la carpeta si no existe"
  [ -d "$NUEVA" ] && pasa "crea la carpeta cuando el usuario acepta" || falla "crea la carpeta cuando el usuario acepta"
  rm -rf "$NUEVA" "$SIN_MARCAS/.claude"
else
  salta "preguntas de carpeta (falta el comando 'script')"
fi

# ---------------------------------------------- 8. Lanzadores de doble clic

titulo "8. Lanzadores de doble clic"

# Los lanzadores descargan install.sh de una URL base configurable. En las
# pruebas se apunta al propio repositorio con file://, que curl entiende: así
# no hace falta red ni servidor.
LANZ_URL="file://$RAIZ"
LANZ_DIR="$TMP/lanzadores"
mkdir -p "$LANZ_DIR"

if bash -n "$RAIZ/lanzadores/instalar-macos.command"; then pasa "instalar-macos.command parsea"
else falla "instalar-macos.command parsea"; fi
if bash -n "$RAIZ/lanzadores/instalar-linux.sh"; then pasa "instalar-linux.sh parsea"
else falla "instalar-linux.sh parsea"; fi

[ -x "$RAIZ/lanzadores/instalar-macos.command" ] \
  && pasa "instalar-macos.command es ejecutable" || falla "instalar-macos.command es ejecutable"
[ -x "$RAIZ/lanzadores/instalar-linux.sh" ] \
  && pasa "instalar-linux.sh es ejecutable" || falla "instalar-linux.sh es ejecutable"

# Un npx falso para que el lanzador llegue hasta el final sin instalar nada.
LANZ_NPX_LOG="$TMP/npx-lanzador.log"
crear_stub "$STUB/npx" <<STUBEOF
#!/usr/bin/env bash
echo "npx \$*" >> "$LANZ_NPX_LOG"
exit 0
STUBEOF
printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$STUB/git"

for lanzador in instalar-macos.command instalar-linux.sh; do
  rm -f "$LANZ_NPX_LOG"
  salida="$(cd "$LANZ_DIR" && printf '\n' | PATH="$STUB" VIBE_SKILLS_RAW="$LANZ_URL" \
    bash "$RAIZ/lanzadores/$lanzador" --all --envs=claude --yes --local 2>&1)"
  contiene "$salida" "comprobando el entorno" "$lanzador descarga y ejecuta el instalador"
  contiene "$salida" "Pulsa una tecla" "$lanzador deja la ventana abierta al terminar"
  [ -f "$LANZ_NPX_LOG" ] && contiene "$(cat "$LANZ_NPX_LOG")" "--all --envs=claude" "$lanzador pasa los argumentos" \
                        || falla "$lanzador pasa los argumentos" "npx no se ejecutó"
done

# Sin red: mensaje comprensible en lugar de un error críptico.
salida="$(cd "$LANZ_DIR" && printf '\n' | PATH="$STUB" VIBE_SKILLS_RAW="file://$TMP/no-existe" \
  bash "$RAIZ/lanzadores/instalar-linux.sh" 2>&1)"
contiene "$salida" "No se pudo descargar" "el lanzador avisa si no puede descargar"

# El lanzador de Windows no se puede ejecutar aquí; se comprueba que contenga
# las piezas de las que depende.
BAT="$(cat "$RAIZ/lanzadores/instalar-windows.bat")"
contiene "$BAT" "Invoke-WebRequest" "instalar-windows.bat descarga el instalador"
contiene "$BAT" "-File" "instalar-windows.bat lo ejecuta como script, no por tubería"
contiene "$BAT" "%*" "instalar-windows.bat reenvía los argumentos"
contiene "$BAT" "pause" "instalar-windows.bat deja la ventana abierta"

rm -f "$STUB/git" "$LANZ_NPX_LOG"

# --------------------------------------------------------- 9. Modo sin Node

titulo "9. Modo sin Node"

if bash -n "$RAIZ/lib/sin-node.sh"; then pasa "lib/sin-node.sh parsea"; else falla "lib/sin-node.sh parsea"; fi

SN_PROY="$TMP/sin-node"
mkdir -p "$SN_PROY"

# Con una copia local no descarga nada: copia directamente.
salida="$(cd "$SN_PROY" && PATH="$STUB" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node --local < /dev/null 2>&1)"
contiene "$salida" "sin Node" "instala sin Node cuando se pide con --sin-node"
contiene "$salida" "archivo(s) instalados" "informa de cuántos archivos copió"
[ -f "$SN_PROY/.claude/skills/solution-architect/SKILL.md" ] && pasa "sin Node: copia las skills de Claude" || falla "sin Node: copia las skills de Claude"
[ -f "$SN_PROY/.claude/agents/solution-architect.md" ] && pasa "sin Node: copia los subagentes" || falla "sin Node: copia los subagentes"
[ -f "$SN_PROY/.cursor/rules/java-developer.mdc" ] && pasa "sin Node: copia las reglas de Cursor" || falla "sin Node: copia las reglas de Cursor"
[ -f "$SN_PROY/.agents/workflows/solution-architect.md" ] && pasa "sin Node: separa los flujos de Antigravity" || falla "sin Node: separa los flujos de Antigravity"
[ -f "$SN_PROY/.claude/skills/solution-architect/assets/PLAN-template.md" ] && pasa "sin Node: copia los assets" || falla "sin Node: copia los assets"

# Lo que copia sin Node tiene que ser exactamente lo mismo que copia con Node.
CON_NODE="$TMP/con-node"
mkdir -p "$CON_NODE"
(cd "$CON_NODE" && node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --local >/dev/null 2>&1)
if diff -r "$CON_NODE" "$SN_PROY" >/dev/null 2>&1; then pasa "sin Node instala exactamente lo mismo que con Node"
else falla "sin Node instala exactamente lo mismo que con Node" "$(diff -rq "$CON_NODE" "$SN_PROY" | head -5)"; fi

# Segunda pasada: respeta lo que ya existe.
salida="$(cd "$SN_PROY" && PATH="$STUB" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node --local < /dev/null 2>&1)"
contiene "$salida" "ya existían y no se tocaron" "sin Node es idempotente"

# Descarga de verdad: se empaqueta el repositorio y se sirve por file://.
if command -v tar >/dev/null 2>&1; then
  SN_DESCARGA="$TMP/sin-node-descarga"
  mkdir -p "$SN_DESCARGA"
  (cd "$RAIZ" && tar -czf "$TMP/repo.tar.gz" --transform 's,^,repo-main/,' skills >/dev/null 2>&1) \
    || tar -czf "$TMP/repo.tar.gz" -C "$RAIZ" skills >/dev/null 2>&1
  cp "$RAIZ/install.sh" "$TMP/install-suelto.sh"
  salida="$(cd "$SN_DESCARGA" && PATH="$STUB" VIBE_SKILLS_RAW="file://$RAIZ" VIBE_SKILLS_TARBALL="file://$TMP/repo.tar.gz" \
    bash "$TMP/install-suelto.sh" --sin-node --local < /dev/null 2>&1)"
  contiene "$salida" "Descargando" "sin Node descarga las skills si no hay copia local"
  [ -f "$SN_DESCARGA/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "sin Node instala lo descargado" || falla "sin Node instala lo descargado" "$salida"
else
  salta "descarga del modo sin Node (falta tar)"
fi

# Se ofrece como salida cuando el usuario rechaza instalar Node.
if command -v script >/dev/null 2>&1; then
  SN_OFERTA="$TMP/sin-node-oferta"
  SN_ELEGIDA="$TMP/sin-node-elegida"
  mkdir -p "$SN_OFERTA" "$SN_ELEGIDA"
  rm -f "$LOG"
  transcripcion="$TMP/pty-sn.txt"
  {
    sleep 1; printf 'n\n'; sleep 0.8; printf 's\n'; sleep 0.8
    printf '2\n'; sleep 0.8; printf '%s\n' "$SN_ELEGIDA"; sleep 0.8; printf '1\n'; sleep 1
  } | script -q -c "cd '$SN_OFERTA' && env PATH='$STUB' VIBE_SKILLS_SRC='$RAIZ' bash '$RAIZ/install.sh'" "$transcripcion" >/dev/null 2>&1
  salida="$(cat "$transcripcion")"
  contiene "$salida" "Hay otra salida" "ofrece el modo sin Node al rechazar la instalación"
  [ ! -f "$LOG" ] && pasa "el modo sin Node no toca el gestor de paquetes" || falla "el modo sin Node no toca el gestor de paquetes"
  [ -f "$SN_ELEGIDA/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "sin Node instala en la carpeta elegida" || falla "sin Node instala en la carpeta elegida"
  [ ! -d "$SN_ELEGIDA/.cursor" ] && pasa "sin Node respeta las herramientas elegidas" || falla "sin Node respeta las herramientas elegidas"
else
  salta "oferta interactiva del modo sin Node (falta el comando 'script')"
fi

# Comprobar sigue siendo comprobar: no ofrece instalar de ninguna manera.
salida="$(cd "$TMP" && PATH="$STUB" bash "$RAIZ/install.sh" --check < /dev/null 2>&1)"
no_contiene "$salida" "Hay otra salida" "--check no ofrece el modo sin Node"

# Versión de PowerShell.
if [ -n "${PWSH:-}" ]; then
  SN_PS="$TMP/sin-node-ps"
  mkdir -p "$SN_PS"
  salida="$(cd "$SN_PS" && VIBE_SKILLS_SRC="$RAIZ" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --sin-node --local < /dev/null 2>&1)"
  contiene "$salida" "archivo(s) instalados" "install.ps1 instala sin Node"
  if diff -r "$CON_NODE" "$SN_PS" >/dev/null 2>&1; then pasa "install.ps1 sin Node copia lo mismo que con Node"
  else falla "install.ps1 sin Node copia lo mismo que con Node" "$(diff -rq "$CON_NODE" "$SN_PS" | head -5)"; fi
else
  salta "modo sin Node de PowerShell (PowerShell no está instalado)"
fi

# ------------------------------------------- 10. Instalación global vs proyecto

titulo "10. Instalación global (todos los proyectos)"

# Cada prueba usa su propia carpeta personal de mentira.
casa_limpia() {
  local casa="$TMP/casa-$1"
  rm -rf "$casa"
  mkdir -p "$casa"
  printf '%s' "$casa"
}

G_PROY="$TMP/proyecto-global"
mkdir -p "$G_PROY"
: > "$G_PROY/package.json"

CASA="$(casa_limpia global)"
salida="$(cd "$G_PROY" && HOME="$CASA" node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --global 2>&1)"
contiene "$salida" "global (todos tus proyectos)" "--global anuncia el ámbito global"
[ -f "$CASA/.claude/skills/solution-architect/SKILL.md" ] && pasa "global: skills de Claude Code en ~/.claude/skills" || falla "global: skills de Claude Code en ~/.claude/skills"
[ -f "$CASA/.claude/agents/solution-architect.md" ] && pasa "global: subagentes en ~/.claude/agents" || falla "global: subagentes en ~/.claude/agents"
[ -f "$CASA/.cursor/rules/java-developer.mdc" ] && pasa "global: reglas de Cursor en ~/.cursor/rules" || falla "global: reglas de Cursor en ~/.cursor/rules"
[ -f "$CASA/.junie/rules/java-developer.md" ] && pasa "global: reglas de Junie en ~/.junie/rules" || falla "global: reglas de Junie en ~/.junie/rules"
[ -f "$CASA/.gemini/antigravity/rules/solution-architect-01.md" ] && pasa "global: reglas de Antigravity en ~/.gemini/antigravity/rules" || falla "global: reglas de Antigravity en ~/.gemini/antigravity/rules"
[ -f "$CASA/.gemini/antigravity/global_workflows/solution-architect.md" ] && pasa "global: flujos de Antigravity en global_workflows" || falla "global: flujos de Antigravity en global_workflows"
[ ! -d "$G_PROY/.claude" ] && pasa "global no escribe nada en el proyecto" || falla "global no escribe nada en el proyecto"

# Índices para las herramientas que leen sus guías globales de un solo archivo.
[ -f "$CASA/.junie/AGENTS.md" ] && pasa "global: crea el índice de Junie" || falla "global: crea el índice de Junie"
[ -f "$CASA/.gemini/AGENTS.md" ] && pasa "global: crea el índice de Antigravity" || falla "global: crea el índice de Antigravity"
if [ -f "$CASA/.junie/AGENTS.md" ]; then
  contiene "$(cat "$CASA/.junie/AGENTS.md")" ".junie/rules/java-developer.md" "el índice apunta a archivos que existen de verdad"
  ruta_citada="$(grep -o "$CASA/.junie/rules/[a-z-]*\.md" "$CASA/.junie/AGENTS.md" | head -1)"
  [ -f "$ruta_citada" ] && pasa "la primera ruta del índice existe" || falla "la primera ruta del índice existe" "$ruta_citada"
fi

# El índice es un bloque entre marcas: se reescribe sin tocar lo que haya alrededor.
printf '# Mis guías\n\nEscribe en español.\n' > "$CASA/.junie/AGENTS.md"
(cd "$G_PROY" && HOME="$CASA" node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --global >/dev/null 2>&1)
(cd "$G_PROY" && HOME="$CASA" node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --global >/dev/null 2>&1)
contiene "$(cat "$CASA/.junie/AGENTS.md")" "Escribe en español." "el índice respeta el texto del usuario"
igual "$(grep -c 'vibe-coding-skills: inicio' "$CASA/.junie/AGENTS.md")" "1" "el índice no se duplica al repetir la instalación"

# Ambos ámbitos a la vez.
CASA="$(casa_limpia ambos)"
G_PROY2="$TMP/proyecto-ambos"
mkdir -p "$G_PROY2"
salida="$(cd "$G_PROY2" && HOME="$CASA" node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --scope=global,proyecto 2>&1)"
[ -f "$CASA/.claude/skills/java-developer/SKILL.md" ] && pasa "--scope=global,proyecto instala en la carpeta personal" || falla "--scope=global,proyecto instala en la carpeta personal"
[ -f "$G_PROY2/.claude/skills/java-developer/SKILL.md" ] && pasa "--scope=global,proyecto instala también en el proyecto" || falla "--scope=global,proyecto instala también en el proyecto"

# Validación previa: se informa de qué herramientas hay antes de instalar.
CASA="$(casa_limpia deteccion)"
mkdir -p "$CASA/.claude"
salida="$(cd "$G_PROY2" && HOME="$CASA" node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --yes --global --dry-run 2>&1)"
contiene "$salida" "Herramientas detectadas" "informa de las herramientas antes de instalar"
contiene "$salida" "detectada" "marca como detectada la que existe"
contiene "$salida" "no detectada" "marca como no detectada la que falta"

# Claude Code respeta CLAUDE_CONFIG_DIR.
CASA="$(casa_limpia configdir)"
(cd "$G_PROY2" && HOME="$CASA" CLAUDE_CONFIG_DIR="$CASA/otra-config" node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --global >/dev/null 2>&1)
[ -f "$CASA/otra-config/skills/java-developer/SKILL.md" ] && pasa "respeta CLAUDE_CONFIG_DIR" || falla "respeta CLAUDE_CONFIG_DIR"

# El modo sin Node instala exactamente lo mismo en el ámbito global.
CASA_SN="$(casa_limpia sinnode)"
CASA_NODE="$(casa_limpia connode)"
(cd "$G_PROY2" && HOME="$CASA_SN" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node --global < /dev/null >/dev/null 2>&1)
(cd "$G_PROY2" && HOME="$CASA_NODE" node "$RAIZ/bin/vibe-coding-skills.cjs" --all --yes --global >/dev/null 2>&1)
if diff -r -x "AGENTS.md" "$CASA_SN" "$CASA_NODE" >/dev/null 2>&1; then pasa "sin Node instala lo mismo que con Node en global"
else falla "sin Node instala lo mismo que con Node en global" "$(diff -rq -x AGENTS.md "$CASA_SN" "$CASA_NODE" | head -5)"; fi
[ -f "$CASA_SN/.junie/AGENTS.md" ] && pasa "sin Node también escribe el índice" || falla "sin Node también escribe el índice"

# Menú interactivo: la opción 1 instala en global y no toca el proyecto.
if command -v script >/dev/null 2>&1; then
  CASA="$(casa_limpia menu)"
  G_PROY3="$TMP/proyecto-menu"
  rm -rf "$G_PROY3"; mkdir -p "$G_PROY3"; : > "$G_PROY3/package.json"
  transcripcion="$TMP/pty-global.txt"
  rm -f "$transcripcion"
  {
    sleep 1; printf '3\n'; sleep 0.7; printf '1\n'; sleep 0.7; printf '1\n'; sleep 0.7; printf '\n'; sleep 1.2
  } | script -q -c "cd '$G_PROY3' && env HOME='$CASA' node '$RAIZ/bin/vibe-coding-skills.cjs'" "$transcripcion" >/dev/null 2>&1
  salida="$(cat "$transcripcion")"
  contiene "$salida" "Dónde quieres instalarlas" "el menú pregunta el ámbito"
  [ -f "$CASA/.claude/skills/java-developer/SKILL.md" ] && pasa "el menú instala en global al elegir 1" || falla "el menú instala en global al elegir 1"
  [ ! -d "$G_PROY3/.claude" ] && pasa "el menú no toca el proyecto si eligió global" || falla "el menú no toca el proyecto si eligió global"
else
  salta "menú de ámbito (falta el comando 'script')"
fi

# Nada de esto puede haber tocado la carpeta personal de verdad.
if [ -n "${CASA_REAL:-}" ] && [ -d "$CASA_REAL" ]; then
  if grep -rqs "vibe-coding-skills: inicio" "$CASA_REAL/.junie/AGENTS.md" "$CASA_REAL/.gemini/AGENTS.md" 2>/dev/null; then
    falla "las pruebas no tocan la carpeta personal real"
  else
    pasa "las pruebas no tocan la carpeta personal real"
  fi
fi

# ------------------------------------ 10b. El ámbito por variable de entorno

# El README documenta VIBE_SKILLS_AMBITO para PowerShell, donde `irm | iex` no
# admite argumentos: tiene que llegar igual al instalador con Node.
CASA_VAR="$(casa_limpia variable)"
PROY_VAR="$TMP/proyecto-variable"
mkdir -p "$PROY_VAR"

(cd "$PROY_VAR" && HOME="$CASA_VAR" VIBE_SKILLS_AMBITO=proyecto node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes >/dev/null 2>&1)
[ -f "$PROY_VAR/.claude/skills/java-developer/SKILL.md" ] && pasa "VIBE_SKILLS_AMBITO=proyecto instala en el proyecto" || falla "VIBE_SKILLS_AMBITO=proyecto instala en el proyecto"
[ ! -d "$CASA_VAR/.claude" ] && pasa "VIBE_SKILLS_AMBITO=proyecto no toca la carpeta personal" || falla "VIBE_SKILLS_AMBITO=proyecto no toca la carpeta personal"

rm -rf "$PROY_VAR/.claude"
(cd "$PROY_VAR" && HOME="$CASA_VAR" VIBE_SKILLS_AMBITO=global node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes >/dev/null 2>&1)
[ -f "$CASA_VAR/.claude/skills/java-developer/SKILL.md" ] && pasa "VIBE_SKILLS_AMBITO=global instala en la carpeta personal" || falla "VIBE_SKILLS_AMBITO=global instala en la carpeta personal"

# El arranque la convierte en bandera antes de llamar al instalador.
rm -f "$NPX_LOG"
crear_stub "$STUB/npx" <<STUBEOF
#!/usr/bin/env bash
echo "npx \$*" >> "$NPX_LOG"
exit 0
STUBEOF
printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$STUB/git"
salida="$(cd "$PROY_VAR" && PATH="$STUB" HOME="$CASA_VAR" VIBE_SKILLS_AMBITO=global bash "$RAIZ/install.sh" --all --yes < /dev/null 2>&1)"
[ -f "$NPX_LOG" ] && contiene "$(cat "$NPX_LOG")" "--global" "install.sh convierte VIBE_SKILLS_AMBITO en --global" \
                  || falla "install.sh convierte VIBE_SKILLS_AMBITO en --global" "npx no se ejecutó"
rm -f "$STUB/git" "$NPX_LOG"

# --------------------------------------- 11. La comprobación previa completa

titulo "11. Comprobación previa (--check)"

CASA_CHK="$(casa_limpia check)"
PROY_CHK="$TMP/proyecto-check"
mkdir -p "$PROY_CHK"

# El PATH reducido no tiene el comando `claude`, así que la máquina de pruebas
# aparece de verdad sin ningún asistente; git sí tiene que estar, o el informe
# se iría por la rama de "faltan requisitos".
printf '#!/usr/bin/env bash\necho "git version 2.99.0"\n' | crear_stub "$STUB/git"
salida="$(cd "$PROY_CHK" && HOME="$CASA_CHK" PATH="$STUB" node "$RAIZ/bin/vibe-coding-skills.cjs" --check 2>&1)"
contiene "$salida" "instala skills" "--check explica para qué sirve la aplicación"
contiene "$salida" "Comprobación del entorno" "--check revisa los requisitos del sistema"
contiene "$salida" "Asistentes en este computador" "--check revisa también los asistentes"
contiene "$salida" "Claude Code" "--check nombra cada asistente"
contiene "$salida" "~/.claude/skills" "--check dice dónde iría la instalación global"
contiene "$salida" "No encontré ninguno de los cuatro asistentes" "--check avisa si no hay ningún asistente"
no_contiene "$salida" "Faltan requisitos" "--check no inventa requisitos que sí están"
[ -z "$(ls -A "$CASA_CHK")" ] && pasa "--check no escribe en la carpeta personal" || falla "--check no escribe en la carpeta personal" "$(ls -A "$CASA_CHK")"
[ -z "$(ls -A "$PROY_CHK")" ] && pasa "--check no escribe en el proyecto" || falla "--check no escribe en el proyecto"

# Con un asistente presente, lo marca como detectado y no da el aviso.
mkdir -p "$CASA_CHK/.cursor"
salida="$(cd "$PROY_CHK" && HOME="$CASA_CHK" PATH="$STUB" node "$RAIZ/bin/vibe-coding-skills.cjs" --check 2>&1)"
contiene "$salida" "detectado" "--check marca el asistente que sí está"
no_contiene "$salida" "No encontré ninguno" "--check no avisa de más cuando hay un asistente"

# El mismo informe llega por el arranque, que es la vía del usuario sin Node.
# Con npx de verdad y el paquete local: es el camino que sigue el usuario que
# arranca con curl | bash sin tener nada instalado.
salida="$(cd "$PROY_CHK" && HOME="$CASA_CHK" VIBE_SKILLS_REPO="$RAIZ" bash "$RAIZ/install.sh" --check < /dev/null 2>&1)"
contiene "$salida" "Asistentes en este computador" "install.sh --check llega al mismo informe"
rm -f "$STUB/git"

# --------------------------------------------- 12. Nombre y compatibilidad

titulo "12. Nombre del proyecto y compatibilidad"

# El nombre visible tiene que ser el del proyecto, no el del paquete.
CASA_N="$(casa_limpia nombre)"
PROY_N="$TMP/proyecto-nombre"
mkdir -p "$PROY_N"

salida="$(cd "$PROY_N" && HOME="$CASA_N" node "$RAIZ/bin/vibe-coding-skills.cjs" --check 2>&1)"
contiene "$salida" "Vibe Coding Skills" "--check se presenta como Vibe Coding Skills"

salida="$(cd "$PROY_N" && HOME="$CASA_N" node "$RAIZ/bin/vibe-coding-skills.cjs" --help 2>&1)"
contiene "$salida" "Vibe Coding Skills" "la ayuda se presenta como Vibe Coding Skills"

salida="$(cd "$PROY_N" && HOME="$CASA_N" PATH="$STUB:$PATH" bash "$RAIZ/install.sh" --check < /dev/null 2>&1)"
contiene "$salida" "Vibe Coding Skills — comprobando el entorno" "install.sh se presenta con el nombre nuevo"

if [ -n "${PWSH:-}" ]; then
  salida="$(cd "$PROY_N" && HOME="$CASA_N" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --check < /dev/null 2>&1)"
  contiene "$salida" "Vibe Coding Skills - comprobando el entorno" "install.ps1 se presenta con el nombre nuevo"
fi

# El paquete se llama igual y su ejecutable también.
salida="$(node -e "console.log(require('$RAIZ/package.json').name + ' ' + Object.keys(require('$RAIZ/package.json').bin).join(','))")"
igual "$salida" "vibe-coding-skills vibe-coding-skills" "package.json usa el nombre nuevo"

# Las variables nuevas mandan; las antiguas siguen funcionando.
CASA_C="$(casa_limpia compat)"
PROY_C="$TMP/proyecto-compat"
mkdir -p "$PROY_C"

(cd "$PROY_C" && HOME="$CASA_C" VIBE_SKILLS_AMBITO=proyecto node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes >/dev/null 2>&1)
[ -f "$PROY_C/.claude/skills/java-developer/SKILL.md" ] && pasa "VIBE_SKILLS_AMBITO funciona" || falla "VIBE_SKILLS_AMBITO funciona"
rm -rf "$PROY_C/.claude"

(cd "$PROY_C" && HOME="$CASA_C" AGENT_SKILLS_AMBITO=proyecto node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes >/dev/null 2>&1)
[ -f "$PROY_C/.claude/skills/java-developer/SKILL.md" ] && pasa "la variable antigua AGENT_SKILLS_AMBITO sigue funcionando" || falla "la variable antigua AGENT_SKILLS_AMBITO sigue funcionando"
rm -rf "$PROY_C/.claude"

salida="$(cd "$PROY_C" && HOME="$CASA_C" PATH="$STUB:$PATH" AGENT_SKILLS_CHECK=1 bash "$RAIZ/install.sh" < /dev/null 2>&1)"
contiene "$salida" "comprobando el entorno" "install.sh acepta la variable antigua AGENT_SKILLS_CHECK"

salida="$(cd "$PROY_C" && HOME="$CASA_C" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node --local < /dev/null 2>&1)"
contiene "$salida" "Vibe Coding Skills — instalación sin Node" "el modo sin Node se presenta con el nombre nuevo"
rm -rf "$PROY_C/.claude" "$PROY_C/.cursor" "$PROY_C/.junie" "$PROY_C/.agents"

# El índice usa la marca nueva y reemplaza la antigua en lugar de duplicarla.
CASA_M="$(casa_limpia marcas)"
mkdir -p "$CASA_M/.junie"
cat > "$CASA_M/.junie/AGENTS.md" <<'VIEJO'
# Mis guías

Escribe en español.

<!-- agent-skills: inicio (bloque generado, no editar) -->
## Skills de agent-skills instaladas globalmente

- viejo
<!-- agent-skills: fin -->
VIEJO
(cd "$PROY_C" && HOME="$CASA_M" node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=junie --yes --global >/dev/null 2>&1)
contiene "$(cat "$CASA_M/.junie/AGENTS.md")" "vibe-coding-skills: inicio" "el índice usa la marca nueva"
no_contiene "$(cat "$CASA_M/.junie/AGENTS.md")" "agent-skills: inicio" "el índice antiguo se reemplaza, no se duplica"
contiene "$(cat "$CASA_M/.junie/AGENTS.md")" "Escribe en español." "al migrar la marca respeta el texto del usuario"

# Lo mismo por el camino sin Node.
CASA_M2="$(casa_limpia marcas-sin-node)"
mkdir -p "$CASA_M2/.junie"
cp "$CASA_M/.junie/AGENTS.md" "$CASA_M2/.junie/AGENTS.md"
python3 - "$CASA_M2/.junie/AGENTS.md" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
open(p,'w',encoding='utf-8').write(s.replace('vibe-coding-skills:','agent-skills:'))
PY
(cd "$PROY_C" && HOME="$CASA_M2" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node --global < /dev/null >/dev/null 2>&1)
contiene "$(cat "$CASA_M2/.junie/AGENTS.md")" "vibe-coding-skills: inicio" "sin Node: el índice usa la marca nueva"
no_contiene "$(cat "$CASA_M2/.junie/AGENTS.md")" "agent-skills: inicio" "sin Node: reemplaza el índice antiguo"

# ------------------------------- 13. Las banderas valen en los dos caminos

titulo "13. Paridad de banderas entre el camino con Node y el de sin Node"

CASA_P="$(casa_limpia paridad)"
PROY_P="$TMP/proyecto-paridad"
mkdir -p "$PROY_P"

sn() { # sn <argumentos…>  — modo sin Node con la copia local del repositorio
  (cd "$PROY_P" && HOME="$CASA_P" VIBE_SKILLS_SRC="$RAIZ" bash "$RAIZ/install.sh" --sin-node "$@" < /dev/null 2>&1)
}

# --dry-run tiene que simular de verdad: es la bandera que promete no tocar nada.
rm -rf "$PROY_P"/.[a-z]* "$CASA_P"/.[a-z]*
salida="$(sn --local --dry-run --yes)"
contiene "$salida" "no se escribió nada" "sin Node: --dry-run avisa de que simula"
igual "$(find "$PROY_P" -type f | wc -l | tr -d ' ')" "0" "sin Node: --dry-run no escribe en el proyecto"
igual "$(find "$CASA_P" -type f | wc -l | tr -d ' ')" "0" "sin Node: --dry-run no escribe en la carpeta personal"

# --envs= y --skills= acotan lo que se instala.
salida="$(sn --local --envs=claude --skills=java-developer --yes)"
[ -f "$PROY_P/.claude/skills/java-developer/SKILL.md" ] && pasa "sin Node: --skills= instala la pedida" || falla "sin Node: --skills= instala la pedida"
[ ! -d "$PROY_P/.cursor" ] && pasa "sin Node: --envs= no instala en las demás herramientas" || falla "sin Node: --envs= no instala en las demás herramientas"
[ ! -f "$PROY_P/.claude/skills/python-developer/SKILL.md" ] && pasa "sin Node: --skills= no instala las demás" || falla "sin Node: --skills= no instala las demás"

# --force sobrescribe lo que ya existe.
echo "MIO" > "$PROY_P/.claude/skills/java-developer/SKILL.md"
sn --local --envs=claude --skills=java-developer --force --yes >/dev/null
if grep -q "MIO" "$PROY_P/.claude/skills/java-developer/SKILL.md"; then falla "sin Node: --force sobrescribe"
else pasa "sin Node: --force sobrescribe"; fi

# --scope= elige el ámbito igual que --global y --local.
rm -rf "$PROY_P"/.[a-z]* "$CASA_P"/.[a-z]*
salida="$(sn --scope=proyecto --envs=claude --skills=java-developer --yes)"
contiene "$salida" "Ámbito:       proyecto" "sin Node: --scope= elige el ámbito"
[ -f "$PROY_P/.claude/skills/java-developer/SKILL.md" ] && pasa "sin Node: --scope=proyecto instala en el proyecto" || falla "sin Node: --scope=proyecto instala en el proyecto"
[ ! -d "$CASA_P/.claude" ] && pasa "sin Node: --scope=proyecto no toca la carpeta personal" || falla "sin Node: --scope=proyecto no toca la carpeta personal"

# --dir= sin estar dentro del proyecto.
OTRA="$TMP/otra-carpeta-sin-node"
rm -rf "$OTRA"; mkdir -p "$OTRA"
sn --local --dir="$OTRA" --envs=claude --skills=java-developer --yes >/dev/null
[ -f "$OTRA/.claude/skills/java-developer/SKILL.md" ] && pasa "sin Node: --dir= instala en la carpeta indicada" || falla "sin Node: --dir= instala en la carpeta indicada"

# La variable de comprobación también frena al instalador con Node.
CASA_V="$(casa_limpia variable-check)"
PROY_V="$TMP/proyecto-variable-check"
mkdir -p "$PROY_V"
salida="$(cd "$PROY_V" && HOME="$CASA_V" VIBE_SKILLS_CHECK=1 node "$RAIZ/bin/vibe-coding-skills.cjs" --skills=java-developer --envs=claude --yes --local 2>&1)"
contiene "$salida" "Comprobación del entorno" "VIBE_SKILLS_CHECK convierte la ejecución en comprobación"
[ ! -d "$PROY_V/.claude" ] && pasa "VIBE_SKILLS_CHECK no instala nada" || falla "VIBE_SKILLS_CHECK no instala nada"

# Un asistente instalado solo como comando (sin su carpeta) también se detecta.
salida="$(node -e "
  var e = require('$RAIZ/lib/entornos.cjs');
  console.log(typeof e.hayEnPath === 'function' ? 'hay-en-path' : 'falta');
  console.log(e.ENTORNOS.claude.comando || 'sin-comando');
" 2>&1)"
contiene "$salida" "hay-en-path" "la detección mira también el PATH"
contiene "$salida" "claude" "Claude Code se detecta por su comando"

# Lo mismo por el camino de PowerShell.
if [ -n "${PWSH:-}" ]; then
  CASA_PS="$(casa_limpia paridad-ps)"
  PROY_PS="$TMP/proyecto-paridad-ps"
  mkdir -p "$PROY_PS"
  salida="$(cd "$PROY_PS" && HOME="$CASA_PS" VIBE_SKILLS_SRC="$RAIZ" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --sin-node --local --dry-run --yes < /dev/null 2>&1)"
  contiene "$salida" "no se escribio nada" "install.ps1 sin Node: --dry-run simula"
  igual "$(find "$PROY_PS" -type f | wc -l | tr -d ' ')" "0" "install.ps1 sin Node: --dry-run no escribe"

  (cd "$PROY_PS" && HOME="$CASA_PS" VIBE_SKILLS_SRC="$RAIZ" "$PWSH" -NoProfile -File "$RAIZ/install.ps1" --sin-node --local --envs=claude --skills=java-developer --yes < /dev/null >/dev/null 2>&1)
  [ -f "$PROY_PS/.claude/skills/java-developer/SKILL.md" ] && pasa "install.ps1 sin Node: respeta --skills= y --envs=" || falla "install.ps1 sin Node: respeta --skills= y --envs="
  [ ! -d "$PROY_PS/.cursor" ] && pasa "install.ps1 sin Node: no instala entornos no pedidos" || falla "install.ps1 sin Node: no instala entornos no pedidos"
else
  salta "paridad de banderas en PowerShell (pwsh no está instalado)"
fi

# ------------------------------- 14. Versión, notas de versión y copyright

titulo "14. Versión, notas y copyright"

VERSION_PAQUETE="$(node -p "require('$RAIZ/package.json').version")"

# La versión vive en package.json; los dos arranques la llevan escrita porque se
# descargan sueltos. Aquí se comprueba que no se hayan desfasado.
igual "$(grep -oE '^VERSION="[0-9.]+"' "$RAIZ/install.sh" | grep -oE '[0-9.]+')" "$VERSION_PAQUETE" \
  "install.sh lleva la misma versión que el paquete"
igual "$(grep -oE "^\\\$Version = '[0-9.]+'" "$RAIZ/install.ps1" | grep -oE '[0-9.]+')" "$VERSION_PAQUETE" \
  "install.ps1 lleva la misma versión que el paquete"

igual "$(node "$RAIZ/bin/vibe-coding-skills.cjs" --version)" "Vibe Coding Skills v$VERSION_PAQUETE" \
  "el instalador responde a --version"
igual "$(bash "$RAIZ/install.sh" --version)" "Vibe Coding Skills v$VERSION_PAQUETE" \
  "install.sh responde a --version"
igual "$(node "$RAIZ/bin/vibe-coding-skills.cjs" -v)" "Vibe Coding Skills v$VERSION_PAQUETE" \
  "el atajo -v también funciona"
if [ -n "${PWSH:-}" ]; then
  igual "$("$PWSH" -NoProfile -File "$RAIZ/install.ps1" --version)" "Vibe Coding Skills v$VERSION_PAQUETE" \
    "install.ps1 responde a --version"
fi

# --version no puede tener efectos: es solo mirar.
CASA_V2="$(casa_limpia version)"
PROY_V2="$TMP/proyecto-version"
mkdir -p "$PROY_V2"
(cd "$PROY_V2" && HOME="$CASA_V2" node "$RAIZ/bin/vibe-coding-skills.cjs" --version >/dev/null 2>&1)
igual "$(find "$PROY_V2" "$CASA_V2" -type f | wc -l | tr -d ' ')" "0" "--version no escribe nada"

# Cada versión publicada tiene que estar documentada.
[ -f "$RAIZ/RELEASES.md" ] && pasa "existe el documento de notas de versión" || falla "existe el documento de notas de versión"
contiene "$(cat "$RAIZ/RELEASES.md")" "## $VERSION_PAQUETE " "las notas documentan la versión actual"
contiene "$(cat "$RAIZ/RELEASES.md")" "Novedades" "las notas separan las novedades"
contiene "$(cat "$RAIZ/RELEASES.md")" "Correcciones" "las notas separan las correcciones"

# El versionamiento es secuencial: cada escalón sube uno, sin saltos.
COPIA="$TMP/copia-version"
rm -rf "$COPIA"; mkdir -p "$COPIA"
cp -r "$RAIZ/package.json" "$RAIZ/install.sh" "$RAIZ/install.ps1" "$RAIZ/RELEASES.md" "$COPIA/"
mkdir -p "$COPIA/scripts" && cp "$RAIZ/scripts/version.sh" "$COPIA/scripts/"
(cd "$COPIA" && bash scripts/version.sh parche >/dev/null 2>&1)
esperada="$(node -e "
  var v = '$VERSION_PAQUETE'.split('.');
  console.log(v[0] + '.' + v[1] + '.' + (Number(v[2]) + 1));
")"
igual "$(node -p "require('$COPIA/package.json').version")" "$esperada" "el script sube un escalón de parche"
igual "$(grep -oE '^VERSION="[0-9.]+"' "$COPIA/install.sh" | grep -oE '[0-9.]+')" "$esperada" "el script actualiza install.sh"
contiene "$(cat "$COPIA/RELEASES.md")" "## $esperada " "el script abre la sección de notas de la versión nueva"

(cd "$COPIA" && bash scripts/version.sh mayor >/dev/null 2>&1)
igual "$(node -p "require('$COPIA/package.json').version")" "$(node -e "console.log((Number('$VERSION_PAQUETE'.split('.')[0]) + 1) + '.0.0')")" \
  "el script sube un escalón mayor"

# Todo el código y los scripts llevan el aviso de copyright del autor.
sin_copyright=""
for archivo in "$RAIZ"/install.sh "$RAIZ"/install.ps1 "$RAIZ"/bin/*.cjs "$RAIZ"/lib/*.cjs "$RAIZ"/lib/*.mjs \
               "$RAIZ"/lib/*.sh "$RAIZ"/lib/*.ps1 "$RAIZ"/lanzadores/* "$RAIZ"/scripts/*.sh "$RAIZ"/tests/*.sh; do
  [ -f "$archivo" ] || continue
  if ! head -12 "$archivo" | grep -q "Copyright (c) .* Adolfo Orozco <bigfito@gmail.com>"; then
    sin_copyright="$sin_copyright $(basename "$archivo")"
  fi
done
[ -z "$sin_copyright" ] && pasa "todos los archivos de código llevan el copyright del autor" \
                        || falla "todos los archivos de código llevan el copyright del autor" "faltan:$sin_copyright"

contiene "$(cat "$RAIZ/LICENSE")" "Adolfo Orozco" "la licencia nombra al autor"
igual "$(node -p "require('$RAIZ/package.json').author")" "Adolfo Orozco <bigfito@gmail.com>" "package.json declara al autor"

# ------------------------------------------------------------------- resumen

printf '\n'
if [ "$FALLOS" -eq 0 ]; then
  printf '%s%d pruebas pasaron, 0 fallos.%s\n\n' "$G" "$OK" "$N"
  exit 0
fi
printf '%s%d pruebas pasaron, %d fallos.%s\n\n' "$R" "$OK" "$FALLOS" "$N"
exit 1
