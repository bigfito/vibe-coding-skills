/*
 * Vibe Coding Skills
 * Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
 * Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
 */
/*
 * entornos.cjs — dónde vive cada herramienta.
 *
 * Una sola tabla con las carpetas de Claude Code, Cursor, Junie y Antigravity,
 * en sus dos ámbitos, y cómo detectar si están instaladas. Vive aquí, en
 * CommonJS, para que la usen tanto el instalador (lib/install.mjs, módulo ES)
 * como el punto de entrada (bin/vibe-coding-skills.cjs, que tiene que poder
 * ejecutarse en versiones antiguas de Node).
 */

'use strict';

const { join, resolve } = require('node:path');
const { existsSync } = require('node:fs');
const { homedir } = require('node:os');
const { execSync } = require('node:child_process');

// La carpeta personal, normalizada: $HOME puede venir con ".." o barras raras y
// entonces las comparaciones de rutas fallan sin que se note.
const CASA = resolve(homedir());

/*
 * Cada herramienta se puede instalar en dos ámbitos:
 *
 *   global   — en la carpeta personal, disponible en TODOS los proyectos.
 *   proyecto — dentro de la carpeta del proyecto, solo para él.
 *
 * `soporte` dice cuánto respaldo tiene la ruta global en la documentación
 * oficial de cada herramienta, porque no todas la documentan igual:
 *
 *   documentado — la herramienta documenta esa carpeta como ámbito personal.
 *   parcial     — la carpeta funciona o se usa en la comunidad, pero la vía
 *                 oficial es otra; en ese caso se avisa y, cuando la
 *                 herramienta lee un archivo de guías global, se añade allí un
 *                 índice con las skills instaladas.
 */
const ENTORNOS = {
  claude: {
    nombre: "Claude Code",
    marca: ".claude",
    soporte: "documentado",
    comando: "claude",
    // Claude Code documenta ~/.claude/skills y ~/.claude/agents como el ámbito
    // personal, disponible en todas las sesiones de la máquina.
    baseGlobal: () => process.env.CLAUDE_CONFIG_DIR || join(CASA, ".claude"),
    baseProyecto: (destino) => join(destino, ".claude"),
    pistas: () => [join(CASA, ".claude"), join(CASA, ".claude.json")],
  },
  cursor: {
    nombre: "Cursor",
    marca: ".cursor",
    soporte: "parcial",
    nota: "Cursor documenta las reglas globales como User Rules (Ajustes → Rules). Las versiones que leen ~/.cursor/rules las tomarán de ahí; si la tuya no lo hace, copia el contenido en Ajustes.",
    baseGlobal: () => join(CASA, ".cursor"),
    baseProyecto: (destino) => join(destino, ".cursor"),
    pistas: () => [
      join(CASA, ".cursor"),
      "/Applications/Cursor.app",
      join(CASA, "Library/Application Support/Cursor"),
      join(CASA, ".config/Cursor"),
      join(process.env.LOCALAPPDATA || "", "Programs/cursor"),
      join(process.env.APPDATA || "", "Cursor"),
    ],
  },
  junie: {
    nombre: "IntelliJ IDEA Ultimate (Junie)",
    marca: ".junie",
    soporte: "parcial",
    nota: "Junie documenta ~/.junie/AGENTS.md como guía global; las reglas se copian en ~/.junie/rules y se añade allí un índice que las señala.",
    indice: () => join(CASA, ".junie", "AGENTS.md"),
    baseGlobal: () => join(CASA, ".junie"),
    baseProyecto: (destino) => join(destino, ".junie"),
    pistas: () => [
      join(CASA, ".junie"),
      join(CASA, "Library/Application Support/JetBrains"),
      join(CASA, ".config/JetBrains"),
      join(process.env.APPDATA || "", "JetBrains"),
    ],
  },
  antigravity: {
    nombre: "Google Antigravity",
    marca: ".agents",
    soporte: "parcial",
    nota: "Antigravity lee las reglas globales de ~/.gemini/AGENTS.md; las reglas se copian en ~/.gemini/antigravity y se añade allí un índice que las señala.",
    indice: () => join(CASA, ".gemini", "AGENTS.md"),
    baseGlobal: () => join(CASA, ".gemini", "antigravity"),
    baseProyecto: (destino) => join(destino, ".agents"),
    pistas: () => [
      join(CASA, ".gemini"),
      join(CASA, ".antigravity"),
      "/Applications/Antigravity.app",
      join(CASA, ".config/Antigravity"),
      join(process.env.APPDATA || "", "Antigravity"),
      join(process.env.LOCALAPPDATA || "", "Programs/Antigravity"),
    ],
  },
};

/*
 * Carpetas concretas de cada herramienta según el ámbito. La forma es la misma
 * en los dos: cambia la base (la carpeta personal o la del proyecto).
 */
function carpetas(env, ambito, destino) {
  const e = ENTORNOS[env];
  const base = ambito === "global" ? e.baseGlobal() : e.baseProyecto(destino);
  if (env === "claude") return { skills: join(base, "skills"), agentes: join(base, "agents") };
  if (env === "cursor" || env === "junie") return { reglas: join(base, "rules") };
  // Antigravity separa reglas y flujos; en global los flujos van aparte.
  return {
    reglas: join(base, "rules"),
    flujos: ambito === "global" ? join(base, "global_workflows") : join(base, "workflows"),
  };
}

/** ¿Existe este ejecutable en el PATH? */
function hayEnPath(cmd) {
  if (!/^[A-Za-z0-9_.+-]+$/.test(cmd)) return false;
  try {
    execSync((process.platform === 'win32' ? 'where ' : 'command -v ') + cmd, { stdio: 'ignore', shell: true });
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * ¿Hay rastro de que esta herramienta esté instalada en el computador?
 * Se mira su carpeta de configuración, su aplicación y, si lo tiene, su
 * comando: Claude Code puede estar instalado sin haber creado aún ~/.claude.
 */
function estaInstalada(env) {
  const e = ENTORNOS[env];
  if (e.pistas().some((p) => p && existsSync(p))) return true;
  return !!(e.comando && hayEnPath(e.comando));
}


/** Ruta corta para los mensajes: relativa al proyecto, o con ~ si es personal. */
function rutaLegible(ruta, destino) {
  if (destino && (ruta.startsWith(destino + "/") || ruta.startsWith(destino + "\\"))) {
    return ruta.slice(destino.length + 1);
  }
  if (ruta.startsWith(CASA)) return "~" + ruta.slice(CASA.length);
  return ruta;
}

module.exports = { CASA, ENTORNOS, carpetas, estaInstalada, hayEnPath, rutaLegible };
