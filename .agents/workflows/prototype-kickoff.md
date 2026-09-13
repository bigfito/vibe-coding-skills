# /prototype-kickoff

Ejecuta el método completo de `prototype-kickoff` sobre lo que el usuario acaba de pedir.

Las reglas de `.agents/rules/prototype-kickoff*.md` aportan el criterio; este flujo aporta la secuencia. Sigue el flujo de trabajo descrito en esas reglas paso a paso, **validando con el usuario antes de avanzar de un paso al siguiente**, y deja cada artefacto escrito en el repositorio en lugar de solo en la conversación.

Si las reglas no están cargadas en el workspace, dilo antes de empezar y pide que se instalen: sin ellas este flujo no tiene el criterio que lo hace útil.
