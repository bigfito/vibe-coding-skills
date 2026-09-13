# Índice de estado del plan

> Punto de entrada para retomar el trabajo. Lo mantiene el agente que ejecuta el plan (o el integrador si hay trabajo en paralelo). Actualízalo al empezar y al cerrar cada fase, y en el mismo commit.

## Punto de reanudación

- **Fase actual:** 0
- **Estado de la fase:** no iniciada
- **Próximo paso:** Ejecutar la Fase 0: crear `progreso/0.md` desde `_PLANTILLA.md` y empezar la tarea 0.1.
- **Última actualización:** <AAAA-MM-DD HH:MM UTC>

## Fases

| Fase | Estado | Archivo de estado | Verificación de fase |
|---|---|---|---|
| 0 | no iniciada | `progreso/0.md` | — |
| <N> | no iniciada | `progreso/<N>.md` | — |

## Solo si hay trabajo en paralelo

### Worktrees abiertos

| Carril | Carpeta | Rama | Estado según su archivo |
|---|---|---|---|

### Merge en curso

<Vacío si no hay. Rama, archivos en conflicto y resolución aplicada hasta el momento.>

### Solicitudes de cambio de contrato

| Carril | Solicitud | Decisión | Commit |
|---|---|---|---|

## Última verificación

- **Comando:** <…>
- **Resultado:** <…>
- **Fecha:** <AAAA-MM-DD HH:MM UTC>
