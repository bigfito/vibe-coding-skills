# AGENTS.md — Convenciones para agentes de IA

> Lo leen agentes como **Google Antigravity** y **Genie (IntelliJ IDEA)**. Para **Claude Code**, ver
> `CLAUDE.md`. La **secuencia de trabajo** vive en **`PLAN.md`** — síguelo por fases.

## Primero: protocolo de reanudación
El trabajo pudo haberse interrumpido a mitad de una tarea (sin tokens, contexto lleno, herramienta cerrada). **Al iniciar cualquier sesión, antes de escribir código:**
1. Revisa rama y carpeta para saber tu fase.
2. Lee `progreso/INDICE.md` y `progreso/<fase>.md` (créalo desde `_PLANTILLA.md` si no existe).
3. Ejecuta `git status` y `git log --oneline -10`.
4. Si hay cambios sin commit que el archivo de estado no registra, **no los descartes**: descríbelos y pregunta.
5. Compila y corre las pruebas de la tarea actual.
6. Anota la reanudación en "Decisiones" y continúa desde el **próximo paso**.

## Disciplina de estado
- Al empezar una tarea: márcala `en curso` y escribe el próximo paso como acción concreta.
- Durante: actualiza subpaso y cambios sin commit tras cada archivo y antes de comandos largos.
- Al terminar: márcala `terminada` con evidencia y haz un commit con el código y el archivo de estado (`<id>: <resumen>`).
- Nunca empieces una tarea con cambios sin commit de la anterior.

## Qué es este proyecto
<Resumen de una o dos líneas: dominio, stack, componentes.>

## Regla de oro sobre el orden de trabajo
1. Lee `PLAN.md` completo antes de tocar código.
2. Ejecuta **Fase 0 → Fase N en orden**. No marques una tarea hecha sin cumplir sus criterios.
3. Al terminar cada fase corre su **"Verificación de fase"**; corrige antes de seguir si falla.

## Comandos
```bash
<build>
<tests>
<levantar entorno>
<crear esquema/índice>
<seed>
<smoke test>
```

## Estructura del repo
<Módulos/carpetas y su propósito. Coordenadas/paquetes si aplica.>
- `progreso/` — estado del trabajo para retomar sesiones (versionado; no confundir con carpetas de estado de la aplicación).

## Reglas de código
**Lee `docs/convenciones-<stack>.md` completo antes de escribir código**; manda sobre las preferencias por defecto de tu herramienta. Resumen de lo esencial:
1. Diseña antes de codificar: tarea `.0` con `docs/diseno/<fase>.md`; en <fases con aprobación>, detente hasta que el usuario lo apruebe.
2. <Principios y umbrales de estilo. Si es Java/Spring: estilo JavaMentor — Java moderno con mesura, SOLID, métodos cortos, nombres intuitivos, excepciones con códigos significativos, logging SLF4J, Javadoc en API pública; Maven para dependencias.>
3. <Patrones permitidos y reglas del framework.>
4. <Errores, logging y documentación.>
5. Verificación automática: <comando>; no relajes umbrales de `config/`; toda supresión se justifica y se registra en el diseño.
6. Al cerrar la fase: resumen de diseño y revisión de convenciones en tu archivo de estado.

## Reglas del dominio
<Estados, límites, formatos (fechas UTC), idioma de la UI y mensajes.>

## Seguridad y secretos
- <Autenticación o acceso abierto (si es prototipo, decláralo intencional).>
- **Nunca** escribas secretos en el código ni los subas a control de versiones. Todo por `.env`.
- `.gitignore` excluye `.env`, credenciales y directorios de trabajo/staging.

## Definición de Hecho
Ver la sección correspondiente de `PLAN.md`. El proyecto no está terminado hasta que todo pase.
