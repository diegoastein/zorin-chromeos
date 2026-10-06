#!/usr/bin/env bash
# Regenera los scripts de la carpeta scripts/ a partir del panel.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p scripts
node tools/generate.js --preset rec --out scripts/setup-recomendado.sh
node tools/generate.js --preset min --out scripts/setup-minimo.sh
node tools/generate.js --preset all --out scripts/setup-completo.sh
node tools/generate.js --preset rec --target mx --out scripts/setup-recomendado-mx.sh
node tools/generate.js --preset min --target mx --out scripts/setup-minimo-mx.sh
node tools/generate.js --preset all --target mx --out scripts/setup-completo-mx.sh
node tools/generate.js --diag --out scripts/diagnostico-hardware.sh
echo "Scripts regenerados en scripts/"
