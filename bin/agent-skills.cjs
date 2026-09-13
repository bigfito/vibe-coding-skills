#!/usr/bin/env node
/*
 * Punto de entrada de agent-skills.
 *
 * Este archivo se mantiene deliberadamente en CommonJS y con sintaxis antigua
 * (sin arrow functions, sin optional chaining, sin import estático) para que
 * pueda PARSEARSE y EJECUTARSE incluso en versiones muy viejas de Node. Si el
 * entorno no cumple los requisitos, su trabajo es explicar con exactitud qué
 * instalar según el sistema operativo, en lugar de romperse con un error
 * incomprensible.
 *
 * Solo cuando el entorno es válido carga lib/install.mjs, que ya usa sintaxis
 * moderna.
 */

'use strict';

var NODE_MINIMO = 18;

var os = require('os');
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

// ------------------------------------------------------------------ colores

var tty = process.stdout && process.stdout.isTTY;
function col(codigo, texto) { return tty ? '\u001b[' + codigo + 'm' + texto + '\u001b[0m' : texto; }
function bold(t) { return col('1', t); }
function dim(t) { return col('2', t); }
function rojo(t) { return col('31', t); }
function verde(t) { return col('32', t); }
function amar(t) { return col('33', t); }

// ------------------------------------------------- detección de plataforma

/** Devuelve un identificador de plataforma y, en Linux, la familia de distro. */
function detectarPlataforma() {
  var p = process.platform;
  if (p === 'darwin') return { so: 'macos', etiqueta: 'macOS' };
  if (p === 'win32') return { so: 'windows', etiqueta: 'Windows' };
  if (p === 'linux') {
    var wsl = false;
    try {
      var rel = fs.readFileSync('/proc/version', 'utf8').toLowerCase();
      wsl = rel.indexOf('microsoft') !== -1;
    } catch (e) {}
    var id = '', idLike = '';
    try {
      var osRelease = fs.readFileSync('/etc/os-release', 'utf8');
      var mId = osRelease.match(/^ID=("?)([^"\n]+)\1/m);
      var mLike = osRelease.match(/^ID_LIKE=("?)([^"\n]+)\1/m);
      if (mId) id = mId[2];
      if (mLike) idLike = mLike[2];
    } catch (e) {}
    var familia = 'desconocida';
    var todo = (id + ' ' + idLike).toLowerCase();
    if (/debian|ubuntu|mint|pop/.test(todo)) familia = 'debian';
    else if (/fedora|rhel|centos|rocky|alma/.test(todo)) familia = 'fedora';
    else if (/arch|manjaro/.test(todo)) familia = 'arch';
    else if (/alpine/.test(todo)) familia = 'alpine';
    else if (/suse/.test(todo)) familia = 'suse';
    return { so: 'linux', familia: familia, wsl: wsl, etiqueta: wsl ? 'WSL (Linux sobre Windows)' : 'Linux' };
  }
  return { so: 'otro', etiqueta: process.platform };
}

/** ¿Existe este ejecutable en el PATH? */
function hayComando(cmd) {
  var probar = process.platform === 'win32' ? 'where' : 'command -v';
  try {
    cp.execSync(probar + ' ' + cmd, { stdio: 'ignore', shell: true });
    return true;
  } catch (e) {
    return false;
  }
}

// ------------------------------------------------------------ instrucciones

/** Instrucciones de instalación de Node.js según el sistema operativo. */
function instruccionesNode(plat) {
  var lineas = [];
  if (plat.so === 'macos') {
    if (hayComando('brew')) {
      lineas.push(['Homebrew (ya lo tienes instalado)', 'brew install node']);
    } else {
      lineas.push(['Homebrew (recomendado)', '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n     brew install node']);
    }
    lineas.push(['Instalador oficial', 'Descarga el .pkg de la versión LTS desde https://nodejs.org/es/download']);
  } else if (plat.so === 'windows') {
    if (hayComando('winget')) {
      lineas.push(['winget (ya lo tienes instalado)', 'winget install OpenJS.NodeJS.LTS']);
    } else {
      lineas.push(['winget', 'winget install OpenJS.NodeJS.LTS']);
    }
    if (hayComando('choco')) lineas.push(['Chocolatey (ya lo tienes instalado)', 'choco install nodejs-lts -y']);
    lineas.push(['Instalador oficial', 'Descarga el .msi de la versión LTS desde https://nodejs.org/es/download']);
    lineas.push(['Importante', 'Cierra y vuelve a abrir la terminal después de instalar, para que el PATH se actualice.']);
  } else if (plat.so === 'linux') {
    if (plat.familia === 'debian') {
      lineas.push(['Debian, Ubuntu o derivadas', 'curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -\n     sudo apt-get install -y nodejs']);
      lineas.push(['Alternativa del repositorio', 'sudo apt-get install -y nodejs npm   ' + dim('(suele traer una versión más antigua)')]);
    } else if (plat.familia === 'fedora') {
      lineas.push(['Fedora, RHEL, Rocky o Alma', 'sudo dnf install -y nodejs npm']);
    } else if (plat.familia === 'arch') {
      lineas.push(['Arch o Manjaro', 'sudo pacman -S --noconfirm nodejs npm']);
    } else if (plat.familia === 'alpine') {
      lineas.push(['Alpine', 'sudo apk add nodejs npm']);
    } else if (plat.familia === 'suse') {
      lineas.push(['openSUSE', 'sudo zypper install -y nodejs npm']);
    }
    lineas.push(['nvm (cualquier distribución, sin sudo)', 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash\n     nvm install --lts']);
    if (plat.wsl) lineas.push(['Estás en WSL', 'Instala Node dentro de WSL, no en Windows: la versión de Windows no se ve desde aquí.']);
  } else {
    lineas.push(['Descarga oficial', 'https://nodejs.org/es/download']);
  }
  return lineas;
}

/** Instrucciones para cuando hay Node pero falta npm/npx. */
function instruccionesNpm(plat) {
  if (plat.so === 'linux' && plat.familia === 'debian') return 'sudo apt-get install -y npm';
  if (plat.so === 'linux' && plat.familia === 'fedora') return 'sudo dnf install -y npm';
  if (plat.so === 'linux' && plat.familia === 'arch') return 'sudo pacman -S --noconfirm npm';
  if (plat.so === 'linux' && plat.familia === 'alpine') return 'sudo apk add npm';
  if (plat.so === 'macos') return 'brew install node   (npm viene incluido)';
  if (plat.so === 'windows') return 'winget install OpenJS.NodeJS.LTS   (npm viene incluido)';
  return 'Reinstala Node.js desde https://nodejs.org/es/download, que incluye npm y npx';
}

function imprimirBloque(titulo, plat, lineas, pie) {
  console.error('');
  console.error(rojo('  ' + titulo));
  console.error('');
  console.error('  Sistema detectado: ' + bold(plat.etiqueta));
  console.error('');
  console.error('  ' + bold('Cómo instalarlo:'));
  for (var i = 0; i < lineas.length; i++) {
    console.error('');
    console.error('   ' + (i + 1) + ') ' + bold(lineas[i][0]));
    var cmds = String(lineas[i][1]).split('\n');
    for (var j = 0; j < cmds.length; j++) console.error('      ' + verde(cmds[j].trim()));
  }
  console.error('');
  if (pie) { console.error('  ' + pie); console.error(''); }
}

// -------------------------------------------------------------- validación

function versionNode() {
  var v = String(process.versions.node).split('.');
  return { mayor: parseInt(v[0], 10), texto: process.versions.node };
}

function validarEntorno() {
  var plat = detectarPlataforma();
  var v = versionNode();

  // 1. Versión de Node suficiente.
  if (!(v.mayor >= NODE_MINIMO)) {
    imprimirBloque(
      'Tu versión de Node.js es demasiado antigua (tienes ' + v.texto + ', hace falta ' + NODE_MINIMO + ' o superior).',
      plat, instruccionesNode(plat),
      'Cuando termines, vuelve a ejecutar este mismo comando. Comprueba con: ' + verde('node --version'));
    return false;
  }

  // 2. npm/npx presentes. Node puede estar instalado sin ellos en algunas distribuciones.
  if (!hayComando('npx')) {
    imprimirBloque(
      'Tienes Node.js ' + v.texto + ', pero no se encontró npx en el PATH.',
      plat, [['Instala npm, que incluye npx', instruccionesNpm(plat)]],
      'Cuando termines, vuelve a ejecutar este mismo comando. Comprueba con: ' + verde('npx --version'));
    return false;
  }

  return true;
}

// ------------------------------------------------------------------ arranque

function main() {
  var args = process.argv.slice(2);

  // Modo diagnóstico: comprueba el entorno y no instala nada.
  if (args.indexOf('--check') !== -1 || args.indexOf('--doctor') !== -1) {
    var plat = detectarPlataforma();
    var v = versionNode();
    console.log('');
    console.log('  ' + bold('Comprobación del entorno'));
    console.log('  Sistema:  ' + plat.etiqueta);
    console.log('  Node.js:  ' + (v.mayor >= NODE_MINIMO ? verde(v.texto) : rojo(v.texto + '  (hace falta ' + NODE_MINIMO + '+)')));
    console.log('  npx:      ' + (hayComando('npx') ? verde('disponible') : rojo('no encontrado')));
    console.log('  npm:      ' + (hayComando('npm') ? verde('disponible') : amar('no encontrado')));
    console.log('  git:      ' + (hayComando('git') ? verde('disponible') : amar('no encontrado  (npx github:… lo necesita)')));
    console.log('');
    if (!validarEntorno()) process.exit(1);
    console.log('  ' + verde('Todo listo.') + ' Ejecuta el comando sin --check para instalar las skills.');
    console.log('');
    return;
  }

  if (!validarEntorno()) process.exit(1);

  // Carga diferida del instalador moderno. Se usa eval para que el import()
  // dinámico no se parsee en versiones de Node que no lo soportan: así el
  // mensaje de arriba llega a mostrarse en lugar de un SyntaxError.
  var ruta = path.join(__dirname, '..', 'lib', 'install.mjs');
  var url = require('url').pathToFileURL(ruta).href;
  var cargar;
  try {
    cargar = eval('(function (u) { return import(u); })');
  } catch (e) {
    console.error(rojo('\n  Tu versión de Node no admite módulos ES. Actualiza a Node ' + NODE_MINIMO + ' o superior.\n'));
    process.exit(1);
  }
  cargar(url).catch(function (e) {
    console.error(rojo('\n  Error al iniciar el instalador: ' + e.message + '\n'));
    process.exit(1);
  });
}

main();
