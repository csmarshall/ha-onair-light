# Home Assistant — On-Air / Busy Status Light

A **dedicated** status light for a home office: one physical bulb that shows whether you're busy, available, on-air, or do-not-disturb. Drive it from a Home Assistant dashboard, an Elgato Stream Deck, or automatically from **MuteDeck** meeting state across every machine you work on. It's one self-contained Home Assistant package — no custom integrations, no add-ons.

Everything past the dashboard is optional: MuteDeck automation and the Stream Deck color mirror each stand alone, so you can start with just a dashboard button.

> 📦 **Download:** grab the latest `ha-onair-light-vX.Y.Z.zip` bundle from the [Releases](https://github.com/csmarshall/ha-onair-light/releases) page, or clone this repo.

## Prerequisites

- **A color (RGB) smart bulb, dedicated to this.** It's driven as a pure output and turned fully *off* when you're clear, so don't use a bulb you also want as normal room lighting.
- **Home Assistant** with access to your `/config` folder (Container, Core, or OS all work). **HA 2024.8+** recommended — the dashboard card uses the newer `perform-action` action; on older cores replace it with `call-service`.
- **For MuteDeck automation (optional):** a **Home Assistant Cloud / [Nabu Casa](https://www.nabucasa.com/)** subscription (used to mint the public webhook), and **[MuteDeck](https://mutedeck.com)** installed on a version that supports **outbound webhook notifications**.
- **For the Stream Deck mirror (optional):** the [cgiesche `streamdeck-homeassistant`](https://github.com/cgiesche/streamdeck-homeassistant) plugin and a Home Assistant **long-lived access token** (the plugin can't connect without one).

## Quick start (dashboard only)

1. Enable packages in `configuration.yaml` (one-time):
   ```yaml
   homeassistant:
     packages: !include_dir_named packages
   ```
2. In `status_light.yaml`, find/replace **every** `light.status_light_bulb` with your bulb's entity id.
3. Copy `status_light.yaml` into `/config/packages/`.
4. **Restart** Home Assistant (a full restart, not a reload — see below).
5. Add the card from [`dashboard-card.yaml`](dashboard-card.yaml) to a dashboard. Tap **Busy** → your bulb turns solid red. 🎉

Add [MuteDeck](#optional-mutedeck-automation) and the [Stream Deck mirror](#optional-stream-deck-color-mirror) when you want them.

## Features

- **Dedicated model.** The bulb is a pure output. One master switch (`input_boolean.status_light`) is the single source of truth — no virtual overlay light, no save/restore, no ghost entities. The dashboard always matches reality.
- **Resilience.** Recovery is biased toward staying on (a false "busy" is safer than a false "clear"): state restores across HA restarts, the bulb is re-driven the instant it reconnects, and a watchdog re-asserts on silent drift.
- **MuteDeck push.** Every machine's MuteDeck posts to one shared webhook; HA maps meeting state to the right preset. Push, not poll — no LAN access or exposed ports needed.
- **Stream Deck color mirror.** A single glanceable sensor collapses the light into one readable status and a display color, so a Stream Deck key shows live state and can drive the presets.

## How it works

The bulb (`input_text.status_light_target`) is driven purely as an **output**. The master switch `input_boolean.status_light` is the one source of truth:

| Master | Strobe | Result |
|--------|--------|--------|
| on | off | bulb solid color |
| on | on | bulb strobes |
| off | — | **bulb off** (dedicated light — nothing to save or restore) |

The dashboard binds to `input_boolean.status_light`, so it always reflects reality — and stays stably "on" while the bulb physically flickers during a strobe.

**Drivers.** Every state or look change funnels through one routine, `script.status_light_refresh`, which reads live state and drives the bulb: off → bulb off, on + strobe → a flashing loop, on + no strobe → steady color.

**Presets (scripts).** `status_light_busy`, `status_light_available`, `status_light_on_air`, `status_light_dnd`, `status_light_off`, `status_light_toggle`, plus a generic `status_light_apply(color, brightness, strobe)`. Call these from the dashboard, the Stream Deck plugin, or the MuteDeck automations.

**Recovery automations.** State-bearing helpers omit `initial:` so they restore their last value; a startup automation re-lights the bulb after an HA restart, a reconnect automation re-drives it the moment it returns from `unavailable`, and a 30-second watchdog re-asserts if the status is on but the bulb drifted off (strobe excluded — its loop self-asserts). Hard dependency: if HA itself is down nothing can drive the bulb, but a bulb already showing "busy" holds that state.

**MuteDeck receiver.** [MuteDeck](https://mutedeck.com) (recent versions) pushes a webhook on every status change. A meeting is a meeting, so every machine points at the **same** HA webhook and the last event wins. HA maps the payload to a meeting state and drives the matching preset:

| MuteDeck state | Meeting | Preset |
|----------------|---------|--------|
| in a call + camera on | on_air | **On Air** |
| in a call + camera off | busy | **Busy** |
| not in a call | off | **Off** |

Edit the mapping in the `status_light_mutedeck` automation if you want different behavior.

## Install

### Enable packages (one-time)

`/config` is your Home Assistant configuration directory — where `configuration.yaml` lives (Container/Core: wherever you mapped it; HA OS: reachable via the File editor, Samba, or Studio Code Server add-ons). Add:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

### Core (dashboard control)

1. **Point it at your bulb.** In `status_light.yaml`, replace **every** occurrence of `light.status_light_bulb` with your bulb's entity id. A global find/replace is the clean way — there are three functional spots (the `status_light_target` default, the **Reconnect Recovery** trigger, and the **Watchdog** condition); the recovery/watchdog ones are `state` triggers/conditions so they *must* name your entity literally.
2. **Copy the files in.** Put `status_light.yaml` in `/config/packages/`. Or run `./deploy.sh` (override locations with `HA_PACKAGES=... HA_WWW=... ./deploy.sh`; the packages dir is often root-owned, so you may need `sudo`). `deploy.sh` also copies the Stream Deck theme into `/config/www/` — harmless if you don't use Stream Deck.
3. **Restart Home Assistant** (**Settings → System → Restart**). A *full restart* is required the first time: the package adds new `input_*` helper entities, and those aren't created by a YAML reload.
4. **Add the dashboard card.** Edit a dashboard → **Add card → Manual** → paste [`dashboard-card.yaml`](dashboard-card.yaml).

That's the whole light. The two sections below add automatic/remote control.

### Optional: MuteDeck automation

Do the webhook-id step **before** you copy/deploy the package (the id has to be in the file that lands in `/config`; if you already deployed, re-copy afterward).

1. **Set a unique webhook id.** Run `./setup.sh` — it replaces the `statuslight_meeting_CHANGE_ME` placeholder in `status_light.yaml` with a random id (and backs up the original). Then copy/deploy and restart HA.
2. **Create the cloud webhook.** In HA: **Settings → Home Assistant Cloud → Webhooks**. The *"Status Light - MuteDeck Receiver"* automation appears in that list once it's loaded — toggle it on and **copy the generated `https://hooks.nabu.casa/...` URL**. (The automation already sets `local_only: false`, which is what lets the cloud hook reach it.)
3. **Point MuteDeck at it.** Paste that URL into **MuteDeck → Settings → Notifications** on each machine you want reporting meeting state. Mapping: in a call + camera on → **On Air**; camera off → **Busy**; not in a call → **Off**.

> Keep the `hooks.nabu.casa/...` URL private — anyone who has it can drive your light. The mapping keys on MuteDeck's `call` / `video` webhook fields; if your MuteDeck version's payload or menu path differs, adjust the `status_light_mutedeck` automation.

### Optional: Stream Deck color mirror

Uses the [cgiesche `streamdeck-homeassistant`](https://github.com/cgiesche/streamdeck-homeassistant) plugin — a Stream Deck key that shows the light's live color + status (handy for a bulb that's out of sight).

1. **Connect the plugin to HA first.** In the plugin's **Global Settings**, set your HA **Server URL** and a **long-lived access token** (HA → your profile → **Security → Long-Lived Access Tokens → Create Token**). Without the token it can't connect.
2. **Serve the theme.** Make sure `streamdeck-theme.yml` is in `/config/www/` (`deploy.sh` does this). Set the plugin's **Custom theme URL**:
   - Stream Deck on the same LAN as HA: `http://<HA-IP>:8123/local/streamdeck-theme.yml`
   - Off-LAN / via Nabu Casa: `https://<your-id>.ui.nabu.casa/local/streamdeck-theme.yml`

   Reconnect the plugin after setting it.
3. **Add a key.** Use the **Entity (generic)** action bound to `sensor.status_light_status`; **Icon Source** = Home Assistant; **Label** = `{{state}}`. **Short press** → `script.status_light_toggle`; **long press** → toggle `input_boolean.status_light_strobe`.

## Verify it works

- **Dashboard:** tap **Busy** → bulb goes solid red; tap **Off** → bulb off. `sensor.status_light_status` reads `Busy` / `Off`.
- **MuteDeck webhook** (no meeting required) — POST a test payload to your cloud webhook URL:
  ```bash
  curl -X POST -H "Content-Type: application/json" \
    -d '{"call":"active","video":"active"}' \
    https://hooks.nabu.casa/XXXXXXXX
  ```
  → `input_select.status_light_meeting` flips to `on_air` and the bulb goes On Air.

## Troubleshooting

- **Bulb doesn't respond at all** — confirm you replaced *all* `light.status_light_bulb` references, and that your bulb supports `rgb_color`.
- **Entities/helpers missing after install** — you reloaded instead of doing a full **restart**; the new `input_*` helpers require a restart.
- **Target bulb reverts after a restart** — you set `status_light_target` in the UI; edit the value in the YAML instead (the helper has an `initial:` that re-applies on start).
- **Cloud webhook doesn't appear in the list** — the automation failed to load; check **Developer Tools → YAML → Check Configuration** for errors.
- **Webhook does nothing / returns 405** — wrong URL, the cloud webhook isn't toggled on, or the request wasn't a `POST`.
- **Strobe doesn't flash** — some bulbs can't keep up with fast on/off toggles; lower the strobe Hz.

## Entities

| Kind | Entity | Purpose |
|------|--------|---------|
| `input_boolean` | `status_light` | Master on/off — the truth |
| `input_boolean` | `status_light_strobe` | Strobe on/off |
| `input_text` | `status_light_color` | Color, `[R, G, B]` string |
| `input_text` | `status_light_target` | The bulb entity to drive |
| `input_number` | `status_light_brightness` | 1–255 |
| `input_number` | `status_light_strobe_speed` | Strobe Hz |
| `input_select` | `status_light_strobe_preset` | Strobe speed presets |
| `input_select` | `status_light_meeting` | Meeting state from MuteDeck (any machine) |
| `sensor` | `status_light_status` | Glanceable status + display color for Stream Deck |

## Related projects

- [chelming/mutedeck2mqtt](https://github.com/chelming/mutedeck2mqtt) — bridges MuteDeck webhooks to MQTT for Home Assistant. This project skips the broker and takes MuteDeck's webhook straight into an HA webhook trigger (and works off-LAN via a Nabu Casa cloud webhook).
- [MuteDeck — "Do Not Disturb Light with MuteDeck and Home Assistant"](https://mutedeck.com/blog/do-not-disturb-light-with-mutedeck-and-home-assistant/) — the local-API *polling* approach this replaces with push.
- [Nick Moline — "Free 'On Air' Light for Business Meetings"](https://nickmoline.com/2024/11/13/your-smart-home-can-help-prevent-remote-work-meeting-blunders) — client-side call detection driving an on-air light.
- [popcornhax/hubitat-mutedeck](https://github.com/popcornhax/hubitat-mutedeck) — the same MuteDeck-webhook idea, for Hubitat.
- [cgiesche/streamdeck-homeassistant](https://github.com/cgiesche/streamdeck-homeassistant) — the Stream Deck plugin the color mirror targets. ([basnijholt/home-assistant-streamdeck-yaml](https://github.com/basnijholt/home-assistant-streamdeck-yaml) is a cross-platform alternative.)

## Credits

Adapted from an MIT-licensed Home Assistant community "Notify Light" template. MuteDeck integration via [mutedeck.com](https://mutedeck.com). Stream Deck support via the [`streamdeck-homeassistant`](https://github.com/cgiesche/streamdeck-homeassistant) plugin by cgiesche.
