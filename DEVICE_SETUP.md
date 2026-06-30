# CandyBarV2 — ARM Device Provisioning Guide

This covers everything needed to go from a fresh ARM Linux board (Raspberry Pi
or equivalent, Debian/Ubuntu-based) to a running kiosk. Do this once per device.

---

## 1. EMQX broker

### Why EMQX, and what we confirmed

CandyBarV2 uses EMQX 5 as its MQTT broker. We use it because:

- WebSocket listener (port 8083) is **enabled by default** — no extra config needed
- Single `apt` install, managed by systemd, auto-starts on boot
- ARM64 `.deb` packages are published officially by EMQ

The WebSocket path the browser pages connect to is `ws://<device-ip>:8083/mqtt`.
This matches EMQX 5's default `websocket.mqtt_path = "/mqtt"` exactly. Confirmed
on the dev machine against EMQX 5.7.0 (`emqx ctl listeners` output shows
`ws:default` bound to `0.0.0.0:8083`, `running: true`, out of the box).

### Install

```bash
# Add the EMQX apt repository
curl -s https://assets.emqx.com/scripts/install-emqx-deb.sh | sudo bash

# Install
sudo apt-get install -y emqx

# Enable and start
sudo systemctl enable emqx
sudo systemctl start emqx
```

### Verify listeners are up

```bash
sudo emqx ctl listeners
```

You should see four listeners all with `running: true`:

```
tcp:default   0.0.0.0:1883   ← paho (Python app) connects here
ssl:default   0.0.0.0:8883
ws:default    0.0.0.0:8083   ← browsers (admin + public pages) connect here
wss:default   0.0.0.0:8084
```

If `ws:default` is missing or `running: false`, the admin and public web pages
will not receive live MQTT updates. Fix by checking `emqx.conf` and restarting:

```bash
sudo systemctl restart emqx
sudo emqx ctl listeners
```

### Verify WebSocket port is actually bound

```bash
ss -tlnp | grep 8083
```

Expected output: a `LISTEN` line on `0.0.0.0:8083`.

### Auth / ACL

**EMQX 5 default auth state: anonymous access, intentionally.**

EMQX 5.x has no `allow_anonymous` flag. The rule is simpler: if no authenticator
is configured, every client connects without credentials. This installation has no
authenticator configured — confirmed by the stock `emqx.conf` and `base.hocon`
above, neither of which adds any `authentication` block.

This is an **intentional decision for v1**, not an oversight, for these reasons:

- The MQTT broker only listens on the local network (LAN). It is not exposed to
  the internet. Binding to `0.0.0.0` means all LAN interfaces, but the device
  should sit behind a router with no port-forwarding rules for 1883 or 8083.
- The data on the `display/#` topic is non-sensitive: queue numbers, a facility
  name, an accent color. There is nothing an attacker gains from reading or
  writing it beyond briefly disrupting a queue display.
- The admin PIN (stored in `candybar_display.ini`, enforced by the HTTP server)
  is the actual access control layer for staff operations. MQTT auth would be a
  second layer on top of that, not a replacement for it.

**If the threat model changes** (broker moved to a shared server, multi-location
deployment, or the `display/#` topic gains sensitive payloads), enable EMQX's
built-in database authenticator via the dashboard at
`http://<device-ip>:18083` → Access Control → Authentication → Add → Built-in
Database. Then set `CANDYBAR_MQTT_USER` and `CANDYBAR_MQTT_PASS` in the systemd
unit (see section 4). The browser pages use anonymous WebSocket connections and
would also need credentials passed to `mqtt.connect()` in `admin.html` and
`public.html`.

### Config files (for reference)

| File | Purpose |
|------|---------|
| `/etc/emqx/emqx.conf` | Static config — node name, cluster, dashboard port |
| `/etc/emqx/base.hocon` | Base defaults, merged before dashboard/API overrides |
| `/var/lib/emqx/data/configs/cluster.hocon` | Dashboard/API runtime overrides |

Do **not** add listener config to `emqx.conf` — the defaults are correct and
changes there take precedence over the dashboard in a confusing way. If you ever
need to override a listener, put it in `base.hocon`.

---

## 2. Python environment

```bash
# From the project root
python3 -m venv venv
source venv/bin/activate
pip install PySide6 paho-mqtt
```

> `aiohttp` is NOT required — it is dead code in the current repo and can be
> ignored.

---

## 3. Run the app

```bash
# From project root, with venv active
python3 -m example.main
```

The app will:
1. Connect to EMQX on `localhost:1883` (TCP, via paho)
2. Start the HTTP server on port 8080
3. Open the kiosk window fullscreen

Admin page: `http://<device-ip>:8080/admin`  
Public page: `http://<device-ip>:8080/`

---

## 4. systemd service (auto-start, auto-restart)

Create `/etc/systemd/system/candybar.service`:

```ini
[Unit]
Description=CandyBarV2 kiosk display
After=network.target emqx.service
Requires=emqx.service

[Service]
Type=simple
User=<your-user>
WorkingDirectory=/home/<your-user>/CandyBar v2
ExecStart=/home/<your-user>/CandyBar v2/venv/bin/python3 -m example.main
Restart=on-failure
RestartSec=5s

# Qt / display
Environment=DISPLAY=:0
Environment=QT_QPA_PLATFORM=xcb
# Use eglfs instead of xcb for bare-metal ARM without X11:
# Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QUICK_CONTROLS_STYLE=Basic

# MQTT broker — defaults point to localhost:1883 (EMQX on the same device).
# Override these if the broker moves to a separate machine or auth is enabled:
# Environment=CANDYBAR_MQTT_HOST=192.168.1.50
# Environment=CANDYBAR_MQTT_PORT=1883
# Environment=CANDYBAR_MQTT_USER=candybar
# Environment=CANDYBAR_MQTT_PASS=secret

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable candybar
sudo systemctl start candybar

# Watch logs
journalctl -u candybar -f
```

---

## 5. Moving the broker off-device (future)

If EMQX is later moved to a separate server, no code changes are needed.
Update the systemd unit:

```ini
Environment=CANDYBAR_MQTT_HOST=192.168.1.50
Environment=CANDYBAR_MQTT_PORT=1883
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart candybar
```

The browser pages always connect to `ws://<device-ip>:8083/mqtt` — the device IP
is the kiosk device's own IP, because the HTTP server and the EMQX broker are
both on the same device. If the broker moves to a separate machine but the HTTP
server stays on the kiosk device, the WebSocket URL in `admin.html` and
`public.html` will need to be updated to point to the broker's IP instead.

---

## 6. Port reference

| Port | Protocol | Used by |
|------|----------|---------|
| 1883 | MQTT/TCP | Python app → EMQX |
| 8083 | MQTT/WS  | Browser admin + public pages → EMQX |
| 8080 | HTTP     | Admin and public web pages (served by CandyBarV2) |
| 18083 | HTTP    | EMQX dashboard (staff/ops only, not customer-facing) |
