#!/usr/bin/env bash
# Packaging del firmware compilato + generazione manifest OTA per una variante.
# Uso: package-firmware.sh <variante>   (es. everything-presence-lite-ha-esp32c3)
set -euo pipefail

VARIANT="$1"
YAML="${VARIANT}.yaml"

NAME=$(sed -n 's/^  name: *"\(.*\)"/\1/p' "$YAML" | head -1)
VERSION=$(sed -n 's/^  fork_version: *"\(.*\)"/\1/p' "$YAML" | head -1)
FRIENDLY=$(sed -n 's/^  friendly_name: *"\(.*\)"/\1/p' "$YAML" | head -1)

BUILD_DIR=".esphome/build/${NAME}/.pioenvs/${NAME}"
OUT="output/${VARIANT}"
mkdir -p "$OUT"

cp "${BUILD_DIR}/firmware.ota.bin" "$OUT/firmware.ota.bin"
cp "${BUILD_DIR}/firmware.factory.bin" "$OUT/firmware.factory.bin"

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
