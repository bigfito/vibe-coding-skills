# agent-skills

Una colección de siete **skills** listas para instalar en tu asistente de programación.

## ¿Qué es una skill y para qué sirve esto?

Una skill es un documento de instrucciones que tu asistente de IA lee antes de responderte. Sin skills, el asistente responde con criterio genérico. Con ellas, responde como un especialista: un arquitecto de soluciones pregunta lo que hace falta antes de diseñar, un gerente de proyecto arma un plan realista, un experto en nube se niega a dejarte un puerto abierto.

No tienes que escribir nada especial ni recordar ningún comando: una vez instaladas, el asistente las usa solo cuando la conversación lo amerita.

Funcionan en cuatro herramientas: **Claude Code**, **Cursor**, **IntelliJ IDEA Ultimate (Junie)** y **Google Antigravity**. Puedes instalarlas en una o en todas.

El instalador se encarga solo de los requisitos: detecta tu sistema operativo, comprueba si tienes lo necesario y, si te falta algo, **te pide permiso y lo instala por ti**.

---

# Instalación paso a paso

Si nunca has usado una terminal, sigue estos cinco pasos en orden. Toma unos tres minutos.

## Paso 1. Abre la terminal

La terminal es una ventana donde se escriben comandos en lugar de hacer clic. Viene incluida en todos los sistemas.

**En Windows**
1. Pulsa la tecla **Windows**.
2. Escribe `PowerShell`.
3. Haz clic en **Windows PowerShell**.

**En macOS**
1. Pulsa **Command (⌘) + Barra espaciadora**.
2. Escribe `Terminal`.
3. Pulsa **Enter**.

**En Linux**
Pulsa **Ctrl + Alt + T**, o busca "Terminal" en tus aplicaciones.

Se abrirá una ventana con texto y un cursor parpadeando. Es normal que se vea vacía.

## Paso 2. Ve a la carpeta de tu proyecto

Las skills se instalan **dentro de la carpeta del proyecto** en el que vas a trabajar, no en todo el computador. Por eso primero hay que "entrar" en esa carpeta.

Escribe `cd` (de *change directory*), un espacio, y la ruta de tu carpeta:

```
cd /ruta/de/mi/proyecto
```

**Truco para no escribir la ruta a mano:** escribe `cd`, pon un espacio, y **arrastra la carpeta desde el explorador de archivos hasta la ventana de la terminal**. La ruta se escribe sola. Después pulsa **Enter**.

Para confirmar que estás en el sitio correcto, escribe `ls` (en Windows, `dir`) y pulsa Enter: deberías ver los archivos de tu proyecto.

## Paso 3. Ejecuta el instalador

Copia la línea que corresponda a tu sistema, pégala en la terminal y pulsa **Enter**.

**En Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
```

**En macOS o Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash
```

*Para pegar en la terminal:* en Windows haz clic derecho; en macOS usa **⌘ + V**; en Linux usa **Ctrl + Shift + V**.

El instalador revisa primero que tu computador tenga lo necesario: **Node.js 18 o superior, npm, npx y git**.

Si falta algo, detecta tu sistema y tu gestor de paquetes (Homebrew en macOS; APT, DNF, pacman, apk o zypper en Linux; winget, Chocolatey o Scoop en Windows), te muestra la orden exacta que ejecutaría y te pregunta:

```
  Faltan requisitos para poder continuar:
   • git: no está instalado  — npx lo necesita para descargar el paquete desde GitHub

  Puedo instalarlos con APT:
      sudo apt-get update
      sudo apt-get install -y git

  ¿Los instalo ahora? [S/n]
```

Pulsa **Enter** y los instala. Responde `n` y no toca nada: te deja las instrucciones para hacerlo a mano.

Tres cosas que conviene saber:

- **Nunca instala nada sin tu permiso.** Si no hay nadie para responder (por ejemplo, dentro de un script automático), se detiene y te lo dice, en lugar de decidir por ti.
- **En Linux y macOS puede pedirte tu contraseña**, porque instalar paquetes del sistema requiere permisos de administrador (`sudo`). Homebrew es la excepción y nunca se ejecuta con `sudo`.
- **Comprueba el resultado**: después de instalar vuelve a verificar que los comandos existan de verdad. Si tu sistema no los expone hasta reabrir la terminal, te lo advierte.

Si prefieres que no instale nada automáticamente, añade `--no-install`. Si quieres autorizarlo de antemano (por ejemplo, en un script), añade `--yes`.

## Paso 4. Elige qué instalar

Aparecerá una lista de las siete skills con su descripción:

```
¿Qué skills quieres instalar?
   1. aws-expert          Arquitectura, desarrollo serverless, CloudOps...
   2. gcp-expert          Arquitectura, ingeniería de datos, redes...
   3. java-developer      Desarrollo profesional de software en Java 25...
   ...

Números separados por coma (p. ej. 1,3,5-7) o Enter para todas:
```

- Para instalarlas **todas**, simplemente pulsa **Enter**.
- Para elegir algunas, escribe sus números separados por comas: `2,4,5` y Enter.
- También puedes usar rangos: `1-3` significa las skills 1, 2 y 3.

Luego preguntará **en qué herramientas** instalarlas. Las que ya usas en ese proyecto aparecen marcadas como *(detectado en el proyecto)*. Si no sabes qué elegir, pulsa Enter para instalarlas en todas: no estorba tener las cuatro.

Por último pedirá confirmación. Escribe `s` y pulsa Enter.

## Paso 5. Comprueba que funcionó

Verás un mensaje como este:

```
✓ 34 archivo(s) instalados.
Versiona estas carpetas en git para que el equipo comparta el mismo comportamiento.
```

Eso es todo. Abre tu asistente y pídele algo relacionado: por ejemplo, *"quiero construir una aplicación para gestionar inventario"*. Si instalaste `solution-architect`, en lugar de lanzarse a escribir código debería empezar haciéndote preguntas.

---

# Qué necesita tu computador (y qué hace el instalador con eso)

Para funcionar hacen falta cuatro programas: **Node.js 18 o superior**, **npm**, **npx** y **git**. No tienes que instalarlos tú.

| Situación | Qué hace el instalador |
|-----------|------------------------|
| No te falta nada | Sigue de largo y te muestra el menú |
| Te falta algo y hay gestor de paquetes | Te enseña la orden exacta, te pide permiso y lo instala |
| Dices que no | No toca nada y te deja las instrucciones para hacerlo a mano |
| Nadie puede responder (script automático) | Se detiene: nunca instala sin autorización |
| Tu sistema pide contraseña de administrador | Te la pide la propia orden `sudo`, no el instalador |
| No hay gestor de paquetes conocido | Te dice cómo instalarlo a mano, paso a paso |
| Tu Linux solo ofrece una versión antigua de Node | Te lo dice y te da los comandos de `nvm` para tener una moderna |
| Se instaló pero la terminal aún no lo ve | Te avisa de que cierres y vuelvas a abrir la terminal |

En todos los casos **comprueba el resultado**: después de instalar verifica que los programas existan de verdad, en lugar de fiarse de que el gestor dijera que fue bien.

Lo que el instalador **no** hace: no cambia versiones que ya tengas funcionando, no instala nada fuera de esa lista de cuatro programas, no modifica tu sistema si respondes que no, y no toca nada fuera de la carpeta del proyecto cuando copia las skills.

---

# Si algo sale mal

| Lo que ves | Qué significa y qué hacer |
|------------|---------------------------|
| `Faltan requisitos para poder continuar` | Es normal la primera vez. Responde `s` (o pulsa Enter) y el instalador los instala por ti. |
| `No hay terminal interactiva` (al pedir permiso) | Nadie puede responder la pregunta. Repite el comando añadiendo `--yes` para autorizar la instalación de antemano. |
| `Se instaló, pero todavía falta…` | El paquete se instaló, pero tu terminal aún no lo ve. **Ciérrala y vuelve a abrirla**, y repite el paso 3. |
| `Hace falta sudo…` | Tu usuario no puede instalar paquetes del sistema. Pide ayuda a quien administre el equipo, o usa `nvm` (el mensaje incluye los comandos). |
| `curl: command not found` (Windows) | Estás usando el comando de macOS. Usa la línea de PowerShell del paso 3. |
| `No hay terminal interactiva disponible` | El menú no puede abrirse. Añade `--all --yes` al final del comando para instalar todo sin menú. |
| `ya existían y no se tocaron` | Ya habías instalado esas skills. Si quieres reemplazarlas por la versión nueva, repite el comando añadiendo `--force` al final. |
| No pasa nada al pegar | Puede que no se pegara el texto. Prueba con clic derecho (Windows) o **⌘ + V** (macOS). |
| Instaló, pero el asistente no cambia | Cierra y vuelve a abrir el asistente. En Cursor, comprueba **Settings → Rules**. |

**Para revisar tu computador sin instalar ni cambiar nada**, usa esta línea:

**En Windows (PowerShell)**

```powershell
$env:AGENT_SKILLS_CHECK=1; irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
```

**En macOS o Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash -s -- --check
```

Te dice qué tienes, qué te falta y con qué comando lo instalaría, y termina sin tocar nada. Sirve incluso si no tienes Node.js todavía.

---

# Mantenimiento

**Actualizar a la última versión:** repite el paso 3 añadiendo `--force` al final, para que reemplace los archivos anteriores.

**Quitar las skills:** se borran las carpetas que se crearon. No hay desinstalador porque no hace falta: solo son archivos de texto dentro de tu proyecto.

**Trabajo en equipo:** si tu proyecto usa git, guarda estas carpetas en el repositorio (`git add .claude .cursor .junie .agents`). Así todo el equipo obtiene el mismo comportamiento del asistente sin instalar nada.

---

# Las siete skills

| Skill | Para qué sirve |
|-------|----------------|
| `solution-architect` | Entrevista para entender qué necesitas, y produce arquitectura, modelo de datos, pantallas y un plan por fases |
| `project-manager` | Plan de proyecto, cronograma, dependencias, riesgos, métricas y reportes de estado |
| `prototype-kickoff` | Coordina un equipo de agentes para construir un prototipo completo que funcione |
| `java-developer` | Escribe Java 25 y Spring Boot legible y mantenible |
| `python-developer` | Escribe Python 3.14, FastAPI y Django con buenas prácticas |
| `gcp-expert` | Arquitectura, datos, redes y seguridad en Google Cloud |
| `aws-expert` | Arquitectura, serverless, datos y DevOps en Amazon Web Services |

Puedes instalar solo las que te sirvan. Si no trabajas con Java, no instales `java-developer`.

---

# Dónde queda instalado cada archivo

| Herramienta | Carpeta que se crea |
|-------------|---------------------|
| Claude Code | `.claude/skills/` y los agentes en `.claude/agents/` |
| Cursor | `.cursor/rules/` |
| IntelliJ IDEA Ultimate (Junie) | `.junie/rules/` |
| Google Antigravity | `.agents/rules/` y los flujos en `.agents/workflows/` |

Son carpetas ocultas (empiezan por punto). Para verlas: en macOS pulsa **⌘ + Shift + .** en Finder; en Windows activa **Ver → Elementos ocultos**.

Dos detalles: en Antigravity las guías largas se instalan partidas en varios archivos numerados, porque esa herramienta limita el tamaño de cada archivo de reglas; se leen como un solo documento. Y `solution-architect` incluye plantillas adicionales que el instalador copia junto a la regla.

---

# Opciones avanzadas

Si prefieres saltarte el menú, o automatizarlo:

```bash
npx github:bigfito/vibe-coding-skills --all --envs=claude,cursor --yes
npx github:bigfito/vibe-coding-skills --skills=gcp-expert,project-manager --envs=claude --yes
npx github:bigfito/vibe-coding-skills --all --dry-run      # simula, no escribe nada
```

| Opción | Efecto |
|--------|--------|
| `--skills=a,b` | Instala solo esas skills |
| `--envs=a,b` | Destinos: `claude`, `cursor`, `junie`, `antigravity` |
| `--all` | Todas las skills |
| `--yes`, `-y` | Sin pedir confirmación |
| `--force` | Sobrescribe lo ya instalado |
| `--dry-run` | Muestra qué haría, sin tocar nada |
| `--check` | Solo diagnostica el entorno: no instala ni cambia nada |
| `--no-install` | Nunca instala requisitos: solo dice qué falta y cómo instalarlo |
| `--help` | Ayuda |

También se pueden fijar por variable de entorno: `AGENT_SKILLS_ASSUME_YES=1` equivale a `--yes`, `AGENT_SKILLS_NO_INSTALL=1` a `--no-install` y `AGENT_SKILLS_CHECK=1` a `--check` (útil en PowerShell, donde `irm … | iex` no admite argumentos).

**Instalación manual:** cada skill tiene su propio `INSTALL.md` dentro de `skills/`, con los cuatro caminos explicados, y un archivo `.skill` que se instala directamente en Claude.ai o Cowork.

**Requisitos técnicos:** Node.js 18 o superior, npm, npx y git. No hace falta instalarlos a mano: el instalador los detecta y, con tu permiso, los instala. No usa dependencias externas, solo módulos nativos de Node.

**Gestores de paquetes que reconoce:** Homebrew (macOS), APT, DNF/YUM, pacman, apk y zypper (Linux y WSL), y winget, Chocolatey y Scoop (Windows).

---

# Para el dueño del repositorio

**Pruebas:** el repositorio trae una batería de pruebas de extremo a extremo que no toca el sistema (usa gestores de paquetes simulados en carpetas temporales):

```bash
npm test          # o: bash tests/run-tests.sh
```

Cubren la sintaxis de los tres puntos de entrada, la detección de sistema y gestor, el diálogo de consentimiento (incluido que cancelar no instale nada), la instalación y reverificación, y la copia de skills en los cuatro entornos. Las pruebas de `install.ps1` se ejecutan si hay PowerShell instalado, y se saltan si no.

**Comprobación rápida del entorno**, desde cualquier carpeta:

```bash
npx github:bigfito/vibe-coding-skills --check
```

---

Licencia MIT.
