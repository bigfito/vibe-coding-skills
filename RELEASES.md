# 📋 Notas de versión

Qué cambió en cada entrega de **Vibe Coding Skills**.

> [!NOTE]
> **Cómo se numeran las versiones.** El versionamiento es **secuencial**: cada entrega sube exactamente un escalón, sin saltos, con el formato `MAYOR.MENOR.PARCHE`.
>
> | Escalón | Cuándo sube | Ejemplo |
> |---|---|---|
> | **Parche** | Solo correcciones | 2.1.0 → 2.1.1 |
> | **Menor** | Funcionalidad nueva compatible con lo anterior | 2.1.0 → 2.2.0 |
> | **Mayor** | Cambios que rompen lo que ya funcionaba | 2.1.0 → 3.0.0 |
>
> Para subirla: `bash scripts/version.sh parche|menor|mayor`. El script actualiza `package.json`, los dos arranques y abre el hueco de estas notas.
>
> Las versiones **1.0.0 a 2.0.0 se documentan de forma retroactiva**: el proyecto se desarrolló sin numerar y sus hitos se reconstruyeron a partir del historial de commits.

### 🏷️ Etiquetas

Cada versión tiene una **etiqueta anotada** en el repositorio, sobre el commit que la entregó:

| Versión | Etiqueta | Commit |
|---|---|---|
| 1.0.0 | `v1.0.0` | `5432bba` |
| 1.1.0 | `v1.1.0` | `7b68018` |
| 1.2.0 | `v1.2.0` | `1f81221` |
| 1.3.0 | `v1.3.0` | `b612f97` |
| 2.0.0 | `v2.0.0` | `606a03d` |
| 2.1.0 | `v2.1.0` | `fca9a38` |
| 2.1.1 | `v2.1.1` | `355b2af` |
| 2.2.0 | `v2.2.0` | `a8f1e38` |

Para publicarlas en el remoto:

```bash
git push origin --tags
```

Cada entrega nueva añade la suya sobre su propio commit:

```bash
git tag -a vX.Y.Z -m "Versión X.Y.Z" && git push --follow-tags
```

---

## 2.2.0 — 2026-09-14

### ✨ Novedades

- **Skills nativas de Google Antigravity.** Antigravity documenta ahora Skills con carpeta y `SKILL.md`, igual que Claude Code. `scripts/instalar-antigravity.sh` y `scripts/instalar-antigravity.ps1` instalan las siete skills completas en `~/.gemini/config/skills/` (global) o en `.agents/skills/` del proyecto (`--dir=` / `-Dir`), con sus carpetas `references/`, `assets/` y `agents/`. Funcionan desde una copia local del repositorio; el instalador principal sigue instalando reglas y flujos.
- **Pruebas** para los dos scripts: copian cada skill completa, repetir no anida carpetas y un `--dir` inexistente se rechaza.

### 🐛 Correcciones

- **Los scripts de Bash dejaban de funcionar al clonar en Windows.** Con `core.autocrlf=true`, Git los convertía a finales de línea CRLF y bash fallaba en la primera línea. Un `.gitattributes` fija LF para `.sh`, `.command`, `.cjs` y `.mjs`, CRLF para los `.bat`, y trata los `.skill` como binarios.

---

## 2.1.1 — 2026-09-13

### 🐛 Correcciones

- **La documentación de cada skill se había quedado atrás.** Los siete `INSTALL.md` explicaban solo la instalación por proyecto, no mencionaban que existe un instalador y no decían nada del ámbito global, que existe desde la 1.3.0. Ahora empiezan por el instalador, incluyen la tabla de carpetas de los dos ámbitos y advierten de que Junie y Antigravity necesitan además una línea en su archivo de guías globales.
- **Los paquetes `.skill` llevaban dentro una copia vieja de ese mismo documento**, que es la que lee quien los instala en Claude.ai o Cowork. Se regeneraron los siete conservando el resto de su contenido.

---

## 2.1.0 — 2026-09-13

### ✨ Novedades

- **Versionamiento secuencial.** `package.json` es la fuente de verdad, y `scripts/version.sh` sube la versión un escalón (parche, menor o mayor), actualiza los arranques y prepara la sección de estas notas.
- **`--version` / `-v`** en los tres puntos de entrada: el instalador, `install.sh` e `install.ps1`.
- **Este documento**, con el historial completo del proyecto.
- **Aviso de copyright** de Adolfo Orozco <bigfito@gmail.com> en todo el código y los scripts, y autor declarado en `package.json`.

---

## 2.0.0 — 2026-09-13

Cambio de nombre del proyecto y revisión a fondo de la coherencia entre sus tres implementaciones.

### ⚠️ Cambios incompatibles

- El proyecto pasa a llamarse **Vibe Coding Skills**: el paquete es `vibe-coding-skills` y su ejecutable, `bin/vibe-coding-skills.cjs`.
- Las variables de entorno pasan a `VIBE_SKILLS_*`. Las antiguas `AGENT_SKILLS_*` **se siguen leyendo**, así que nada de lo que ya tuvieras escrito deja de funcionar.
- La marca del índice que se escribe en `~/.junie/AGENTS.md` y `~/.gemini/AGENTS.md` pasa a `<!-- vibe-coding-skills: … -->`. Al reescribir el bloque se reconoce también la marca antigua, de modo que se migra en su sitio en lugar de duplicarse.

### 🐛 Correcciones

- **`--dry-run` escribía los archivos** en el modo sin Node, pese a prometer que no toca nada.
- `--force` no sobrescribía, y `--envs=`, `--skills=` y `--scope=` se ignoraban por completo en el modo sin Node.
- `--dir=` se perdía en el modo sin Node: la función pisaba el destino con su primer argumento.
- `--yes` no evitaba las preguntas del modo sin Node.
- `VIBE_SKILLS_CHECK` solo la leían los arranques: al invocar el instalador directamente con `npx`, instalaba en vez de comprobar.
- La detección de asistentes no miraba el PATH, así que Claude Code aparecía como no instalado si aún no existía `~/.claude`.
- `--scope=` se traducía con `\b` en `sed`, que el `sed` de macOS no entiende.
- El README afirmaba que no se escribe nada fuera de las carpetas de skills, cuando la instalación global también toca el bloque del índice.

---

## 1.3.0 — 2026-09-13

### ✨ Novedades

- **Instalación global además de por proyecto.** Las skills pueden instalarse en la carpeta personal, para que estén disponibles en todos los proyectos, o solo en uno; o en ambos sitios. Sin menú, el ámbito por defecto es el global.
- **Detección y validación previas:** antes de instalar se comprueba qué asistentes hay en el computador y se muestra a qué carpeta iría cada cosa.
- **Índice para Junie y Antigravity**, que leen sus guías globales de un único archivo: se les añade un bloque, entre marcas, que señala las skills instaladas sin tocar el resto del archivo.
- `--check` responde también por los asistentes, no solo por los programas del sistema.

---

## 1.2.0 — 2026-09-13

### ✨ Novedades

- **El instalador pregunta en qué carpeta instalar** cuando la actual no parece un proyecto, y acepta que se arrastre la carpeta hasta la ventana. También se puede indicar con `--dir=`.
- **Lanzadores de doble clic** para Windows, macOS y Linux, en `lanzadores/`: no hay que escribir ningún comando.
- **Modo sin Node** (`--sin-node`): descarga las skills y las copia sin instalar nada en el sistema. Se ofrece solo cuando la instalación de requisitos no es posible o el usuario la rechaza.

---

## 1.1.0 — 2026-09-13

### ✨ Novedades

- **Detección del sistema e instalación de requisitos con permiso.** Se reconocen Homebrew, APT, DNF/YUM, pacman, apk, zypper, winget, Chocolatey y Scoop; se muestra la orden exacta y se pide autorización antes de ejecutarla.
- Tras instalar **se verifica que los programas existan de verdad**, ampliando el PATH con las rutas habituales, en lugar de fiarse del código de salida del gestor.
- **`--check` nunca instala nada**, ni siquiera con `--yes`, y funciona sin tener Node.

### 🐛 Correcciones

- El consentimiento podía darse por sí solo: cuando no había nadie al otro lado, la lectura vacía se tomaba como un "sí".
- La verificación posterior fallaba aunque la instalación hubiera ido bien, porque el binario nuevo no estaba todavía en el PATH del proceso.

---

## 1.0.0 — 2026-09-13

### ✨ Novedades

- Publicación inicial de las **siete skills**: `solution-architect`, `project-manager`, `prototype-kickoff`, `java-developer`, `python-developer`, `gcp-expert` y `aws-expert`.
- Instalador con menú para **Claude Code, Cursor, IntelliJ IDEA Ultimate (Junie) y Google Antigravity**.
- Arranques `install.sh` e `install.ps1`, y distribuciones por herramienta dentro de cada skill.
