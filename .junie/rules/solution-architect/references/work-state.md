# Estado del trabajo y reanudación

Cómo diseñar el plan para que un agente de codificación retome el trabajo sin perder avance cuando una
sesión termina sin aviso: se acaban los tokens, se llena o compacta el contexto, o se cierra la
herramienta. Aplica a **todo** plan que genere esta skill, sea secuencial o con trabajo en paralelo.

## Por qué hace falta

Un agente no puede medir con fiabilidad cuántos tokens le quedan, así que "guardar antes de que se
acaben" no es una estrategia. La protección real es una **disciplina por tarea**: el estado vive en
archivos versionados junto al código, se actualiza al empezar y al terminar cada tarea, y cada tarea
terminada queda en un commit. Así la pérdida máxima es la tarea en curso, y cualquier agente (el mismo
u otro, en la misma herramienta u otra) puede continuar leyendo el estado en lugar de confiar en su
memoria de la conversación.

Las casillas `- [ ]` del plan no bastan: suelen marcarse al final de una fase y no dicen en qué subpaso
se interrumpió el trabajo ni qué acción sigue.

## Archivos de estado

Incluye en el entregable una carpeta **`progreso/`** con:

| Archivo | Quién lo mantiene | Qué registra |
|---|---|---|
| `progreso/_PLANTILLA.md` | Nadie (plantilla) | Estructura de un archivo de estado por unidad (`assets/STATE-template.md`) |
| `progreso/INDICE.md` | El agente que ejecuta el plan (o el integrador si hay trabajo en paralelo) | Fase actual, estado de cada fase, próximo paso global y, si aplica, worktrees abiertos y merges en curso (`assets/STATE-INDEX-template.md`) |
| `progreso/<unidad>.md` | El agente que trabaja esa fase (o carril) | Se crea desde la plantilla al empezar la unidad |

Reglas de diseño:

- **Un archivo por unidad de trabajo** (fase, o carril si el plan tiene trabajo paralelo). Evita
  conflictos de merge entre agentes y mantiene cada archivo corto.
- **Se versiona en git.** Nunca lo excluyas en `.gitignore`.
- **Elige un nombre que no choque** con carpetas de la aplicación. Si el sistema usa `estado/`,
  `state/` o `checkpoints/` para su propia lógica, conserva `progreso/` para el estado del desarrollo y
  deja explícita la diferencia en el plan.

## Contenido obligatorio de un archivo de estado por unidad

1. **Identificación:** unidad, nombre, rama, carpeta y herramienta de la última sesión.
2. **Estado general:** `no iniciado`, `en curso`, `esperando aprobación de diseño`, `bloqueado`,
   `en verificación` o `terminado`.
3. **Punto de reanudación:** tarea actual, subpaso en curso, **próximo paso** y fecha UTC de la última
   actualización. El próximo paso debe ser una acción concreta que otro agente pueda ejecutar sin
   contexto previo ("Escribir `XTest` que simula dos respuestas 429 y afirma tres intentos"), nunca
   algo vago ("seguir con la ingesta").
4. **Tabla de tareas:** id, estado, hash del commit y evidencia (comando y resultado).
5. **Cambios sin commit:** archivos tocados en la tarea actual y qué falta en cada uno.
6. **Última verificación:** comando, resultado y fecha.
7. **Decisiones:** incluye un registro de cada reanudación.
8. **Bloqueos y solicitudes** (por ejemplo, de cambio de contrato si hay trabajo en paralelo).

## Disciplina de actualización (va en `PLAN.md` y en `AGENTS.md`)

1. **Al empezar una tarea:** marcarla `en curso`, escribir tarea actual, subpaso y próximo paso, y anotar
   el hash del commit de la tarea anterior.
2. **Durante la tarea:** actualizar subpaso y cambios sin commit después de cada archivo terminado y
   antes de cada comando largo (suite completa de pruebas, contenedores, refactorizaciones amplias).
3. **Al pasar el criterio:** marcar `terminada` con evidencia, vaciar cambios sin commit, escribir el
   nuevo próximo paso y hacer **un commit que incluya el código y el archivo de estado**, con el id de
   la tarea como prefijo del mensaje (`2.3: validación de configuración`).
4. **Nunca** empezar una tarea con cambios sin commit de la anterior.
5. **Si hay bloqueo:** estado `bloqueado`, describirlo, commit y detenerse.
6. **Al terminar la unidad:** estado `terminado`, última verificación y commit; actualizar `INDICE.md`.

Esto implica que las tareas del plan deben ser **lo bastante pequeñas para cerrarse en una sesión** y
tener un id estable (`2.3`, `1C.4`) que sirva de prefijo de commit.

## Protocolo de reanudación (va en `PLAN.md` y al inicio de `AGENTS.md`)

Toda sesión empieza así, sea nueva o reanudada tras una interrupción o compactación de contexto:

1. **Ubicarse:** rama actual y carpeta → modo de trabajo y unidad.
2. **Leer el estado:** `progreso/INDICE.md` y `progreso/<unidad>.md`. Si la unidad no tiene archivo,
   no ha empezado: crearlo desde la plantilla.
3. **Revisar git:** `git status` y `git log --oneline -10`.
4. **Contrastar:**
   - estado `esperando aprobación de diseño` → no escribir código; preguntar al usuario si aprueba el
     diseño y registrar la respuesta;
   - merge o rebase a medias → seguir lo registrado en `INDICE.md`;
   - cambios sin commit que coinciden con el archivo de estado → continuar sobre ellos;
   - cambios sin commit **no registrados** → no descartarlos ni sobrescribirlos; describirlos al usuario
     y preguntar;
   - commits posteriores a la última actualización del archivo → reconstruir la tabla desde los mensajes
     de commit y actualizar el archivo.
5. **Confirmar el punto real:** compilar y correr las pruebas de la tarea actual.
6. **Registrar la reanudación** en "Decisiones".
7. **Continuar desde el próximo paso**, sin rehacer tareas terminadas con commit.

## Cómo reflejarlo en cada entregable

- **`PLAN.md`:** paso 1 de "Cómo usar este plan" = aplicar el protocolo de reanudación; una sección
  "Estado del trabajo y reanudación" con los archivos, la disciplina y el protocolo; en la Fase 0, una
  tarea que verifique que `progreso/` existe y no está en `.gitignore`; en la Definición de Hecho, todos
  los archivos de estado en `terminado` y sin cambios sin commit.
- **`AGENTS.md`:** una sección "Primero: protocolo de reanudación" **antes** de cualquier otra regla, y
  una sección breve "Disciplina de estado".
- **`CLAUDE.md`:** aplicar el protocolo también tras `/clear`, una compactación automática o al retomar
  una conversación, porque la memoria de la sesión puede estar incompleta; detenerse en un punto seguro
  si la conversación ya es muy larga.
- **`README.md`:** una sección "Si una sesión se interrumpe" con la instrucción lista para copiar:
  > Retoma el trabajo: aplica el protocolo de reanudación de `AGENTS.md` y continúa desde el próximo
  > paso registrado en tu archivo de `progreso/`.
- **`.zip`:** incluye `progreso/_PLANTILLA.md` y `progreso/INDICE.md` inicializado con la Fase 0 como
  próximo paso.

## Si el plan tiene trabajo en paralelo

Cuando el plan divide fases en carriles con worktrees, `INDICE.md` lo mantiene el **integrador** y
registra además los worktrees abiertos, los carriles ya integrados, el merge en curso y las solicitudes
de cambio de contrato. Cada carril tiene su propio archivo de estado, y el integrador marca las casillas
de `PLAN.md` a partir de ellos.

## Verificaciones antes de entregar

- `progreso/_PLANTILLA.md` y `progreso/INDICE.md` existen y no están en `.gitignore`.
- `PLAN.md`, `AGENTS.md`, `CLAUDE.md` y `README.md` mencionan el protocolo de reanudación.
- Todas las tareas del plan tienen id único, usable como prefijo de commit.
- No hay colisión de nombres entre `progreso/` y carpetas de estado propias de la aplicación.
