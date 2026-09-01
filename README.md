# CandyBarV2

A self-contained kiosk queue-number display system with web-based admin panel.

## Prerequisites

- Python 3.8 or higher
- Linux system (Ubuntu/Debian or Raspberry Pi OS)
- Audio output device

## Running on Local PC

```bash
git clone <repository-url>
cd CandyBarV2
./run
```

Access admin panel: `http://localhost:8080/admin` (PIN: 1234)

## Running on Raspberry Pi Zero 2 W

### Hardware
- Raspberry Pi Zero 2 W
- MicroSD card (16GB+)
- HDMI display
- Network connection
- Audio output

### Setup
```bash
# Install Raspberry Pi OS Lite with SSH and WiFi enabled
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-venv python3-pip git

git clone <repository-url>
cd CandyBarV2
./run
```

Access admin panel: `http://<PI-IP>:8080/admin` (PIN: 1234)
