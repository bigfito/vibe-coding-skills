# Instalación de `prototype-kickoff`

Este paquete contiene la misma guía en tres formatos, uno por entorno. Elige el que uses; si trabajas con varios, instala los que apliquen y versiónalos en el repositorio para que todo el equipo comparta el mismo comportamiento.

## Claude Code y Claude.ai

Copia la carpeta del skill (con su `SKILL.md` y su carpeta `agents/`) a:

```
.claude/skills/prototype-kickoff/
```

En Claude.ai o Cowork, instala directamente el archivo `prototype-kickoff.skill` incluido en este paquete.

## Cursor

Copia el archivo de reglas a la carpeta de reglas del proyecto:

```
.cursor/rules/prototype-kickoff.mdc
```

Está en `dist/cursor/prototype-kickoff.mdc`. Usa el modo **Agent Requested**: la regla no se carga siempre, sino que el agente la incorpora cuando la descripción coincide con la tarea, que es lo que evita gastar contexto en cada petición.

## IntelliJ IDEA Ultimate (Junie)

Copia el archivo a la carpeta de reglas de Junie:

```
.junie/rules/prototype-kickoff.md
```

Está en `dist/junie/prototype-kickoff.md`. Si tu versión de Junie usa el formato anterior, pega ese mismo contenido en `.junie/guidelines.md`; si el proyecto ya tiene un `AGENTS.md` en la raíz, puedes incluirlo ahí como una sección. Junie lee `AGENTS.md`, `.junie/rules/*.md` y `.junie/guidelines.md`, así que cualquiera de las tres rutas funciona: elige una sola para no duplicar la guía.

En proyectos monorepo, indica la ruta de forma explícita en **Settings → Tools → Junie → Project Settings → Guidelines path**.

## Google Antigravity

Copia **todos** los archivos `.md` de `dist/antigravity/` (hoy son 3) a `.agents/rules/`:

```
.agents/rules/prototype-kickoff-01.md
.agents/rules/prototype-kickoff-02.md
.agents/rules/prototype-kickoff-03.md
```

Antigravity también lee un `AGENTS.md` o un `GEMINI.md` en la raíz del workspace, y `.agent/rules/` (en singular) por compatibilidad con proyectos antiguos. Elige una sola ubicación para no duplicar la guía.

La guía viene dividida en varias partes porque **Antigravity limita cada archivo de reglas a 12.000 caracteres** y esta supera ese tamaño. Instálalas todas: cada parte declara en su cabecera que forma parte de un solo documento. Si prefieres un archivo único, pega el contenido completo en el `AGENTS.md` de la raíz, que no tiene ese límite.

Este skill describe un proceso de varios pasos, y Antigravity distingue entre **Rules** (contexto permanente) y **Workflows** (secuencias que se invocan). Por eso se incluye también `dist/antigravity/workflows/prototype-kickoff.md`: cópialo a `.agents/workflows/prototype-kickoff.md` para poder lanzar el método completo escribiendo `/prototype-kickoff` en el chat del agente.

## Verificación

Instalado correctamente, el agente debería cambiar su comportamiento sin que se lo pidas en el prompt. Una forma rápida de comprobarlo: di "hazme un prototipo de X" y verifica que el agente encuadre primero (qué demuestra, quién lo ve, qué queda fuera) antes de proponer código.
