<div align="center">

# 🎓 Vibe Coding Skills

**Convierte tu asistente de IA en un equipo de especialistas.**

[![Licencia MIT](https://img.shields.io/badge/licencia-MIT-blue)](LICENSE)
[![Node.js 18+](https://img.shields.io/badge/Node.js-18%2B-brightgreen?logo=node.js&logoColor=white)](https://nodejs.org/es/download)
[![Windows · macOS · Linux](https://img.shields.io/badge/Windows%20%C2%B7%20macOS%20%C2%B7%20Linux-informational)](#5--instalación-en-4-pasos)
[![Pruebas de extremo a extremo](https://img.shields.io/badge/pruebas-de%20extremo%20a%20extremo-success)](#-para-el-dueño-del-repositorio)

7 skills · 4 herramientas · 3 minutos de instalación

</div>

---

## 📖 Índice

1. [¿Qué es esto y para qué sirve?](#1--qué-es-esto-y-para-qué-sirve)
2. [Las siete skills](#2--las-siete-skills)
3. [¿Qué necesita mi computador?](#3--qué-necesita-mi-computador)
4. [¿Global o por proyecto?](#4--global-o-por-proyecto)
5. [Instalación en 4 pasos](#5--instalación-en-4-pasos)
6. [Si algo sale mal](#6--si-algo-sale-mal)
7. [Mantenimiento](#7--mantenimiento)
8. [Opciones avanzadas](#8--opciones-avanzadas)

---

## 1. 💡 ¿Qué es esto y para qué sirve?

Una **skill** es un documento de instrucciones que tu asistente de IA lee antes de responderte.

| Sin skills 😐 | Con skills 🎯 |
|---|---|
| Responde con criterio genérico | Responde como un especialista |
| Se lanza a escribir código | Un arquitecto te pregunta qué necesitas **antes** de diseñar |
| Improvisa el plan | Un gerente de proyecto arma un plan realista |
| Te deja un puerto abierto | Un experto en nube se niega a dejarlo |

> [!TIP]
> No tienes que escribir nada especial ni recordar ningún comando. Una vez instaladas, **el asistente las usa solo** cuando la conversación lo amerita.

### 🛠️ Funcionan en cuatro herramientas

| | Herramienta |
|---|---|
| 🤖 | **Claude Code** |
| ✨ | **Cursor** |
| 🧠 | **IntelliJ IDEA Ultimate (Junie)** |
| 🚀 | **Google Antigravity** |

Puedes instalarlas en una o en todas.

### ✅ Lo que hace el instalador por ti

- 🔍 **Detecta tu sistema operativo** y qué asistentes tienes instalados.
- 📦 **Comprueba los programas necesarios** y, si falta alguno, **te pide permiso** y lo instala.
- 🌍 **Las deja disponibles en todos tus proyectos** (o solo en uno, si lo prefieres).

---

## 2. 📚 Las siete skills

| | Skill | Para qué sirve |
|:---:|---|---|
| 🏗️ | `solution-architect` | Te entrevista para entender qué necesitas y produce arquitectura, modelo de datos, pantallas y un plan por fases |
| 📋 | `project-manager` | Plan de proyecto, cronograma, dependencias, riesgos, métricas y reportes de estado |
| 🧪 | `prototype-kickoff` | Coordina un equipo de agentes para construir un prototipo completo que funcione |
| ☕ | `java-developer` | Escribe Java 25 y Spring Boot legible y mantenible |
| 🐍 | `python-developer` | Escribe Python 3.14, FastAPI y Django con buenas prácticas |
| ☁️ | `gcp-expert` | Arquitectura, datos, redes y seguridad en Google Cloud |
| 🟧 | `aws-expert` | Arquitectura, serverless, datos y DevOps en Amazon Web Services |

> [!TIP]
> Instala solo las que te sirvan. Si no trabajas con Java, no instales `java-developer`.

---

## 3. 🧰 ¿Qué necesita mi computador?

Cuatro programas: **Node.js 18+**, **npm**, **npx** y **git**. 🙌 **No tienes que instalarlos tú.**

### 🔎 Compruébalo sin instalar nada

**🪟 Windows (PowerShell)**

```powershell
$env:VIBE_SKILLS_CHECK=1; irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
```

**🍎 macOS · 🐧 Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash -s -- --check
```

Te responde dos cosas y **termina sin tocar nada**:

1. ✅ Si tu sistema tiene lo necesario, y con qué comando instalaría lo que falte.
2. ✅ Qué asistentes tienes instalados y en qué carpeta quedarían las skills de cada uno.

Funciona **aunque todavía no tengas Node.js**.

### 🤔 Qué hace el instalador en cada caso

| Situación | Qué hace |
|---|---|
| ✅ No te falta nada | Sigue de largo y te muestra el menú |
| 📦 Falta algo y hay gestor de paquetes | Te enseña la orden exacta, **te pide permiso** y lo instala |
| 🚫 Dices que no | No toca nada; te deja las instrucciones para hacerlo a mano |
| 🤖 Nadie puede responder (script automático) | Se detiene: **nunca instala sin autorización** |
| 🔐 Tu sistema pide contraseña | Te la pide la propia orden `sudo`, no el instalador |
| ❓ No hay gestor de paquetes conocido | Te dice cómo instalarlo a mano, paso a paso |
| 🕰️ Tu Linux solo trae un Node antiguo | Te lo dice y te da los comandos de `nvm` |
| 🙅 No quieres instalar nada | Te ofrece el **[modo sin Node](#-modo-sin-node)** |
| 🧩 No tienes ningún asistente instalado | Te lo dice y te deja seguir: las carpetas quedan listas |
| 🔄 Se instaló pero la terminal no lo ve | Te avisa de que la cierres y la vuelvas a abrir |

> [!IMPORTANT]
> En todos los casos **comprueba el resultado**: después de instalar verifica que los programas existan de verdad, en lugar de fiarse de que el gestor dijera que fue bien.

**Lo que el instalador *no* hace:** ❌ no cambia versiones que ya te funcionan · ❌ no instala nada fuera de esos cuatro programas · ❌ no modifica tu sistema si respondes que no · ❌ no toca nada fuera de las carpetas de skills.

### 🪶 Modo sin Node

¿No puedes instalar Node (sin permisos de administrador) o no quieres? Las skills son solo archivos de texto:

```bash
curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash -s -- --sin-node
```

```powershell
$env:VIBE_SKILLS_SIN_NODE=1; irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
```

Descarga las skills, te pregunta dónde las quieres y las copia. **Nada más.** Y si dices que **no** a instalar Node durante la instalación normal, el propio instalador te ofrece este camino.

> [!NOTE]
> Única diferencia: instala **todas** las skills (en la normal puedes elegir cuáles). El resultado es idéntico, archivo por archivo.

---

## 4. 🌍 ¿Global o por proyecto?

| | 🌍 **Global** | 📁 **Por proyecto** |
|---|---|---|
| **Dónde** | Tu carpeta personal | La carpeta del proyecto |
| **Para qué** | Todos tus proyectos, también los de mañana | Solo ese proyecto |
| **Se comparte con tu equipo** | ❌ No | ✅ Sí, si lo subes a git |
| **Cómo pedirlo** | `--global` *(por defecto)* | `--local` |

> [!TIP]
> **Lo normal es la global.** La instalación por proyecto tiene sentido cuando quieres que tu equipo reciba las mismas skills al clonar el repositorio.

Si eliges **por proyecto** y no estás dentro de la carpeta del proyecto, el instalador te la preguntará: puedes **arrastrar la carpeta hasta la ventana** de la terminal y pulsar Enter. También puedes indicarla de antemano con `--dir=/ruta/de/mi/proyecto`.

<details>
<summary><b>📂 Dónde queda cada archivo</b></summary>

<br>

| Herramienta | 🌍 Global | 📁 Por proyecto |
|---|---|---|
| 🤖 Claude Code | `~/.claude/skills/` y `~/.claude/agents/` | `.claude/skills/` y `.claude/agents/` |
| ✨ Cursor | `~/.cursor/rules/` | `.cursor/rules/` |
| 🧠 Junie | `~/.junie/rules/` + índice en `~/.junie/AGENTS.md` | `.junie/rules/` |
| 🚀 Antigravity | `~/.gemini/antigravity/` + índice en `~/.gemini/AGENTS.md` | `.agents/rules/` y `.agents/workflows/` |

- En Windows, `~` es tu carpeta de usuario (`C:\Users\TuNombre`).
- Son **carpetas ocultas** (empiezan por punto). Para verlas: macOS **⌘ + Shift + .** en Finder; Windows **Ver → Elementos ocultos**.
- Si usas `CLAUDE_CONFIG_DIR`, Claude Code se instala ahí en lugar de en `~/.claude`.

</details>

<details>
<summary><b>⚠️ Un detalle por herramienta (importante para la instalación global)</b></summary>

<br>

Las cuatro documentan su carpeta personal de forma distinta:

- 🤖 **Claude Code** — documenta `~/.claude/skills` como carpeta personal: lo que se instala ahí se carga en todas tus sesiones. ✅ Nada más que hacer.
- ✨ **Cursor** — su vía oficial son las *User Rules* (Ajustes → Rules), que son texto en la configuración, no archivos. Las versiones que leen `~/.cursor/rules` tomarán las skills de ahí; si la tuya no lo hace, copia el contenido de la regla que te interese en Ajustes.
- 🧠 **Junie** — lee sus guías globales de `~/.junie/AGENTS.md`. Las reglas se copian a `~/.junie/rules/` y en ese archivo se añade **un índice** que las señala.
- 🚀 **Antigravity** — igual: las reglas van a `~/.gemini/antigravity/` y el índice a `~/.gemini/AGENTS.md`.

> [!NOTE]
> El índice va entre marcas (`<!-- vibe-coding-skills: inicio -->` … `<!-- vibe-coding-skills: fin -->`). Se reescribe entero en cada instalación y **nunca toca lo que hayas escrito alrededor**.

</details>

---

## 5. 🚀 Instalación en 4 pasos

Ya sabes **qué skills hay**, **qué necesita tu computador** y **dónde van a quedar**. Esto es lo único que falta hacer.

> [!NOTE]
> Si nunca has usado una terminal, no te preocupes: sigue estos pasos en orden. Toma unos **tres minutos**.

### 🖥️ Paso 1. Abre la terminal

La terminal es una ventana donde se escriben comandos en lugar de hacer clic. Viene incluida en todos los sistemas.

<details>
<summary><b>🪟 En Windows</b></summary>

1. Pulsa la tecla **Windows**.
2. Escribe `PowerShell`.
3. Haz clic en **Windows PowerShell**.

</details>

<details>
<summary><b>🍎 En macOS</b></summary>

1. Pulsa **Command (⌘) + Barra espaciadora**.
2. Escribe `Terminal`.
3. Pulsa **Enter**.

</details>

<details>
<summary><b>🐧 En Linux</b></summary>

1. Pulsa **Ctrl + Alt + T**.
2. O busca "Terminal" en tus aplicaciones.

</details>

Se abrirá una ventana con texto y un cursor parpadeando. Es normal que se vea vacía. 👌

---

### ▶️ Paso 2. Ejecuta el instalador

Elige **una** de las dos opciones.

#### 🖱️ Opción A — Doble clic (sin escribir nada)

Descarga el lanzador de tu sistema desde la carpeta [`lanzadores/`](lanzadores) y ábrelo:

| Sistema | Archivo | Cómo abrirlo |
|:---:|---|---|
| 🪟 Windows | `instalar-windows.bat` | Doble clic. Si sale un aviso azul: **Más información → Ejecutar de todas formas**. |
| 🍎 macOS | `instalar-macos.command` | **Clic derecho → Abrir → Abrir** la primera vez. |
| 🐧 Linux | `instalar-linux.sh` | Clic derecho → **Ejecutar como programa**. |

Se abre una ventana y el instalador te va preguntando. **No hay que escribir comandos.**

#### ⌨️ Opción B — Una línea en la terminal

Copia la línea de tu sistema, pégala y pulsa **Enter**.

**🪟 Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
```

**🍎 macOS · 🐧 Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash
```

> [!TIP]
> **Para pegar en la terminal:** en Windows haz **clic derecho**; en macOS **⌘ + V**; en Linux **Ctrl + Shift + V**.

---

### 🙋 Paso 3. Responde tres preguntas

El instalador revisa primero tu computador. Si le falta algo, **te lo dice y te pide permiso**:

```text
  Faltan requisitos para poder continuar:
   • git: no está instalado  — npx lo necesita para descargar el paquete

  Puedo instalarlos con APT:
      sudo apt-get update
      sudo apt-get install -y git

  ¿Los instalo ahora? [S/n]
```

👉 Pulsa **Enter** y los instala. Responde `n` y **no toca nada**: te deja las instrucciones para hacerlo a mano.

Después vienen las tres preguntas:

**1️⃣ ¿Qué skills quieres?**

```text
   1. aws-expert          Arquitectura, serverless, CloudOps...
   2. gcp-expert          Arquitectura, datos, redes...
   3. java-developer      Java 25 y Spring Boot...

Números separados por coma (p. ej. 1,3,5-7) o Enter para todas:
```

- ⏎ **Enter** → todas
- ✏️ `2,4,5` → solo esas
- ➖ `1-3` → un rango (las skills 1, 2 y 3)

**2️⃣ ¿En qué herramientas?** Enter para todas (no estorba tenerlas).

**3️⃣ ¿Dónde las instalo?** Antes de preguntarlo te muestra lo que encontró:

```text
Herramientas detectadas en este computador
  Claude Code                      detectada
    global:   ~/.claude
    proyecto: .claude
  Cursor                           no detectada

¿Dónde quieres instalarlas?
   1. Global — en tu carpeta personal, disponibles en todos tus proyectos
   2. Solo en este proyecto
   3. En los dos sitios
```

👉 Pulsa **Enter** para la **global**: así sirven para cualquier proyecto que empieces después.

---

### 🎉 Paso 4. Comprueba que funcionó

Verás un mensaje como este:

```text
✓ 96 archivo(s) instalados.
```

Ahora abre tu asistente y pídele algo relacionado, por ejemplo:

> *"Quiero construir una aplicación para gestionar inventario"*

Si instalaste `solution-architect`, en lugar de lanzarse a escribir código debería **empezar haciéndote preguntas**. 🎯

> [!IMPORTANT]
> Si el asistente ya estaba abierto, **ciérralo y vuelve a abrirlo** para que cargue las skills nuevas.

---

## 6. 🆘 Si algo sale mal

| 😕 Lo que ves | 💡 Qué significa y qué hacer |
|---|---|
| `Faltan requisitos para poder continuar` | Normal la primera vez. Pulsa **Enter** y los instala por ti. |
| `No hay terminal interactiva` | Nadie puede responder. Repite añadiendo `--yes` al final. |
| `Se instaló, pero todavía falta…` | Se instaló, pero tu terminal no lo ve. **Ciérrala, ábrela** y repite. |
| `Hace falta sudo…` | Tu usuario no puede instalar programas. Pide ayuda a quien administre el equipo, o usa `nvm`. |
| `curl: command not found` en Windows | Estás usando el comando de macOS. Usa la línea de **PowerShell**. |
| `ya existían y no se tocaron` | Ya las tenías. Para reemplazarlas, añade `--force` al final. |
| No pasa nada al pegar | Puede que no se pegara. Prueba **clic derecho** (Windows) o **⌘ + V** (macOS). |
| La ventana del lanzador se cierra sola | Ábrelo desde la terminal para leer el mensaje: `bash instalar-macos.command`. |
| macOS dice que no se puede abrir | Es el aviso para archivos de internet. **Clic derecho → Abrir → Abrir**. |
| Instaló, pero el asistente no cambia | Cierra y vuelve a abrir el asistente. En Cursor, mira **Settings → Rules**. |

---

## 7. 🔧 Mantenimiento

- 🔄 **Actualizar:** repite el paso 2 añadiendo `--force`, para que reemplace los archivos anteriores.
- 🗑️ **Quitar las skills:** borra las carpetas de la tabla de [¿Global o por proyecto?](#4--global-o-por-proyecto). No hay desinstalador porque no hace falta: solo son archivos de texto. Si las instalaste globalmente, borra además el bloque entre `<!-- vibe-coding-skills: inicio -->` y `<!-- vibe-coding-skills: fin -->` de `~/.junie/AGENTS.md` y `~/.gemini/AGENTS.md`.
- 👥 **Trabajo en equipo:** si tu proyecto usa git, sube las carpetas al repositorio (`git add .claude .cursor .junie .agents`). Así todo el equipo obtiene el mismo comportamiento sin instalar nada.

---

## 8. ⚙️ Opciones avanzadas

<details>
<summary><b>Saltarse el menú y automatizar la instalación</b></summary>

<br>

```bash
npx github:bigfito/vibe-coding-skills --all --envs=claude,cursor --yes      # global
npx github:bigfito/vibe-coding-skills --all --local --yes                   # solo este proyecto
npx github:bigfito/vibe-coding-skills --all --scope=global,proyecto --yes   # los dos
npx github:bigfito/vibe-coding-skills --skills=gcp-expert,project-manager --envs=claude --yes
npx github:bigfito/vibe-coding-skills --all --dry-run                       # simula, no escribe nada
```

| Opción | Efecto |
|---|---|
| `--skills=a,b` | Instala solo esas skills |
| `--dir=ruta` | Carpeta del proyecto donde instalar (por defecto, la actual) |
| `--global` | En tu carpeta personal: sirve para todos tus proyectos *(por defecto sin menú)* |
| `--local` | Solo en este proyecto |
| `--scope=a,b` | Ámbitos: `global`, `proyecto`; indica los dos para instalar en ambos |
| `--envs=a,b` | Destinos: `claude`, `cursor`, `junie`, `antigravity` |
| `--all` | Todas las skills |
| `--yes`, `-y` | Sin pedir confirmación |
| `--force` | Sobrescribe lo ya instalado |
| `--dry-run` | Muestra qué haría, sin tocar nada |
| `--check` | Solo diagnostica: no instala ni cambia nada |
| `--no-install` | Nunca instala requisitos: solo dice qué falta |
| `--sin-node` | Copia las skills sin Node, sin instalar nada en el sistema |
| `--help` | Ayuda |

**Variables de entorno** (útiles en PowerShell, donde `irm … | iex` no admite argumentos):

| Variable | Equivale a |
|---|---|
| `VIBE_SKILLS_ASSUME_YES=1` | `--yes` |
| `VIBE_SKILLS_NO_INSTALL=1` | `--no-install` |
| `VIBE_SKILLS_CHECK=1` | `--check` |
| `VIBE_SKILLS_SIN_NODE=1` | `--sin-node` |
| `VIBE_SKILLS_AMBITO=global` | `--global` |

> [!NOTE]
> Antes se llamaban `AGENT_SKILLS_*`. Esos nombres **siguen funcionando**, así que no hace falta cambiar nada de lo que ya tuvieras escrito.

</details>

<details>
<summary><b>Instalación manual y detalles técnicos</b></summary>

<br>

- 📄 **Instalación manual:** cada skill tiene su `INSTALL.md` dentro de [`skills/`](skills), con los cuatro caminos explicados, y un archivo `.skill` que se instala directamente en Claude.ai o Cowork.
- 🧰 **Requisitos:** Node.js 18+, npm, npx y git. Sin dependencias externas: solo módulos nativos de Node.
- 📦 **Gestores de paquetes que reconoce:** Homebrew (macOS); APT, DNF/YUM, pacman, apk y zypper (Linux y WSL); winget, Chocolatey y Scoop (Windows).
- 🧩 **Antigravity:** las guías largas se instalan partidas en varios archivos numerados, porque esa herramienta limita el tamaño de cada archivo de reglas; se leen como un solo documento.
- 🗂️ **solution-architect** incluye plantillas adicionales que el instalador copia junto a la regla.

</details>

---

## 🔬 Para el dueño del repositorio

**Pruebas de extremo a extremo** (usan gestores de paquetes simulados en carpetas temporales: no tocan el sistema ni tu carpeta personal):

```bash
npm test          # o: bash tests/run-tests.sh
```

Cubren la sintaxis de los puntos de entrada, la detección de sistema y gestor, el diálogo de consentimiento (incluido que cancelar no instale nada), la instalación y su reverificación, los dos ámbitos y la copia de skills en las cuatro herramientas. Las de PowerShell se ejecutan si hay `pwsh` instalado, y se saltan si no.

**Comprobación rápida** desde cualquier carpeta:

```bash
npx github:bigfito/vibe-coding-skills --check
```

---
<div align="center">

Licencia MIT · Hecho para que tu asistente trabaje como un especialista 🎓

</div>
