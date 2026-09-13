# Instalación de `project-manager`

Este paquete contiene la misma guía en tres formatos, uno por entorno. Elige el que uses; si trabajas con varios, instala los que apliquen y versiónalos en el repositorio para que todo el equipo comparta el mismo comportamiento.

## Claude Code y Claude.ai

Copia la carpeta del skill (con su `SKILL.md`) a:

```
.claude/skills/project-manager/
```

En Claude.ai o Cowork, instala directamente el archivo `project-manager.skill` incluido en este paquete.

## Cursor

Copia el archivo de reglas a la carpeta de reglas del proyecto:

```
.cursor/rules/project-manager.mdc
```

Está en `dist/cursor/project-manager.mdc`. Usa el modo **Agent Requested**: la regla no se carga siempre, sino que el agente la incorpora cuando la descripción coincide con la tarea, que es lo que evita gastar contexto en cada petición.

## IntelliJ IDEA Ultimate (Junie)

Copia el archivo a la carpeta de reglas de Junie:

```
.junie/rules/project-manager.md
```

Está en `dist/junie/project-manager.md`. Si tu versión de Junie usa el formato anterior, pega ese mismo contenido en `.junie/guidelines.md`; si el proyecto ya tiene un `AGENTS.md` en la raíz, puedes incluirlo ahí como una sección. Junie lee `AGENTS.md`, `.junie/rules/*.md` y `.junie/guidelines.md`, así que cualquiera de las tres rutas funciona: elige una sola para no duplicar la guía.

En proyectos monorepo, indica la ruta de forma explícita en **Settings → Tools → Junie → Project Settings → Guidelines path**.

## Google Antigravity

Copia **todos** los archivos `.md` de `dist/antigravity/` (hoy son 3) a:

```
.agents/rules/project-manager-01.md
.agents/rules/project-manager-02.md
.agents/rules/project-manager-03.md
```

Antigravity también lee un `AGENTS.md` o un `GEMINI.md` en la raíz del workspace, y `.agent/rules/` (en singular) por compatibilidad con proyectos antiguos. Elige una sola ubicación para no duplicar la guía.

La guía viene dividida en varias partes porque **Antigravity limita cada archivo de reglas a 12.000 caracteres** y esta supera ese tamaño. Instálalas todas: cada parte declara en su cabecera que forma parte de un solo documento. Si prefieres un archivo único, pega el contenido completo en el `AGENTS.md` de la raíz, que no tiene ese límite.

Este skill describe un proceso de varios pasos, y Antigravity distingue entre **Rules** (contexto permanente) y **Workflows** (secuencias que se invocan). Por eso se incluye también `dist/antigravity/workflows/project-manager.md`: cópialo a `.agents/workflows/project-manager.md` para poder lanzar el método completo escribiendo `/project-manager` en el chat del agente.

## Verificación

Instalado correctamente, el agente debería cambiar su comportamiento sin que se lo pidas en el prompt. Una forma rápida de comprobarlo: di "el proyecto va retrasado" y verifica que el agente pida contexto y responda con opciones y una recomendación, no solo con un diagnóstico.
