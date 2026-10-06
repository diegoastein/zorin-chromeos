#!/usr/bin/env bash
# Pruebas: sintaxis de bash, modo de prueba (DRY_RUN) y que scripts/ esté al día con el panel.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

for name in setup-recomendado setup-minimo setup-completo setup-recomendado-mx setup-minimo-mx setup-completo-mx diagnostico-hardware; do
  f="scripts/$name.sh"
  if bash -n "$f"; then echo "sintaxis ok     $f"; else echo "SINTAXIS FALLA  $f"; fail=1; fi
done

for name in setup-recomendado setup-minimo setup-completo setup-recomendado-mx setup-minimo-mx setup-completo-mx; do
  f="scripts/$name.sh"
  if DRY_RUN=1 HOME="$tmp" bash "$f" >/dev/null 2>"$tmp/err"; then
    echo "dry-run ok      $f"
  else
    echo "DRY-RUN FALLA   $f"; cat "$tmp/err"; fail=1
  fi
done

# scripts/ debe coincidir con lo que genera el panel hoy
node tools/generate.js --preset rec --out "$tmp/rec.sh" 2>/dev/null
node tools/generate.js --preset min --out "$tmp/min.sh" 2>/dev/null
node tools/generate.js --preset all --out "$tmp/all.sh" 2>/dev/null
node tools/generate.js --preset rec --target mx --out "$tmp/rec-mx.sh" 2>/dev/null
node tools/generate.js --preset min --target mx --out "$tmp/min-mx.sh" 2>/dev/null
node tools/generate.js --preset all --target mx --out "$tmp/all-mx.sh" 2>/dev/null
node tools/generate.js --diag --out "$tmp/diag.sh" 2>/dev/null
for pair in "rec:setup-recomendado" "min:setup-minimo" "all:setup-completo" "rec-mx:setup-recomendado-mx" "min-mx:setup-minimo-mx" "all-mx:setup-completo-mx" "diag:diagnostico-hardware"; do
  a="${pair%%:*}"; b="${pair##*:}"
  if cmp -s "$tmp/$a.sh" "scripts/$b.sh"; then echo "al día          scripts/$b.sh"; else echo "DESACTUALIZADO  scripts/$b.sh (corré tools/build.sh)"; fail=1; fi
done

exit "$fail"
