#!/usr/bin/env bash
# Allinea il fork all'upstream EverythingSmartHome/everything-presence-lite.
# Grazie alla struttura a overlay (common/esp32c3-overlay.yaml) il merge è
# normalmente privo di conflitti: i file upstream non vengono mai modificati.
set -euo pipefail

UPSTREAM_URL="https://github.com/EverythingSmartHome/everything-presence-lite.git"

git remote add upstream "$UPSTREAM_URL" 2>/dev/null || git remote set-url upstream "$UPSTREAM_URL"
git fetch upstream main

BEHIND=$(git rev-list --count HEAD..upstream/main)
if [ "$BEHIND" -eq 0 ]; then
  echo "✔ Fork già allineato all'upstream."
  exit 0
fi

echo "Upstream ha ${BEHIND} commit nuovi: eseguo il merge..."
git merge --no-edit upstream/main

UP_VER=$(sed -n 's/.*version: *"\([0-9.]*\)".*/\1/p' common/everything-presence-lite-base.yaml | head -1)
FORK_VER=$(sed -n 's/^  fork_version: *"\(.*\)"/\1/p' everything-presence-lite-ha-esp32c3.yaml | head -1)

echo
echo "✔ Merge completato."
echo "  Versione upstream : ${UP_VER}"
echo "  fork_version      : ${FORK_VER}"
if [ "${FORK_VER%%+*}" != "$UP_VER" ]; then
  echo
  echo "⚠ AZIONI RICHIESTE prima del push:"
  echo "  1. Aggiorna 'fork_version' a \"${UP_VER}+c3.1\" in:"
  echo "     - everything-presence-lite-ha-esp32c3.yaml"
  echo "     - everything-presence-lite-ha-no-ble-esp32c3.yaml"
  echo "  2. Verifica che gli anchor dell'overlay esistano ancora upstream:"
  echo "     id bus_a, id esp32_led, uart tx/rx in common/ld2450-base.yaml"
  echo "     (la pipeline 'validate' li verifica comunque via 'esphome config')"
fi
