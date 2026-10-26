# 🏠 Local Smart Home & Home Assistant Setup (Ubuntu + Docker + BLE)

Complete documentation for a local **Home Assistant** instance in Docker on Ubuntu: it passes through the onboard Intel Bluetooth controller (`hci0`) to control **Philips Hue Bluetooth (BLE)** bulbs (`Bulb 1` & `Bulb 2`), uses the **Samsung Galaxy S24 Ultra** (`my S24Ultra`) and the Ubuntu desktop for presence, activity and sleep triggers, and shows everything on a custom **Home** dashboard with **Google Calendar**. Lights and automations run locally; only the weather forecast and Google Calendar need the internet.

---

## 🖥️ 1. System Architecture & Hardware Inventory

* **Host Machine:** Ubuntu Linux (`skander-chouba-SER8`)
* **Host Local IP:** `192.168.0.164` (Port `8123`)
* **Bluetooth Controller:** Intel Corporate (`hci0` — MAC: `A8:59:5F:F9:E9:C0`)
* **Smart Lighting:** 2x Philips Hue Bluetooth Bulbs (`Bulb 1`, `Bulb 2` assigned to the `Bedroom` area)
* **Home Assistant version:** 2026.10.4 (`stable` image)
* **Wearable:** Galaxy Watch8 registered through the Companion App
* **Mobile Device & Sensor Hub:** Samsung Galaxy S24 Ultra (`my S24Ultra`) running the official Home Assistant Companion App
* **Remote access:** Tailscale (the phone reaches `:8123` over the tailnet away from home)
* **Cloud services:** Met.no weather (`weather.forecast_home`), Google Calendar (section 8)
* **Frontend add-ons:** HACS with Mushroom and card-mod (section 8)

---

## ⚙️ 2. Host Prerequisites (Bluetooth, Firewall & VPN)

Before starting the Docker container, the Ubuntu host requires `BlueZ` and `dbus-broker` to pass Bluetooth Low Energy (BLE) traffic into the container, plus firewall and VPN local subnet whitelisting so the phone can reach port `8123`.

```bash
# 1. Install and enable the Bluetooth stack and D-Bus broker
sudo apt update && sudo apt install -y bluez dbus-broker
sudo systemctl enable --now dbus-broker
sudo systemctl enable --now bluetooth

# 2. Verify the onboard Bluetooth controller (hci0) is visible
bluetoothctl list

# 3. Open port 8123 on Ubuntu's firewall for the mobile companion app
sudo ufw allow 8123/tcp

# 4. Whitelist the local LAN subnet in NordVPN (prevents VPN from blocking phone -> PC traffic)
nordvpn whitelist add subnet 192.168.0.0/24
```

---

## 🐳 3. Docker Compose Configuration

Create the project directory and `docker-compose.yml` file:

```bash
mkdir -p ~/docker/homeassistant/config
cd ~/docker/homeassistant
nano docker-compose.yml
```

### `docker-compose.yml`
```yaml
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=Europe/Berlin
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
```

### Why These Flags Are Required:
* **`network_mode: host`**: Exposes port `8123` directly on the host network interface and allows mDNS/UPnP and mobile app auto-discovery.
* **`/run/dbus:/run/dbus:ro`**: Mounts the host D-Bus socket inside the container so Home Assistant can communicate directly with Ubuntu's `BlueZ` Bluetooth daemon (`hci0`).
* **`privileged: true`**: Grants the container kernel capabilities to manage Bluetooth Low Energy states.

### Container Management Commands:
```bash
# Start Home Assistant in detached mode
docker compose up -d

# Restart Home Assistant
docker restart homeassistant

# View live container logs
docker logs -f homeassistant
```

---

## 📱 4. Device Onboarding & Integrations

Access the web UI at **`http://localhost:8123`** (or **`http://192.168.0.164:8123`** on the local Wi-Fi network).

### A. Onboard Bluetooth Adapter (`hci0`) & iBeacon Tracker
1. Navigate to **Settings** $\rightarrow$ **Devices & services**.
2. Home Assistant auto-discovers the **Bluetooth** integration (`hci0 (A8:59:5F:F9:E9:C0)`) and **iBeacon Tracker**.
3. Click **Configure** $\rightarrow$ **Submit** to activate local BLE scanning.

### B. Smartphone Integration (`my S24Ultra`)
1. Install the **Home Assistant** app (by Open Home Foundation) from the Google Play Store.
2. Connect the phone to the same local Wi-Fi network as the Ubuntu host (`192.168.0.x`) and ensure NordVPN is either disconnected or has `192.168.0.0/24` whitelisted on the host.
3. Connect to `http://192.168.0.164:8123` and log in.
4. Grant background location and sensor permissions. The phone registers under **Settings** $\rightarrow$ **Devices & services** $\rightarrow$ **Mobile App** as `my S24Ultra`.

### C. Philips Hue Bluetooth Bulbs (`Bulb 1` & `Bulb 2`)
1. Open the **Philips Hue** app on the phone $\rightarrow$ **Settings** $\rightarrow$ **Voice Assistants** $\rightarrow$ **Amazon Alexa** $\rightarrow$ tap **Make Discoverable** (puts the bulbs into BLE pairing mode).
2. Pair the bulbs in Home Assistant under **Settings** $\rightarrow$ **Devices & services** $\rightarrow$ **+ Add integration** $\rightarrow$ **Philips Hue BLE** (and assign them to the **Bedroom** area as `Bulb 1` and `Bulb 2`).

### D. HACS, Google Calendar & Dashboard
See section 8: HACS (Mushroom, card-mod), the Google Calendar integration and the **Home** dashboard.

---

## 🎨 5. Saved Scenes

Defined in `config/scenes.yaml`, each sets both bedroom bulbs:

| Scene | Brightness | Color temp | Used by |
| :--- | :--- | :--- | :--- |
| `scene.cool_bright` | 100% (254) | 4000 K | Coming home after Sunset |
| `scene.energize` | 100% (254) | 6410 K | — |
| `scene.sleepy` | 25% (64) | 2000 K | Light Automation Test |
| `scene.storybook` | 70% (177) | 2702 K | — |

Scenes capture the exact current state (On/Off, brightness, and color temperature) of specific light entities so they can be recalled with one tap or inside automations.

### How to Create a Scene:
1. Set the lights (`Bulb 1` and `Bulb 2`) to the desired brightness and color temperature.
2. Go to **Settings** $\rightarrow$ **Automations & scenes** $\rightarrow$ **Scenes** $\rightarrow$ **+ Create scene**.
3. Name the scene (e.g., `Cool Bright`).
4. Under **Entities** (bottom dropdown), add **`Bulb 1`** and **`Bulb 2`** *(avoid using the top "Devices" dropdown so only light states are saved)*.
5. Click **Save**.

### How to Trigger a Scene:
* **Dashboard Button:** Go to **Overview** $\rightarrow$ **Bedroom** $\rightarrow$ click the **Edit (`✎`)** icon $\rightarrow$ **+ Add card** $\rightarrow$ **Tile / Button** $\rightarrow$ select `scene.cool_bright`.
* **In Automations:** Add Action $\rightarrow$ **Scene: Activate** $\rightarrow$ select `Cool Bright`.

---

## ⚡ 6. Automations

All automations live in `config/automations.yaml` (managed by the UI editor). Entities they depend on:

| Entity | Source |
| :--- | :--- |
| `light.bedroom_bulb_1`, `light.bedroom_bulb_2` | Philips Hue BLE (area `bedroom`) |
| `sensor.my_s24ultra_battery_state`, `sensor.my_s24ultra_sleep_confidence`, `binary_sensor.my_s24ultra_interactive`, `notify.mobile_app_my_s24ultra` | Companion app on `my S24Ultra` (sleep confidence and interactive sensors must be enabled in the app) |
| `person.skander_chouba` | Person, tracked by the phone |
| `binary_sensor.computer_active` | Pushed every 30 s by `host/ha-idle.sh` on the Ubuntu desktop (see section 7) |
| `binary_sensor.user_active` | Template helper: `on` when the phone is interactive **or** `binary_sensor.computer_active` is `on` |
| `input_boolean.geranium_outside` | Toggle helper "Geranium outside" (set by hand) |
| `weather.forecast_home` | Met.no weather integration |

| Automation | Trigger | Conditions | Action |
| :--- | :--- | :--- | :--- |
| **Light Automation Test** (bedtime charging) | Phone battery state `discharging` → `charging` for 10 s | 23:59–05:00, person `home` | Scene `Sleepy` |
| **Coming home after Sunset** | Person → `home` | After sunset or before sunrise | Scene `Cool Bright` |
| **Leaving home - bedroom lights off** | Person → `not_home` for 2 min | — | Turn off area `bedroom` |
| **Sleep detected - lights off** | `binary_sensor.user_active` → `off` for 15 min | Sleep confidence > 80, person `home`, 22:00–10:00 | Turn off all lights |
| **Geranium - move inside tonight** | Daily 18:00 | `geranium_outside` is `on`, lowest temp of the next 14 hourly forecasts < 5 °C | Phone notification |
| **Geranium - can go outside again** | Daily 09:00 | `geranium_outside` is `off`, month is April or May, lowest daily low of next 5 days ≥ 8 °C | Phone notification |

Time conditions such as `after: '23:59:00'` / `before: '05:00:00'` wrap past midnight automatically.

### Example: bedtime charging automation

```yaml
- id: '1792951025131'
  alias: Light Automation Test
  description: Turns on the Sleepy scene when I plug in my phone at night while I'm home.
  triggers:
  - trigger: state
    entity_id: sensor.my_s24ultra_battery_state
    from: discharging
    to: charging
    for: 00:00:10
  conditions:
  - condition: time
    after: '23:59:00'
    before: 05:00:00
  - condition: state
    entity_id: person.skander_chouba
    state: home
  actions:
  - action: scene.turn_on
    target:
      entity_id: scene.sleepy
  mode: single
```

### Example: forecast-based notification (Geranium)

```yaml
  actions:
  - action: weather.get_forecasts
    target:
      entity_id: weather.forecast_home
    data:
      type: hourly
    response_variable: forecast
  - variables:
      night_low: "{{ forecast['weather.forecast_home'].forecast[:14] | map(attribute='temperature') | select('number') | min }}"
  - condition: template
    value_template: '{{ night_low | float(99) < 5 }}'
  - action: notify.mobile_app_my_s24ultra
    data:
      title: Geranium
      message: Tonight's low is {{ night_low | round(0) | int }} °C. Move the geranium inside.
```

Toggle **Geranium outside** whenever the plant is moved, otherwise the reminders stop matching.

---

## 🖥️ 7. Computer Activity Sensor

`binary_sensor.computer_active` tells Home Assistant whether you are using the Ubuntu desktop. Together with the phone's `interactive` sensor it feeds `binary_sensor.user_active`, which the **Sleep detected - lights off** automation waits on.

`host/ha-idle.sh` runs as a systemd user service. Every 30 s it reads GNOME's idle time (`org.gnome.Mutter.IdleMonitor`, works on Wayland) and posts to `/api/states/binary_sensor.computer_active`:

* `on`: keyboard or mouse input within the last 2 minutes (`idle_seconds` attribute shows the idle time)
* `off`: idle for 2+ minutes, no GNOME session, or the service stopped

### Install

1. In Home Assistant, open your **Profile** → **Security** → **Long-lived access tokens** → **Create token**.
2. Save it outside the repo:
   ```bash
   mkdir -p ~/.config/ha-idle && nano ~/.config/ha-idle/token && chmod 600 ~/.config/ha-idle/token
   ```
3. Install and start the service:
   ```bash
   cp ~/docker/homeassistant/host/ha-idle.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now ha-idle
   ```

---

## 📊 8. Home Dashboard

A dark "glass" dashboard (**Home** in the sidebar, `http://localhost:8123/dashboard-home`) built with Lovelace, [Mushroom](https://github.com/piitaya/lovelace-mushroom) and [card-mod](https://github.com/thomasloven/lovelace-card-mod). It shows a greeting with chips (clock, weather, home/away, activity, phone battery, next calendar event), scene quick actions, room cards that switch all lights in each area, the weather forecast, a week agenda from Google Calendar, phone/computer activity and sleep status, the geranium toggle and switches for every automation.

| File | Purpose |
| :--- | :--- |
| `config/dashboards/home.yaml` | The dashboard (YAML mode: edit the file, then refresh the page) |
| `config/themes/glass-dark.yaml` | Theme: dark gradient, frosted cards, amber accent |
| `config/configuration.yaml` | Registers the dashboard and loads card-mod globally |

### Setup

1. Install HACS inside the container, then restart:
   ```bash
   docker exec -it homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"
   docker restart homeassistant
   ```
2. **Settings** → **Devices & services** → **+ Add integration** → **HACS**, and sign in with GitHub when asked.
3. In **HACS**, search for and download **Mushroom** and **card-mod**, then restart Home Assistant.
4. **Profile** → **Theme** → `glass-dark`.

HACS files go to `config/custom_components/` and `config/www/community/`, which are git-ignored.

### Google Calendar

The calendar section uses the official **Google Calendar** integration (read and write). Setup, from the [integration docs](https://www.home-assistant.io/integrations/google/):

1. In [Google Cloud Console](https://console.cloud.google.com/): create a project and enable the **Google Calendar API**.
2. **Google Auth Platform → Branding**: app name, support email, audience **External**. The "branding verification" warning can be ignored for personal use.
3. **Audience → Publish app** (otherwise the login expires every 7 days).
4. **Clients → Create client → Web application**, redirect URI `https://my.home-assistant.io/redirect/oauth`. Copy the Client ID and secret.
5. In HA: **Settings → Devices & services → + Add integration → Google Calendar**, paste the credentials, sign in (**Advanced → Go to Home Assistant (unsafe)** on the unverified-app warning), and set `http://localhost:8123` as the instance URL on my.home-assistant.io.

Each Google calendar becomes a `calendar.*` entity (`calendar.skander_chouba_gmail_com`, `calendar.family`, `calendar.birthdays`, holidays, …).

---

## 📁 9. Repository Layout

```
docker-compose.yml               # Home Assistant container
config/configuration.yaml        # Includes automations, scripts, scenes
config/automations.yaml          # Automations (section 6)
config/scenes.yaml               # Scenes (section 5)
config/scripts.yaml              # Empty
host/ha-idle.sh                  # Computer activity reporter (section 7)
host/ha-idle.service             # systemd user unit for it
config/dashboards/home.yaml      # Home dashboard (section 8)
config/themes/glass-dark.yaml    # Dashboard theme
domeassistantsetupgemini.txt     # Setup command notes
```

Secrets, `.storage/`, the database, logs and blueprints are excluded via `.gitignore`.

---

## 🛠️ 10. Troubleshooting & Lessons Learned

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| **Phone app fails with `ERR_CONNECTION_ABORTED` on `192.168.0.164:8123`** | Host firewall (`ufw`) or active **NordVPN** tunnel dropping local LAN HTTP requests. | Run `sudo ufw allow 8123/tcp` and `nordvpn whitelist add subnet 192.168.0.0/24` (or disconnect NordVPN). |
| **Automation error: `two or more values in the same group of exclusion 'brightness'`** | Both `brightness_pct` (absolute %) and `brightness_step_pct` (relative step %) were selected in `light.turn_on`. | Only use **`brightness_pct`** (e.g., `21`) and uncheck `brightness_step_pct`. |
| **Charging trigger didn't fire automatically when plugging in phone** | Trigger was filtering for `from: not_charging` to `charging`, but Android reports **`discharging`** when unplugged. | Set **`from:`** to `discharging` (current setup) or leave it blank. Blank also covers plugging in from `full` / `not_charging`. |
| **Sleep automation never fires** | `binary_sensor.computer_active` stuck at `on` because the old reporter script stopped without sending `off`. | The current `host/ha-idle.sh` sends `off` on stop and when no GNOME session is found. Check it with `systemctl --user status ha-idle`. |
| **`binary_sensor.computer_active` missing from Settings → Entities** | It is set through the REST API, so it has no registry entry and disappears after an HA restart until the next report (≤ 30 s). | Expected; it still works in templates and automations. |
| **Dashboard card shows `Custom element doesn't exist: mushroom-…`** | Mushroom not installed, or the browser cached the old frontend. | Download Mushroom in HACS, restart HA, then hard-refresh the page (Ctrl+Shift+R). |
| **HACS install fails with `wget: bad address 'get.hacs.xyz'`** | Temporary DNS failure inside the container (HA logs showed similar DNS timeouts for Met.no). | Run the install command again; check the host with `getent hosts get.hacs.xyz`. |
| **`Permission denied` editing `config/configuration.yaml`** | Files created by the container are owned by `root`. | Edit with `sudo` (e.g. `sudo nano config/configuration.yaml`), then restart HA. |
| **Google Cloud shows "Branding verification issues" for `home-assistant.io`** | Google can't verify a domain you don't own. Only matters for apps used by other people. | Cancel and ignore it. Accept the "unverified app" warning during sign-in (**Advanced → Go to Home Assistant (unsafe)**). |
| **Google Calendar credentials saved but no `calendar.*` entities** | The account-linking flow was closed before Home Assistant showed **Success!**. | Add the **Google Calendar** integration again; the saved credentials are reused. Wait for **Success!** before closing anything. |
| **Google Calendar stops syncing after 7 days** | The Google Cloud app is still in **Testing**. | **Google Auth Platform → Audience → Publish app**, then re-authenticate in HA. |
| **GitHub CLI / `git clone` password authentication error** | GitHub deprecated account passwords for Git HTTPS operations. | Authenticate via GitHub CLI (`sudo apt install gh && gh auth login`). |
