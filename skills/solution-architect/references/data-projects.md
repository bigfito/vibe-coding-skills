# Sección especializada: proyectos de datos

Aplica cuando el sistema sea de **data engineering, pipelines de ingesta, o búsqueda
vectorial/semántica**. Complementa (no reemplaza) el flujo general de la skill.

## Preguntas de descubrimiento específicas

- **Fuentes y modalidades:** ¿qué entra (texto, tablas, imágenes, audio, video, logs)? ¿formatos,
  tamaños, idioma? ¿alta demanda/concurrencia?
- **Ingesta y transformación:** ¿carga directa o mediada por backend? ¿transcripción (audio/video→
  texto)? ¿OCR/caption de imágenes? ¿extracción de tablas?
- **Embeddings:** ¿se generan dentro del motor (inference/ELSER) o en un servicio aparte? ¿modelo
  denso, disperso o híbrido? ¿multilingüe? ¿dimensiones y cuantización?
- **Persistencia y búsqueda:** ¿motor (Elasticsearch, OpenSearch, pgvector, etc.)? ¿modelo
  normalizado o desnormalizado? ¿búsqueda exacta, full-text, vectorial (kNN), o **híbrida**?
  ¿qué filtros de refinamiento salen del modelo de datos?
- **Orquestación:** ¿cola de mensajes + workers, o motor de workflow? ¿batch o por-evento?
  ¿reintentos y control de concurrencia en las actualizaciones?

## Decisiones de diseño recurrentes

- **Desnormalización guiada por la búsqueda.** La forma del documento sigue el patrón de consulta.
  Si el usuario prohíbe estructuras anidadas, usa campos planos y explica el trade-off (el match se
  identifica por nombre de campo, no con inner_hits).
- **Embeddings externos vs. internos.** Si un servicio propio genera los vectores (p. ej. un
  contenedor con un modelo multimodal), el motor solo almacena e indexa; no necesitas su inference
  API. Deja claro quién normaliza el vector y quién lo cuantiza (a menudo el motor, vía índice).
- **Búsqueda híbrida.** Combina léxico (BM25) y vectorial (kNN), típicamente fusionados con **RRF**,
  más filtros por atributos del modelo. La "semántica pura" es solo kNN. Ambos, con lo que ofrezca
  el motor de forma nativa.
- **Pipeline asíncrono.** Carga → (transcribir) → (embeber) → subir binario a almacenamiento →
  indexar. Cola de mensajes + **workers stateless autoescalables**. Para actualizar el mismo
  documento desde varios workers, usa **control de concurrencia optimista** (update con reintento).
- **Idioma.** Si la entrada es en un idioma concreto, configura el analizador del motor (stemming,
  stopwords, `asciifolding` para acentos) y el idioma del transcriptor; usa modelos de embeddings
  multilingües.
- **Fechas en UTC** en todo el sistema.

## Consideraciones para las fases del plan

- Fase temprana para **crear el índice/esquema** con un script idempotente.
- Servicios de modelos (transcripción, embeddings) como contenedores con endpoint REST, invocados por
  el backend/workers, con su propio health check.
- Validación de conexión con **cada** componente externo (almacenamiento, servicios de modelos, motor
  de datos) y, si hay UI, indicador de estado en el header.
- Pruebas de integración que ejerciten realmente esas conexiones cuando existan credenciales.
