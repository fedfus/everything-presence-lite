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

## Sync con l'upstream (automatico)

Catena completamente automatica:

```
EPL upstream → (GitHub Action "Sync upstream", 05:00 UTC) → github/fedfus main
             → (job GitLab "sync-github" schedulato)      → gitlab main
             → pipeline build+pages                        → OTA ai device
```

- `.github/workflows/sync-upstream.yml`: merge giornaliero dell'upstream nel
  fork GitHub. In caso di conflitto il job fallisce (email da GitHub).
- job `sync-github` in `.gitlab-ci.yml`: gira su una Pipeline schedule
  (consiglio: un'ora dopo la Action). Richiede la variabile CI/CD
  `GITLAB_PUSH_TOKEN` (project access token, ruolo Maintainer, scope
  `write_repository`, masked). Se i rami divergono il push fallisce → notifica.

Sync manuale (o risoluzione conflitti): `./scripts/sync-upstream.sh` in locale,
poi push su GitHub (il GitLab si riallinea alla schedule successiva, o pushi
anche lì direttamente).

Unico punto di attenzione: l'overlay "aggancia" per id alcuni componenti
upstream (`bus_a`, `esp32_led`, `uart_bus`, `flash_button`). Se upstream li
rinomina, il job `validate` della pipeline fallisce e l'overlay va ritoccato.

## Release OTA

1. La versione firmware è automatica: `<versione upstream>+c3.<numero pipeline>`
   (es. `1.5.0+c3.42`), calcolata dalla CI. Il `fork_version` committato nei
   file `*-esp32c3.yaml` serve solo come fallback per le build manuali
2. L'URL OTA non è committato: la pipeline lo inietta a build time
   (`$CI_PAGES_URL`, oppure la variabile CI `OTA_BASE_URL` se impostata in
   Settings → CI/CD → Variables). Il repo — anche il mirror pubblico su
   GitHub — contiene solo un placeholder
3. Push (o sync automatico) su `main` del GitLab → la pipeline compila e pubblica su Pages:
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
