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
for real in node npm npx bash sh env uname grep sed awk tr id cat setsid chmod; do
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
salida="$(PATH="$STUB" node "$RAIZ/bin/agent-skills.cjs" --check --no-install 2>&1)"
codigo=$?
contiene "$salida" "git" "detecta que falta git"
contiene "$salida" "apt-get install -y git" "muestra la orden exacta que usaría"
contiene "$salida" "--no-install" "respeta --no-install"
igual "$codigo" "1" "sale con error cuando falta un requisito"
[ ! -f "$LOG" ] && pasa "con --no-install no ejecuta el gestor" || falla "con --no-install no ejecuta el gestor" "$(cat "$LOG")"

# 3b. Sin terminal y sin --yes: no instala nada a espaldas del usuario.
salida="$(PATH="$STUB" setsid node "$RAIZ/bin/agent-skills.cjs" --check < /dev/null 2>&1)"
contiene "$salida" "No hay terminal interactiva" "sin TTY pide --yes en lugar de instalar"
[ ! -f "$LOG" ] && pasa "sin TTY no ejecuta el gestor" || falla "sin TTY no ejecuta el gestor" "$(cat "$LOG")"

# 3c. Respuesta "n" en un terminal real: cancela sin instalar.
# `script` presta un terminal real (pty) al proceso, que es lo que hace falta
# para ejercitar el diálogo de consentimiento tal como lo ve una persona.
en_terminal() {
  local respuesta="$1" transcripcion="$TMP/pty.txt"
  rm -f "$transcripcion"
  printf '%s' "$respuesta" | script -q -c "env PATH='$STUB' node '$RAIZ/bin/agent-skills.cjs' --check" "$transcripcion" >/dev/null 2>&1
  cat "$transcripcion"
}

if command -v script >/dev/null 2>&1; then
  salida="$(en_terminal 'n
')"
  contiene "$salida" "Los instalo ahora" "pregunta antes de instalar"
  contiene "$salida" "No se instaló nada" "responder 'n' cancela la instalación"
  [ ! -f "$LOG" ] && pasa "al cancelar no ejecuta el gestor" || falla "al cancelar no ejecuta el gestor" "$(cat "$LOG")"

  # 3d. Respuesta vacía (Enter) = sí: instala y vuelve a comprobar.
  salida="$(en_terminal '
')"
  contiene "$salida" "Instalando" "Enter acepta la instalación"
  contiene "$salida" "todos los requisitos están instalados" "reverifica después de instalar"
  [ -f "$LOG" ] && contiene "$(cat "$LOG")" "apt-get install -y git" "ejecutó la instalación del paquete que faltaba" \
                || falla "ejecutó la instalación del paquete que faltaba" "no se registró ninguna llamada"
  rm -f "$STUB/git" "$LOG"
else
  salta "prueba del diálogo de consentimiento (falta el comando 'script')"
fi

# 3e. Con --yes instala sin preguntar.
salida="$(PATH="$STUB" node "$RAIZ/bin/agent-skills.cjs" --check --yes < /dev/null 2>&1)"
contiene "$salida" "Instalando" "--yes instala sin preguntar"
contiene "$salida" "todos los requisitos están instalados" "--yes deja el entorno completo"
[ -f "$LOG" ] && contiene "$(cat "$LOG")" "apt-get update" "refresca el índice antes de instalar" \
              || falla "refresca el índice antes de instalar" "no se registró ninguna llamada"
rm -f "$STUB/git" "$LOG"

# 3f. Simulación: muestra el plan pero no toca nada.
salida="$(PATH="$STUB" node "$RAIZ/bin/agent-skills.cjs" --check --dry-run < /dev/null 2>&1)"
contiene "$salida" "Modo simulación" "--dry-run no instala"
[ ! -f "$LOG" ] && pasa "--dry-run no ejecuta el gestor" || falla "--dry-run no ejecuta el gestor" "$(cat "$LOG")"

# 3g. Sin gestor de paquetes conocido: explica cómo hacerlo a mano.
SOLO_NODE="$TMP/solo-node"
mkdir -p "$SOLO_NODE"
for real in node npm npx; do ln -sf "$(command -v "$real")" "$SOLO_NODE/$real"; done
salida="$(PATH="$SOLO_NODE" node "$RAIZ/bin/agent-skills.cjs" --check --yes < /dev/null 2>&1)"
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

# ------------------------------------------------------------------- resumen

printf '\n'
if [ "$FALLOS" -eq 0 ]; then
  printf '%s%d pruebas pasaron, 0 fallos.%s\n\n' "$G" "$OK" "$N"
  exit 0
fi
printf '%s%d pruebas pasaron, %d fallos.%s\n\n' "$R" "$OK" "$FALLOS" "$N"
exit 1
