#!/usr/bin/env bash
# Vibe Coding Skills
# Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
# Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
#
# Sube la versión del proyecto un escalón y prepara sus notas de versión.
#
#   bash scripts/version.sh parche    2.1.0 → 2.1.1   (correcciones)
#   bash scripts/version.sh menor     2.1.0 → 2.2.0   (funcionalidad nueva)
#   bash scripts/version.sh mayor     2.1.0 → 3.0.0   (cambios incompatibles)
#
# El versionamiento es secuencial: cada entrega sube exactamente un escalón,
# sin saltos. package.json es la fuente de verdad; este script se encarga de
# que los dos arranques, que llevan la versión escrita porque se descargan
# sueltos, no se queden atrás.
#
# No hace commit ni tag: deja los cambios listos para que los revises.

set -eu

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

if [ $# -ne 1 ]; then
  printf 'Uso: bash scripts/version.sh <mayor|menor|parche>\n' >&2
  exit 2
fi

ACTUAL="$(node -p "require('./package.json').version")"
MAYOR="${ACTUAL%%.*}"
RESTO="${ACTUAL#*.}"
MENOR="${RESTO%%.*}"
PARCHE="${RESTO#*.}"

case "$1" in
  mayor|major)  NUEVA="$((MAYOR + 1)).0.0" ;;
  menor|minor)  NUEVA="$MAYOR.$((MENOR + 1)).0" ;;
  parche|patch) NUEVA="$MAYOR.$MENOR.$((PARCHE + 1))" ;;
  *) printf 'Escalón desconocido: %s (usa mayor, menor o parche)\n' "$1" >&2; exit 2 ;;
esac

printf '  %s → %s\n\n' "$ACTUAL" "$NUEVA"

# 1. package.json, la fuente de verdad.
node -e '
  const fs = require("fs");
  const p = "./package.json";
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  d.version = process.argv[1];
  fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
' "$NUEVA"

# 2. Los arranques, que no pueden leer package.json.
sed -i.bak "s/^VERSION=\"$ACTUAL\"/VERSION=\"$NUEVA\"/" install.sh && rm -f install.sh.bak
sed -i.bak "s/^\$Version = '$ACTUAL'/\$Version = '$NUEVA'/" install.ps1 && rm -f install.ps1.bak

# 3. El hueco en las notas de versión, para que nadie publique sin escribirlas.
NOTAS="RELEASES.md"
FECHA="$(date +%Y-%m-%d)"
PLANTILLA="## $NUEVA — $FECHA

### ✨ Novedades

- (describe aquí lo que se añadió, o borra esta sección)

### 🐛 Correcciones

- (describe aquí lo que se arregló, o borra esta sección)

---
"

if grep -q "^## $NUEVA " "$NOTAS" 2>/dev/null; then
  printf '  %s ya tiene una sección en %s: no se toca.\n' "$NUEVA" "$NOTAS"
else
  # Se inserta justo antes de la versión más reciente que ya esté documentada.
  awk -v plantilla="$PLANTILLA" '
    !puesta && /^## [0-9]+\.[0-9]+\.[0-9]+ / { print plantilla; puesta = 1 }
    { print }
    END { if (!puesta) print plantilla }
  ' "$NOTAS" > "$NOTAS.nuevo" && mv "$NOTAS.nuevo" "$NOTAS"
  printf '  Sección nueva en %s: escribe qué cambió.\n' "$NOTAS"
fi

printf '\n  Cuando las notas estén escritas:\n'
printf '      git add -A && git commit -m "Versión %s: …"\n' "$NUEVA"
printf '      git tag -a v%s -m "Versión %s" && git push --follow-tags\n\n' "$NUEVA" "$NUEVA"
