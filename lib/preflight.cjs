/*
 * preflight.cjs — comprobación e instalación de requisitos del sistema.
 *
 * Responde a una sola pregunta: ¿tiene este computador todo lo que
 * agent-skills necesita para funcionar? Si falta algo, detecta el sistema
 * operativo y su gestor de paquetes, PIDE PERMISO y lo instala.
 *
 * Se mantiene en CommonJS y sintaxis antigua (sin arrow functions, sin
 * optional chaining, sin async) para que pueda ejecutarse incluso en versiones
 * de Node anteriores a la mínima admitida: si el entorno está roto, este
 * archivo tiene que poder explicarlo en lugar de fallar con un SyntaxError.
 */

'use strict';

var fs = require('fs');
var cp = require('child_process');

var NODE_MINIMO = 18;

// ------------------------------------------------------------------ colores

var tty = !!(process.stdout && process.stdout.isTTY) && !process.env.NO_COLOR;
function col(codigo, texto) { return tty ? '\u001b[' + codigo + 'm' + texto + '\u001b[0m' : texto; }
var c = {
  bold: function (t) { return col('1', t); },
  dim: function (t) { return col('2', t); },
  rojo: function (t) { return col('31', t); },
  verde: function (t) { return col('32', t); },
  amar: function (t) { return col('33', t); }
};

// ------------------------------------------------- detección de plataforma

/** Identifica el sistema operativo y, en Linux, la familia de distribución. */
function detectarPlataforma() {
  var p = process.platform;
  if (p === 'darwin') return { so: 'macos', etiqueta: 'macOS', familia: 'macos', wsl: false };
  if (p === 'win32') return { so: 'windows', etiqueta: 'Windows', familia: 'windows', wsl: false };
  if (p === 'linux') {
    var wsl = false;
    try {
      wsl = fs.readFileSync('/proc/version', 'utf8').toLowerCase().indexOf('microsoft') !== -1;
    } catch (e) {}
    var id = '', idLike = '', nombre = 'Linux';
    try {
      var osRelease = fs.readFileSync('/etc/os-release', 'utf8');
      var mId = osRelease.match(/^ID=("?)([^"\n]+)\1/m);
      var mLike = osRelease.match(/^ID_LIKE=("?)([^"\n]+)\1/m);
      var mNombre = osRelease.match(/^PRETTY_NAME=("?)([^"\n]+)\1/m);
      if (mId) id = mId[2];
      if (mLike) idLike = mLike[2];
      if (mNombre) nombre = mNombre[2];
    } catch (e) {}
    var todo = (id + ' ' + idLike).toLowerCase();
    var familia = 'desconocida';
    if (/debian|ubuntu|mint|pop/.test(todo)) familia = 'debian';
    else if (/fedora|rhel|centos|rocky|alma|amzn/.test(todo)) familia = 'fedora';
    else if (/arch|manjaro/.test(todo)) familia = 'arch';
    else if (/alpine/.test(todo)) familia = 'alpine';
    else if (/suse/.test(todo)) familia = 'suse';
    return {
      so: 'linux',
      familia: familia,
      wsl: wsl,
      etiqueta: wsl ? nombre + ' sobre WSL' : nombre
    };
  }
  return { so: 'otro', familia: 'desconocida', wsl: false, etiqueta: process.platform };
}

/** ¿Existe este ejecutable en el PATH? */
function hayComando(cmd) {
  if (!/^[A-Za-z0-9_.+-]+$/.test(cmd)) return false;
  var probar = process.platform === 'win32' ? 'where' : 'command -v';
  try {
    cp.execSync(probar + ' ' + cmd, { stdio: 'ignore', shell: true });
    return true;
  } catch (e) {
    return false;
  }
}

/** Número de versión mayor que reporta un ejecutable, o null si no se puede leer. */
function versionMayor(cmd) {
  try {
    var salida = cp.execFileSync(cmd, ['--version'], {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
      timeout: 15000,
      shell: process.platform === 'win32'
    });
    var m = String(salida).match(/(\d+)\.(\d+)(?:\.(\d+))?/);
    return m ? parseInt(m[1], 10) : null;
  } catch (e) {
    return null;
  }
}

// --------------------------------------------------------- gestores de paquetes

/*
 * Cada gestor declara cómo se invoca. `sudo` indica si necesita privilegios de
 * administrador; Homebrew es el caso contrario: se rompe si se ejecuta con sudo.
 * `unoPorUno` es para gestores que no aceptan varios paquetes en una sola orden.
 */
var GESTORES = {
  brew: { etiqueta: 'Homebrew', bin: 'brew', instalar: ['install'], refrescar: null, sudo: false, unoPorUno: false },
  apt: { etiqueta: 'APT', bin: 'apt-get', instalar: ['install', '-y'], refrescar: ['update'], sudo: true, unoPorUno: false },
  dnf: { etiqueta: 'DNF', bin: 'dnf', instalar: ['install', '-y'], refrescar: null, sudo: true, unoPorUno: false },
  yum: { etiqueta: 'YUM', bin: 'yum', instalar: ['install', '-y'], refrescar: null, sudo: true, unoPorUno: false },
  pacman: { etiqueta: 'pacman', bin: 'pacman', instalar: ['-S', '--noconfirm', '--needed'], refrescar: ['-Sy'], sudo: true, unoPorUno: false },
  apk: { etiqueta: 'apk', bin: 'apk', instalar: ['add'], refrescar: ['update'], sudo: true, unoPorUno: false },
  zypper: { etiqueta: 'zypper', bin: 'zypper', instalar: ['install', '-y'], refrescar: ['refresh'], sudo: true, unoPorUno: false },
  winget: {
    etiqueta: 'winget',
    bin: 'winget',
    instalar: ['install', '-e', '--accept-package-agreements', '--accept-source-agreements', '--id'],
    refrescar: null, sudo: false, unoPorUno: true
  },
  choco: { etiqueta: 'Chocolatey', bin: 'choco', instalar: ['install', '-y'], refrescar: null, sudo: false, unoPorUno: false },
  scoop: { etiqueta: 'Scoop', bin: 'scoop', instalar: ['install'], refrescar: null, sudo: false, unoPorUno: false }
};

/** Orden de preferencia de gestores según el sistema. */
function candidatosGestor(plat) {
  if (plat.so === 'macos') return ['brew'];
  if (plat.so === 'windows') return ['winget', 'choco', 'scoop'];
  if (plat.so === 'linux') {
    if (plat.familia === 'debian') return ['apt'];
    if (plat.familia === 'fedora') return ['dnf', 'yum'];
    if (plat.familia === 'arch') return ['pacman'];
    if (plat.familia === 'alpine') return ['apk'];
    if (plat.familia === 'suse') return ['zypper'];
    return ['apt', 'dnf', 'yum', 'pacman', 'apk', 'zypper', 'brew'];
  }
  return [];
}

/** Devuelve el gestor de paquetes utilizable en esta máquina, o null. */
function detectarGestor(plat) {
  var candidatos = candidatosGestor(plat);
  for (var i = 0; i < candidatos.length; i++) {
    var g = GESTORES[candidatos[i]];
    if (g && hayComando(g.bin)) {
      var copia = JSON.parse(JSON.stringify(g));
      copia.id = candidatos[i];
      return copia;
    }
  }
  return null;
}

// --------------------------------------------------------------- requisitos

/*
 * Qué necesita agent-skills para funcionar y qué paquete lo proporciona en cada
 * gestor. `minimo` solo se comprueba donde la versión importa.
 */
var REQUISITOS = [
  {
    clave: 'node',
    etiqueta: 'Node.js',
    comando: 'node',
    minimo: NODE_MINIMO,
    porQue: 'ejecuta el instalador de las skills',
    paquetes: {
      apt: 'nodejs', dnf: 'nodejs', yum: 'nodejs', pacman: 'nodejs', apk: 'nodejs', zypper: 'nodejs',
      brew: 'node', winget: 'OpenJS.NodeJS.LTS', choco: 'nodejs-lts', scoop: 'nodejs-lts'
    }
  },
  {
    clave: 'npm',
    etiqueta: 'npm',
    comando: 'npm',
    porQue: 'descarga y ejecuta el paquete',
    paquetes: {
      apt: 'npm', dnf: 'npm', yum: 'npm', pacman: 'npm', apk: 'npm', zypper: 'npm',
      brew: 'node', winget: 'OpenJS.NodeJS.LTS', choco: 'nodejs-lts', scoop: 'nodejs-lts'
    }
  },
  {
    clave: 'npx',
    etiqueta: 'npx',
    comando: 'npx',
    porQue: 'lanza el instalador sin instalar nada de forma permanente',
    paquetes: {
      apt: 'npm', dnf: 'npm', yum: 'npm', pacman: 'npm', apk: 'npm', zypper: 'npm',
      brew: 'node', winget: 'OpenJS.NodeJS.LTS', choco: 'nodejs-lts', scoop: 'nodejs-lts'
    }
  },
  {
    clave: 'git',
    etiqueta: 'git',
    comando: 'git',
    porQue: 'npx lo necesita para descargar el paquete desde GitHub',
    paquetes: {
      apt: 'git', dnf: 'git', yum: 'git', pacman: 'git', apk: 'git', zypper: 'git',
      brew: 'git', winget: 'Git.Git', choco: 'git', scoop: 'git'
    }
  }
];

/**
 * Estado de cada requisito.
 * Devuelve { todos: [...], faltantes: [...] } donde cada entrada lleva
 * { req, presente, version, motivo }.
 */
function revisar() {
  var estado = [];
  for (var i = 0; i < REQUISITOS.length; i++) {
    var r = REQUISITOS[i];
    var presente = hayComando(r.comando);
    var version = null;
    var motivo = null;

    // Para node, la versión que cuenta es la del proceso actual si lo hay.
    if (r.clave === 'node' && process.versions && process.versions.node) {
      version = parseInt(String(process.versions.node).split('.')[0], 10);
      presente = true;
    } else if (presente && r.minimo) {
      version = versionMayor(r.comando);
    }

    if (!presente) motivo = 'no está instalado';
    else if (r.minimo && version !== null && version < r.minimo) motivo = 'versión ' + version + ', hace falta ' + r.minimo + ' o superior';

    estado.push({ req: r, presente: presente, version: version, ok: !motivo, motivo: motivo });
  }
  var faltantes = estado.filter(function (e) { return !e.ok; });
  return { todos: estado, faltantes: faltantes };
}

/** Paquetes a instalar (sin duplicados) para cubrir los requisitos faltantes. */
function paquetesPara(faltantes, gestorId) {
  var vistos = {};
  var lista = [];
  for (var i = 0; i < faltantes.length; i++) {
    var p = faltantes[i].req.paquetes[gestorId];
    if (p && !vistos[p]) { vistos[p] = true; lista.push(p); }
  }
  return lista;
}

// -------------------------------------------------------------- interacción

/** Abre el terminal real para lectura, o null si no hay ninguno. */
function abrirTerminal() {
  try {
    return fs.openSync(process.platform === 'win32' ? '\\\\.\\CON' : '/dev/tty', 'r');
  } catch (e) {
    return null;
  }
}

/** ¿Podemos preguntarle algo a una persona? */
function hayTerminal() {
  var fd = abrirTerminal();
  if (fd === null) return !!(process.stdin && process.stdin.isTTY);
  try { fs.closeSync(fd); } catch (e) {}
  return true;
}

/**
 * Pregunta de forma síncrona leyendo del terminal real, no de stdin: así
 * funciona también cuando el script llega por una tubería (curl … | bash).
 *
 * Devuelve null si no se pudo leer nada. Es importante distinguirlo de la
 * respuesta vacía: "no hay nadie al otro lado" nunca puede valer como un sí.
 */
function preguntar(texto) {
  process.stdout.write(texto);
  var fd = abrirTerminal();
  var propio = fd !== null;
  if (!propio) {
    if (!(process.stdin && process.stdin.isTTY)) return null;
    fd = 0;
  }
  var buf = Buffer.alloc(256);
  var leido = '';
  var algo = false;
  try {
    while (leido.indexOf('\n') === -1) {
      var n = fs.readSync(fd, buf, 0, buf.length, null);
      if (!n) break;
      algo = true;
      leido += buf.toString('utf8', 0, n);
    }
  } catch (e) {
    // Entrada ilegible: se trata como si no hubiera nadie.
  }
  if (propio) { try { fs.closeSync(fd); } catch (e) {} }
  return algo ? leido.trim() : null;
}

/**
 * Sí/no. Enter equivale a sí, pero solo cuando de verdad hay alguien
 * respondiendo: si no se puede leer el terminal, la respuesta es no.
 */
function confirmar(pregunta) {
  var r = preguntar(pregunta + ' ' + c.dim('[S/n]') + ' ');
  if (r === null) {
    process.stdout.write('\n');
    return false;
  }
  r = r.toLowerCase();
  return r === '' || r === 's' || r === 'si' || r === 'sí' || r === 'y' || r === 'yes';
}

// ---------------------------------------------------------------- ejecución

/** ¿Hace falta sudo y está disponible? */
function planSudo(gestor) {
  if (!gestor.sudo) return { necesita: false, ok: true };
  var esRoot = typeof process.getuid === 'function' && process.getuid() === 0;
  if (esRoot) return { necesita: false, ok: true };
  return { necesita: true, ok: hayComando('sudo') };
}

/** Construye la orden completa, anteponiendo sudo si corresponde. */
function orden(gestor, args) {
  var sudo = planSudo(gestor);
  if (sudo.necesita) return { bin: 'sudo', args: [gestor.bin].concat(args) };
  return { bin: gestor.bin, args: args };
}

function textoOrden(o) { return o.bin + ' ' + o.args.join(' '); }

/** Órdenes que se ejecutarían para instalar estos paquetes. */
function ordenesInstalacion(gestor, paquetes) {
  var ordenes = [];
  if (gestor.refrescar) ordenes.push(orden(gestor, gestor.refrescar));
  if (gestor.unoPorUno) {
    for (var i = 0; i < paquetes.length; i++) ordenes.push(orden(gestor, gestor.instalar.concat([paquetes[i]])));
  } else {
    ordenes.push(orden(gestor, gestor.instalar.concat(paquetes)));
  }
  return ordenes;
}

/*
 * Tras instalar, el binario nuevo puede estar en una carpeta que el PATH de
 * este proceso todavía no incluye (Homebrew en Apple Silicon, /usr/local/bin,
 * ~/.local/bin…). Antes de dar algo por fallido, ampliamos el PATH con las
 * ubicaciones habituales: es la diferencia entre "no se instaló" y "sí se
 * instaló, pero aún no lo veo".
 */
function refrescarPath() {
  if (process.platform === 'win32') return;
  var casa = process.env.HOME || '';
  var candidatas = [
    '/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/games',
    '/opt/homebrew/bin', '/home/linuxbrew/.linuxbrew/bin'
  ];
  if (casa) candidatas.push(casa + '/.local/bin', casa + '/bin');

  var actual = String(process.env.PATH || '').split(':');
  for (var i = 0; i < candidatas.length; i++) {
    if (actual.indexOf(candidatas[i]) === -1 && fs.existsSync(candidatas[i])) actual.push(candidatas[i]);
  }
  process.env.PATH = actual.filter(Boolean).join(':');
}

/** Ejecuta una orden mostrando su salida en vivo (sudo puede pedir contraseña). */
function ejecutar(o) {
  console.log(c.dim('    $ ' + textoOrden(o)));
  var r = cp.spawnSync(o.bin, o.args, { stdio: 'inherit', shell: process.platform === 'win32' });
  if (r.error) return { ok: false, mensaje: r.error.message };
  if (r.status !== 0) return { ok: false, mensaje: 'la orden terminó con código ' + r.status };
  return { ok: true };
}

// --------------------------------------------------------- avisos y consejos

/** Instrucciones manuales cuando no podemos instalar por cuenta propia. */
function instruccionesManuales(plat, faltantes) {
  var lineas = [];
  var necesitaNode = faltantes.some(function (f) { return f.req.clave !== 'git'; });
  var necesitaGit = faltantes.some(function (f) { return f.req.clave === 'git'; });

  if (plat.so === 'macos') {
    if (necesitaNode) lineas.push(['Node.js con Homebrew', 'brew install node']);
    if (necesitaGit) lineas.push(['git con Homebrew', 'brew install git']);
    lineas.push(['Si no tienes Homebrew', '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"']);
    if (necesitaNode) lineas.push(['Instalador oficial', 'Descarga el .pkg LTS desde https://nodejs.org/es/download']);
  } else if (plat.so === 'windows') {
    if (necesitaNode) lineas.push(['Node.js con winget', 'winget install OpenJS.NodeJS.LTS']);
    if (necesitaGit) lineas.push(['git con winget', 'winget install Git.Git']);
    lineas.push(['Si winget no existe', 'Instala "Instalador de aplicaciones" desde Microsoft Store, o descarga el .msi LTS de https://nodejs.org/es/download']);
    lineas.push(['Importante', 'Cierra y vuelve a abrir la terminal después de instalar, para que el PATH se actualice.']);
  } else {
    if (plat.familia === 'debian') lineas.push(['Debian, Ubuntu o derivadas', 'sudo apt-get update && sudo apt-get install -y nodejs npm git']);
    else if (plat.familia === 'fedora') lineas.push(['Fedora, RHEL, Rocky o Alma', 'sudo dnf install -y nodejs npm git']);
    else if (plat.familia === 'arch') lineas.push(['Arch o Manjaro', 'sudo pacman -S --noconfirm nodejs npm git']);
    else if (plat.familia === 'alpine') lineas.push(['Alpine', 'sudo apk add nodejs npm git']);
    else if (plat.familia === 'suse') lineas.push(['openSUSE', 'sudo zypper install -y nodejs npm git']);
    if (necesitaNode) lineas.push(['nvm (cualquier distribución, sin sudo)', 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash\nnvm install --lts']);
    if (plat.wsl) lineas.push(['Estás en WSL', 'Instala Node dentro de WSL: la instalación de Windows no se ve desde aquí.']);
  }
  if (!lineas.length) lineas.push(['Descarga oficial', 'https://nodejs.org/es/download']);
  return lineas;
}

function imprimirManual(plat, faltantes) {
  var lineas = instruccionesManuales(plat, faltantes);
  console.error('');
  console.error('  ' + c.bold('Instálalo a mano y vuelve a ejecutar este mismo comando:'));
  for (var i = 0; i < lineas.length; i++) {
    console.error('');
    console.error('   ' + (i + 1) + ') ' + c.bold(lineas[i][0]));
    var cmds = String(lineas[i][1]).split('\n');
    for (var j = 0; j < cmds.length; j++) console.error('      ' + c.verde(cmds[j].trim()));
  }
  console.error('');
}

// ----------------------------------------------------------------- fachada

/**
 * Comprueba los requisitos y, si falta alguno, pide permiso e instala.
 *
 * opciones: { yes: bool, noInstalar: bool, dryRun: bool, silencioso: bool }
 * Devuelve true si al terminar el entorno está completo.
 */
function asegurarRequisitos(opciones) {
  opciones = opciones || {};
  var plat = detectarPlataforma();
  var estado = revisar();

  if (!estado.faltantes.length) {
    if (!opciones.silencioso) {
      console.log('  ' + c.verde('Requisitos completos') + c.dim('  (' + plat.etiqueta + ')'));
    }
    return true;
  }

  console.log('');
  console.log('  ' + c.amar('Faltan requisitos para poder continuar.'));
  console.log('  Sistema detectado: ' + c.bold(plat.etiqueta));
  console.log('');
  for (var i = 0; i < estado.faltantes.length; i++) {
    var f = estado.faltantes[i];
    console.log('   • ' + c.bold(f.req.etiqueta) + ': ' + f.motivo + c.dim('  — ' + f.req.porQue));
  }

  var gestor = detectarGestor(plat);
  if (!gestor) {
    console.log('');
    console.log('  ' + c.rojo('No encontré un gestor de paquetes conocido en este sistema,'));
    console.log('  así que no puedo instalarlos por ti.');
    imprimirManual(plat, estado.faltantes);
    return false;
  }

  var paquetes = paquetesPara(estado.faltantes, gestor.id);
  if (!paquetes.length) {
    imprimirManual(plat, estado.faltantes);
    return false;
  }

  var sudo = planSudo(gestor);
  if (sudo.necesita && !sudo.ok) {
    console.log('');
    console.log('  ' + c.rojo('Hace falta sudo para instalar con ' + gestor.etiqueta + ', y no está disponible.'));
    console.log('  Ejecuta el instalador como administrador, o instálalo a mano.');
    imprimirManual(plat, estado.faltantes);
    return false;
  }

  var ordenes = ordenesInstalacion(gestor, paquetes);

  console.log('');
  console.log('  Puedo instalarlos con ' + c.bold(gestor.etiqueta) + ':');
  for (var k = 0; k < ordenes.length; k++) console.log('      ' + c.verde(textoOrden(ordenes[k])));
  if (sudo.necesita) console.log('  ' + c.dim('sudo puede pedirte la contraseña de tu usuario.'));

  if (opciones.dryRun) {
    console.log('');
    console.log('  ' + c.amar('Modo simulación: no se instaló nada.'));
    return false;
  }

  if (opciones.noInstalar) {
    console.log('');
    console.log('  ' + c.amar('Instalación automática desactivada (--no-install).'));
    imprimirManual(plat, estado.faltantes);
    return false;
  }

  if (!opciones.yes) {
    if (!hayTerminal()) {
      console.log('');
      console.log('  ' + c.rojo('No hay terminal interactiva para pedirte permiso.'));
      console.log('  Vuelve a ejecutarlo con ' + c.verde('--yes') + ' para autorizar la instalación,');
      console.log('  o instala los requisitos a mano.');
      imprimirManual(plat, estado.faltantes);
      return false;
    }
    console.log('');
    if (!confirmar('  ¿Los instalo ahora?')) {
      console.log('');
      console.log('  ' + c.amar('No se instaló nada.'));
      imprimirManual(plat, estado.faltantes);
      return false;
    }
  }

  console.log('');
  console.log('  ' + c.bold('Instalando…'));
  for (var m = 0; m < ordenes.length; m++) {
    var res = ejecutar(ordenes[m]);
    // Un fallo al refrescar índices no es fatal: puede haber repos caídos y aun
    // así instalarse desde la caché local.
    var esRefresco = gestor.refrescar && m === 0;
    if (!res.ok && !esRefresco) {
      console.log('');
      console.log('  ' + c.rojo('La instalación falló: ' + res.mensaje));
      imprimirManual(plat, estado.faltantes);
      return false;
    }
    if (!res.ok && esRefresco) console.log('  ' + c.amar('No se pudo actualizar el índice de paquetes; sigo con la instalación.'));
  }

  // Reverificación: lo que importa no es que el gestor dijera "ok", sino que
  // los comandos existan de verdad ahora.
  refrescarPath();
  var despues = revisar();
  if (!despues.faltantes.length) {
    console.log('');
    console.log('  ' + c.verde('Listo: todos los requisitos están instalados.'));
    return true;
  }

  console.log('');
  console.log('  ' + c.amar('Se instaló, pero todavía falta:'));
  for (var n = 0; n < despues.faltantes.length; n++) {
    console.log('   • ' + despues.faltantes[n].req.etiqueta + ': ' + despues.faltantes[n].motivo);
  }
  if (process.platform === 'win32') {
    console.log('');
    console.log('  ' + c.bold('Cierra y vuelve a abrir PowerShell') + ' para que el PATH se actualice, y repite el comando.');
  } else if (despues.faltantes.some(function (f) { return f.req.clave === 'node' && f.version !== null; })) {
    console.log('');
    console.log('  La versión de Node del repositorio de tu sistema es demasiado antigua.');
    console.log('  Instala una versión moderna con nvm:');
    console.log('      ' + c.verde('curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'));
    console.log('      ' + c.verde('nvm install --lts'));
  } else {
    imprimirManual(plat, despues.faltantes);
  }
  return false;
}

/** Diagnóstico legible del entorno, sin instalar nada. */
function diagnostico() {
  var plat = detectarPlataforma();
  var gestor = detectarGestor(plat);
  var estado = revisar();

  console.log('');
  console.log('  ' + c.bold('Comprobación del entorno'));
  console.log('  Sistema:  ' + plat.etiqueta);
  console.log('  Gestor:   ' + (gestor ? gestor.etiqueta + c.dim('  (' + gestor.bin + ')') : c.amar('ninguno conocido')));
  for (var i = 0; i < estado.todos.length; i++) {
    var e = estado.todos[i];
    var valor = e.ok
      ? c.verde(e.version ? String(e.version) + '.x' : 'disponible')
      : c.rojo(e.motivo);
    var titulo = e.req.etiqueta + ':';
    while (titulo.length < 10) titulo += ' ';
    console.log('  ' + titulo + valor);
  }
  console.log('');
  return estado;
}

module.exports = {
  NODE_MINIMO: NODE_MINIMO,
  colores: c,
  detectarPlataforma: detectarPlataforma,
  detectarGestor: detectarGestor,
  hayComando: hayComando,
  versionMayor: versionMayor,
  revisar: revisar,
  paquetesPara: paquetesPara,
  ordenesInstalacion: ordenesInstalacion,
  textoOrden: textoOrden,
  hayTerminal: hayTerminal,
  refrescarPath: refrescarPath,
  confirmar: confirmar,
  asegurarRequisitos: asegurarRequisitos,
  diagnostico: diagnostico,
  REQUISITOS: REQUISITOS,
  GESTORES: GESTORES
};
