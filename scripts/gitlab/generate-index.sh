#!/usr/bin/env bash
# Genera una index.html minimale che elenca varianti e manifest pubblicati.
set -euo pipefail
DIR="${1:-public}"
{
  echo "<html><head><title>EP Lite ESP32-C3 firmware</title></head><body>"
  echo "<h1>Everything Presence Lite &mdash; firmware ESP32-C3 (fork)</h1><ul>"
  for m in "$DIR"/*/manifest.json; do
    v=$(basename "$(dirname "$m")")
    ver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$m" | head -1)
    echo "<li><a href=\"${v}/manifest.json\">${v}</a> &mdash; ${ver}</li>"
  done
  echo "</ul><p>Generated $(date -u +%FT%TZ) - pipeline ${CI_PIPELINE_ID:-local}</p></body></html>"
} > "$DIR/index.html"
