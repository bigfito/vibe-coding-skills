# Empaquetado para agentes de IA

El objetivo: el usuario descomprime un `.zip` en un **directorio vacío**, abre esa carpeta desde su
herramienta con IA (Claude Code, Google Antigravity, Genie de IntelliJ) y le pide al agente que lea
el plan y ejecute las fases en orden.

## Archivos de convenciones

Genera dos archivos hermanos con el mismo fondo (uno lo lee cada familia de agentes):

- **`AGENTS.md`** — estándar que leen **Antigravity** y **Genie**. Contiene, **antes que todo**, el
  **protocolo de reanudación** y la disciplina de estado (`references/work-state.md`); una sección de
  reglas de código que obligue a leer `docs/convenciones-<stack>.md` y resuma lo esencial, incluidas las
  compuertas de aprobación de diseño (`references/coding-conventions.md`); después, qué es el
  proyecto, la regla de "ejecutar fases en orden y no avanzar si la verificación falla", los **comandos**
  (build, test, levantar entorno, crear esquema, seed, smoke test), la **estructura del repo**, las
  **reglas de código** (del stack elegido; si es Java, las de `java-developer`), las **reglas del
  dominio**, y la política de **secretos** (nunca en el código).
- **`CLAUDE.md`** — equivalente para **Claude Code**. Puede ser más breve y apuntar a `AGENTS.md` y
  `PLAN.md`, más notas específicas de uso con Claude Code: aplicar el protocolo de reanudación al
  iniciar, tras `/clear`, tras una compactación automática o al retomar una conversación; un commit
  por tarea con su archivo de estado; detenerse en un punto seguro si la conversación ya es muy larga;
  leer el documento de convenciones del proyecto aunque la skill de convenciones esté instalada, y
  presentar el diseño en la conversación en las unidades con aprobación.

Ambos deben remitir a `PLAN.md` como la fuente de la secuencia de trabajo.

## Organización del `.zip`

Coloca cada artefacto en la **ruta que el `PLAN.md` espera**. Estructura típica:

```
<proyecto>/
├── PLAN.md
├── AGENTS.md
├── CLAUDE.md
├── README.md                     # orientación de arranque (persona + agente) y cómo retomar
├── progreso/
│   ├── _PLANTILLA.md              # estado por unidad (assets/STATE-template.md)
│   └── INDICE.md                  # índice inicializado (assets/STATE-INDEX-template.md)
├── config/                        # configuraciones de estilo, análisis estático y arquitectura
├── docs/
│   ├── arquitectura.mermaid       # diagrama de arquitectura
│   ├── convenciones-<stack>.md    # cómo se escribe el código (portable a cualquier agente)
│   └── diseno/_PLANTILLA.md       # plantilla de diseño por unidad (assets/DESIGN-template.md)
├── design/
│   └── <prototipo>.html           # pantallas aprobadas (si hay frontend)
└── <motor-de-datos>/
    └── <esquema o mapping>        # p. ej. elasticsearch/index/<indice>-mapping.json
```

El `README.md` de la raíz debe explicar, en el idioma del usuario: qué contiene el paquete, los
prerrequisitos (herramientas y credenciales que el usuario provee), el **comando en lenguaje natural**
para pedirle al agente que empiece ("lee `PLAN.md` y los recursos que lo acompañan y ejecuta las
fases en orden desde la Fase 0"), el orden de arranque resumido, y una sección **"Si una sesión se
interrumpe"** con la instrucción para retomar ("aplica el protocolo de reanudación de `AGENTS.md` y
continúa desde el próximo paso registrado en `progreso/`").

## Construcción del `.zip` (ejemplo)

```bash
ROOT=<carpeta-de-trabajo>/<proyecto>
mkdir -p "$ROOT"/{docs,design,<motor>/...}
# copiar PLAN.md, AGENTS.md, CLAUDE.md, README.md y los artefactos a sus rutas
cd <carpeta-de-trabajo> && zip -r -q <proyecto>.zip <proyecto>
```

## Verificaciones antes de entregar

- El plan **referencia** los artefactos incluidos (diagrama, esquema, prototipo) por sus rutas.
- Los artefactos son **válidos** (JSON parseable, Mermaid balanceado, HTML/JS sin errores de sintaxis).
- No hay **secretos** embebidos en ningún archivo.
- `progreso/_PLANTILLA.md` y `progreso/INDICE.md` existen, `.gitignore` no excluye `progreso/`, y no
  hay colisión de nombre con carpetas de estado propias de la aplicación.
- `PLAN.md`, `AGENTS.md`, `CLAUDE.md` y `README.md` mencionan el protocolo de reanudación, y todas las
  tareas del plan tienen id único.
- Existe `docs/convenciones-<stack>.md` con ejemplos y desviaciones declaradas; las configuraciones de
  `config/` y los ejemplos se validaron ejecutando las herramientas (o el plan tiene una tarea de Fase 0
  que lo hace); todas las fases con código tienen tarea `.0` de diseño.
- El `.zip` se descomprime a una sola carpeta raíz del proyecto, organizada por subcarpetas.

Presenta el `.zip` al usuario con la herramienta de entrega de archivos disponible.
