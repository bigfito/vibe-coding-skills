# Rondas de descubrimiento

Cómo conducir la captura de requerimientos de forma rápida y no agotadora.

## Patrón de cada punto

Nunca preguntes "en seco". Cada punto abierto sigue esta forma:

> **[Tema] Recomendación:** <lo que propones>. **Por qué:** <razón breve>. ¿Lo confirmas o ajustas?

Esto convierte una entrevista larga en una serie de confirmaciones rápidas. El usuario puede decir
"sí" a casi todo y solo detenerse donde discrepa.

## Reglas de las rondas

- **Agrupa por tema.** No mezcles preguntas de dominios distintos en un mismo bloque.
- **Máximo ~5–7 puntos por ronda.** Si hay más, prioriza y marca cuáles "mueven más el diseño".
- **Ofrece siempre el atajo:** *"Si prefieres, di «usa tus defaults recomendados» y avanzo con lo que
  recomendé, marcando los supuestos."*
- **Una pregunta abierta real por ronda, a lo sumo.** El resto, recomendaciones a confirmar.
- **Refleja lo que ya dijo el usuario** al inicio de cada ronda, para que vea que lo incorporaste.
- **Cierra la ronda** diciendo qué desbloquea (p. ej. "con esto puedo dibujar la arquitectura").

## Temas típicos a cubrir (adáptalos al proyecto)

1. **Sujeto y propósito** — qué es, quién lo usa, cuál es el trabajo principal, si es prototipo o
   producción.
2. **Usuarios y accesos** — roles, autenticación/SSO, RBAC, o acceso abierto (para prototipos).
3. **Datos** — entidades principales, relaciones, volumen, formato de entrada, idioma, retención.
4. **Integraciones y servicios externos** — almacenamiento, colas, modelos/IA, APIs de terceros;
   cómo se autentican y si sus credenciales las provee el usuario.
5. **Procesamiento** — síncrono vs. asíncrono, orquestación, pasos del pipeline, reintentos.
6. **Persistencia y búsqueda** — motor de datos, modelo (normalizado/desnormalizado), tipo de
   consultas (exacta, full-text, vectorial, híbrida), filtros.
7. **Escala y concurrencia** — usuarios concurrentes, cargas/día, tamaños, picos.
8. **Seguridad y cumplimiento** — cifrado, auditoría, residencia de datos, cadena de custodia; o
   explícitamente fuera de alcance en fase de exploración.
9. **Stack** — lenguaje, framework, build; frontend (framework o estático); infraestructura local
   (contenedores) vs. nube.
10. **Entorno de ejecución del agente** — qué corre local vs. en la nube, qué secretos provee el
    usuario, y cómo se configuran desde el código.

## Señales para dejar de preguntar

- El usuario responde con impaciencia o pide "usa tus defaults".
- Las respuestas empiezan a repetirse o el diseño ya no cambia con nuevas respuestas.
- Ya tienes lo necesario para el siguiente artefacto: avanza y valida sobre él, no sobre más preguntas.

## Manejo de cambios de rumbo

Si el usuario cambia una decisión ya tomada (p. ej. "evita los campos anidados", "usa otra versión"),
**revalida el impacto** en los artefactos ya diseñados, di explícitamente qué ajustas y por qué, y
señala con honestidad las consecuencias (p. ej. "sin anidados, la búsqueda identifica el match por
nombre de campo, no con inner_hits"). Nunca apliques un cambio en silencio.
