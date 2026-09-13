#!/usr/bin/env node
/**
 * Instalador de la suite de skills de agente.
 *
 *   npx github:bigfito/vibe-coding-skills
 *
 * Sin dependencias externas: solo módulos nativos de Node (>=18).
 */

import { createInterface } from "node:readline/promises";
import { stdin, stdout, argv, exit, cwd } from "node:process";
import { readdir, mkdir, copyFile, stat, readFile } from "node:fs/promises";
import { existsSync, statSync } from "node:fs";
import { join, dirname, basename, resolve, isAbsolute, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(RAIZ, "skills");

// Carpeta donde se instalan las skills. Por defecto la actual, pero se puede
// indicar con --dir= o elegir en el menú: el paso de "ve a tu proyecto" es
// justo donde más gente se pierde.
let DESTINO = cwd();

const ENTORNOS = {
  claude: { nombre: "Claude Code", marca: ".claude", carpeta: ".claude/skills" },
  cursor: { nombre: "Cursor", marca: ".cursor", carpeta: ".cursor/rules" },
  junie: { nombre: "IntelliJ IDEA Ultimate (Junie)", marca: ".junie", carpeta: ".junie/rules" },
  antigravity: { nombre: "Google Antigravity", marca: ".agents", carpeta: ".agents/rules" },
};

const c = {
  bold: (s) => `\x1b[1m${s}\x1b[0m`,
  dim: (s) => `\x1b[2m${s}\x1b[0m`,
  verde: (s) => `\x1b[32m${s}\x1b[0m`,
  amar: (s) => `\x1b[33m${s}\x1b[0m`,
  rojo: (s) => `\x1b[31m${s}\x1b[0m`,
};

// ---------------------------------------------------------------- argumentos

function parseArgs(args) {
  const o = { skills: null, envs: null, dir: null, all: false, yes: false, dryRun: false, force: false, help: false };
  for (const a of args) {
    if (a === "--all") o.all = true;
    else if (a === "--yes" || a === "-y") o.yes = true;
    else if (a === "--dry-run") o.dryRun = true;
    else if (a === "--force") o.force = true;
    else if (a === "--help" || a === "-h") o.help = true;
    else if (a.startsWith("--skills=")) o.skills = a.slice(9).split(",").map((s) => s.trim()).filter(Boolean);
    else if (a.startsWith("--envs=")) o.envs = a.slice(7).split(",").map((s) => s.trim()).filter(Boolean);
    else if (a.startsWith("--dir=")) o.dir = a.slice(6).trim();
  }
  return o;
}

function ayuda() {
  console.log(`
${c.bold("agent-skills")} — instala la suite de skills en tu proyecto

Una skill es un documento de instrucciones que tu asistente de IA lee antes de
responderte, para que trabaje como un especialista (arquitecto de soluciones,
gerente de proyecto, desarrollador Java o Python, experto en AWS o GCP) en vez
de con criterio genérico. Este comando copia esas skills dentro de tu proyecto,
en el formato que entiende cada herramienta: Claude Code, Cursor, Junie y
Google Antigravity.

${c.bold("Uso")}
  npx github:bigfito/vibe-coding-skills            menú interactivo
  npx github:bigfito/vibe-coding-skills --all --envs=claude,cursor --yes

${c.bold("Opciones")}
  --skills=a,b     instala solo esas skills (omite el menú)
  --dir=ruta       carpeta del proyecto donde instalarlas (por defecto, la actual)
  --envs=a,b       destinos: claude, cursor, junie, antigravity
  --all            todas las skills
  --yes, -y        no pedir confirmación
  --force          sobrescribe archivos existentes
  --dry-run        muestra qué haría, sin escribir nada
  --check          solo comprueba el entorno: no instala ni cambia nada
  --no-install     no instala requisitos del sistema: solo dice qué falta
  --help, -h       esta ayuda

Se ejecuta sobre el directorio actual: ${c.dim(DESTINO)}
`);
}

// ---------------------------------------------------------------- utilidades

async function copiarArbol(origen, destino, ctx) {
  const entradas = await readdir(origen, { withFileTypes: true });
  for (const e of entradas) {
    const o = join(origen, e.name);
    const d = join(destino, e.name);
    if (e.isDirectory()) await copiarArbol(o, d, ctx);
    else await copiarArchivo(o, d, ctx);
  }
}

async function copiarArchivo(origen, destino, ctx) {
  const rel = relative(DESTINO, destino) || basename(destino);
  if (existsSync(destino) && !ctx.force) {
    ctx.omitidos.push(rel);
    return;
  }
  if (ctx.dryRun) {
    ctx.copiados.push(rel);
    return;
  }
  await mkdir(dirname(destino), { recursive: true });
  await copyFile(origen, destino);
  ctx.copiados.push(rel);
}

async function existe(p) {
  try { await stat(p); return true; } catch { return false; }
}

/** Instala una skill en un entorno concreto. */
async function instalar(skill, env, ctx) {
  const base = join(SKILLS_DIR, skill);

  if (env === "claude") {
    const dest = join(DESTINO, ".claude/skills", skill);
    await copiarArchivo(join(base, "SKILL.md"), join(dest, "SKILL.md"), ctx);
    for (const extra of ["references", "assets"]) {
      if (await existe(join(base, extra))) await copiarArbol(join(base, extra), join(dest, extra), ctx);
    }
    // Los subagentes viven en .claude/agents/, no dentro del skill.
    if (await existe(join(base, "agents"))) {
      for (const f of await readdir(join(base, "agents"))) {
        await copiarArchivo(join(base, "agents", f), join(DESTINO, ".claude/agents", f), ctx);
      }
    }
    return;
  }

  const mapa = {
    cursor: { dir: join(base, "dist/cursor"), dest: join(DESTINO, ".cursor/rules") },
    junie: { dir: join(base, "dist/junie"), dest: join(DESTINO, ".junie/rules") },
    antigravity: { dir: join(base, "dist/antigravity"), dest: join(DESTINO, ".agents/rules") },
  }[env];

  if (!(await existe(mapa.dir))) return;

  for (const f of await readdir(mapa.dir, { withFileTypes: true })) {
    if (f.isDirectory()) {
      // dist/antigravity/workflows/ -> .agents/workflows/
      if (env === "antigravity" && f.name === "workflows") {
        for (const w of await readdir(join(mapa.dir, "workflows"))) {
          await copiarArchivo(join(mapa.dir, "workflows", w), join(DESTINO, ".agents/workflows", w), ctx);
        }
      }
      continue;
    }
    await copiarArchivo(join(mapa.dir, f.name), join(mapa.dest, f.name), ctx);
  }

  // Archivos de apoyo que las reglas referencian por ruta relativa.
  for (const extra of ["references", "assets"]) {
    if (await existe(join(base, extra))) {
      await copiarArbol(join(base, extra), join(mapa.dest, skill, extra), ctx);
    }
  }
}

async function descripcionCorta(skill) {
  try {
    const t = await readFile(join(SKILLS_DIR, skill, "SKILL.md"), "utf8");
    const m = t.match(/^description:\s*([\s\S]*?)(?=\n[a-z_]+:|\n---)/m);
    if (!m) return "";
    const d = m[1].replace(/^>-?\s*/, "").replace(/\s+/g, " ").trim();
    const corte = d.indexOf(". ");
    return corte > 0 ? d.slice(0, corte + 1) : d.slice(0, 120);
  } catch { return ""; }
}

// ---------------------------------------------------------------- interactivo

function parseSeleccion(respuesta, total) {
  const r = respuesta.trim().toLowerCase();
  if (r === "" || r === "a" || r === "todas" || r === "all") return [...Array(total).keys()];
  const idx = new Set();
  for (const parte of r.split(/[\s,]+/).filter(Boolean)) {
    const rango = parte.match(/^(\d+)-(\d+)$/);
    if (rango) {
      for (let i = +rango[1]; i <= +rango[2]; i++) if (i >= 1 && i <= total) idx.add(i - 1);
    } else {
      const n = Number(parte);
      if (Number.isInteger(n) && n >= 1 && n <= total) idx.add(n - 1);
    }
  }
  return [...idx].sort((a, b) => a - b);
}

async function menu(rl, titulo, opciones, pista) {
  console.log(`\n${c.bold(titulo)}`);
  opciones.forEach((o, i) => console.log(`  ${String(i + 1).padStart(2)}. ${o.etiqueta}${o.nota ? c.dim("  " + o.nota) : ""}`));
  const r = await rl.question(c.dim(`\n${pista} `));
  return parseSeleccion(r, opciones.length).map((i) => opciones[i].valor);
}

// ------------------------------------------------------------------- carpeta

/*
 * Señales de que una carpeta es un proyecto. No pretende ser exhaustivo: sirve
 * para decidir si preguntar o no, y equivocarse solo cuesta una pregunta de más.
 */
const MARCAS_PROYECTO = [
  ".git", "package.json", "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle",
  "pyproject.toml", "requirements.txt", "go.mod", "Cargo.toml", "composer.json", "Gemfile",
  "CMakeLists.txt", "Makefile", "src", ".claude", ".cursor", ".junie", ".agents",
];

function pareceProyecto(dir) {
  return MARCAS_PROYECTO.some((m) => existsSync(join(dir, m)));
}

/**
 * Normaliza lo que escribe una persona: comillas de copiar y pegar, espacios
 * escapados (lo que inserta arrastrar una carpeta al terminal en macOS y
 * Linux), y el atajo ~ de la carpeta personal.
 */
function normalizarRuta(entrada) {
  let r = entrada.trim();
  if (r.length > 1 && ((r.startsWith('"') && r.endsWith('"')) || (r.startsWith("'") && r.endsWith("'")))) {
    r = r.slice(1, -1);
  }
  r = r.replace(/\\(.)/g, "$1").trim();
  if (r === "~") r = homedir();
  else if (r.startsWith("~/") || r.startsWith("~\\")) r = join(homedir(), r.slice(2));
  return isAbsolute(r) ? r : resolve(cwd(), r);
}

function esCarpeta(ruta) {
  try { return statSync(ruta).isDirectory(); } catch { return false; }
}

/**
 * Pregunta en qué carpeta instalar. Solo se pregunta cuando hace falta: si ya
 * estás dentro de un proyecto, la carpeta actual se usa sin molestar.
 */
async function elegirDestino(rl) {
  console.log(`\n${c.amar("Esta carpeta no parece un proyecto:")} ${c.dim(DESTINO)}`);
  console.log("Las skills se instalan dentro de la carpeta del proyecto en el que vas a trabajar.");

  for (let intento = 0; intento < 3; intento++) {
    console.log(c.dim("\nArrastra la carpeta de tu proyecto hasta esta ventana y pulsa Enter,"));
    console.log(c.dim("escribe su ruta, o pulsa Enter a secas para usar la carpeta actual."));
    const respuesta = await rl.question(c.dim("\nCarpeta: "));

    if (!respuesta.trim()) return DESTINO;

    const ruta = normalizarRuta(respuesta);
    if (esCarpeta(ruta)) return ruta;

    if (existsSync(ruta)) {
      console.log(c.rojo(`\n"${ruta}" existe pero no es una carpeta.`));
      continue;
    }

    const crear = await rl.question(c.dim(`\nLa carpeta "${ruta}" no existe. ¿La creo? [S/n] `));
    if (!crear.trim().toLowerCase().startsWith("n")) {
      try {
        await mkdir(ruta, { recursive: true });
        return ruta;
      } catch (e) {
        console.log(c.rojo(`\nNo se pudo crear: ${e.message}`));
      }
    }
  }

  console.log(c.amar("\nSeguimos con la carpeta actual."));
  return DESTINO;
}

// ---------------------------------------------------------------- principal

async function main() {
  const args = parseArgs(argv.slice(2));
  if (args.help) return ayuda();

  if (args.dir) {
    const ruta = normalizarRuta(args.dir);
    if (!esCarpeta(ruta)) {
      console.error(c.rojo(`\nLa carpeta indicada en --dir no existe: ${ruta}\n`));
      exit(1);
    }
    DESTINO = ruta;
  }

  const disponibles = (await readdir(SKILLS_DIR, { withFileTypes: true }))
    .filter((e) => e.isDirectory()).map((e) => e.name).sort();

  if (!disponibles.length) {
    console.error(c.rojo("No se encontraron skills en el paquete."));
    exit(1);
  }

  console.log(`\n${c.bold("agent-skills")} ${c.dim("— instalación en " + DESTINO)}`);

  let skills, envs;
  const interactivo = !args.all && !args.skills;

  if (interactivo && !stdin.isTTY) {
    console.error(c.rojo("\nNo hay terminal interactiva disponible (stdin no es un TTY)."));
    console.error("Indica qué instalar con banderas, por ejemplo:");
    console.error(c.dim("  npx github:bigfito/vibe-coding-skills --all --envs=claude,cursor --yes\n"));
    exit(1);
  }

  if (interactivo) {
    const rl = createInterface({ input: stdin, output: stdout });
    try {
      // El tropiezo más común de quien no usa terminal: ejecutar el instalador
      // sin haber entrado antes en la carpeta del proyecto.
      if (!args.dir && (!pareceProyecto(DESTINO) || DESTINO === homedir())) {
        DESTINO = await elegirDestino(rl);
        console.log(`${c.dim("Se instalará en:")} ${DESTINO}`);
      }

      const opts = [];
      for (const s of disponibles) opts.push({ etiqueta: s, nota: await descripcionCorta(s), valor: s });
      skills = await menu(rl, "¿Qué skills quieres instalar?", opts,
        "Números separados por coma (p. ej. 1,3,5-7) o Enter para todas:");
      if (!skills.length) { console.log(c.amar("\nNo se seleccionó ninguna skill.")); return; }

      const envOpts = Object.entries(ENTORNOS).map(([k, v]) => ({
        etiqueta: v.nombre,
        nota: existsSync(join(DESTINO, v.marca)) ? "(detectado en el proyecto)" : "",
        valor: k,
      }));
      envs = await menu(rl, "¿En qué entornos?", envOpts,
        "Números separados por coma o Enter para todos:");
      if (!envs.length) { console.log(c.amar("\nNo se seleccionó ningún entorno.")); return; }
    } finally {
      rl.close();
    }
  } else {
    skills = args.all ? disponibles : args.skills.filter((s) => disponibles.includes(s));
    const invalidas = (args.skills || []).filter((s) => !disponibles.includes(s));
    if (invalidas.length) console.log(c.amar(`Skills desconocidas, se omiten: ${invalidas.join(", ")}`));
    if (!skills.length) { console.error(c.rojo("No hay skills válidas que instalar.")); exit(1); }
    envs = (args.envs || Object.keys(ENTORNOS)).filter((e) => e in ENTORNOS);
    if (!envs.length) { console.error(c.rojo("No hay entornos válidos.")); exit(1); }
  }

  console.log(`\n${c.bold("Se instalarán")}`);
  console.log(`  Skills:   ${skills.join(", ")}`);
  console.log(`  Entornos: ${envs.map((e) => ENTORNOS[e].nombre).join(", ")}`);
  if (args.dryRun) console.log(c.amar("  Modo simulación: no se escribirá ningún archivo."));

  if (!args.yes && !args.dryRun) {
    const rl = createInterface({ input: stdin, output: stdout });
    const r = await rl.question(c.dim("\n¿Continuar? [S/n] "));
    rl.close();
    if (r.trim().toLowerCase().startsWith("n")) { console.log("Cancelado."); return; }
  }

  const ctx = { copiados: [], omitidos: [], dryRun: args.dryRun, force: args.force };
  for (const s of skills) for (const e of envs) await instalar(s, e, ctx);

  console.log(`\n${c.verde("✓")} ${ctx.copiados.length} archivo(s) ${args.dryRun ? "se copiarían" : "instalados"}.`);
  if (ctx.omitidos.length) {
    console.log(c.amar(`! ${ctx.omitidos.length} ya existían y no se tocaron. Usa --force para sobrescribir:`));
    for (const f of ctx.omitidos.slice(0, 8)) console.log(c.dim(`    ${f}`));
    if (ctx.omitidos.length > 8) console.log(c.dim(`    … y ${ctx.omitidos.length - 8} más`));
  }

  if (envs.includes("claude") && skills.includes("prototype-kickoff")) {
    console.log(c.dim("\nNota: los subagentes de prototype-kickoff quedaron en .claude/agents/."));
  }
  if (envs.includes("antigravity")) {
    console.log(c.dim("Nota: las reglas largas se instalaron divididas en partes numeradas; se leen juntas."));
  }
  console.log(c.dim("Versiona estas carpetas en git para que el equipo comparta el mismo comportamiento.\n"));
}

main().catch((e) => {
  console.error(c.rojo("\nError: " + e.message));
  exit(1);
});
