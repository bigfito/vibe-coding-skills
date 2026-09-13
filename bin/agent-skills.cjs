#!/usr/bin/env node
/*
 * Punto de entrada de agent-skills.
 *
 * Este archivo se mantiene deliberadamente en CommonJS y con sintaxis antigua
 * (sin arrow functions, sin optional chaining, sin import estático) para que
 * pueda PARSEARSE y EJECUTARSE incluso en versiones muy viejas de Node. Si el
 * entorno no cumple los requisitos, su trabajo es detectar el sistema, ofrecer
 * instalar lo que falte y, solo con tu permiso, instalarlo; nunca romperse con
 * un error incomprensible.
 *
 * Cuando el entorno es válido carga lib/install.mjs, que ya usa sintaxis
 * moderna.
 */

'use strict';

var path = require('path');

var pre;
try {
  pre = require(path.join(__dirname, '..', 'lib', 'preflight.cjs'));
} catch (e) {
  console.error('\n  No se pudo cargar lib/preflight.cjs: ' + e.message);
  console.error('  Reinstala el paquete o clona el repositorio de nuevo.\n');
  process.exit(1);
}

var c = pre.colores;

// ------------------------------------------------------------------ opciones

function leerOpciones(args) {
  return {
    check: args.indexOf('--check') !== -1 || args.indexOf('--doctor') !== -1,
    yes: args.indexOf('--yes') !== -1 || args.indexOf('-y') !== -1 || process.env.AGENT_SKILLS_ASSUME_YES === '1',
    noInstalar: args.indexOf('--no-install') !== -1 || process.env.AGENT_SKILLS_NO_INSTALL === '1',
    dryRun: args.indexOf('--dry-run') !== -1,
    help: args.indexOf('--help') !== -1 || args.indexOf('-h') !== -1
  };
}

// ------------------------------------------------------------------ arranque

function main() {
  var args = process.argv.slice(2);
  var o = leerOpciones(args);

  // Modo diagnóstico: dice qué hay, qué falta y qué haría para arreglarlo,
  // pero no toca el sistema. Comprobar nunca instala.
  if (o.check) {
    console.log('');
    console.log('  ' + c.bold('agent-skills') + ' instala skills (guías de especialista) para tu asistente de IA.');
    console.log('  ' + c.dim('Esta comprobación solo mira tu sistema: no instala ni cambia nada.'));
    var estado = pre.diagnostico();
    if (!estado.faltantes.length) {
      console.log('  ' + c.verde('Todo listo.') + ' Ejecuta el comando sin --check para instalar las skills.');
      console.log('');
      return;
    }
    pre.asegurarRequisitos({ soloComprobar: true, silencioso: true });
    process.exit(1);
  }

  // La ayuda no necesita entorno completo: siempre se puede leer.
  if (!o.help) {
    // En simulación se informa de lo que falta, pero no se bloquea ni se instala.
    var completo = pre.asegurarRequisitos({
      yes: o.yes,
      noInstalar: o.noInstalar,
      dryRun: o.dryRun,
      silencioso: true
    });
    if (!completo && !o.dryRun) process.exit(1);
  }

  // Carga diferida del instalador moderno. Se usa eval para que el import()
  // dinámico no se parsee en versiones de Node que no lo soportan: así el
  // mensaje de arriba llega a mostrarse en lugar de un SyntaxError.
  var ruta = path.join(__dirname, '..', 'lib', 'install.mjs');
  var url = require('url').pathToFileURL(ruta).href;
  var cargar;
  try {
    cargar = eval('(function (u) { return import(u); })');
  } catch (e) {
    console.error(c.rojo('\n  Tu versión de Node no admite módulos ES. Actualiza a Node ' + pre.NODE_MINIMO + ' o superior.\n'));
    process.exit(1);
  }
  cargar(url).catch(function (e) {
    console.error(c.rojo('\n  Error al iniciar el instalador: ' + e.message + '\n'));
    process.exit(1);
  });
}

main();
