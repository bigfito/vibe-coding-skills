# Diseño de artefactos

Construye los artefactos en este orden y **valida cada uno antes de pasar al siguiente**. Cada
artefacto debe terminar en la **ruta que el `PLAN.md` espera**, para que el agente lo encuentre.

## 1. Diagrama de arquitectura (Mermaid → Lucidchart)

- Escribe el diagrama en **Mermaid** (`flowchart`), porque es texto, versionable, e **importable en
  Lucidchart** (y en la mayoría de herramientas). Guárdalo como `docs/arquitectura.mermaid`.
- Representa: clientes, capa web/BFF, servicios, colas, workers, almacenamiento, motor de datos, y
  servicios externos. Usa `subgraph` para segmentar (p. ej. red local vs. nube).
- Distingue con líneas punteadas las **respuestas/lecturas asíncronas** de las acciones.
- Numera los pasos del flujo principal (1, 2, 3…) y explícalos en prosa debajo.
- Valida el balance del diagrama antes de entregarlo: cada `subgraph` tiene su `end`.
- Evita caracteres que rompan el render (acentos en identificadores de nodo); ponlos solo en las
  etiquetas entre comillas.

## 2. Modelo de datos

- Parte de las entidades y relaciones que capturaste. Decide **normalizado vs. desnormalizado** según
  el patrón de acceso (las búsquedas mandan sobre la forma).
- Si el destino es un **motor concreto** (Elasticsearch, Postgres, BigQuery, etc.), entrega el
  **esquema/DDL/mapping** listo, en su archivo (p. ej. `elasticsearch/index/<indice>-mapping.json`).
- Explica las decisiones clave: por qué desnormalizas, qué campos son filtros, qué es exacto
  (`keyword`) vs. analizado (full-text), tipos de vector y su cuantización, formato de fechas (UTC).
- Respeta las restricciones del usuario aunque impliquen un trade-off; nómbralo con honestidad.

## 3. Diseño de pantallas (si hay frontend)

- Apóyate en la skill **`frontend-design`** para la dirección visual: fija un pequeño sistema de
  tokens (paleta con 4–6 hex, tipografías por rol, layout, y **un elemento distintivo** anclado al
  sujeto). Evita los "defaults de IA" genéricos.
- Prototipa las pantallas como un **HTML navegable, autocontenido** (CSS/JS en el mismo archivo,
  datos de demostración en memoria, responsive, foco de teclado, `prefers-reduced-motion`).
  Guárdalo en `design/`.
- El `PLAN.md` debe exigir que el frontend real **reproduzca fielmente** ese prototipo (misma paleta,
  tipografía, componentes y comportamiento), no que lo rediseñe.
- Verifica el HTML/JS antes de entregar (sintaxis válida, vistas presentes).

## Regla transversal

Presenta cada artefacto, resume las **decisiones clave** (no el detalle exhaustivo), y pregunta si lo
confirma. Si el usuario ajusta algo, revalida el impacto en los artefactos anteriores.
