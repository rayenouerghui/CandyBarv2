# CandyBarV2

A self-contained kiosk queue-number display system with web-based admin panel.

![Data Flow Diagram](./Dataflow%20Diagram.png)

## Features

- **Queue Display**: Fullscreen Qt/QML display showing current queue numbers
- **Web Admin Panel**: Manage display from any device on the local network
- **Multi-language Support**: English, French, and Arabic with RTL support
- **Audio Announcements**: TTS-based number announcements
- **Customizable**: Fonts, colors, layouts, backgrounds, and logos
- **Persistent Settings**: All settings survive power loss
- **MQTT Integration**: Optional MQTT broker for distributed systems

## Tech Stack

| Layer | Technology |
|-------|------------|
| Display UI | PySide6 + QML (Qt 6) |
| HTTP Server | Python stdlib http.server |
| Messaging | paho-mqtt (MQTT) |
| Audio | pygame.mixer + edge-tts |
| Persistence | QSettings INI file |

## Installation

### Prerequisites

- Python 3.8 or higher
- Linux system (tested on Ubuntu 22.04)
- Audio output device

### Quick Start

```bash
# First run (creates venv, installs deps, compiles resources, generates audio)
./run

# Subsequent runs
./run
```

The script will:
1. Create a Python virtual environment
2. Install all dependencies from `requirements.txt`
3. Compile QML resources
4. Generate TTS audio files
5. Launch the application

### Manual Installation

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Compile resources
python scripts/update_resources.py

# Generate audio files (requires internet)
python scripts/generate_audio.py --output-dir ~/.local/share/CandyBarV2/CandyBarV2/audio

# Run the application
python -m app.main
```

## Usage

### Starting the Application

```bash
./run
```

The application will:
- Launch the fullscreen display on the main screen
- Start the web server on port 8080
- Display the LAN IP address for remote access

### Accessing the Admin Panel

From any device on the same network:

```
http://<LAN-IP>:8080/admin
```

**Default PIN:** `1234`

### Admin Panel Features

The admin panel provides the following tabs:

- **Home**: Quick access to main features
- **Remote**: Control queue numbers and audio
- **Settings**: Configure categories, facility name, banner text, TTS, and admin PIN
- **Theme**: Customize fonts, colors, layouts, backgrounds, and logos
- **Health**: Monitor system uptime and activity

### Queue Management

1. Navigate to the **Remote** tab
2. Use the stepper to increment/decrement the queue number
3. Click "Call Next" to announce the number
4. Adjust volume and mute audio as needed

### Customization

#### Fonts
- Choose from 5 built-in fonts: DM Mono, Barriecito, DT Getai Grotesk Display Black, Gluten, LC Mogi, Manosque
- Set font size for each text element independently
- Customize colors for numbers, categories, facility name, banner, and "NOW SERVING" label

#### Layouts
- **Classic**: Traditional vertical layout
- **Split**: Two-column layout with next-up queue
- **Centered**: Centered single-column layout

#### Backgrounds
- Choose from built-in templates
- Upload custom background images
- Adjust fit mode (crop, fit, stretch, auto)
- Fine-tune position and scale with adjustment sliders

#### Logo
- Upload custom logo
- Position: top-left, top-center, or hidden
- Adjustable size

## Configuration

### Settings Persistence

All settings are automatically saved to:
```
~/.local/share/CandyBarV2/CandyBarV2/candybar_display.ini
```

Settings include:
- Current queue number
- Category information
- Display layout and styling
- Audio preferences
- Background and logo settings
- Admin PIN

### Audio Configuration

Audio files are stored in:
```
~/.local/share/CandyBarV2/CandyBarV2/audio/
```

Structure:
```
audio/
├── en/
│   ├── numbers/     # Individual number audio files
│   ├── phrases/     # "NOW SERVING" etc.
│   └── category/    # Category name audio
├── fr/              # Same structure for French
└── ar/              # Same structure for Arabic
```

### MQTT Configuration

To enable MQTT integration, configure the broker in `app/mqtt_client.py`:
- Broker host and port
- Topic structure: `display/<category>/<key>`
- Connection settings

## Project Structure

```
CandyBarV2/
├── app/                    # Main application
│   ├── main.py            # Entry point, Qt init, context properties
│   ├── mqtt_client.py     # MQTT client and Qt signal bridge
│   ├── helper/            # Helper modules
│   │   ├── AudioEngine.py          # pygame TTS playback
│   │   ├── CategoryAudioHelper.py  # edge-tts generation
│   │   ├── DisplayPersistence.py   # QSettings persistence
│   │   ├── FontManager.py          # Custom font registration
│   │   ├── NetworkHelper.py        # LAN IP discovery
│   │   └── UsageStats.py           # Uptime/session counters
│   └── imports/app/qml/   # QML UI files
│       ├── global/
│       │   ├── DisplayState.qml    # Central state registry
│       │   └── qmldir             # QML module registration
│       ├── App.qml                 # Root window
│       ├── MainDisplay.qml         # Boot splash orchestration
│       ├── DisplayView.qml         # All display layouts
│       ├── WelcomeSplash.qml       # Boot screen
│       ├── ConnectionBanner.qml    # MQTT status
│       └── CustomerSiteQrOverlay.qml  # QR code overlay
├── web/                    # Web admin panel
│   ├── server.py          # HTTP server and API handlers
│   ├── admin.html         # Admin UI (HTML+CSS+JS)
│   └── public.html        # Read-only customer display
├── scripts/               # Utility scripts
│   ├── generate_audio.py         # TTS audio generation
│   ├── sync_sounds.py            # Audio file sync
│   └── update_resources.py        # QRC compilation
├── resources/            # Bundled assets
│   ├── audio/            # Pre-generated audio files
│   └── fonts/            # Custom font files
├── fluentui/             # Vendored FluentUI components
├── requirements.txt      # Python dependencies
├── CODEBASE.md          # Technical documentation
└── README.md            # This file
```

## Data Flow

The application follows a strict data flow pattern:

```
Admin Panel (web)
  → POST /api/publish
    → server.py Handler._handle_publish()
      → DisplayPersistence.save()
      → MQTTClient.direct_command()
        → Command queue (thread-safe)
          → Qt main thread timer
            → DisplayState.applyMqttCommand()
              → QML property updates
              → AudioEngine.announceNumber()
```

**Key principle:** `DisplayState.applyMqttCommand()` is the only write path into the display UI.

## Development

### Adding New Display Properties

1. Add property to `DisplayState.qml`
2. Add persistence in `loadFromDisk()`
3. Add command handling in `applyMqttCommand()`
4. Bind property in `DisplayView.qml`
5. Add to state builder in `server.py`
6. Add control in `admin.html`

### Adding New Languages

1. Add translations to `DisplayState.qml` `_tr` object
2. Add language button in `admin.html`
3. Add to `ADMIN_I18N` dict in `admin.html`
4. Update audio generation scripts
5. Update `AudioEngine.py` language validation

### Testing

Run unit tests:
```bash
python -m pytest tests/
```

## Troubleshooting

### Audio Not Playing
- Check system audio output device
- Verify audio files exist in `~/.local/share/CandyBarV2/CandyBarV2/audio/`
- Check if audio is muted in admin panel
- Regenerate audio files: `python scripts/generate_audio.py`

### Admin Panel Not Accessible
- Verify the application is running
- Check firewall settings (port 8080)
- Ensure devices are on the same network
- Check LAN IP: `ip addr show | grep inet`

### Display Not Updating
- Check MQTT connection status in admin panel
- Verify `DisplayState.qml` property bindings
- Check browser console for JavaScript errors
- Restart the application

### Settings Not Persisting
- Check write permissions on `~/.local/share/CandyBarV2/CandyBarV2/`
- Verify INI file exists and is not corrupted
- Check `DisplayPersistence.py` save operations

## Documentation

For detailed technical documentation, see [CODEBASE.md](CODEBASE.md), which includes:
- Complete data flow architecture
- DisplayState property reference
- File-by-file change guide
- MQTT topic structure
- Audio system details
- Thread safety contracts

## License

See LICENSE file for details.
