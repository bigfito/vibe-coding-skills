#!/usr/bin/env node
/*
 * Vibe Coding Skills
 * Copyright (c) 2026 Adolfo Orozco <bigfito@gmail.com>
 * Licencia MIT: ver el archivo LICENSE en la raíz del repositorio.
 */
/*
 * Punto de entrada de Vibe Coding Skills.
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

var pre, entornos;
try {
  pre = require(path.join(__dirname, '..', 'lib', 'preflight.cjs'));
  entornos = require(path.join(__dirname, '..', 'lib', 'entornos.cjs'));
} catch (e) {
  console.error('\n  No se pudo cargar lib/preflight.cjs: ' + e.message);
  console.error('  Reinstala el paquete o clona el repositorio de nuevo.\n');
  process.exit(1);
}

var c = pre.colores;

// ------------------------------------------------------------------ opciones

/*
 * Las variables de entorno se llaman VIBE_SKILLS_*; los nombres antiguos
 * AGENT_SKILLS_* se siguen aceptando para no romper a quien ya los usaba.
 */
function variable(nombre) {
  return process.env['VIBE_SKILLS_' + nombre] || process.env['AGENT_SKILLS_' + nombre] || '';
}

function leerOpciones(args) {
  return {
    version: args.indexOf('--version') !== -1 || args.indexOf('-v') !== -1,
    check: args.indexOf('--check') !== -1 || args.indexOf('--doctor') !== -1 || variable('CHECK') === '1',
    yes: args.indexOf('--yes') !== -1 || args.indexOf('-y') !== -1 || variable('ASSUME_YES') === '1',
    noInstalar: args.indexOf('--no-install') !== -1 || variable('NO_INSTALL') === '1',
    dryRun: args.indexOf('--dry-run') !== -1,
    help: args.indexOf('--help') !== -1 || args.indexOf('-h') !== -1
  };
}

// --------------------------------------------------------------- asistentes

/*
 * La otra mitad de "¿tengo todo lo necesario?": qué asistentes hay en el
 * computador y en qué carpeta quedarían las skills de cada uno. Se lee de la
 * misma tabla que usa el instalador, para que no puedan decir cosas distintas.
 */
function informarAsistentes() {
  var claves = Object.keys(entornos.ENTORNOS);
  var alguno = false;

  console.log('  ' + c.bold('Asistentes en este computador'));
  for (var i = 0; i < claves.length; i++) {
    var clave = claves[i];
    var env = entornos.ENTORNOS[clave];
    var instalada = entornos.estaInstalada(clave);
    if (instalada) alguno = true;

    var nombre = env.nombre;
    while (nombre.length < 32) nombre += ' ';
    console.log('  ' + nombre + (instalada ? c.verde('detectado') : c.amar('no detectado')));

    // La ruta global se muestra siempre como ~/…, aunque el proyecto esté
    // dentro de la carpeta personal: si no, las dos líneas parecerían iguales.
    console.log(c.dim('    global:   ' + rutas(entornos.carpetas(clave, 'global', process.cwd()), null)));
    console.log(c.dim('    proyecto: ' + rutas(entornos.carpetas(clave, 'proyecto', process.cwd()), process.cwd())));
  }
  console.log('');
  return alguno;
}

/** Lista legible de las carpetas de destino de una herramienta. */
function rutas(carpetas, destino) {
  var salida = [];
  for (var clave in carpetas) {
    if (Object.prototype.hasOwnProperty.call(carpetas, clave)) {
      salida.push(entornos.rutaLegible(carpetas[clave], destino));
    }
  }
  return salida.join(', ');
}

// ------------------------------------------------------------------ arranque

/** La versión sale de package.json: una sola fuente para todo el proyecto. */
function version() {
  try {
    return require(path.join(__dirname, '..', 'package.json')).version;
  } catch (e) {
    return 'desconocida';
  }
}

function main() {
  var args = process.argv.slice(2);
  var o = leerOpciones(args);

  if (o.version) {
    console.log('Vibe Coding Skills v' + version());
    return;
  }

  // Modo diagnóstico: dice qué hay, qué falta y qué haría para arreglarlo,
  // pero no toca el sistema. Comprobar nunca instala.
  if (o.check) {
    console.log('');
    console.log('  ' + c.bold('Vibe Coding Skills') + ' instala skills (guías de especialista) para tu asistente de IA.');
    console.log('  ' + c.dim('Esta comprobación solo mira tu sistema: no instala ni cambia nada.'));
    var estado = pre.diagnostico();
    var hayAsistente = informarAsistentes();
    if (!estado.faltantes.length) {
      console.log('  ' + c.verde('Tu sistema tiene todo lo necesario.'));
      if (!hayAsistente) {
        console.log('  ' + c.amar('No encontré ninguno de los cuatro asistentes en este computador.'));
        console.log('  ' + c.dim('Puedes instalar las skills igual: quedarán listas para cuando instales uno.'));
      }
      console.log('  Ejecuta el comando ' + c.bold('sin') + ' ' + c.verde('--check') + ' para instalar las skills.');
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
