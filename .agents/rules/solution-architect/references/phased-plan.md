# Plan por fases (PLAN.md)

El `PLAN.md` es la **fuente única de verdad** que el agente ejecuta. Debe ser autocontenido y no
dejar decisiones importantes al azar.

## Anatomía recomendada

1. **Encabezado / cómo usar este plan** — dirigido al agente: **aplicar primero el protocolo de
   reanudación**, leer el plan, ejecutar fases en orden, no marcar tarea sin cumplir sus criterios, un
   commit por tarea con su archivo de estado, correr la verificación de fase antes de avanzar, nunca
   escribir secretos en el código.
2. **Contexto y objetivo** — qué es el sistema y qué debe lograr el prototipo/producto.
3. **Arquitectura** — el diagrama Mermaid embebido + notas de implementación.
4. **Stack y versiones** — tabla con tecnologías y **versiones concretas verificadas en la web**.
5. **Estructura del repositorio** — árbol de carpetas del monorepo.
6. **Modelo de datos** — el esquema/índice, embebido o referenciado a su archivo.
7. **Contrato de API / interfaces** — endpoints o límites entre componentes.
8. **Convenciones** — idioma, fechas (UTC), configuración por variables de entorno, secretos.
9. **Fases de desarrollo** — el corazón del plan (ver abajo).
10. **Definición de Hecho global** — checklist que cierra el proyecto.
11. **Variables de entorno** — `.env.example` con todo lo necesario (sin secretos reales).
12. **Estado del trabajo y reanudación** — archivos de `progreso/`, disciplina de actualización por
    tarea y protocolo de reanudación. Contenido detallado en `references/work-state.md`.
13. **Calidad de código** — documento de convenciones, compuertas de aprobación de diseño, matriz de
    dependencias, comandos de verificación y revisión de cierre. Contenido detallado en
    `references/coding-conventions.md`.

## Anatomía de una fase

Cada fase tiene:

- **Objetivo** en una frase.
- **Tarea `.0` de diseño** si la fase produce código: `docs/diseno/<fase>.md` con diagramas Mermaid, en
  un commit previo al código; en las fases críticas, detenerse hasta la aprobación del usuario.
- **Tareas numeradas** con checkboxes `- [ ]`, verbos de acción, **rutas de archivo** concretas y
  **comandos** cuando apliquen. Tareas claras y sencillas: una cosa bien hecha por tarea, con **id
  estable** (`2.3`) que se usa como prefijo del commit, y lo bastante pequeñas para cerrarse en una
  sola sesión de agente.
- **Verificación de fase**: un bloque de comandos y un **Criterio** objetivo y verificable
  (un comando que devuelve 0, un endpoint que responde X, un valor presente en el motor de datos).

Ejemplo de criterio verificable (bien): *"`GET /actuator/health` devuelve 200 con los componentes
gcs, whisper y elasticsearch en UP"*. Criterio vago (mal): *"el backend funciona"*.

## Secuenciación típica de fases

Adáptala al proyecto, pero suele seguir esta lógica:

- **Fase 0 — Andamiaje e infraestructura local** (estructura, build, contenedores, `.env.example`, y
  verificación de que `progreso/` existe y no está excluido de git; configuración de las herramientas de
  calidad del stack con una prueba negativa que demuestre que el build falla ante una violación, y
  pruebas de arquitectura con la matriz de dependencias).
- **Fase 1 — Persistencia** (crear esquema/índice; script idempotente).
- **Fases intermedias — Servicios y backend** (integraciones externas + health checks; luego la
  lógica: carga/ingesta, pipeline asíncrono, dominio, búsqueda).
- **Fase de frontend** (portar el prototipo de pantallas al framework, cablear a la API).
- **Fase de pruebas** (unitarias con énfasis en el backend; integración que valida conexiones con
  cada servicio externo; smoke test end-to-end; seed de datos demo).
- **Fase de documentación y cierre** (README de arranque, verificación de la Definición de Hecho).

## Buenas prácticas del plan

- **Verifica versiones en la web** antes de fijarlas; si el usuario pide una versión específica,
  respétala y anótalo, señalando brevemente cualquier riesgo de compatibilidad.
- **Salud de servicios externos**: incluye validación de conexión con cada componente externo y, si
  hay UI, un indicador de estado en el header que lea el health del backend.
- **Secretos por entorno**: nunca en el código ni en control de versiones; el usuario provee
  credenciales por `.env`, configurables desde el código.
- **Criterios de aceptación** en cada tarea/fase, siempre verificables, e incluyendo la calidad del
  código ("0 violaciones de estilo y análisis estático, pruebas de arquitectura en verde"), no solo el
  comportamiento funcional.
- **Reanudable por diseño:** el avance vive en `progreso/` y en commits por tarea, no en la memoria de la
  conversación del agente. La Definición de Hecho incluye todos los archivos de estado en `terminado`.
