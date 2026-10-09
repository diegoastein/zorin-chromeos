#!/usr/bin/env node
// Genera el script de instalación sin abrir el panel en el navegador.
// Usa los mismos módulos de bash y el mismo generador que panel/index.html.
//
// Ejemplos:
//   node tools/generate.js --preset rec > setup.sh
//   node tools/generate.js --preset rec --target mx --out setup-mx.sh
//   node tools/generate.js --code "zcos1:chrome,zram|target=mx|pwas=word,excel|scheme=system|keymap=latam" --out setup.sh
//   node tools/generate.js --diag > diag.sh
//   node tools/generate.js --analyze diagnostico-hardware.txt [--target mx]
//   node tools/generate.js --list

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '..', 'panel', 'index.html'), 'utf8');

const mods = {};
for (const m of html.matchAll(/<script type="text\/plain" data-mod="(\w+)">([\s\S]*?)<\/script>/g)) {
  mods[m[1]] = m[2];
}
const gen = html.match(/<script id="gen">([\s\S]*?)<\/script>/)[1];
const { build, analyzeDiag, PWAS, SCHEMES, KEYMAPS, TARGETS, ZORIN_ONLY } = new Function(gen + '; return { build, analyzeDiag, PWAS, SCHEMES, KEYMAPS, TARGETS, ZORIN_ONLY };')();

// Debe coincidir con las marcas "p" del panel (r = recomendado, m = mínimo).
const REC = ['backup_snapshot', 'chrome', 'pwas', 'onedrive', 'region', 'accounts', 'look_shelf', 'look_wallpaper', 'look_font', 'look_icons', 'look_scroll', 'look_touchpad',
  'look_keys', 'look_favs', 'zram', 'perf_anim', 'perf_tracker', 'perf_power', 'updates', 'drv_wifi_ps', 'drv_audio_unmute', 'drv_audio_jd'];
const MIN = ['chrome', 'region', 'zram', 'updates'];
const ALL = ['region', 'chrome', 'chrome_autostart', 'pwas', 'onedrive', 'cleanup_apps', 'accounts', 'acc_cal', 'acc_contacts', 'acc_mail',
  'drv_fw', 'drv_hwe', 'drv_rtl', 'drv_bcm', 'drv_wifi_ps', 'drv_audio', 'drv_audio_fw', 'drv_audio_unmute', 'drv_audio_jd', 'drv_brightness', 'backup_snapshot',
  'zram', 'perf_anim', 'perf_tracker', 'perf_power',
  'perf_services', 'updates', 'updates_reboot', 'look_shelf', 'look_wallpaper', 'look_font', 'look_icons', 'look_scheme', 'look_scroll', 'look_touchpad',
  'look_keys', 'look_favs'];
const DEFAULT_PWAS = ['word', 'excel', 'powerpoint', 'gmail', 'gdrive'];

const PRESETS = {
  rec: { on: REC, pwas: DEFAULT_PWAS, scheme: 'system', keymap: 'latam', target: 'zorin' },
  min: { on: MIN, pwas: DEFAULT_PWAS, scheme: 'system', keymap: 'latam', target: 'zorin' },
  all: { on: ALL, pwas: PWAS.map(p => p.id), scheme: 'system', keymap: 'latam', target: 'zorin' }
};

function parseCode(text) {
  const t = text.trim();
  if (t.indexOf('zcos1:') !== 0) throw new Error('El código tiene que empezar con zcos1:');
  const parts = t.slice(6).split('|');
  const state = { on: (parts[0] || '').split(',').filter(id => ALL.indexOf(id) >= 0), pwas: DEFAULT_PWAS, scheme: 'system', keymap: 'latam', target: 'zorin' };
  parts.slice(1).forEach(kv => {
    const i = kv.indexOf('=');
    if (i < 0) return;
    const k = kv.slice(0, i), v = kv.slice(i + 1);
    if (k === 'target' && TARGETS[v]) state.target = v;
    if (k === 'pwas') state.pwas = v.split(',').filter(id => PWAS.some(p => p.id === id));
    if (k === 'scheme' && SCHEMES[v]) state.scheme = v;
    if (k === 'keymap' && KEYMAPS.indexOf(v) >= 0) state.keymap = v;
  });
  return state;
}

function usage(code) {
  console.error('Uso: node tools/generate.js (--preset rec|min|all | --code "zcos1:..." | --diag | --analyze diagnostico.txt | --list) [--target zorin|mx] [--out archivo]');
  process.exit(code);
}

const args = process.argv.slice(2);
const opt = name => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
if (args.length === 0 || args.includes('--help')) usage(args.length === 0 ? 1 : 0);

// --target pisa el sistema del preset o del código; por defecto, Zorin
const forcedTarget = opt('--target');
if (forcedTarget !== undefined && !TARGETS[forcedTarget]) { console.error('Sistema no válido: ' + forcedTarget + ' (usá zorin o mx)'); process.exit(1); }
const withTarget = s => (forcedTarget ? Object.assign({}, s, { target: forcedTarget }) : s);

let output;
if (args.includes('--list')) {
  output = 'Sistemas: ' + Object.keys(TARGETS).map(k => k + ' (' + TARGETS[k].name + ')').join(', ') +
    '\nMódulos: ' + ALL.join(', ') + '\nSolo Zorin: ' + ZORIN_ONLY.join(', ') + '\nApps web: ' + PWAS.map(p => p.id).join(', ') +
    '\nTemas: ' + Object.keys(SCHEMES).join(', ') + '\nTeclados: ' + KEYMAPS.join(', ') + '\n';
} else if (opt('--analyze')) {
  let text;
  try { text = fs.readFileSync(opt('--analyze'), 'utf8'); }
  catch (e) { console.error('No se pudo leer ' + opt('--analyze') + ': ' + e.message); process.exit(1); }
  const r = analyzeDiag(text, forcedTarget || 'zorin');
  if (r.error) { console.error(r.error); process.exit(1); }
  const tag = { ok: 'ANDA  ', info: 'DATO  ', warn: 'OJO   ' };
  output = r.notes.map(n => tag[n.level] + n.text).concat(
    r.suggest.length ? r.suggest.map(s => 'SUGIERE ' + s.id + ': ' + s.why) : ['No hace falta activar módulos de drivers.']).join('\n') + '\n';
} else if (args.includes('--diag')) {
  output = mods.diag.replace(/^\n/, '');
} else if (opt('--preset')) {
  const p = PRESETS[opt('--preset')];
  if (!p) usage(1);
  output = build(withTarget(p), mods).script;
} else if (opt('--code')) {
  try { output = build(withTarget(parseCode(opt('--code'))), mods).script; }
  catch (e) { console.error(e.message); process.exit(1); }
} else {
  usage(1);
}

const out = opt('--out');
if (out) { fs.writeFileSync(out, output, { mode: 0o755 }); console.error('Escrito: ' + out); }
else process.stdout.write(output);
