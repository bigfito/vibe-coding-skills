#!/usr/bin/env node
/*
 * Vibe Coding Skills
 * Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
 * Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
 */
/**
 * Instalador de Vibe Coding Skills.
 *
 *   npx github:bigfito/vibe-coding-skills
 *
 * Sin dependencias externas: solo módulos nativos de Node (>=18).
 */

import { createInterface } from "node:readline/promises";
import { stdin, stdout, argv, exit, cwd } from "node:process";
import { readdir, mkdir, copyFile, stat, readFile, writeFile } from "node:fs/promises";
import { existsSync, statSync } from "node:fs";
import { join, dirname, basename, resolve, isAbsolute, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { homedir } from "node:os";

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(RAIZ, "skills");

// Carpeta donde se instalan las skills. Por defecto la actual, pero se puede
// indicar con --dir= o elegir en el menú: el paso de "ve a tu proyecto" es
// justo donde más gente se pierde.
let DESTINO = cwd();

// La carpeta personal, normalizada: $HOME puede venir con ".." o barras raras y
// entonces las comparaciones de rutas fallan sin que se note.
const CASA = resolve(homedir());

// Las carpetas de cada herramienta viven en un módulo aparte, compartido con
// bin/vibe-coding-skills.cjs para que la comprobación previa y la instalación no
// puedan decir cosas distintas.
const require_ = createRequire(import.meta.url);
const { ENTORNOS, carpetas: carpetasDe, estaInstalada, rutaLegible: rutaLegibleDe } = require_("./entornos.cjs");

/** Carpetas de una herramienta en un ámbito, con el proyecto actual. */
function carpetas(env, ambito) {
  return carpetasDe(env, ambito, DESTINO);
}

const c = {
  bold: (s) => `\x1b[1m${s}\x1b[0m`,
  dim: (s) => `\x1b[2m${s}\x1b[0m`,
  verde: (s) => `\x1b[32m${s}\x1b[0m`,
  amar: (s) => `\x1b[33m${s}\x1b[0m`,
  rojo: (s) => `\x1b[31m${s}\x1b[0m`,
};

// ---------------------------------------------------------------- argumentos

function parseArgs(args) {
  const o = { skills: null, envs: null, dir: null, ambitos: null, all: false, yes: false, dryRun: false, force: false, help: false };
  for (const a of args) {
    if (a === "--all") o.all = true;
    else if (a === "--yes" || a === "-y") o.yes = true;
    else if (a === "--dry-run") o.dryRun = true;
    else if (a === "--force") o.force = true;
    else if (a === "--help" || a === "-h") o.help = true;
    else if (a.startsWith("--skills=")) o.skills = a.slice(9).split(",").map((s) => s.trim()).filter(Boolean);
    else if (a.startsWith("--envs=")) o.envs = a.slice(7).split(",").map((s) => s.trim()).filter(Boolean);
    else if (a.startsWith("--dir=")) o.dir = a.slice(6).trim();
    else if (a === "--global") o.ambitos = [...new Set([...(o.ambitos || []), "global"])];
    else if (a === "--local" || a === "--proyecto") o.ambitos = [...new Set([...(o.ambitos || []), "proyecto"])];
    else if (a.startsWith("--scope=") || a.startsWith("--ambito=")) {
      o.ambitos = a.slice(a.indexOf("=") + 1).split(",").map((x) => x.trim())
        .map((x) => (x === "local" || x === "project" ? "proyecto" : x))
        .filter((x) => x === "global" || x === "proyecto");
    }
  }
  // El ámbito también se puede fijar por variable de entorno, porque en
  // PowerShell `irm … | iex` no admite argumentos.
  const ambitoPedido = process.env.VIBE_SKILLS_AMBITO || process.env.AGENT_SKILLS_AMBITO;
  if (!o.ambitos && ambitoPedido) {
    const pedidos = ambitoPedido.split(/[\s,]+/)
      .map((x) => (x === "local" || x === "project" ? "proyecto" : x))
      .filter((x) => x === "global" || x === "proyecto");
    if (pedidos.length) o.ambitos = [...new Set(pedidos)];
  }
  return o;
}

function ayuda() {
  console.log(`
${c.bold("Vibe Coding Skills")} — instala la suite de skills para tu asistente de IA

Una skill es un documento de instrucciones que tu asistente de IA lee antes de
responderte, para que trabaje como un especialista (arquitecto de soluciones,
gerente de proyecto, desarrollador Java o Python, experto en AWS o GCP) en vez
de con criterio genérico. Este comando copia esas skills dentro de tu proyecto,
en el formato que entiende cada herramienta: Claude Code, Cursor, Junie y
Google Antigravity.

Se pueden instalar de forma ${c.bold("global")} (en tu carpeta personal, disponibles en todos
tus proyectos) o ${c.bold("por proyecto")}. Sin menú, el ámbito por defecto es el global.

${c.bold("Uso")}
  npx github:bigfito/vibe-coding-skills            menú interactivo
  npx github:bigfito/vibe-coding-skills --all --envs=claude,cursor --yes

${c.bold("Opciones")}
  --skills=a,b     instala solo esas skills (omite el menú)
  --dir=ruta       carpeta del proyecto donde instalarlas (por defecto, la actual)
  --global         instala en la carpeta personal: sirve para todos tus proyectos
  --local          instala solo en este proyecto
  --scope=a,b      ámbitos: global, proyecto (ambos si indicas los dos)
  --envs=a,b       destinos: claude, cursor, junie, antigravity
  --all            todas las skills
  --yes, -y        no pedir confirmación
  --force          sobrescribe archivos existentes
  --dry-run        muestra qué haría, sin escribir nada
  --check          solo comprueba el entorno: no instala ni cambia nada
  --no-install     no instala requisitos del sistema: solo dice qué falta
  --version, -v    muestra la versión y termina
  --help, -h       esta ayuda

Carpeta de proyecto actual: ${c.dim(DESTINO)}
Carpeta personal:           ${c.dim(CASA)}
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

/** Ruta corta para los mensajes: relativa al proyecto, o con ~ si es personal. */
function rutaLegible(ruta) {
  return rutaLegibleDe(ruta, DESTINO);
}

async function copiarArchivo(origen, destino, ctx) {
  const rel = rutaLegible(destino) || basename(destino);
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

/** Instala una skill en un entorno y ámbito concretos. */
async function instalar(skill, env, ambito, ctx) {
  const base = join(SKILLS_DIR, skill);
  const destino = carpetas(env, ambito);

  if (env === "claude") {
    const dest = join(destino.skills, skill);
    await copiarArchivo(join(base, "SKILL.md"), join(dest, "SKILL.md"), ctx);
    for (const extra of ["references", "assets"]) {
      if (await existe(join(base, extra))) await copiarArbol(join(base, extra), join(dest, extra), ctx);
    }
    // Los subagentes viven en agents/, no dentro del skill.
    if (await existe(join(base, "agents"))) {
      for (const f of await readdir(join(base, "agents"))) {
        await copiarArchivo(join(base, "agents", f), join(destino.agentes, f), ctx);
      }
    }
    return;
  }

  const origen = join(base, "dist", env === "antigravity" ? "antigravity" : env);
  if (!(await existe(origen))) return;

  for (const f of await readdir(origen, { withFileTypes: true })) {
    if (f.isDirectory()) {
      // dist/antigravity/workflows/ va a su propia carpeta de flujos.
      if (env === "antigravity" && f.name === "workflows") {
        for (const w of await readdir(join(origen, "workflows"))) {
          await copiarArchivo(join(origen, "workflows", w), join(destino.flujos, w), ctx);
        }
      }
      continue;
    }
    await copiarArchivo(join(origen, f.name), join(destino.reglas, f.name), ctx);
  }

  // Archivos de apoyo que las reglas referencian por ruta relativa.
  for (const extra of ["references", "assets"]) {
    if (await existe(join(base, extra))) {
      await copiarArbol(join(base, extra), join(destino.reglas, skill, extra), ctx);
    }
  }
}

// ------------------------------------------------------------------- índice
//
// Junie y Antigravity leen sus guías globales de un único archivo. Copiar las
// reglas a una carpeta no basta para que las vean, así que se añade a ese
// archivo un bloque con la lista y la ruta de lo instalado. El bloque va entre
// marcas: se reescribe entero en cada instalación y nunca toca lo que el
// usuario haya escrito alrededor.

const MARCA_INICIO = "<!-- vibe-coding-skills: inicio (bloque generado, no editar) -->";
const MARCA_FIN = "<!-- vibe-coding-skills: fin -->";

// Marcas de versiones anteriores: se reconocen al reescribir el bloque, para no
// dejar dos índices en el archivo de quien ya lo tenía instalado.
const MARCAS_ANTIGUAS = [
  ["<!-- agent-skills: inicio (bloque generado, no editar) -->", "<!-- agent-skills: fin -->"],
];

/** Archivos de regla que quedaron instalados para una skill. */
async function archivosDeSkill(carpetaReglas, skill) {
  try {
    const entradas = await readdir(carpetaReglas, { withFileTypes: true });
    return entradas
      .filter((e) => e.isFile() && e.name.startsWith(skill) && /\.(md|mdc)$/.test(e.name))
      .map((e) => e.name)
      .sort();
  } catch {
    return [];
  }
}

function bloqueIndice(entradas, carpetaReglas) {
  const lineas = [
    MARCA_INICIO,
    "## Skills de Vibe Coding Skills instaladas globalmente",
    "",
    `Estas guías están en \`${carpetaReglas}\`. Cuando la tarea encaje con alguna,`,
    "lee sus archivos antes de responder:",
    "",
  ];
  for (const { skill, archivos } of entradas) {
    if (!archivos.length) continue;
    lineas.push(`- **${skill}**: ${archivos.map((a) => `\`${join(carpetaReglas, a)}\``).join(", ")}`);
  }
  lineas.push(MARCA_FIN);
  return lineas.join("\n");
}

async function escribirIndice(env, skills, ctx) {
  const e = ENTORNOS[env];
  if (!e.indice) return null;

  const archivo = e.indice();
  const carpetaReglas = carpetas(env, "global").reglas;
  const entradas = [];
  for (const skill of skills) {
    entradas.push({ skill, archivos: await archivosDeSkill(carpetaReglas, skill) });
  }
  if (!entradas.some((x) => x.archivos.length)) return null;
  const bloque = bloqueIndice(entradas, carpetaReglas);

  let contenido = "";
  if (existsSync(archivo)) contenido = await readFile(archivo, "utf8");

  // Se busca el bloque con las marcas actuales y, si no está, con las antiguas.
  let inicio = contenido.indexOf(MARCA_INICIO);
  let fin = contenido.indexOf(MARCA_FIN);
  let largoFin = MARCA_FIN.length;
  for (const [ini, fi] of MARCAS_ANTIGUAS) {
    if (inicio !== -1) break;
    inicio = contenido.indexOf(ini);
    fin = contenido.indexOf(fi);
    largoFin = fi.length;
  }

  let nuevo;
  if (inicio !== -1 && fin !== -1 && fin > inicio) {
    nuevo = contenido.slice(0, inicio) + bloque + contenido.slice(fin + largoFin);
  } else {
    nuevo = contenido.trim() ? `${contenido.trimEnd()}\n\n${bloque}\n` : `${bloque}\n`;
  }

  if (ctx.dryRun) return archivo;
  await mkdir(dirname(archivo), { recursive: true });
  await writeFile(archivo, nuevo, "utf8");
  return archivo;
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
  if (r === "~") r = CASA;
  else if (r.startsWith("~/") || r.startsWith("~\\")) r = join(CASA, r.slice(2));
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

// ----------------------------------------------------------------- ámbitos

/** Informe de qué herramientas hay en el computador y dónde iría cada cosa. */
function informarDeteccion(envs) {
  console.log(`\n${c.bold("Herramientas detectadas en este computador")}`);
  for (const e of envs) {
    const v = ENTORNOS[e];
    const marca = estaInstalada(e) ? c.verde("detectada") : c.amar("no detectada");
    console.log(`  ${v.nombre.padEnd(32)} ${marca}`);
    console.log(c.dim(`    global:   ${rutaLegible(v.baseGlobal())}`));
    console.log(c.dim(`    proyecto: ${rutaLegible(v.baseProyecto(DESTINO))}`));
  }
}

/** Pregunta el ámbito, proponiendo el global porque sirve para todo proyecto. */
async function elegirAmbitos(rl, envs) {
  const detectadas = envs.filter(estaInstalada);
  console.log(`\n${c.bold("¿Dónde quieres instalarlas?")}`);
  console.log("   1. Global — en tu carpeta personal, disponibles en todos tus proyectos");
  console.log(`   2. Solo en este proyecto — ${c.dim(DESTINO)}`);
  console.log("   3. En los dos sitios");
  if (!detectadas.length) {
    console.log(c.amar("\n  Aviso: no encontré ninguna de esas herramientas instalada."));
    console.log(c.dim("  Puedes instalar igual: las carpetas se crean y servirán cuando la instales."));
  }
  const r = (await rl.question(c.dim("\nElige 1, 2 o 3 (Enter para 1): "))).trim();
  if (r === "2") return ["proyecto"];
  if (r === "3") return ["global", "proyecto"];
  return ["global"];
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

  console.log(`\n${c.bold("Vibe Coding Skills")} ${c.dim("— instalación en " + DESTINO)}`);

  let skills, envs;
  let ambitos = args.ambitos;
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
      if (!args.dir && (!pareceProyecto(DESTINO) || DESTINO === CASA)) {
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

      // Antes de tocar nada: qué hay instalado y a qué carpetas iría.
      informarDeteccion(envs);
      if (!ambitos) ambitos = await elegirAmbitos(rl, envs);
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
    // Sin menú, el ámbito por defecto es el global: sirve para todo proyecto.
    if (!ambitos) ambitos = ["global"];
    informarDeteccion(envs);
  }

  const nombreAmbito = { global: "global (todos tus proyectos)", proyecto: `solo este proyecto (${DESTINO})` };
  console.log(`\n${c.bold("Se instalarán")}`);
  console.log(`  Skills:   ${skills.join(", ")}`);
  console.log(`  Entornos: ${envs.map((e) => ENTORNOS[e].nombre).join(", ")}`);
  console.log(`  Ámbito:   ${ambitos.map((a) => nombreAmbito[a]).join("  +  ")}`);
  for (const a of ambitos) {
    for (const e of envs) {
      const destino = carpetas(e, a);
      console.log(c.dim(`    ${ENTORNOS[e].nombre} → ${Object.values(destino).map(rutaLegible).join(", ")}`));
    }
  }
  if (args.dryRun) console.log(c.amar("  Modo simulación: no se escribirá ningún archivo."));

  if (!args.yes && !args.dryRun) {
    const rl = createInterface({ input: stdin, output: stdout });
    const r = await rl.question(c.dim("\n¿Continuar? [S/n] "));
    rl.close();
    if (r.trim().toLowerCase().startsWith("n")) { console.log("Cancelado."); return; }
  }

  const ctx = { copiados: [], omitidos: [], dryRun: args.dryRun, force: args.force };
  for (const a of ambitos) for (const s of skills) for (const e of envs) await instalar(s, e, a, ctx);

  // Las herramientas que leen sus guías globales de un solo archivo necesitan
  // que alguien les diga dónde quedaron las skills.
  const indices = [];
  if (ambitos.includes("global")) {
    for (const e of envs) {
      const archivo = await escribirIndice(e, skills, ctx);
      if (archivo) indices.push(`${ENTORNOS[e].nombre}: ${rutaLegible(archivo)}`);
    }
  }

  console.log(`\n${c.verde("✓")} ${ctx.copiados.length} archivo(s) ${args.dryRun ? "se copiarían" : "instalados"}.`);
  if (ctx.omitidos.length) {
    console.log(c.amar(`! ${ctx.omitidos.length} ya existían y no se tocaron. Usa --force para sobrescribir:`));
    for (const f of ctx.omitidos.slice(0, 8)) console.log(c.dim(`    ${f}`));
    if (ctx.omitidos.length > 8) console.log(c.dim(`    … y ${ctx.omitidos.length - 8} más`));
  }

  if (indices.length) {
    console.log(c.dim("\nSe añadió un índice de las skills instaladas en:"));
    for (const i of indices) console.log(c.dim(`    ${i}`));
  }

  if (envs.includes("claude") && skills.includes("prototype-kickoff")) {
    console.log(c.dim("\nNota: los subagentes de prototype-kickoff quedaron en la carpeta agents/."));
  }
  if (envs.includes("antigravity")) {
    console.log(c.dim("Nota: las reglas largas se instalaron divididas en partes numeradas; se leen juntas."));
  }

  // Avisos por herramienta: no todas documentan igual su carpeta global.
  if (ambitos.includes("global")) {
    for (const e of envs) {
      if (ENTORNOS[e].soporte === "parcial" && ENTORNOS[e].nota) {
        console.log(c.amar(`\n${ENTORNOS[e].nombre}: `) + c.dim(ENTORNOS[e].nota));
      }
    }
  }
  if (ambitos.includes("proyecto")) {
    console.log(c.dim("\nVersiona las carpetas del proyecto en git para que el equipo comparta el mismo comportamiento.\n"));
  } else {
    console.log("");
  }
}

main().catch((e) => {
  console.error(c.rojo("\nError: " + e.message));
  exit(1);
});
