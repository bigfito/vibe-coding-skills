# Convenciones de código ejecutables por agentes

Cómo asegurar que el código que escriben los agentes siga las convenciones de una skill especializada
(por ejemplo `java-developer` y su persona JavaMentor) aunque el plan lo ejecuten herramientas que no
tienen esa skill. Aplica a todo plan con código; los ejemplos son de Java, pero el método es agnóstico de
stack.

## Por qué no basta con resumir las convenciones en `AGENTS.md`

- **Las skills no viajan entre herramientas.** Una skill instalada en Claude no la leen Cursor,
  Antigravity ni Genie, y Claude Code solo si también la tiene instalada.
- **Un resumen pierde lo importante.** Ocho viñetas conservan "métodos cortos" pero pierden los umbrales,
  los criterios para elegir patrones, el formato de los errores, los ejemplos y las decisiones propias del
  proyecto.
- **Sin verificación, el estilo es voluntario.** Si los criterios de aceptación solo son funcionales, un
  agente puede entregar métodos de 80 líneas o un `catch` que se traga la excepción y la fase "pasa".
- **Sin diseño previo, no hay contra qué revisar.** La skill de convenciones suele pedir diseñar antes de
  codificar; si el plan salta a implementar, ese paso se pierde.

## Los cuatro mecanismos

### 1. Documento de convenciones portable

Entrega `docs/convenciones-<stack>.md` (por ejemplo `docs/convenciones-java.md`), **de lectura
obligatoria** y congelado. Es la skill de convenciones traducida al proyecto, no una copia literal: toma
sus principios y los concreta con nombres, paquetes y umbrales reales. Estructura recomendada:

1. Principios de trabajo de la persona.
2. Flujo por unidad de trabajo (requerimientos → diseño → implementación → explicación).
3. Uso de las características modernas del lenguaje "con mesura": cuándo sí y cuándo no, en tabla.
4. Diseño: SOLID aplicado a componentes concretos del proyecto y **lista cerrada de patrones** con dónde
   y por qué.
5. Estilo y nombres, con umbrales numéricos y una tabla de convenciones de nombres.
6. Framework (por ejemplo Spring): inyección, configuración, dónde se permite.
7. Errores: jerarquía, códigos y formato de mensaje (qué pasó, causa probable, acción sugerida).
8. Logging: niveles con ejemplos del proyecto, contexto obligatorio, datos prohibidos.
9. Documentación en código.
10. Pruebas: nombres, estructura, qué se prohíbe.
11. Reglas de dominio que afectan el código (determinismo, tiempo, concurrencia).
12. Build y dependencias.
13. **Ejemplos de referencia** completos, que pasen la verificación automática del proyecto.
14. **Qué se verifica automáticamente**: tabla regla → herramienta → umbral, y política de supresiones.
15. **Desviaciones declaradas** respecto a la skill de convenciones, con su motivo, para que ningún
    agente las "corrija".
16. **Lista de revisión de cierre**, con preguntas que exigen respuesta.

Declara que el documento **manda sobre las preferencias por defecto de cualquier herramienta**, y que en
temas de dominio mandan el plan y el modelo de datos.

### 2. Diseño antes de codificar

- Toda fase o carril con código empieza por una tarea `<unidad>.0` que produce `docs/diseno/<unidad>.md`
  desde `docs/diseno/_PLANTILLA.md` (`assets/DESIGN-template.md`): propósito, requerimientos cubiertos,
  dudas, diagrama de clases en Mermaid, secuencia o flujo si hay concurrencia o estados,
  responsabilidades, patrones y su justificación, errores, logging, pruebas previstas, alternativas
  descartadas y supresiones.
- El diseño va en un commit **antes** del código de producción.
- **Compuertas de aprobación:** marca en el plan las unidades donde el agente debe detenerse hasta que el
  usuario apruebe el diseño. Elige pocas: las que definen contratos para todos y las que concentran la
  lógica más delicada (concurrencia, reintentos, algoritmos centrales, orquestación). En el resto, el
  diseño lo revisa quien integra.
- El archivo de estado de la unidad necesita el estado `esperando aprobación de diseño`, y el protocolo de
  reanudación debe impedir escribir código mientras siga así (`references/work-state.md`).

### 3. Verificación automática en el build

Convierte en reglas de build todo lo que sea medible, para que no dependa de la buena voluntad del agente.

| Stack | Estilo y tamaño | Análisis estático | Arquitectura y dependencias |
|---|---|---|---|
| Java | Checkstyle | PMD | ArchUnit |
| Python | Ruff | mypy (estricto) | import-linter |
| TypeScript | ESLint | `tsc --strict` | dependency-cruiser |

Reglas para elegir y configurar:

- **Verifica en la web** la versión vigente de cada herramienta, de su plugin de build y su soporte para la
  versión del lenguaje del proyecto. Si un plugin de integración con el framework de pruebas puede tener
  problemas de compatibilidad, prefiere usar el núcleo de la herramienta con pruebas normales.
- **Umbrales que reflejen la skill:** longitud de método, parámetros, complejidad ciclomática y
  cognitiva, anidamiento, tamaño de clase, documentación pública obligatoria, excepciones silenciadas o
  genéricas prohibidas, salida por consola prohibida, APIs prohibidas por reglas del dominio.
- **Mensajes propios** con prefijo reconocible (`JM-LOG-01`) en las reglas por expresión regular, para
  que el agente entienda qué corregir.
- **Matriz de dependencias** derivada de los contratos del plan: qué paquete puede depender de qué, que los
  componentes paralelos no se conozcan entre sí, dónde se permite el framework y cada librería externa.
- **Valida las configuraciones antes de entregarlas**, si el entorno lo permite: ejecuta las herramientas
  sobre un ejemplo correcto (debe dar 0 violaciones, incluyendo sintaxis moderna del lenguaje) y uno
  incorrecto (debe disparar las reglas esperadas). Los ejemplos del documento de convenciones también
  deben pasar. Los nombres y propiedades de las reglas cambian entre versiones y un error de
  configuración rompe el build del agente en la primera fase.
- Los archivos de configuración quedan **congelados**; una regla que parezca mal se cambia por solicitud,
  nunca relajando el umbral desde un carril. Las supresiones puntuales requieren justificación en el
  código y registro en el diseño.
- Separa un comando de verificación sin dependencias pesadas (por ejemplo sin contenedores) para que
  todas las unidades puedan correr estilo, análisis y arquitectura.

### 4. Revisión de cierre

- **El agente**, al cerrar la unidad, escribe en su archivo de estado un **resumen de diseño** (estructura
  final, decisiones, alternativas descartadas) y responde la **lista de revisión** del documento de
  convenciones. Si se apartó del diseño, lo actualiza explicando por qué.
- **Quien integra** (usuario o integrador) confirma antes del merge: diseño presente y aprobado si
  correspondía, lista de revisión respondida y creíble, supresiones justificadas y lectura de las clases
  principales. Si algo falla, devuelve la unidad con observaciones.

## Cómo reflejarlo en cada entregable

- **`PLAN.md`:** paso de "Cómo usar" que obliga a leer el documento de convenciones y a diseñar antes de
  codificar; sección "Calidad de código" con compuertas de aprobación, matriz de dependencias, comandos de
  verificación y revisión de cierre; tareas `.0` de diseño en cada unidad con código; en la Fase 0,
  configuración de las herramientas, una prueba negativa que confirme que el build falla ante una
  violación, y las pruebas de arquitectura; criterios de verificación que incluyan "0 violaciones" y
  "arquitectura en verde"; Definición de Hecho con diseños, aprobaciones y revisiones.
- **Stack y versiones:** filas para cada herramienta de calidad con su versión verificada.
- **`AGENTS.md`:** sección de reglas de código que empiece con "lee `docs/convenciones-<stack>.md`
  completo" y un resumen numerado de lo esencial, incluyendo las compuertas de aprobación.
- **`CLAUDE.md`:** leer el documento del proyecto **aunque la skill de convenciones esté instalada**,
  porque el documento incluye umbrales y desviaciones que la skill no conoce; presentar el diseño en la
  conversación en las unidades con aprobación.
- **`README.md`:** cómo aprobar o pedir cambios a un diseño, con frases listas para copiar.
- **Archivo de estado:** estado `esperando aprobación de diseño`, secciones "Resumen de diseño" y
  "Revisión de convenciones".
- **`.zip`:** `docs/convenciones-<stack>.md`, `docs/diseno/_PLANTILLA.md` y `config/` con las
  configuraciones de las herramientas.

## Verificaciones antes de entregar

- El documento de convenciones existe, cubre las 16 secciones y declara sus desviaciones.
- Sus ejemplos y las configuraciones de las herramientas se validaron ejecutándolas, o se indica
  explícitamente que no se pudo y qué tarea de la Fase 0 lo valida.
- Todas las unidades con código tienen tarea `.0`, y las compuertas de aprobación están listadas en un
  solo lugar del plan.
- La matriz de dependencias es coherente con los contratos y con la propiedad de rutas de cada carril.
