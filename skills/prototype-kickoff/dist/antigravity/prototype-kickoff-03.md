# prototype-kickoff (parte 3 de 3)

> Regla de workspace para Google Antigravity. Colócala en `.agents/rules/` junto con las demás partes.
> **Cuándo aplica:** Construcción de prototipos de software funcionales entregados como una aplicación en mono-repo, orquestando subagentes especializados (arquitecto de soluciones, gerente de proyecto, desarrolladores Java y Python, y especialistas de GCP y AWS). Usa este skill siempre que el usuario quiera construir un prototipo, una prueba de concepto, un demo funcional o un MVP; cuando pida "hazme un prototipo de X", "quiero una app que demuestre Y", "arma una PoC"; cuando el trabajo implique diseñar, planear y después programar una aplicación completa de varios módulos; cuando haya que coordinar diseño de arquitectura, plan de proyecto y desarrollo en Java o Python dentro de un mismo repositorio; o cuando el usuario quiera que varios agentes trabajen en paralelo sobre un mismo proyecto. Aplica aunque el usuario no mencione la palabra prototipo, si lo que describe es una aplicación nueva que debe quedar corriendo.
> Esta guía está dividida en 3 partes por el límite de 12.000 caracteres de Antigravity; léelas todas, son un solo documento.

---

## Compatibilidad entre agentes

Este skill funciona en **Claude Code**, **Cursor** e **IntelliJ IDEA Ultimate (Junie)**. El contenido es idéntico en los tres entornos; solo cambia el archivo donde vive:

| Entorno | Ubicación |
|---------|-----------|
| Claude Code y Claude.ai | `.claude/skills/prototype-kickoff/SKILL.md` |
| Cursor | `.cursor/rules/prototype-kickoff.mdc` (generado en `dist/cursor/`) |
| IntelliJ IDEA Ultimate (Junie) | `.junie/rules/prototype-kickoff.md` o su contenido dentro de `AGENTS.md` (generado en `dist/junie/`) |
| Google Antigravity | `.agents/rules/prototype-kickoff*.md` (generado en `dist/antigravity/`) |

Los pasos de instalación están en `INSTALL.md`.

Al ejecutar, aplica estas reglas de portabilidad:

- Cuando el texto diga "usa la skill X", entiéndelo como **"usa la skill o regla X si el entorno la ofrece; si no está disponible, aplica sus principios de forma inline y dilo"**. Nunca supongas que otra skill está cargada.
- Las herramientas concretas que se mencionan son orientativas. Si el entorno no tiene una equivalente, **dilo en lugar de simular que la usaste**.
- **Antigravity limita cada archivo de reglas a 12.000 caracteres.** Si esta guía se entregó dividida en varias partes numeradas, léelas todas: son un solo documento y ninguna se sostiene sola.
- No dependas de rutas, comandos ni mecanismos propios de un solo agente. Todo lo que este skill produce debe quedar en archivos del repositorio, que es lo único que los tres entornos comparten.

- **Los subagentes existen como tales solo en Claude Code**, donde se declaran en `.claude/agents/`. En **Google Antigravity**, el Agent Manager sí permite varios agentes en paralelo: úsalo asignando un rol por agente y respetando el mismo tope de dos desarrolladores concurrentes. En Cursor y en Junie, que no tienen subagentes, **ejecuta los roles en secuencia dentro de la misma sesión**: anuncia de forma explícita qué rol asumes en cada turno, carga la definición correspondiente desde `agents/` y respeta los mismos límites (un rol a la vez, contexto mínimo suficiente, reporte al project-manager al cerrar cada tarea). Sin subagentes, el tope de dos desarrolladores concurrentes se convierte en **un rol por turno**, y la disciplina de reportar y registrar el avance pasa a ser todavía más importante, porque es lo único que conserva el estado entre turnos.

## Principios de trabajo

1. **Un prototipo se mide corriendo**, no leyendo.
2. **Diseño validado antes de la primera línea de código.**
3. **El contrato primero:** es lo que permite paralelizar sin bloqueos.
4. **Un módulo, un dueño, un turno.** Nunca dos agentes en el mismo archivo.
5. **Un solo lenguaje, un solo desarrollador; una sola nube, un solo especialista:** el rol que no aporta trabajo no se convoca.
6. **Máximo dos desarrolladores a la vez.** Más agentes en paralelo no acortan el prototipo, multiplican el costo.
7. **Ninguna tarea se cierra sin pruebas en verde**, y ninguna se cierra sin reportarse.
8. **Empieza por lo que hay que demostrar**, no por lo que es fácil.
9. **Verifica entre delegaciones:** un error propagado entre agentes es el más caro de todos.
10. **Contexto mínimo suficiente** para cada subagente: de más distrae, de menos hace inventar.
11. **Recortar alcance a tiempo es sano;** descubrirlo el último día no lo es.
12. **Lo que el prototipo finge, se escribe.**
