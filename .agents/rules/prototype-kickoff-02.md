# prototype-kickoff (parte 2 de 3)

> Regla de workspace para Google Antigravity. Colócala en `.agents/rules/` junto con las demás partes.
> **Cuándo aplica:** Construcción de prototipos de software funcionales entregados como una aplicación en mono-repo, orquestando subagentes especializados (arquitecto de soluciones, gerente de proyecto, desarrolladores Java y Python, y especialistas de GCP y AWS). Usa este skill siempre que el usuario quiera construir un prototipo, una prueba de concepto, un demo funcional o un MVP; cuando pida "hazme un prototipo de X", "quiero una app que demuestre Y", "arma una PoC"; cuando el trabajo implique diseñar, planear y después programar una aplicación completa de varios módulos; cuando haya que coordinar diseño de arquitectura, plan de proyecto y desarrollo en Java o Python dentro de un mismo repositorio; o cuando el usuario quiera que varios agentes trabajen en paralelo sobre un mismo proyecto. Aplica aunque el usuario no mencione la palabra prototipo, si lo que describe es una aplicación nueva que debe quedar corriendo.
> Esta guía está dividida en 3 partes por el límite de 12.000 caracteres de Antigravity; léelas todas, son un solo documento.

---

## Flujo de trabajo

### Etapa 0 — Encuadre (lo haces tú, con el usuario)

Antes de invocar a nadie, deja claras cinco cosas y confírmalas:

- **Qué debe demostrar el prototipo.** El flujo concreto que alguien va a ver funcionando.
- **Quién lo va a ver.** Un comité, un cliente, un equipo técnico: cambia dónde poner el esfuerzo.
- **Qué queda fuera** de forma deliberada.
- **Stack y restricciones:** Java, Python o ambos; base de datos; si debe correr en local o desplegarse.
- **Horizonte:** días u horas disponibles. Determina cuántas fases caben.

Si algo falta, pregunta con una recomendación por delante para que confirmar sea rápido. **No delegues sobre una idea difusa:** los subagentes amplifican la claridad y amplifican igual la ambigüedad.

### Etapa 1 — Diseño (subagente solution-architect)

Entrégale el encuadre confirmado y pídele que conduzca el descubrimiento y produzca los artefactos de diseño:

- **Entrevista de requisitos** con el usuario, en las rondas que hagan falta, hasta que no queden huecos que obliguen a asumir.
- **Matriz de requisitos** en hoja de cálculo, separando siempre lo funcional de lo no funcional.
- **Diagrama de arquitectura, modelo de datos y contratos de API** entre módulos.
- Si el prototipo tiene interfaz, **diseño de pantallas y mockups navegables**, más la estrategia de pruebas de esa interfaz con Playwright.

- Si el prototipo corre en la nube, **validación de los requisitos del proveedor** con `gcp-expert` o `aws-expert`.

El descubrimiento no es un trámite previo: en un prototipo, el requisito no funcional que nadie preguntó es lo que obliga a rehacer la arquitectura a mitad de la construcción.

**Los contratos de API son el entregable crítico de esta etapa**, porque son lo que después permite que java-dev y python-dev trabajen en paralelo sin esperarse.

Presenta el diseño al usuario y **valídalo antes de seguir**. Rehacer un diseño cuesta una conversación; rehacer el código cuesta la mitad del prototipo.

### Etapa 2 — Plan (subagente project-manager)

Entrégale el diseño validado y pídele el plan de construcción. Debe incluir:

- Fases ordenadas, con tareas de identificador estable, cerrables en una sesión y con **criterios de aceptación verificables**.
- **Qué se puede construir en paralelo** y qué no, con el tipo de dependencia entre tareas, respetando el tope de dos desarrolladores concurrentes.
- **El responsable de cada tarea**, validando antes que el lenguaje de esa tarea corresponda a un desarrollador que sí participa en el prototipo, y que **las tareas de infraestructura queden asignadas al especialista de la nube correspondiente** y no a un desarrollador de aplicación.
- La **ruta crítica** del prototipo, que casi siempre coincide con el camino de demostración.
- El **Definition of Done reducido** del prototipo, escrito de forma explícita: qué sí se exige (que compile, que corra con un comando, pruebas del camino principal, README) y qué no se exige en este contexto.
- **Tareas de prueba de la interfaz con Playwright** cuando el prototipo tiene frontend, cubriendo al menos el camino de demostración completo.
- El registro de riesgos y dependencias, y el protocolo de desbloqueo.

La **Fase 0 siempre es el esqueleto del mono-repo**: estructura de carpetas, herramienta de construcción, configuración de calidad, `docker-compose` o equivalente, y un comando de arranque que ya corra aunque no haga nada todavía. Empezar por algo que arranca evita el prototipo que solo compila el último día.

### Etapa 3 — Construcción (subagentes java-dev y python-dev)

Ejecuta el plan **fase por fase**, no tarea por tarea suelta.

- Dentro de una fase, **invoca en paralelo** a los desarrolladores cuyas tareas no dependan entre sí, **sin exceder nunca dos en simultáneo**. Si hay más trabajo paralelizable, ejecútalo en tandas de dos, empezando por la ruta crítica.
- **La infraestructura la escribe el especialista de nube, no el desarrollador de aplicación.** Un dev que improvisa Terraform produce infraestructura que funciona en la demostración y no se puede auditar ni repetir.
- **Nunca pongas a dos subagentes a escribir el mismo archivo o el mismo módulo en el mismo turno.** Es la causa más común de trabajo perdido. Reparte por módulo, no por capa.
- Dale a cada desarrollador solo lo que necesita: su tarea, el contrato que debe cumplir, las convenciones del stack y los criterios de aceptación. Contexto de más lo distrae; contexto de menos lo hace inventar.
- Si un módulo depende de otro que aún no existe, el desarrollador consume un **mock o stub generado a partir del contrato**, nunca espera.
- **Cada tarea terminada se reporta de inmediato.** El desarrollador cierra una tarea solo cuando **sus pruebas corren sin error**, y entonces reporta al project-manager qué quedó hecho, qué decisiones tomó, qué dificultades encontró y qué quedó pendiente. El project-manager actualiza el `PLAN.md` y `progreso/` con ese reporte antes de que arranque la siguiente tarea del mismo desarrollador. El avance se registra tarea por tarea, no fase por fase: un plan que solo se actualiza al final no sirve para retomar una sesión interrumpida ni para detectar una desviación a tiempo.

Al terminar cada fase, **verifica tú mismo que el proyecto sigue corriendo** antes de abrir la siguiente. Una fase que rompe la anterior se detecta ahora o se paga al triple más adelante.

### Etapa 4 — Control de avance (subagente project-manager)

El project-manager registra el avance **cada vez que un desarrollador cierra una tarea con sus pruebas en verde**, y al terminar cada fase hace la revisión completa: estado contra el plan, calidad de los artefactos y la documentación, y desviaciones, bloqueos y riesgos nuevos.

Cuando el plan se desvíe, **no lo ocultes ni lo absorbas en silencio**: preséntale al usuario qué cambió, qué opciones hay y cuál recomiendas. Recortar alcance a tiempo es una decisión sana en un prototipo; descubrirlo el último día no lo es.

### Etapa 5 — Cierre y entrega

- Verifica el **arranque desde cero**: clonar, un comando, funciona.
- Comprueba que el `README.md` explique qué es, cómo se ejecuta, cómo se ve el flujo de demostración y **qué limitaciones tiene**.
- Pídele al project-manager el cierre: estado final contra el plan, lecciones y siguiente paso si el prototipo avanzara a producto.
- Entrega al usuario el mono-repo y un resumen breve de qué se construyó y qué quedó fuera.

## Estructura del mono-repo

Usa esta estructura como punto de partida y adáptala al prototipo. Un solo módulo es un caso válido: no inventes módulos para justificar carpetas.

```
<prototipo>/
├── README.md              # qué es, cómo se corre, qué demuestra, qué finge
├── PLAN.md                # plan por fases: la fuente única de verdad
├── CLAUDE.md / AGENTS.md  # convenciones y protocolo de reanudación
├── docs/
│   ├── arquitectura.md    # diagrama Mermaid y decisiones
│   ├── requisitos.xlsx     # matriz de requisitos funcionales y no funcionales
│   ├── modelo-datos.md
│   ├── contratos/         # OpenAPI, esquemas de eventos
│   ├── mockups/           # pantallas navegables, si aplica
│   └── convenciones-<stack>.md
├── progreso/              # estado por unidad e índice de avance
├── apps/                  # los módulos ejecutables
│   ├── api-java/
│   └── procesador-python/
├── packages/              # código compartido y clientes generados
├── infra/                 # docker-compose, migraciones, datos semilla
└── scripts/               # arranque, semillas, demo
```

Reglas del mono-repo:

- **Un solo comando de arranque** en la raíz (`make demo`, `docker compose up` o `./scripts/run.sh`). Es lo primero que se construye y lo último que se rompe.
- **Un módulo, un dueño.** Cada módulo tiene un subagente responsable durante la fase.
- **Los contratos viven en la raíz**, no dentro de un módulo. Si el contrato pertenece a quien lo produce, quien lo consume queda subordinado.
- **Datos semilla siempre.** Un prototipo con la base vacía no demuestra nada; que el arranque deje datos listos para la demo.
- **Una sola configuración de calidad por stack**, en la raíz, para que todos los módulos del mismo lenguaje se vean iguales.

## Protocolo de delegación

Al invocar a un subagente, entrégale siempre:

1. **Objetivo** de la tarea y su identificador en el `PLAN.md`.
2. **Contexto mínimo suficiente:** el artefacto de diseño o contrato aplicable, y nada más.
3. **Criterios de aceptación** verificables, tomados del plan.
4. **Límites:** qué archivos o módulos puede tocar y cuáles no.
5. **Qué debe devolver:** el código, más un reporte breve de decisiones, dificultades y pendientes.

Cuando recibas su resultado, **intégralo y verifícalo tú**: que compile, que corra, que respete el contrato. No encadenes una delegación con otra sin comprobar la primera; un error propagado entre agentes cuesta mucho más que detenerse a verificar.

## Reanudación

El `PLAN.md` y la carpeta `progreso/` son lo que permite retomar el trabajo si la sesión se corta por contexto o por tiempo. Manténlos actualizados al cerrar cada fase, no al final. Al reanudar, **lee primero el estado y después el código**, y confirma con el usuario dónde se quedó antes de seguir construyendo.
