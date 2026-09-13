# Instalación de `solution-architect`

Este paquete contiene la misma guía en tres formatos, uno por entorno. Elige el que uses; si trabajas con varios, instala los que apliquen y versiónalos en el repositorio para que todo el equipo comparta el mismo comportamiento.

## Claude Code y Claude.ai

Copia la carpeta del skill (con su `SKILL.md`) a:

```
.claude/skills/solution-architect/
```

En Claude.ai o Cowork, instala directamente el archivo `solution-architect.skill` incluido en este paquete.

## Cursor

Copia el archivo de reglas a la carpeta de reglas del proyecto:

```
.cursor/rules/solution-architect.mdc
```

Está en `dist/cursor/solution-architect.mdc`. Usa el modo **Agent Requested**: la regla no se carga siempre, sino que el agente la incorpora cuando la descripción coincide con la tarea, que es lo que evita gastar contexto en cada petición.

## IntelliJ IDEA Ultimate (Junie)

Copia el archivo a la carpeta de reglas de Junie:

```
.junie/rules/solution-architect.md
```

Está en `dist/junie/solution-architect.md`. Si tu versión de Junie usa el formato anterior, pega ese mismo contenido en `.junie/guidelines.md`; si el proyecto ya tiene un `AGENTS.md` en la raíz, puedes incluirlo ahí como una sección. Junie lee `AGENTS.md`, `.junie/rules/*.md` y `.junie/guidelines.md`, así que cualquiera de las tres rutas funciona: elige una sola para no duplicar la guía.

En proyectos monorepo, indica la ruta de forma explícita en **Settings → Tools → Junie → Project Settings → Guidelines path**.

## Nota para este skill

`solution-architect` usa archivos de apoyo en `references/` y `assets/`, y la guía los referencia por ruta relativa. **Copia esas dos carpetas junto con la regla** en cualquiera de los tres entornos; si solo copias el archivo de reglas, el agente seguirá el método pero no encontrará las plantillas.

En Cursor puedes referenciarlas desde la regla con `@references/artifacts.md`; en Junie, indica la ruta en el texto de la tarea.

## Google Antigravity

Copia `dist/antigravity/solution-architect.md` a:

```
.agents/rules/solution-architect.md
```

Antigravity también lee un `AGENTS.md` o un `GEMINI.md` en la raíz del workspace, y `.agent/rules/` (en singular) por compatibilidad con proyectos antiguos. Elige una sola ubicación para no duplicar la guía.

Este skill describe un proceso de varios pasos, y Antigravity distingue entre **Rules** (contexto permanente) y **Workflows** (secuencias que se invocan). Por eso se incluye también `dist/antigravity/workflows/solution-architect.md`: cópialo a `.agents/workflows/solution-architect.md` para poder lanzar el método completo escribiendo `/solution-architect` en el chat del agente.

## Verificación

Instalado correctamente, el agente debería cambiar su comportamiento sin que se lo pidas en el prompt. Una forma rápida de comprobarlo: describe una idea de sistema en dos frases y verifica que el agente haga rondas de preguntas antes de proponer arquitectura, en lugar de saltar directo al diseño.
