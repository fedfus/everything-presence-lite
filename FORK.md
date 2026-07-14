# Fork ESP32-C3 (XIAO) — guida operativa

Fork di [EverythingSmartHome/everything-presence-lite](https://github.com/EverythingSmartHome/everything-presence-lite)
con supporto per Seeed Studio **XIAO ESP32-C3** e distribuzione OTA da GitLab privato.

## Struttura

I file upstream **non vengono mai modificati**. Tutto il delta del fork vive in:

| File | Ruolo |
|---|---|
| `common/esp32c3-overlay.yaml` | Delta hardware C3 (board, I2C 6/7, LED GPIO4, UART 21/20) applicato via packages/`!extend` |
| `everything-presence-lite-ha-esp32c3.yaml` | Variante C3 con BLE: include i base upstream + overlay |
| `everything-presence-lite-ha-no-ble-esp32c3.yaml` | Variante C3 senza BLE |
| `.gitlab-ci.yml`, `scripts/gitlab/` | Pipeline build + pubblicazione OTA |
| `scripts/sync-upstream.sh` | Allineamento con l'upstream |

## Sync con l'upstream

```bash
./scripts/sync-upstream.sh
```

Fa fetch+merge di `upstream/main`. Poiché i file upstream sono intatti, il merge è
normalmente senza conflitti. Dopo il merge lo script segnala se va aggiornata
`fork_version` (convenzione: `<versione upstream>+c3.<n>`).

In alternativa, lo scheduled job `check-upstream` della pipeline (Settings →
CI/CD → Pipeline schedules) fallisce quando l'upstream ha commit nuovi, così
ricevi una notifica.

Unico punto di attenzione: l'overlay "aggancia" per id alcuni componenti
upstream (`bus_a`, `esp32_led`, `uart_bus`, `flash_button`). Se upstream li
rinomina, il job `validate` della pipeline fallisce e l'overlay va ritoccato.

## Release OTA

1. (Dopo un sync o una modifica) aggiorna `fork_version` nei due file `*-esp32c3.yaml`
2. L'URL OTA non è committato: la pipeline lo inietta a build time
   (`$CI_PAGES_URL`, oppure la variabile CI `OTA_BASE_URL` se impostata in
   Settings → CI/CD → Variables). Il repo — anche il mirror pubblico su
   GitHub — contiene solo un placeholder
3. Push su `main` del GitLab privato → la pipeline compila e pubblica su Pages:
   - `<ota_base_url>/<variante>/manifest.json`
   - `<ota_base_url>/<variante>/firmware.ota.bin` (OTA)
   - `<ota_base_url>/<variante>/firmware.factory.bin` (flash via ESP Web Tools)
4. I device controllano il manifest ogni 6 h (`update_interval`) e in Home
   Assistant compare l'entità update quando `version` cambia. L'entità è
   `disabled_by_default`: abilitala in HA la prima volta.

## Requisiti GitLab (self-hosted)

- Runner Docker con accesso internet (ghcr.io + toolchain PlatformIO; la cache CI riduce i tempi dopo la prima build)
- GitLab Pages abilitato e, per questo progetto, **senza access control**
  (Settings → General → Visibility → Pages: *Everyone*): i device ESPHome non
  possono autenticarsi. In LAN puoi comunque limitare l'esposizione a livello rete.

## Migrazione dei device già installati

I device flashati con il vecchio firmware del fork puntano ancora al manifest
upstream (everythingsmarthome.github.io) — **non usarlo**: servirebbe firmware
per ESP32 classico, non C3. Serve un ultimo aggiornamento manuale:

1. Compila e flasha via ESPHome Dashboard/CLI (OTA di rete va bene) la nuova
   variante `*-esp32c3.yaml`
2. Da quel momento l'update entity punta al tuo GitLab e gli aggiornamenti
   successivi sono OTA automatici. Il firmware 1.5.0 upstream include anche
   l'action HA `esphome.<device>_set_update_manifest` per cambiare manifest a runtime.
