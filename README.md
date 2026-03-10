# MQTT Downstream

A Home Assistant addon that syncs entities to a downstream MQTT broker. Useful for exposing a subset of your HA entities to external systems, guest networks, or other HA instances via MQTT discovery.

## How it works

- Connects to HA via WebSocket and subscribes to all state changes
- Publishes MQTT discovery (`/config`), state (`/state`), and attribute sub-topics for each resolved entity
- Routes inbound MQTT commands back to HA services
- Re-runs discovery automatically on startup, when any config dropdown changes, or when an MQTT birth message is received
- When an entity is removed from the resolved list, its discovery payload is cleared from the broker
- New entities added to HA after startup are detected automatically and re-evaluated against configured globs
- Supports multiple instances — each instance operates independently with its own configuration

## Installation

1. Copy the `mqtt_downstream` folder to `/addons/` on your HA host
2. Go to **Settings → Add-ons → Add-on Store → ⋮ → Check for updates**
3. Install **MQTT Downstream** from the Local Add-ons section
4. Create the required helpers, configure the options, and start the addon

## Prerequisites

Create the following helpers in HA (**Settings → Helpers → Add Helper → Dropdown**) as needed:

| Helper | Purpose |
|---|---|
| Entity list | Entity IDs or glob patterns to include (e.g. `light.kitchen`, `cover.*`) |
| Area list | Area names whose entities should be included (e.g. `Living Room`) |
| Domain list | Domain names to include all entities of (e.g. `light`, `cover`, `climate`) |
| Exclude list | Glob patterns to exclude after all other resolution (e.g. `light.debug_*`) |

At least one of **entity list**, **area list**, or **domain list** must be configured.

## Entity resolution order

Entities are resolved in this order on startup and whenever any config dropdown changes:

1. **Entity list** — specific entity IDs and glob patterns expanded against all known HA entities
2. **Area list** — all entities belonging to the named areas via the HA entity registry
3. **Domain list** — all entities whose domain matches (e.g. `light` adds every `light.*` entity in HA)
4. **Exclude list** — removes any entities matching the exclusion glob patterns from the combined result

All sources are additive — an entity only needs to appear in one source to be included. A warning is logged if an area name is not found in HA, if an exclude pattern matches nothing, or if an explicitly listed entity is also matched by an exclude pattern.

## Configuration

| Option | Required | Default | Description |
|---|---|---|---|
| `mqtt_base` | ✅ | `homeassistant-guest` | Base topic for all state, attribute, and command messages. Also used as the unique identifier for MQTT discovery — must be unique per instance |
| `discovery_prefix` | ✅ | `homeassistant` | MQTT discovery topic prefix. Set to a custom value (e.g. `homeassistant-guest`) to prevent your main HA from picking up these entities — the downstream HA must set `discovery_prefix` to the same value in its `configuration.yaml` |
| `instance_name` | ❌ | — | Optional display label appended to entity names in the downstream HA (e.g. `Guest` → `Kitchen Light (Guest)`) and shown in addon log lines. Does not affect MQTT topics |
| `broker_host` | ✅ | — | MQTT broker hostname or IP |
| `broker_username` | ✅ | — | MQTT broker username |
| `broker_password` | ✅ | — | MQTT broker password (stored securely) |
| `entities_select` | ⚠️ | `input_select.mqtt_downstream_entities` | `input_select` entity ID for the entity watch list. Supports glob patterns |
| `areas_select` | ⚠️ | `input_select.mqtt_downstream_areas` | `input_select` entity ID for area names to include |
| `domains_select` | ⚠️ | `input_select.mqtt_downstream_domains` | `input_select` entity ID for domains to include. Adds all entities of the listed domains |
| `excludes_select` | ❌ | `input_select.mqtt_downstream_excludes` | `input_select` entity ID for glob exclusion patterns |
| `broker_port` | ❌ | `1883` | MQTT broker port |
| `discovery_on_startup` | ❌ | `true` | Run discovery when the addon starts |
| `discovery_on_dropdown` | ❌ | `true` | Run discovery when any config dropdown changes |
| `discovery_on_birth` | ❌ | `true` | Run discovery when an MQTT birth message is received |
| `retain` | ❌ | `true` | Publish all messages with the MQTT retain flag. Recommended — ensures the downstream HA restores the last known state on restart without waiting for a new change |
| `debug` | ❌ | `false` | Enable verbose logging including the full resolved entity list on startup and on any dropdown change |

⚠️ = at least one of these three must be configured.

## Topic structure

```
{discovery_prefix}/{domain}/{slug}/config   ← MQTT discovery payload
{mqtt_base}/{domain}/{slug}/state           ← Current state
{mqtt_base}/{domain}/{slug}/{attribute}     ← Attribute sub-topics
{mqtt_base}/{domain}/{slug}/set             ← Inbound command topic
{mqtt_base}/{domain}/{slug}/set_{attr}      ← Inbound attribute command topics
{mqtt_base}/{domain}/{slug}/send_command    ← Vendor-specific commands (vacuum, remote)
```

## Supported domains

`light`, `switch`, `lock`, `cover`, `climate`, `fan`, `media_player`, `number`, `select`, `text`, `button`, `scene`, `script`, `vacuum`, `humidifier`, `alarm_control_panel`, `valve`, `water_heater`, `siren`, `lawn_mower`, `remote`, `input_boolean`, `input_number`, `input_text`, `input_select`, `input_datetime`, `input_button`

## Domain mapping

HA helper domains are mapped to their MQTT equivalents:

| HA domain | MQTT domain |
|---|---|
| `input_boolean` | `switch` |
| `input_number` | `number` |
| `input_text` | `text` |
| `input_select` | `select` |
| `input_datetime` | `datetime` |
| `input_button` | `button` |

## Attribute sub-topics

| Domain | Sub-topics published |
|---|---|
| `light` | `brightness`, `color_temp`, `rgb`, `hs`, `xy`, `effect` (if supported) |
| `fan` | `percentage`, `preset_mode`, `oscillation`, `direction` (only if supported by device) |
| `climate` | `temperature`, `current_temperature`, `target_temp_high`, `target_temp_low`, `action`, `fan_mode`, `swing_mode`, `preset_mode` |
| `cover` | `position`, `tilt` |
| `media_player` | `volume`, `muted`, `source`, `sound_mode`, `media_title`, `media_artist` |
| `humidifier` | `target_humidity`, `current_humidity`, `mode` |
| `water_heater` | `temperature`, `current_temperature`, `mode`, `away_mode` |
| `vacuum` | `battery_level`, `status`, `fan_speed` (if supported) |
| `alarm_control_panel` | `code_format` |
| `valve` | `position` |
| `lawn_mower` | `battery_level` |

All attribute sub-topics are only published when the value is actually present on the entity — no empty payloads.

## Downstream HA setup

To have a downstream HA instance auto-discover the entities, add this to its `configuration.yaml` matching your `discovery_prefix` setting:

```yaml
mqtt:
  discovery_prefix: homeassistant-guest
```

## Multiple instances

This addon supports multiple instances. Each instance must have a unique `mqtt_base` value — this is used as the MQTT topic namespace and as the entity unique ID prefix, so two instances with different `mqtt_base` values will produce completely separate, non-conflicting entities in the downstream HA.

Set `instance_name` on each instance (e.g. `Guest`, `IoT`, `Automation`) to distinguish them in the addon log and in downstream entity names.

**Example — two instances:**

| | Instance 1 | Instance 2 |
|---|---|---|
| `mqtt_base` | `homeassistant-guest` | `homeassistant-iot` |
| `instance_name` | `Guest` | `IoT` |
| `discovery_prefix` | `homeassistant-guest` | `homeassistant-iot` |

## Enable / disable toggle

You can expose an `input_boolean` helper as a switch to control whether the addon is running. This is useful for temporarily disabling the downstream without going into the addon UI, or for building automations around it (e.g. disable at night, disable when guests leave).

**1. Create the helper**

Go to **Settings → Helpers → Add Helper → Toggle** and name it `mqtt_downstream_enabled`.

**2. Add a `rest_command` to `configuration.yaml`**

The Supervisor API is the correct way to set `boot` and `watchdog` on an addon — there is no native HA service for this:

```yaml
rest_command:
  mqtt_downstream_enable:
    url: "http://supervisor/addons/local_mqtt_downstream/options"
    method: POST
    headers:
      Authorization: "Bearer {{ states('sensor.supervisor_token') }}"
      Content-Type: application/json
    payload: '{"boot": "auto", "watchdog": true}'

  mqtt_downstream_disable:
    url: "http://supervisor/addons/local_mqtt_downstream/options"
    method: POST
    headers:
      Authorization: "Bearer {{ states('sensor.supervisor_token') }}"
      Content-Type: application/json
    payload: '{"boot": "manual", "watchdog": false}'
```

> **Note:** Replace `local_mqtt_downstream` with your actual addon slug. The Supervisor token can be obtained from the `SUPERVISOR_TOKEN` environment variable — the easiest way is to expose it via a template sensor or use a hardcoded long-lived access token.

**3. Create the automation**

```yaml
automation:
  - alias: "MQTT Downstream — Enable / Disable"
    trigger:
      - platform: state
        entity_id: input_boolean.mqtt_downstream_enabled
    action:
      - choose:
          - conditions:
              - condition: state
                entity_id: input_boolean.mqtt_downstream_enabled
                state: "on"
            sequence:
              - service: rest_command.mqtt_downstream_enable
              - service: hassio.addon_start
                data:
                  addon: mqtt_downstream
          - conditions:
              - condition: state
                entity_id: input_boolean.mqtt_downstream_enabled
                state: "off"
            sequence:
              - service: hassio.addon_stop
                data:
                  addon: mqtt_downstream
              - service: rest_command.mqtt_downstream_disable
```

When turned **off**, the addon is stopped and `boot: manual` + `watchdog: false` are set via the Supervisor API — preventing HA from restarting it automatically. When turned **on**, the options are restored before the addon starts.

> **Note:** If running multiple instances, use the full slug shown in the addon URL (e.g. `mqtt_downstream_2`) in the `addon` field.

When the addon is stopped, the downstream HA will retain the last published states from the broker until they are overwritten or the broker is restarted — entities will not disappear, they will just stop updating.

To re-run discovery without restarting the addon, trigger any of the following:

- Edit any option in a configured dropdown helper — the state change triggers re-expansion and re-discovery automatically
- Publish `online` to `{mqtt_base}/status` via any MQTT client

## Notes

- Glob patterns (e.g. `light.*`, `*.kitchen_*`) are supported in the entity list and exclude list
- Area entities are resolved via the HA entity registry — area assignment changes are picked up on the next dropdown change or restart
- The addon connects directly to the broker; it does not route through HA's MQTT integration
- **Recommended:** use a broker that supports per-user topic ACLs rather than HA's built-in MQTT broker. HA's integration only supports per-user credentials with no topic-level restrictions — a standalone broker lets you lock Guest HA credentials down to command topics only, preventing it from publishing to state or discovery topics even if credentials are compromised. Good options are **Mosquitto** (ACLs via config file, lightweight) or **EMQX** (ACLs via web dashboard, easier to manage for multiple users). See `ARCHITECTURE.md` for an example ACL config
- Retained state topics are read-only on the downstream side — restoring retained state updates the UI but does not trigger automations or services
- When an entity is removed from the resolved list, its discovery topic is cleared (empty retained payload) causing the downstream HA to remove the entity. State and attribute sub-topics are **not** cleared from the broker — they remain with their last retained value until manually deleted or the broker is restarted

---

## Support

If this addon saves you some time or adds value to your setup, consider buying me a home automation toy ☕

[![Buy Me A Home Automation Toy](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://www.buymeacoffee.com/maxwellluong)