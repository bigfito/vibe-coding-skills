#!/usr/bin/env bash
# Pruebas de extremo a extremo de agent-skills.
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

# ---------------------------------------------------------------- 1. sintaxis

titulo "1. Sintaxis"

if node --check "$RAIZ/bin/agent-skills.cjs" 2>/dev/null; then pasa "bin/agent-skills.cjs parsea"
else falla "bin/agent-skills.cjs parsea"; fi

if node --check "$RAIZ/lib/preflight.cjs" 2>/dev/null; then pasa "lib/preflight.cjs parsea"
else falla "lib/preflight.cjs parsea"; fi

if node --input-type=module --eval "$(cat "$RAIZ/lib/install.mjs" | sed 's/^main()/\/\/main()/')" --check 2>/dev/null \
   || node --check "$RAIZ/lib/install.mjs" 2>/dev/null; then pasa "lib/install.mjs parsea"
else falla "lib/install.mjs parsea"; fi

if bash -n "$RAIZ/install.sh"; then pasa "install.sh parsea"; else falla "install.sh parsea"; fi

if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -Command "
      \$e=\$null
      [System.Management.Automation.Language.Parser]::ParseFile('$RAIZ/install.ps1',[ref]\$null,[ref]\$e) > \$null
      if (\$e.Count -gt 0) { \$e | ForEach-Object { \$_.Message }; exit 1 }" >/dev/null 2>&1
  then pasa "install.ps1 parsea"; else falla "install.ps1 parsea"; fi
else
  salta "install.ps1 parsea (pwsh no está instalado en esta máquina)"
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
for real in node npm npx bash sh env uname grep sed awk tr id cat setsid chmod curl wget dirname rm mkdir; do
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

salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/agent-skills.cjs" --check 2>&1)"
codigo=$?
contiene "$salida" "git" "detecta que falta git"
contiene "$salida" "apt-get install -y git" "muestra la orden exacta que usaría"
contiene "$salida" "solo una comprobación" "--check avisa de que no instala nada"
igual "$codigo" "1" "sale con error cuando falta un requisito"
[ ! -f "$LOG" ] && pasa "--check no ejecuta el gestor" || falla "--check no ejecuta el gestor" "$(cat "$LOG")"

# Comprobar nunca instala, ni aunque se autorice de antemano con --yes.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/agent-skills.cjs" --check --yes < /dev/null 2>&1)"
contiene "$salida" "solo una comprobación" "--check gana sobre --yes"
[ ! -f "$LOG" ] && pasa "--check --yes sigue sin instalar" || falla "--check --yes sigue sin instalar" "$(cat "$LOG")"

# 3b. Con --no-install: informa, da instrucciones manuales y no toca nada.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/agent-skills.cjs" --all --envs=claude --no-install < /dev/null 2>&1)"
contiene "$salida" "--no-install" "respeta --no-install"
contiene "$salida" "Instálalo a mano" "con --no-install da instrucciones manuales"
[ ! -f "$LOG" ] && pasa "con --no-install no ejecuta el gestor" || falla "con --no-install no ejecuta el gestor" "$(cat "$LOG")"

# 3c. Sin terminal y sin --yes: no instala nada a espaldas del usuario.
salida="$(cd "$PROY_REQ" && PATH="$STUB" setsid node "$RAIZ/bin/agent-skills.cjs" --all --envs=claude < /dev/null 2>&1)"
contiene "$salida" "No hay terminal interactiva" "sin TTY pide --yes en lugar de instalar"
[ ! -f "$LOG" ] && pasa "sin TTY no ejecuta el gestor" || falla "sin TTY no ejecuta el gestor" "$(cat "$LOG")"

# 3d. Diálogo real: `script` presta un terminal (pty) al proceso, que es lo que
# hace falta para ejercitar el consentimiento tal como lo ve una persona.
en_terminal() {
  local respuesta="$1" transcripcion="$TMP/pty.txt"
  rm -f "$transcripcion"
  printf '%s' "$respuesta" | script -q -c "cd '$PROY_REQ' && env PATH='$STUB' node '$RAIZ/bin/agent-skills.cjs' --skills=java-developer --envs=claude" "$transcripcion" >/dev/null 2>&1
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
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/agent-skills.cjs" --skills=java-developer --envs=claude --yes < /dev/null 2>&1)"
contiene "$salida" "Instalando" "--yes instala sin preguntar"
contiene "$salida" "todos los requisitos están instalados" "--yes deja el entorno completo"
[ -f "$LOG" ] && contiene "$(cat "$LOG")" "apt-get update" "refresca el índice antes de instalar" \
              || falla "refresca el índice antes de instalar" "no se registró ninguna llamada"
rm -rf "$PROY_REQ/.claude"
rm -f "$STUB/git" "$LOG"

# 3f. Simulación: muestra el plan pero no toca nada.
salida="$(cd "$PROY_REQ" && sin_git node "$RAIZ/bin/agent-skills.cjs" --all --dry-run < /dev/null 2>&1)"
contiene "$salida" "Modo simulación" "--dry-run no instala"
[ ! -f "$LOG" ] && pasa "--dry-run no ejecuta el gestor" || falla "--dry-run no ejecuta el gestor" "$(cat "$LOG")"

# 3g. Sin gestor de paquetes conocido: explica cómo hacerlo a mano.
SOLO_NODE="$TMP/solo-node"
mkdir -p "$SOLO_NODE"
for real in node npm npx; do ln -sf "$(command -v "$real")" "$SOLO_NODE/$real"; done
salida="$(cd "$PROY_REQ" && PATH="$SOLO_NODE" node "$RAIZ/bin/agent-skills.cjs" --all --envs=claude --yes < /dev/null 2>&1)"
contiene "$salida" "gestor de paquetes" "sin gestor, lo dice claramente"
contiene "$salida" "Instálalo a mano" "sin gestor, da instrucciones manuales"

# ------------------------------------------------- 4. instalación de las skills

titulo "4. Instalación de skills en un proyecto"

PROY="$TMP/proyecto"
mkdir -p "$PROY"

salida="$(cd "$PROY" && node "$RAIZ/bin/agent-skills.cjs" --all --envs=claude,cursor --yes 2>&1)"
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
salida="$(cd "$PROY" && node "$RAIZ/bin/agent-skills.cjs" --all --envs=claude,cursor --yes 2>&1)"
contiene "$salida" "ya existían y no se tocaron" "es idempotente sin --force"

# Con --force sí sobrescribe.
echo "modificado" > "$PROY/.cursor/rules/java-developer.mdc"
salida="$(cd "$PROY" && node "$RAIZ/bin/agent-skills.cjs" --skills=java-developer --envs=cursor --yes --force 2>&1)"
if grep -q "modificado" "$PROY/.cursor/rules/java-developer.mdc"; then falla "--force sobrescribe"
else pasa "--force sobrescribe"; fi

# Simulación: no escribe nada.
PROY2="$TMP/proyecto-seco"
mkdir -p "$PROY2"
salida="$(cd "$PROY2" && node "$RAIZ/bin/agent-skills.cjs" --all --dry-run 2>&1)"
contiene "$salida" "se copiarían" "--dry-run informa sin escribir"
[ -z "$(ls -A "$PROY2")" ] && pasa "--dry-run deja la carpeta intacta" || falla "--dry-run deja la carpeta intacta"

# Antigravity: reglas y flujos van a carpetas distintas.
PROY3="$TMP/proyecto-antigravity"
mkdir -p "$PROY3"
(cd "$PROY3" && node "$RAIZ/bin/agent-skills.cjs" --skills=solution-architect --envs=antigravity,junie --yes >/dev/null 2>&1)
[ -f "$PROY3/.agents/rules/solution-architect-01.md" ] \
  && pasa "instala las reglas de Antigravity" || falla "instala las reglas de Antigravity"
[ -f "$PROY3/.agents/workflows/solution-architect.md" ] \
  && pasa "separa los flujos de Antigravity" || falla "separa los flujos de Antigravity"
[ -f "$PROY3/.junie/rules/solution-architect.md" ] \
  && pasa "instala las reglas de Junie" || falla "instala las reglas de Junie"

# Skill inexistente: avisa y no revienta.
salida="$(cd "$TMP" && node "$RAIZ/bin/agent-skills.cjs" --skills=no-existe --envs=claude --yes 2>&1)"
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
salida="$(PATH="$STUB" AGENT_SKILLS_CHECK=1 bash "$RAIZ/install.sh" < /dev/null 2>&1)"
[ -f "$NPX_LOG" ] && contiene "$(cat "$NPX_LOG")" "--check" "AGENT_SKILLS_CHECK reenvía --check al instalador" \
                  || falla "AGENT_SKILLS_CHECK reenvía --check al instalador" "npx no se ejecutó"
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

PWSH="$(command -v pwsh 2>/dev/null || true)"
[ -z "$PWSH" ] && [ -x /opt/pwsh/pwsh ] && PWSH=/opt/pwsh/pwsh

if [ -z "$PWSH" ]; then
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
  salida="$(PATH="$PS_STUB" AGENT_SKILLS_CHECK=1 "$PWSH" -NoProfile -File "$RAIZ/install.ps1" < /dev/null 2>&1)"
  [ -f "$PS_NPX_LOG" ] && contiene "$(cat "$PS_NPX_LOG")" "--check" "install.ps1 reenvía --check con AGENT_SKILLS_CHECK" \
                       || falla "install.ps1 reenvía --check con AGENT_SKILLS_CHECK" "npx no se ejecutó"
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
  } | script -q -c "cd '$dir' && node '$RAIZ/bin/agent-skills.cjs' $argumentos" "$transcripcion" >/dev/null 2>&1
  cat "$transcripcion"
}

DESTINO_DIR="$TMP/otro proyecto"
SIN_MARCAS="$TMP/carpeta-suelta"
CON_MARCAS="$TMP/proyecto-marcado"
mkdir -p "$DESTINO_DIR" "$SIN_MARCAS" "$CON_MARCAS"
: > "$CON_MARCAS/package.json"

# 7a. --dir= instala en otra carpeta, aunque tenga espacios.
salida="$(cd "$SIN_MARCAS" && node "$RAIZ/bin/agent-skills.cjs" --skills=java-developer --envs=claude --yes --dir="$DESTINO_DIR" 2>&1)"
contiene "$salida" "instalados" "--dir instala sin preguntar"
[ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
  && pasa "--dir instala en la carpeta indicada" || falla "--dir instala en la carpeta indicada"
[ ! -d "$SIN_MARCAS/.claude" ] && pasa "--dir no toca la carpeta actual" || falla "--dir no toca la carpeta actual"
rm -rf "$DESTINO_DIR/.claude"

# 7b. Una ruta escrita como la deja arrastrar la carpeta (espacios escapados).
salida="$(cd "$SIN_MARCAS" && node "$RAIZ/bin/agent-skills.cjs" --skills=java-developer --envs=claude --yes --dir="${DESTINO_DIR// /\\ }" 2>&1)"
[ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
  && pasa "--dir entiende los espacios escapados de arrastrar" || falla "--dir entiende los espacios escapados de arrastrar"
rm -rf "$DESTINO_DIR/.claude"

# 7c. --dir con una carpeta que no existe: lo dice y no inventa nada.
salida="$(node "$RAIZ/bin/agent-skills.cjs" --all --yes --dir="$TMP/no-existe" 2>&1)"
codigo=$?
contiene "$salida" "no existe" "--dir inexistente avisa con claridad"
igual "$codigo" "1" "--dir inexistente termina con error"

if command -v script >/dev/null 2>&1; then
  # 7d. Carpeta que no parece proyecto: pregunta y usa la ruta indicada.
  salida="$(en_pty_dir "$SIN_MARCAS" "" "$DESTINO_DIR" "3" "1" "")"
  contiene "$salida" "no parece un proyecto" "pregunta cuando la carpeta no parece un proyecto"
  contiene "$salida" "Se instalará en" "confirma la carpeta elegida"
  [ -f "$DESTINO_DIR/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "instala en la carpeta que responde el usuario" || falla "instala en la carpeta que responde el usuario"
  [ ! -d "$SIN_MARCAS/.claude" ] && pasa "no instala en la carpeta actual si eligió otra" || falla "no instala en la carpeta actual si eligió otra"
  rm -rf "$DESTINO_DIR/.claude"

  # 7e. Enter a secas: se queda en la carpeta actual.
  salida="$(en_pty_dir "$SIN_MARCAS" "" "" "3" "1" "")"
  [ -f "$SIN_MARCAS/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "Enter a secas usa la carpeta actual" || falla "Enter a secas usa la carpeta actual"
  rm -rf "$SIN_MARCAS/.claude"

  # 7f. Dentro de un proyecto de verdad, no molesta con la pregunta.
  salida="$(en_pty_dir "$CON_MARCAS" "" "3" "1" "")"
  no_contiene "$salida" "no parece un proyecto" "no pregunta si ya estás en un proyecto"
  [ -f "$CON_MARCAS/.claude/skills/java-developer/SKILL.md" ] \
    && pasa "instala en el proyecto detectado" || falla "instala en el proyecto detectado"
  rm -rf "$CON_MARCAS/.claude"

  # 7g. Ruta que no existe: ofrece crearla.
  NUEVA="$TMP/carpeta-nueva"
  rm -rf "$NUEVA"
  salida="$(en_pty_dir "$SIN_MARCAS" "" "$NUEVA" "s" "3" "1" "")"
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
  salida="$(cd "$LANZ_DIR" && printf '\n' | PATH="$STUB" AGENT_SKILLS_RAW="$LANZ_URL" \
    bash "$RAIZ/lanzadores/$lanzador" --all --envs=claude --yes 2>&1)"
  contiene "$salida" "comprobando el entorno" "$lanzador descarga y ejecuta el instalador"
  contiene "$salida" "Pulsa una tecla" "$lanzador deja la ventana abierta al terminar"
  [ -f "$LANZ_NPX_LOG" ] && contiene "$(cat "$LANZ_NPX_LOG")" "--all --envs=claude" "$lanzador pasa los argumentos" \
                        || falla "$lanzador pasa los argumentos" "npx no se ejecutó"
done

# Sin red: mensaje comprensible en lugar de un error críptico.
salida="$(cd "$LANZ_DIR" && printf '\n' | PATH="$STUB" AGENT_SKILLS_RAW="file://$TMP/no-existe" \
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

# ------------------------------------------------------------------- resumen

printf '\n'
if [ "$FALLOS" -eq 0 ]; then
  printf '%s%d pruebas pasaron, 0 fallos.%s\n\n' "$G" "$OK" "$N"
  exit 0
fi
printf '%s%d pruebas pasaron, %d fallos.%s\n\n' "$R" "$OK" "$FALLOS" "$N"
exit 1
