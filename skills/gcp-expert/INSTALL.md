# Instalación de `gcp-expert`

Este paquete contiene la misma guía en cuatro formatos, uno por entorno. Elige el que uses; si trabajas con varios, instala los que apliquen y versiónalos en el repositorio para que todo el equipo comparta el mismo comportamiento.

> [!TIP]
> **La forma rápida es el instalador**, que hace todo esto por ti y te pregunta dónde:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.sh | bash
> ```
>
> ```powershell
> irm https://raw.githubusercontent.com/bigfito/vibe-coding-skills/main/install.ps1 | iex
> ```
>
> Lo que sigue es la **instalación manual**, por si prefieres hacerlo a mano o copiar solo esta skill.

## Dos ámbitos: global o por proyecto

Las rutas de abajo son las del **proyecto** (dentro de la carpeta en la que trabajas). Para que la skill esté disponible en **todos** tus proyectos, usa las mismas carpetas dentro de tu carpeta personal:

| Herramienta | Global | Por proyecto |
|---|---|---|
| Claude Code | `~/.claude/skills/` y `~/.claude/agents/` | `.claude/skills/` y `.claude/agents/` |
| Cursor | `~/.cursor/rules/` | `.cursor/rules/` |
| Junie | `~/.junie/rules/` | `.junie/rules/` |
| Antigravity | `~/.gemini/antigravity/rules/` y `~/.gemini/antigravity/global_workflows/` | `.agents/rules/` y `.agents/workflows/` |

En Windows, `~` es tu carpeta de usuario (`C:\Users\TuNombre`).

> [!IMPORTANT]
> Junie y Antigravity leen sus guías **globales** de un solo archivo (`~/.junie/AGENTS.md` y `~/.gemini/AGENTS.md`). Si instalas a mano en el ámbito global, añade en ese archivo una línea que apunte a la guía copiada, o el asistente no sabrá que está ahí. El instalador lo hace solo, entre marcas y sin tocar el resto del archivo.

## Claude Code y Claude.ai

Copia la carpeta del skill (con su `SKILL.md`) a:

```
.claude/skills/gcp-expert/
```

En Claude.ai o Cowork, instala directamente el archivo `gcp-expert.skill` incluido en este paquete.

## Cursor

Copia el archivo de reglas a:

```
.cursor/rules/gcp-expert.mdc
```

Está en `dist/cursor/gcp-expert.mdc`, en modo **Agent Requested**: la regla no se carga siempre, sino cuando la descripción coincide con la tarea. Trae además `globs` para archivos `.tf`, `.tfvars`, `Dockerfile` y `.yaml`, de modo que también se adjunta sola al abrir infraestructura como código.

## IntelliJ IDEA Ultimate (Junie)

Copia el archivo a:

```
.junie/rules/gcp-expert.md
```

Está en `dist/junie/gcp-expert.md`. Si tu versión de Junie usa el formato anterior, pega ese mismo contenido en `.junie/guidelines.md`; si el proyecto ya tiene un `AGENTS.md` en la raíz, puedes incluirlo ahí como una sección. Elige una sola ubicación para no duplicar la guía.

En monorepos, indica la ruta en **Settings → Tools → Junie → Project Settings → Guidelines path**.

## Google Antigravity

Copia **todos** los archivos `.md` de `dist/antigravity/` a `.agents/rules/`.

Antigravity también lee un `AGENTS.md` o un `GEMINI.md` en la raíz del workspace, y `.agent/rules/` (en singular) por compatibilidad con proyectos antiguos. Elige una sola ubicación para no duplicar la guía. La guía viene dividida en varias partes porque **Antigravity limita cada archivo de reglas a 12.000 caracteres**; instálalas todas.

## Verificación

Instalado correctamente, el agente debería cambiar su comportamiento sin que se lo pidas en el prompt. Una forma rápida de comprobarlo: pide "un bucket y una VM para pruebas" y verifica que el agente pregunte por región, cumplimiento y presupuesto antes de responder, entregue Terraform con versiones fijadas y etiquetas, y se niegue a abrir el puerto 22 a `0.0.0.0/0` proponiendo IAP en su lugar.
