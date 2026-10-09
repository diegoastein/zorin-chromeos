#!/usr/bin/env node
// Prueba el análisis del diagnóstico (analyzeDiag) con salidas inventadas, sin datos de ningún equipo real.
// Uso: node tools/test-diag.js   (lo corre tools/test.sh)

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '..', 'panel', 'index.html'), 'utf8');
const gen = html.match(/<script id="gen">([\s\S]*?)<\/script>/)[1];
const { analyzeDiag } = new Function(gen + '; return { analyzeDiag };')();

// Arma un diagnóstico con el mismo formato que scripts/diagnostico-hardware.sh
function diag(o) {
  return [
    '## Fecha', 'mar 06 oct 2026 16:13:17 -03',
    '## Kernel', '6.8.0-45-generic',
    '## CPU y RAM', 'CPU(s):                          ' + (o.cores || 2), '               total       usado       libre',
    'Mem:           ' + (o.ram || '3,7Gi') + '       1,1Gi       1,5Gi',
    '## Placas PCI de red y audio', (o.pci || ''),
    '## Dispositivos USB', (o.usb || 'Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub'),
    '## Tarjetas de sonido', (o.snd || ''),
    '## Módulos de audio cargados', '',
    '## Bloqueos de radio', (o.rfkill || '0: phy0: Wireless LAN\n\tSoft blocked: no\n\tHard blocked: no'),
    '## Interfaces de red', 'DEVICE  TYPE  STATE  CONNECTION', (o.net || ''),
    '## Mensajes del kernel sobre firmware, WiFi y audio', (o.kmsg || '')
  ].join('\n');
}

const INTEL_AUDIO = '00:1f.3 Audio device [0403]: Intel Corporation Celeron/Pentium Silver Series HD Audio [8086:5a98] (rev 0b)\n\tSubsystem: Intel Corporation Device [8086:7270]\n\tKernel driver in use: snd_hda_intel';
const SND_OK = 'tarjeta 0: PCH [HDA Intel PCH], dispositivo 0: ALC269 Analog [ALC269 Analog]';
const WIFI_UP = 'wlp2s0  wifi  conectado  Casa';

let fails = 0;
function check(name, cond, extra) {
  if (cond) console.log('ok     ' + name);
  else { console.log('FALLA  ' + name + (extra ? '\n       ' + extra : '')); fails++; }
}
const ids = r => (r.suggest || []).map(s => s.id).sort().join(',');
const levels = r => (r.notes || []).map(n => n.level).join(',');

// 1. Realtek 8821CE sin driver y sin interfaz WiFi, con firmware faltante
let r = analyzeDiag(diag({
  pci: '03:00.0 Network controller [0280]: Realtek Semiconductor Co., Ltd. RTL8821CE 802.11ac PCIe Wireless Network Adapter [10ec:c821]\n\tSubsystem: Foo [1a3b:2c4d]\n\tKernel modules: rtw88_8821ce\n--\n' + INTEL_AUDIO,
  snd: SND_OK,
  kmsg: '[    5.1] rtw_8821ce 0000:03:00.0: Direct firmware load for rtw88/rtw8821c_fw.bin failed with error -2'
}), 'zorin');
check('Realtek 8821CE sin driver: sugiere drv_rtl y drv_fw', ids(r) === 'drv_fw,drv_rtl', ids(r));

// 2. Realtek 8821CE con driver y WiFi conectado: no sugiere nada
r = analyzeDiag(diag({
  pci: '03:00.0 Network controller [0280]: Realtek Semiconductor Co., Ltd. RTL8821CE 802.11ac PCIe Wireless Network Adapter [10ec:c821]\n\tSubsystem: Foo [1a3b:2c4d]\n\tKernel driver in use: rtw_8821ce\n--\n' + INTEL_AUDIO,
  snd: SND_OK, net: WIFI_UP
}), 'zorin');
check('Realtek 8821CE que anda: no sugiere módulos', ids(r) === '', ids(r));
check('Realtek 8821CE que anda: avisa que anda', levels(r) === 'ok,ok', levels(r));

// 3. Broadcom sin driver
r = analyzeDiag(diag({
  pci: '02:00.0 Network controller [0280]: Broadcom Inc. and subsidiaries BCM43142 802.11b/g/n [14e4:4365] (rev 01)\n\tKernel modules: bcma\n--\n' + INTEL_AUDIO,
  snd: SND_OK
}), 'zorin');
check('Broadcom sin driver: sugiere drv_bcm', ids(r) === 'drv_bcm', ids(r));

// 4. Intel sin tarjeta de sonido: sugiere el audio clásico
r = analyzeDiag(diag({ pci: INTEL_AUDIO, snd: 'aplay: device_list:274: no soundcards found...' }), 'zorin');
check('Intel sin tarjetas de sonido: sugiere drv_audio', ids(r) === 'drv_audio', ids(r));

// 5. Placa de red desconocida sin driver: HWE en Zorin, aviso en MX
const unk = { pci: '02:00.0 Network controller [0280]: Acme Wireless XZ [abcd:1234]\n\tKernel modules: acme\n--\n' + INTEL_AUDIO, snd: SND_OK };
check('Placa sin driver en Zorin: sugiere drv_hwe', ids(analyzeDiag(diag(unk), 'zorin')) === 'drv_hwe');
r = analyzeDiag(diag(unk), 'mx');
check('Placa sin driver en MX: no sugiere HWE y avisa', ids(r) === '' && levels(r).indexOf('warn') >= 0, ids(r) + ' / ' + levels(r));

// 6. Audio de un chip que no es Intel y sin tarjetas: avisa, no sugiere el módulo de Intel
r = analyzeDiag(diag({ pci: '00:14.2 Audio device [0403]: Acme Audio Controller [1234:5678]\n\tKernel driver in use: snd_hda_intel', snd: 'aplay: device_list:274: no soundcards found...' }), 'zorin');
check('Audio no Intel sin tarjetas: avisa y no sugiere drv_audio', ids(r) === '' && levels(r).indexOf('warn') >= 0, ids(r) + ' / ' + levels(r));

// 7. Bloqueos de radio
r = analyzeDiag(diag({ pci: INTEL_AUDIO, snd: SND_OK, rfkill: '0: phy0: Wireless LAN\n\tSoft blocked: no\n\tHard blocked: yes' }), 'zorin');
check('Bloqueo por hardware: avisa', r.notes.some(n => n.level === 'warn' && /hardware/.test(n.text)));

// 8. Equipo distinto de la Philco
r = analyzeDiag(diag({ cores: 4, ram: '6,7Gi', pci: INTEL_AUDIO, snd: SND_OK, net: WIFI_UP }), 'zorin');
check('4 núcleos y 6,7 GB: avisa que no parece la Philco', r.notes.some(n => n.level === 'warn' && /Philco/.test(n.text)));
r = analyzeDiag(diag({ pci: INTEL_AUDIO, snd: SND_OK, net: WIFI_UP }), 'zorin');
check('2 núcleos y 3,7 GB: no avisa de equipo distinto', !r.notes.some(n => /Philco/.test(n.text)));

// 9. Líneas del kernel que no son fallas de firmware
r = analyzeDiag(diag({ pci: INTEL_AUDIO, snd: SND_OK, kmsg: '[    0.3] ACPI: [Firmware Bug]: BIOS _OSI(Linux) query ignored\n[   19.8] amdgpu 0000:00:01.0: Found VCE firmware Version: 50.10 Binary ID: 2' }), 'zorin');
check('Firmware Bug y firmware encontrado no cuentan como falta de firmware', ids(r) === '', ids(r));

// 10. Texto que no es un diagnóstico
check('Texto cualquiera: devuelve error', !!analyzeDiag('hola, esto no es un diagnóstico', 'zorin').error);
check('Texto vacío: devuelve error', !!analyzeDiag('', 'zorin').error);

process.exit(fails ? 1 : 0);
