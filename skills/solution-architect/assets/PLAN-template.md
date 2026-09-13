# PLAN DE DESARROLLO — <Nombre del sistema>

> **Propósito.** Fuente única de verdad para construir <el prototipo/producto> de <qué es>.
> Escrito para ser **ejecutado por un agente de IA** (Claude Code, Google Antigravity, Genie).
>
> **Cómo usar este plan (para el agente).**
> 1. **Al iniciar cualquier sesión, aplica el protocolo de reanudación** (sección "Estado del trabajo y reanudación"): el trabajo pudo interrumpirse a mitad de una tarea.
> 2. Lee `AGENTS.md` (o `CLAUDE.md` en Claude Code) y `docs/convenciones-<stack>.md` antes de tocar código.
> 3. **Diseña antes de codificar:** cada fase con código empieza por su tarea `.0` (`docs/diseno/<fase>.md`). En las fases marcadas con aprobación, detente hasta que el usuario apruebe el diseño.
> 4. Ejecuta las **fases en orden** (Fase 0 → Fase N). No adelantes fases.
> 5. Cada tarea tiene ruta, comando y **criterio de aceptación**. No la marques hecha si el criterio no pasa.
> 6. **Un commit por tarea terminada**, con el código y `progreso/<fase>.md` actualizado. Nunca empieces una tarea con cambios sin commit.
> 7. Al terminar una fase, corre su **"Verificación de fase"**; no continúes si falla.
> 8. Nunca escribas secretos en el código. Todo secreto va por `.env`.

## 1. Contexto y objetivo
<Qué es, quién lo usa, qué debe lograr.>

## 2. Arquitectura
```mermaid
<diagrama flowchart>
```
<Notas de implementación.>

## 3. Stack y versiones
| Componente | Tecnología | Versión (verificada) |
|---|---|---|
| … | … | … |
| Estilo | <Checkstyle, Ruff, ESLint…> | … |
| Análisis estático | <PMD, mypy, tsc estricto…> | … |
| Arquitectura | <ArchUnit, import-linter, dependency-cruiser…> | … |

<Zona horaria: UTC. Convenciones de nomenclatura/paquetes si aplica.>

## 4. Estructura del repositorio
```
<árbol de carpetas>
```

## 5. Contrato de API / interfaces
<Endpoints o límites entre componentes.>

## 6. Modelo de datos
<Esquema/DDL/mapping embebido o referenciado a su archivo.>

## 7. Convenciones
<Idioma, fechas UTC, configuración por entorno, secretos.>

## 8. Calidad de código

**Convenciones.** `docs/convenciones-<stack>.md` es obligatorio y manda sobre las preferencias por defecto de cualquier herramienta. <Origen: skill de convenciones aplicada al proyecto.>

**Diseño antes de codificar.** Cada fase con código empieza por su tarea `.0`. Requieren aprobación del usuario: <lista de fases críticas y motivo>.

**Matriz de dependencias.**
| Paquete o módulo | Puede depender de |
|---|---|
| … | … |

**Verificación automática.**
| Comando | Qué ejecuta |
|---|---|
| <comando rápido> | Pruebas unitarias y de arquitectura |
| <comando completo sin contenedores> | Lo anterior más estilo y análisis estático |
| <comando completo> | Todo, incluidas pruebas de integración |

**Cierre de fase.** Resumen de diseño y revisión de convenciones en `progreso/<fase>.md`; quien integra la confirma.

## 9. Estado del trabajo y reanudación

**Archivos.** `progreso/INDICE.md` (fase actual y próximo paso global) y `progreso/<fase>.md`, creado desde `progreso/_PLANTILLA.md` al empezar cada fase. Se versionan en git. <Si la aplicación tiene su propia carpeta de estado, aclara aquí la diferencia.>

**Disciplina por tarea.**
1. Al empezar: marca la tarea `en curso` y escribe el **próximo paso** como una acción concreta.
2. Durante: actualiza subpaso y cambios sin commit tras cada archivo terminado y antes de comandos largos.
3. Al pasar el criterio: márcala `terminada` con evidencia y haz un commit `<id>: <resumen>` con el código y el archivo de estado.
4. Nunca empieces una tarea con cambios sin commit de la anterior. Si te bloqueas: estado `bloqueado`, commit y detente.

**Protocolo de reanudación.**
1. Rama y carpeta → modo y fase.
2. Lee `progreso/INDICE.md` y `progreso/<fase>.md`.
3. `git status` y `git log --oneline -10`.
4. Contrasta: cambios sin commit registrados → continúa; no registrados → no los descartes, pregunta; commits no reflejados → actualiza el archivo desde los mensajes de commit.
5. Compila y corre las pruebas de la tarea actual.
6. Registra la reanudación en "Decisiones" y continúa desde el próximo paso.

---

## FASES

### FASE 0 — <Andamiaje e infraestructura>
**Objetivo:** <una frase.>
- [ ] **0.1** Crea `progreso/0.md` desde `progreso/_PLANTILLA.md` y confirma que `.gitignore` no excluye `progreso/`.
- [ ] **0.2** Configura las herramientas de calidad con los archivos de `config/` y agrega las pruebas de arquitectura de la sección 8.
- [ ] **0.3** <tarea con ruta/comando>
- [ ] **0.4** …
**Verificación de fase 0:**
```bash
<comandos, incluido el de verificación de calidad>
<prueba negativa: introducir una violación, confirmar que el build falla y revertir>
```
Criterio: <verificable objetivamente, incluida la prueba negativa>.

### FASE 1 — <…>
**Objetivo:** <una frase.>
- [ ] **1.0** Diseño: crea `docs/diseno/1.md` desde `docs/diseno/_PLANTILLA.md`; commit antes del código<; detente hasta la aprobación del usuario si esta fase la requiere>.
- [ ] **1.1** …
**Verificación de fase 1:**
```bash
<comandos funcionales>
<comando de verificación de calidad>
```
Criterio: <funcional>; 0 violaciones de estilo y análisis estático; pruebas de arquitectura en verde; resumen de diseño y revisión de convenciones completos.

---

## Definición de Hecho (global)
- [ ] <checklist que cierra el proyecto>
- [ ] Todos los archivos de `progreso/` en estado `terminado`, sin cambios sin commit, e `INDICE.md` con todas las fases cerradas.
- [ ] 0 violaciones de estilo y análisis estático; pruebas de arquitectura en verde; supresiones justificadas.
- [ ] Cada fase con código tiene su diseño (aprobado cuando correspondía), su resumen de diseño y su revisión de convenciones.

## Variables de entorno (`.env.example`)
```dotenv
<claves sin valores reales>
```
