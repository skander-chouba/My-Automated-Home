# 🏠 Local Smart Home & Home Assistant Setup (Ubuntu + Docker + BLE)

Complete documentation for deploying a local, cloud-free **Home Assistant** instance in Docker on Ubuntu, passing through the onboard Intel Bluetooth controller (`hci0`) to control **Philips Hue Bluetooth (BLE)** bulbs (`Bulb 1` & `Bulb 2`), and integrating the **Samsung Galaxy S24 Ultra** (`my S24Ultra`) for automated state triggers.

---

## 🖥️ 1. System Architecture & Hardware Inventory

* **Host Machine:** Ubuntu Linux (`skander-chouba-SER8`)
* **Host Local IP:** `192.168.0.164` (Port `8123`)
* **Bluetooth Controller:** Intel Corporate (`hci0` — MAC: `A8:59:5F:F9:E9:C0`)
* **Smart Lighting:** 2x Philips Hue Bluetooth Bulbs (`Bulb 1`, `Bulb 2` assigned to the `Bedroom` area)
* **Mobile Device & Sensor Hub:** Samsung Galaxy S24 Ultra (`my S24Ultra`) running the official Home Assistant Companion App

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

---

## 🎨 5. Saved Scenes (`Cool Bright` & Presets)

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

## ⚡ 6. Automation Blueprint: Evening Phone Charging Light Control

Automatically sets the Bedroom lights (`Bulb 1` and `Bulb 2`) to a warm, low-brightness evening mode (`21%` brightness, `2563K` warm color temperature) when the S24 Ultra is plugged in to charge between 6:00 PM and 5:00 AM.

### YAML Configuration (`Light Automation Test`)
*(Located in `~/docker/homeassistant/config/automations.yaml` or via the UI editor)*

```yaml
alias: Light Automation Test
description: Set Bedroom bulbs to warm 21% brightness when S24 Ultra starts charging at night
triggers:
  - trigger: state
    entity_id:
      - sensor.my_s24ultra_battery_state
    to:
      - charging
    for:
      hours: 0
      minutes: 0
      seconds: 10
conditions:
  - condition: time
    after: "18:00:00"
    before: "05:00:00"
actions:
  - action: light.turn_on
    metadata: {}
    target:
      area_id: bedroom
    data:
      color_temp_kelvin: 2563
      brightness_pct: 21
mode: single
```

---

## 🛠️ 7. Troubleshooting & Lessons Learned

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| **Phone app fails with `ERR_CONNECTION_ABORTED` on `192.168.0.164:8123`** | Host firewall (`ufw`) or active **NordVPN** tunnel dropping local LAN HTTP requests. | Run `sudo ufw allow 8123/tcp` and `nordvpn whitelist add subnet 192.168.0.0/24` (or disconnect NordVPN). |
| **Automation error: `two or more values in the same group of exclusion 'brightness'`** | Both `brightness_pct` (absolute %) and `brightness_step_pct` (relative step %) were selected in `light.turn_on`. | Only use **`brightness_pct`** (e.g., `21`) and uncheck `brightness_step_pct`. |
| **Charging trigger didn't fire automatically when plugging in phone** | Trigger was filtering for `from: not_charging` to `charging`, but Android reports **`discharging`** when unplugged. | Leave the **`from:`** field blank (or set to `discharging`) and only require **`to: charging`**. |
| **GitHub CLI / `git clone` password authentication error** | GitHub deprecated account passwords for Git HTTPS operations. | Authenticate via GitHub CLI (`sudo apt install gh && gh auth login`). |
