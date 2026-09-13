# solution-architect (parte 2 de 2)

> Regla de workspace para Google Antigravity. Colócala en `.agents/rules/` junto con las demás partes.
> **Cuándo aplica:** Guía de extremo a extremo para convertir una idea de sistema en un plan de implementación por fases, ejecutable por un agente de IA, con todos los artefactos de diseño. Activa esta skill siempre que el usuario quiera idear, capturar requerimientos, o planear la construcción de un sistema, aplicación, servicio, pipeline o prototipo — incluso si solo dice "quiero construir X", "ayúdame a diseñar Y", "arma un plan para Z", "necesito una arquitectura", o describe un producto a alto nivel sin pedir un plan explícitamente. Úsala cuando la conversación implique diseñar arquitectura, modelar datos, diseñar pantallas, o producir un plan que otro agente (Claude Code, Google Antigravity, Genie de IntelliJ) pueda ejecutar. No es solo para proyectos Java: es agnóstica de stack y descubre la tecnología por conversación. El entregable final es un .zip con PLAN.md + AGENTS.md + CLAUDE.md y los artefactos, organizados por carpetas.
> Esta guía está dividida en 2 partes por el límite de 12.000 caracteres de Antigravity; léelas todas, son un solo documento.

---

## Compatibilidad entre agentes

Este skill funciona en **Claude Code**, **Cursor** e **IntelliJ IDEA Ultimate (Junie)**. El contenido es idéntico en los tres entornos; solo cambia el archivo donde vive:

| Entorno | Ubicación |
|---------|-----------|
| Claude Code y Claude.ai | `.claude/skills/solution-architect/SKILL.md` |
| Cursor | `.cursor/rules/solution-architect.mdc` (generado en `dist/cursor/`) |
| IntelliJ IDEA Ultimate (Junie) | `.junie/rules/solution-architect.md` o su contenido dentro de `AGENTS.md` (generado en `dist/junie/`) |
| Google Antigravity | `.agents/rules/solution-architect*.md` (generado en `dist/antigravity/`) |

Los pasos de instalación están en `INSTALL.md`.

Al ejecutar, aplica estas reglas de portabilidad:

- Cuando el texto diga "usa la skill X", entiéndelo como **"usa la skill o regla X si el entorno la ofrece; si no está disponible, aplica sus principios de forma inline y dilo"**. Nunca supongas que otra skill está cargada.
- Las herramientas concretas que se mencionan son orientativas. Si el entorno no tiene una equivalente, **dilo en lugar de simular que la usaste**.
- **Antigravity limita cada archivo de reglas a 12.000 caracteres.** Si esta guía se entregó dividida en varias partes numeradas, léelas todas: son un solo documento y ninguna se sostiene sola.
- No dependas de rutas, comandos ni mecanismos propios de un solo agente. Todo lo que este skill produce debe quedar en archivos del repositorio, que es lo único que los tres entornos comparten.
