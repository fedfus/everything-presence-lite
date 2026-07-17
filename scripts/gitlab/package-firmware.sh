#!/usr/bin/env bash
# Packaging del firmware compilato + generazione manifest OTA per una variante.
# Uso: package-firmware.sh <variante>   (es. everything-presence-lite-ha-esp32c3)
set -euo pipefail

VARIANT="$1"
YAML="${VARIANT}.yaml"

NAME=$(sed -n 's/^  name: *"\(.*\)"/\1/p' "$YAML" | head -1)
FRIENDLY=$(sed -n 's/^  friendly_name: *"\(.*\)"/\1/p' "$YAML" | head -1)

# Versione automatica: <versione upstream>+c3.<numero pipeline>.
# Deve combaciare con la -s fork_version passata a `esphome compile` in CI.
# Fallback sul fork_version committato quando si builda a mano.
UP_VER=$(sed -n 's/.*version: *"\([0-9.]*\)".*/\1/p' common/everything-presence-lite-base.yaml | head -1)
if [ -n "${CI_PIPELINE_IID:-}" ]; then
  VERSION="${UP_VER}+c3.${CI_PIPELINE_IID}"
else
  VERSION=$(sed -n 's/^  fork_version: *"\(.*\)"/\1/p' "$YAML" | head -1)
fi

# Il percorso di build cambia tra versioni ESPHome
# (.pioenvs/<name>/ in passato, build/ dalle versioni con build IDF nativa):
# cerchiamo i binari invece di assumere il layout.
BUILD_DIR=".esphome/build/${NAME}"
OTA_BIN=$(find "$BUILD_DIR" -name firmware.ota.bin -print -quit)
FACTORY_BIN=$(find "$BUILD_DIR" -name firmware.factory.bin -print -quit)
if [ -z "$OTA_BIN" ] || [ -z "$FACTORY_BIN" ]; then
  echo "ERRORE: firmware.ota.bin/firmware.factory.bin non trovati sotto ${BUILD_DIR}" >&2
  find "$BUILD_DIR" -name '*.bin' >&2 || true
  exit 1
fi

OUT="output/${VARIANT}"
mkdir -p "$OUT"

cp "$OTA_BIN" "$OUT/firmware.ota.bin"
cp "$FACTORY_BIN" "$OUT/firmware.factory.bin"

MD5=$(md5sum "$OUT/firmware.ota.bin" | cut -d' ' -f1)

# Manifest compatibile sia con il componente ESPHome `update: http_request`
# (campo builds[].ota) sia con ESP Web Tools (campo builds[].parts).
cat > "$OUT/manifest.json" <<JSON
{
  "name": "${FRIENDLY} (${VARIANT})",
  "version": "${VERSION}",
  "home_assistant_domain": "esphome",
  "new_install_prompt_erase": false,
  "builds": [
    {
      "chipFamily": "ESP32-C3",
      "ota": {
        "path": "firmware.ota.bin",
        "md5": "${MD5}",
        "summary": "${VARIANT} ${VERSION}",
        "release_url": "${CI_PROJECT_URL:-}/-/commits/main"
      },
      "parts": [
        { "path": "firmware.factory.bin", "offset": 0 }
      ]
    }
  ]
}
JSON

echo "Packaged ${VARIANT} v${VERSION} (md5 ${MD5})"
