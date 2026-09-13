# CLAUDE.md — Guía para Claude Code

> Este proyecto se ejecuta siguiendo **`PLAN.md`** (plan por fases) y las convenciones de
> **`AGENTS.md`**. Este archivo es el punto de entrada para **Claude Code**.

## Antes de empezar
0. Aplica el **protocolo de reanudación** de `AGENTS.md`: lee `progreso/INDICE.md` y el archivo de la fase actual, y contrasta con `git status` y `git log`.
1. Lee **`PLAN.md`** completo (arquitectura, stack, modelo de datos, contrato de API, fases).
2. Lee **`AGENTS.md`** (convenciones de código y del dominio).
3. Trabaja **fase por fase, en orden**. No marques una tarea completada sin cumplir sus criterios, y
   corre la **"Verificación de fase"** antes de avanzar.

## Contexto en una línea
<Dominio + stack + componentes principales.>

## Comandos frecuentes
```bash
<los mismos comandos de AGENTS.md>
```

## Lo que Claude Code debe respetar siempre
- <Reglas de código del stack (si es Java, estilo JavaMentor).>
- <Reglas del dominio (estados, límites, fechas UTC, idioma).>
- Secretos: nunca en el código ni en git; todo por `.env`.

## Sugerencia de uso con Claude Code
- Aborda **una fase por sesión**; haz un *commit* por tarea terminada con su archivo de `progreso/` actualizado.
- Lee `docs/convenciones-<stack>.md` aunque tengas instalada la skill de convenciones del stack: el documento incluye umbrales y desviaciones del proyecto, y manda sobre la skill.
- Presenta el diseño de cada fase antes del código; en las fases con aprobación, muéstralo en la conversación y espera la respuesta del usuario.
- Aplica el protocolo de reanudación también tras `/clear`, una compactación automática o al retomar una conversación: tu memoria de la sesión puede estar incompleta; el archivo de estado y git son la fuente de verdad.
- Si la conversación ya es muy larga, detente en un punto seguro (tarea con commit o estado actualizado) antes de empezar trabajo nuevo.
- Usa el checklist de tareas de `PLAN.md`; marca `- [x]` conforme pasen los criterios.
- Si una verificación falla, **detente y corrige** antes de continuar.

## Definición de Hecho
La de `PLAN.md`. El proyecto está terminado solo cuando todos esos puntos pasan.
