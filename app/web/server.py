"""
web/server.py — thin HTTP server for CandyBarV2 admin web app.

Routes:
  GET  /              → public.html  (read-only customer page)
  GET  /admin         → admin.html   (PIN-protected staff page)
  POST /api/pin       → {"pin":"XXXX"} → {"ok": true/false}
  POST /api/publish   → {"topic":"display/…","payload":"…"} → {"ok": true}
  POST /api/logo      → multipart file upload → {"ok": true, "path": "…"}
  POST /api/background → multipart file upload → {"ok": true}
  POST /api/font      → multipart file upload → {"ok": true, "family": "…"}
  GET  /api/state     → current display state JSON
  GET  /api/stats     → device health/usage JSON
  GET  /api/fonts     → list registered fonts
  GET  /uploads/<f>   → serve uploaded files

No heavy frameworks — pure stdlib http.server with a custom handler.
"""

import http.server
import json
import mimetypes
import os
import re
import socket
import sys
import threading
import struct
import hashlib
import base64
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from PySide6.QtCore import QFile, QStandardPaths
from app.utils.logger import get_logger

logger = get_logger()

_ws_clients = set()
_ws_clients_lock = threading.Lock()

def _ws_encode_frame(data: bytes, opcode=0x1) -> bytes:
    header = bytes([0x80 | opcode])
    payload_len = len(data)
    if payload_len <= 125:
        header += bytes([payload_len])
    elif payload_len <= 65535:
        header += bytes([126]) + struct.pack(">H", payload_len)
    else:
        header += bytes([127]) + struct.pack(">Q", payload_len)
    return header + data

def broadcast_ws(obj: dict):
    """Push a JSON message to every connected admin WS client.
    Thread-safe. Must NEVER raise — callers (HTTP handler thread,
    AudioEngine's playback thread) must never be affected by a
    WS delivery failure."""
    try:
        data = _ws_encode_frame(json.dumps(obj).encode("utf-8"))
    except Exception as e:
        logger.debug(f"[ws] broadcast encode failed (non-fatal): {e}")
        return

    dead = []
    with _ws_clients_lock:
        clients = list(_ws_clients)
    for sock in clients:
        try:
            sock.sendall(data)
        except Exception:
            dead.append(sock)
    if dead:
        with _ws_clients_lock:
            for sock in dead:
                _ws_clients.discard(sock)

# Debounce infrastructure for expensive keys
_debounce_timers = {}
_debounce_lock = threading.Lock()
_DEBOUNCED_KEYS = {"backgroundVideoSource", "backgroundImage",
                    "backgroundScale", "backgroundOffsetX", "backgroundOffsetY"}
_DEBOUNCE_DELAY = 0.15

MAX_LOGO_BYTES = 2 * 1024 * 1024   # 2 MB
MAX_BG_BYTES   = 5 * 1024 * 1024   # 5 MB
MAX_FONT_BYTES = 2 * 1024 * 1024   # 2 MB

PORT      = 8080
SERVE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SERVE_DIR, '..'))

# Cache for QRC resources
_qrc_cache = {}

# Try to import Pillow for image resizing
try:
    from PIL import Image
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False
    logger.warning("Pillow not installed. Uploaded images won't be resized.")


def _get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def _parse_multipart(content_type: str, content_length: int, rfile):
    """
    Manual multipart/form-data parser (replaces deprecated cgi.FieldStorage).
    Returns dict with 'fields' and 'files' keys.
    """
    boundary_match = re.search(r'boundary=([^;]+)', content_type)
    if not boundary_match:
        return None
    boundary = boundary_match.group(1).strip().strip('"')
    boundary_bytes = ('--' + boundary).encode('utf-8')

    data = rfile.read(content_length)
    parts = data.split(boundary_bytes)

    result = {'fields': {}, 'files': {}}
    for part in parts[1:-1]:
        if not part or part == b'--\r\n':
            continue
        header_end = part.find(b'\r\n\r\n')
        if header_end == -1:
            continue
        headers = part[:header_end].decode('utf-8', errors='ignore')
        body = part[header_end + 4:]
        disp_match = re.search(
            r'Content-Disposition: form-data; name="([^"]+)"(?:; filename="([^"]+)")?',
            headers
        )
        if not disp_match:
            continue
        name = disp_match.group(1)
        filename = disp_match.group(2)
        if filename:
            result['files'][name] = {'filename': filename, 'data': body.rstrip(b'\r\n')}
        else:
            result['fields'][name] = body.decode('utf-8', errors='ignore').rstrip('\r\n')
    return result


def create_handler(upload_dir, mqtt_client, display_persistence, usage_stats, font_manager, audio_engine, original_argv):
    """Factory function to create a Handler class with access to dependencies."""
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            logger.info(f"[admin-web] {self.address_string()} {fmt % args}")

        # ── routing ───────────────────────────────────────────────────────────

        def do_GET(self):
            if self.headers.get("Upgrade", "").lower() == "websocket":
                key = self.headers.get("Sec-WebSocket-Key")
                if not key:
                    self._send(400, "text/plain", b"Missing Sec-WebSocket-Key")
                    return
                GUID = "258EAFA5-E914-47DA-95CA-C5ABDC85B711"
                accept_val = base64.b64encode(
                    hashlib.sha1((key + GUID).encode("utf-8")).digest()
                ).decode("utf-8")
                self.send_response(101, "Switching Protocols")
                self.send_header("Upgrade", "websocket")
                self.send_header("Connection", "Upgrade")
                self.send_header("Sec-WebSocket-Accept", accept_val)
                self.end_headers()
                self._handle_websocket()
                return

            path = self.path.split("?")[0]
            if path in ("/", ""):
                self._serve_file("public.html")
            elif path == "/admin":
                self._serve_file("admin.html")
            elif path.startswith("/uploads/"):
                self._serve_static(os.path.join(upload_dir, path[len("/uploads/"):]))
            elif path.startswith("/videos/"):
                video_name = path[len("/videos/"):]
                self._serve_static(os.path.join(SERVE_DIR, "videos", video_name))
            elif path.startswith("/fonts/"):
                font_name = path[len("/fonts/"):]
                allowed_fonts = {
                    "Barriecito-Regular.ttf": ":/app/res/font/Barriecito-Regular.ttf",
                    "Gluten-Regular.ttf": ":/app/res/font/Gluten-Regular.ttf",
                    "LCMogi-A.otf": ":/app/res/font/LCMogi-A.otf",
                    "Manosque-Regular.otf": ":/app/res/font/Manosque-Regular.otf",
                }
                if font_name in allowed_fonts:
                    mime = "font/otf" if font_name.endswith(".otf") else "font/ttf"
                    font_path = allowed_fonts[font_name]
                    if isinstance(font_path, str) and font_path.startswith(":"):
                        self._serve_qrc(font_path, mime)
                    else:
                        self._serve_static(font_path)
                else:
                    self._send(404, "text/plain", b"Not found")
            elif path == "/favicon.ico":
                self._serve_qrc(":/app/res/image/favicon.ico", "image/x-icon")
            elif path.startswith("/api/bg_thumb/"):
                bg_id = path[len("/api/bg_thumb/"):]
                if bg_id and all(c.isalnum() or c == '_' for c in bg_id):
                    self._serve_qrc(f":/app/res/image/{bg_id}.jpg", "image/jpeg")
                else:
                    self._send(404, "text/plain", b"Not found")
            elif path == "/api/state":
                self._json_response(self._build_state())
            elif path == "/api/stats":
                self._json_response(usage_stats.as_dict())
            elif path == "/api/fonts":
                self._handle_get_fonts()
            elif path == "/api/health":
                self._json_response({"ok": True})
            else:
                self._serve_file(path.lstrip("/"))

        def do_OPTIONS(self):
            """Handle CORS preflight requests."""
            self.send_response(200)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers()

        def do_POST(self):
            path = self.path.split("?")[0]
            if path == "/api/pin":
                self._handle_pin()
            elif path == "/api/publish":
                self._handle_publish()
            elif path == "/api/publish_batch":
                self._handle_publish_batch()
            elif path == "/api/logo":
                self._handle_upload("logo", MAX_LOGO_BYTES, (".png", ".jpg", ".jpeg", ".svg"))
            elif path == "/api/background":
                self._handle_upload("background", MAX_BG_BYTES, (".png", ".jpg", ".jpeg"))
            elif path == "/api/font":
                self._handle_font()
            elif path == "/api/reset_stats":
                self._handle_reset_stats()
            elif path == "/api/restart":
                self._handle_restart()
            elif path == "/api/delete_category":
                self._handle_delete_category()
            else:
                self._send(404, "text/plain", b"Not found")

        # ── POST handlers ─────────────────────────────────────────────────────

        def _handle_pin(self):
            body = self._read_json()
            if body is None:
                return
            entered = str(body.get("pin", "")).strip()
            correct = str(display_persistence.get_pin()).strip()
            ok = entered == correct
            logger.info(f"[pin] entered={entered!r} correct={correct!r} ok={ok}")
            self._json_response({"ok": ok})

        def _handle_reset_stats(self):
            try:
                # Preserve current number and category before reset
                current_number = display_persistence.get_current_number()
                current_category = display_persistence.get_category()
                current_category_display = display_persistence.get_category_display_name()
                
                display_persistence.reset_all()
                usage_stats.reset_stats()
                logger.info("[api] reset_stats called - reset all display settings and stats, applying Burger Joint template")
                
                # Apply current display settings as defaults (based on user's preferred configuration)
                current_defaults = [
                    ("nextUp", ""),
                    ("layoutType", "Centered"),
                    ("accentColor", "#8D6E63"),
                    ("accentGradientEnabled", "true"),
                    ("bannerText", "Welcome — please wait for your number to be called"),
                    ("bannerEnabled", "true"),
                    ("facilityName", "CandyBar Service Centre"),
                    ("fontSize", "96"),
                    ("numberFontSize", "315"),
                    ("categoryFontSize", "51"),
                    ("facilityFontSize", "61"),
                    ("bannerFontSize", "41"),
                    ("nowServingFontSize", "38"),
                    ("logoSize", "78"),
                    ("logoVisible", "false"),
                    ("logoPosition", "top-center"),
                    ("facilityVisible", "true"),
                    ("categoryVisible", "false"),
                    ("backgroundImage", "qrc:/app/res/image/pro_geometric.jpg"),
                    ("backgroundFitMode", "crop"),
                    ("backgroundScale", "1.0"),
                    ("backgroundOffsetX", "0"),
                    ("backgroundOffsetY", "0"),
                    ("backgroundOrientation", "portrait"),
                    ("backgroundType", "image"),
                    ("backgroundVideoSource", ""),
                    ("ttsLanguage", "fr"),
                    ("displayLanguage", "en"),
                    ("ttsEnabled", "true"),
                    ("audioMuted", "false"),
                    ("audioVolumeStep", "4"),
                    ("categoryAudioEnabled", "false"),
                    ("numberFont", "DM Mono"),
                    ("numberColor", "#ff0000"),
                    ("categoryFont", "Barriecito"),
                    ("categoryColor", "#ffffff"),
                    ("facilityFont", "Manosque"),
                    ("facilityColor", "#ffffff"),
                    ("bannerColor", "#ffffff"),
                    ("nowServingFont", "Barriecito"),
                    ("nowServingColor", "#ffffff"),
                ]
                
                for key, value in current_defaults:
                    self._persist_and_publish(key, value)
                
                # Restore preserved number and category
                if current_number:
                    self._persist_and_publish("currentNumber", current_number)
                if current_category:
                    self._persist_and_publish("category", current_category)
                if current_category_display:
                    self._persist_and_publish("categoryDisplayName", current_category_display)
                
                self._json_response({"ok": True})
            except Exception as e:
                logger.error(f"[api] reset_stats error: {e}", exc_info=True)
                self._json_response({"ok": False, "error": str(e)})

        def _handle_restart(self):
            logger.info("[api] restart called - restarting application")
            self._json_response({"ok": True})
            import sys
            import os
            import subprocess
            import time
            # Schedule restart in a separate thread so we can send the response first
            def restart():
                time.sleep(1)
                python = sys.executable
                subprocess.Popen([python] + original_argv)
                os._exit(0)
            import threading
            threading.Thread(target=restart, daemon=True).start()

        def _handle_delete_category(self):
            body = self._read_json()
            if body is None:
                return
            category = body.get("category", "").strip()
            if not category:
                self._json_response({"ok": False, "error": "Category name required"})
                return

            try:
                # Remove category from categoriesList
                cats_str = str(display_persistence.load("categoriesList", "Category A"))
                cats = [c.strip() for c in cats_str.split(",") if c.strip()]
                if category in cats:
                    cats.remove(category)
                    display_persistence.save("categoriesList", ",".join(cats))
                    logger.info(f"[api] Deleted category '{category}' from list")

                # Delete MP3 files for this category
                audio_data_dir = os.path.join(
                    QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppLocalDataLocation),
                    "audio"
                )
                for lang in ["en", "fr", "ar"]:
                    cat_dir = os.path.join(audio_data_dir, lang, "category")
                    if os.path.exists(cat_dir):
                        mp3_file = os.path.join(cat_dir, f"{category}.mp3")
                        if os.path.exists(mp3_file):
                            os.remove(mp3_file)
                            logger.info(f"[api] Deleted audio file: {mp3_file}")

                self._json_response({"ok": True})
            except Exception as e:
                logger.error(f"[api] delete_category error: {e}", exc_info=True)
                self._json_response({"ok": False, "error": str(e)})

        def _persist_and_publish(self, key, payload):
            """Helper to persist a single key and publish it (used by both single and batch)."""
            category = display_persistence.load("category", "A")

            if key == "adminPin":
                display_persistence.set_pin(payload)
            elif key == "fontSize":
                display_persistence.save("fontSize", int(payload))
            elif key in ("numberFontSize", "categoryFontSize", "facilityFontSize", "bannerFontSize", "nowServingFontSize"):
                display_persistence.save(key, int(payload))
            elif key == "logoSize":
                display_persistence.save("logoSize", int(payload))
            elif key == "audioVolumeStep":
                display_persistence.save("audioVolumeStep", int(payload))
            else:
                display_persistence.save(key, payload)

            if key == "categoryDisplayName":
                cats_str = str(display_persistence.load("categoriesList", "Category A"))
                cats = [c.strip() for c in cats_str.split(",") if c.strip()]
                new_cat = payload.strip()
                if new_cat and new_cat not in cats:
                    cats.append(new_cat)
                    display_persistence.save("categoriesList", ",".join(cats))

            def _do_publish():
                mqtt_client.direct_command(key, payload)
                mqtt_client.publish(f"display/{category}/{key}", payload)

            if key in _DEBOUNCED_KEYS:
                with _debounce_lock:
                    old = _debounce_timers.get(key)
                    if old:
                        old.cancel()
                    t = threading.Timer(_DEBOUNCE_DELAY, _do_publish)
                    _debounce_timers[key] = t
                    t.start()
            else:
                _do_publish()

            if key == "currentNumber":
                usage_stats.record_number_change()

            broadcast_ws({"type": "state_patch", "key": key, "value": payload})

        def _handle_publish(self):
            body = self._read_json()
            if body is None:
                return
            topic   = str(body.get("topic", ""))
            payload = str(body.get("payload", ""))
            if not topic.startswith("display/"):
                self._json_response({"ok": False, "error": "bad topic"})
                return

            key = topic[len("display/"):]
            self._persist_and_publish(key, payload)
            self._json_response({"ok": True})

        def _handle_publish_batch(self):
            body = self._read_json()
            if body is None:
                return
            items = body.get("items", [])
            for item in items:
                topic = str(item.get("topic", ""))
                payload = str(item.get("payload", ""))
                if not topic.startswith("display/"):
                    self._json_response({"ok": False, "error": "bad topic in batch"})
                    return
                key = topic[len("display/"):]
                self._persist_and_publish(key, payload)
            self._json_response({"ok": True})

        def _handle_upload(self, field: str, max_bytes: int, allowed_exts: tuple):
            """Generic file upload handler for logo and background."""
            ctype          = self.headers.get("Content-Type", "")
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > max_bytes:
                self._json_response({"ok": False, "error": f"file too large (max {max_bytes // (1024*1024)} MB)"})
                return
            try:
                parsed = _parse_multipart(ctype, content_length, self.rfile)
                if not parsed or field not in parsed['files']:
                    self._json_response({"ok": False, "error": "no file"})
                    return
                file_item = parsed['files'][field]
                data      = file_item['data']
                ext       = os.path.splitext(file_item['filename'])[1].lower()
                if len(data) > max_bytes:
                    self._json_response({"ok": False, "error": "file too large"})
                    return
                if ext not in allowed_exts:
                    self._json_response({"ok": False, "error": f"unsupported format (allowed: {', '.join(allowed_exts)})"})
                    return
                
                # Resize image if it's a background and Pillow is available
                processed_data = data
                if field == "background" and HAS_PILLOW and ext in (".png", ".jpg", ".jpeg"):
                    from io import BytesIO
                    try:
                        img = Image.open(BytesIO(data))
                        
                        # Resize to max 1080x1920 (portrait) or 1920x1080 (landscape)
                        max_width, max_height = 1920, 1080
                        img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
                        
                        # Convert to RGB if needed (for PNGs with alpha)
                        if img.mode in ("RGBA", "P"):
                            img = img.convert("RGB")
                        
                        # Re-encode as JPEG with quality 85
                        output = BytesIO()
                        img.save(output, format="JPEG", quality=85)
                        processed_data = output.getvalue()
                        ext = ".jpg"
                    except Exception as e:
                        logger.warning(f"Failed to resize image, using original: {e}")
                
                dest_path = os.path.join(upload_dir, f"{field}{ext}")
                with open(dest_path, "wb") as f:
                    f.write(processed_data)
                category = display_persistence.load("category", "A")
                if field == "logo":
                    # Store relative path for portability
                    rel_path = f"{field}{ext}"
                    display_persistence.save("logoPath", rel_path)
                    # Send absolute path via MQTT for QML to use
                    mqtt_client.direct_command("logoSource", dest_path)
                    mqtt_client.publish(f"display/{category}/logoSource", dest_path)
                else:
                    # Store relative path for portability
                    rel_path = f"{field}{ext}"
                    display_persistence.save("backgroundImage", rel_path)
                    # Send absolute path via MQTT for QML to use
                    mqtt_client.direct_command("backgroundImage", dest_path)
                    mqtt_client.publish(f"display/{category}/backgroundImage", dest_path)
                self._json_response({"ok": True, "url": f"/uploads/{field}{ext}", "path": dest_path})
            except Exception as exc:
                self._json_response({"ok": False, "error": str(exc)})

        def _handle_font(self):
            ctype          = self.headers.get("Content-Type", "")
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > MAX_FONT_BYTES:
                self._json_response({"ok": False, "error": "file too large (max 2 MB)"})
                return
            try:
                parsed = _parse_multipart(ctype, content_length, self.rfile)
                if not parsed or 'font' not in parsed['files']:
                    self._json_response({"ok": False, "error": "no file"})
                    return
                file_item = parsed['files']['font']
                data      = file_item['data']
                ext       = os.path.splitext(file_item['filename'])[1].lower()
                if len(data) > MAX_FONT_BYTES:
                    self._json_response({"ok": False, "error": "file too large"})
                    return
                if ext not in (".ttf", ".otf"):
                    self._json_response({"ok": False, "error": "unsupported format (only TTF/OTF)"})
                    return
                temp_path = os.path.join(upload_dir, f"temp_font_upload{ext}")
                with open(temp_path, "wb") as f:
                    f.write(data)
                family = font_manager.registerFont(temp_path)
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                if not family:
                    self._json_response({"ok": False, "error": "invalid font file or registration failed"})
                    return
                self._json_response({"ok": True, "family": family})
            except Exception as exc:
                self._json_response({"ok": False, "error": str(exc)})

        def _handle_get_fonts(self):
            try:
                fonts = [
                    {"family": "Barriecito", "url": "/fonts/Barriecito-Regular.ttf", "filename": "Barriecito-Regular.ttf"},
                    {"family": "Gluten", "url": "/fonts/Gluten-Regular.ttf", "filename": "Gluten-Regular.ttf"},
                    {"family": "LC Mogi", "url": "/fonts/LCMogi-A.otf", "filename": "LCMogi-A.otf"},
                    {"family": "Manosque", "url": "/fonts/Manosque-Regular.otf", "filename": "Manosque-Regular.otf"},
                ]
                for f in font_manager.listFonts():
                    fonts.append({
                        "family": f["family"],
                        "url": f"/uploads/fonts/{f['filename']}",
                        "filename": f["filename"]
                    })
                self._json_response({"ok": True, "fonts": fonts})
            except Exception as exc:
                self._json_response({"ok": False, "error": str(exc)})

        # ── state builder ─────────────────────────────────────────────────────

        def _build_state(self) -> dict:
            """Build the current display state. Always returns a valid dict, even on errors."""
            try:
                p = display_persistence
                cats_str = str(p.load("categoriesList", "Category A"))
                categories = [c.strip() for c in cats_str.split(",") if c.strip()]
                current_cat = str(p.load("categoryDisplayName", "Category A"))
                if current_cat not in categories:
                    categories.append(current_cat)

                logo_path = p.logo_path()
                logo_url  = f"/uploads/{os.path.basename(logo_path)}" if logo_path and os.path.exists(logo_path) else ""

                bg_path = p.background_path()
                if not bg_path:
                    bg_url = "qrc:/app/res/image/ff_burger_pattern.jpg"
                elif bg_path.startswith("qrc:"):
                    bg_url = bg_path
                elif os.path.exists(bg_path):
                    bg_url = f"/uploads/{os.path.basename(bg_path)}"
                else:
                    bg_url = bg_path

                return {
                    "currentNumber":          p.get_current_number(),
                    "nextUp":                 p.get_next_up(),
                    "layoutType":             p.get_layout(),
                    "accentColor":            p.load("accentColor", "#FFB84D"),
                    "accentGradientEnabled":  p.load("accentGradientEnabled", "false"),
                    "accentGradientDirection":p.load("accentGradientDirection", "top-to-bottom"),
                    "bannerText":             p.get_banner(),
                    "bannerEnabled":          p.load("bannerEnabled", "true"),
                    "facilityName":           p.get_facility(),
                    "fontSize":               p.get_font_size(),
                    "numberFontSize":         p.get_text_size("numberFontSize", p.get_font_size()),
                    "categoryFontSize":       p.get_text_size("categoryFontSize", 120),
                    "facilityFontSize":       p.get_text_size("facilityFontSize", 120),
                    "bannerFontSize":         p.get_text_size("bannerFontSize", 120),
                    "nowServingFontSize":     p.get_text_size("nowServingFontSize", 120),
                    "logoSize":               p.get_logo_size(),
                    "numberFont":             p.load("numberFont", "DM Mono"),
                    "categoryFont":           p.load("categoryFont", p.load("numberFont", "DM Mono")),
                    "facilityFont":           p.load("facilityFont", p.load("numberFont", "DM Mono")),
                    "bannerFont":             p.load("bannerFont", p.load("numberFont", "DM Mono")),
                    "nowServingFont":         p.load("nowServingFont", p.load("numberFont", "DM Mono")),
                    "numberColor":            p.load("numberColor", "#FFB84D"),
                    "categoryColor":          p.load("categoryColor", "#FFB84D"),
                    "facilityColor":          p.load("facilityColor", "#FFB84D"),
                    "bannerColor":            p.load("bannerColor", "#FFFFFF"),
                    "nowServingColor":        p.load("nowServingColor", "#FFFFFF"),
                    "logoUrl":                logo_url,
                    "logoVisible":            p.load("logoVisible", "true"),
                    "logoPosition":           p.load("logoPosition", "top-left"),
                    "facilityVisible":        p.load("facilityVisible", "true"),
                    "backgroundImage":        bg_url,
                    "backgroundFitMode":     p.load("backgroundFitMode", "crop"),
                    "backgroundScale":       p.load("backgroundScale", "1.0"),
                    "backgroundOffsetX":     p.load("backgroundOffsetX", "0"),
                    "backgroundOffsetY":     p.load("backgroundOffsetY", "0"),
                    "backgroundOrientation":  p.load("backgroundOrientation", "portrait"),
                    "backgroundType":         p.load("backgroundType", "image"),
                    "backgroundVideoSource":  p.load("backgroundVideoSource", ""),
                    "category":               p.load("category", "A"),
                    "categoryDisplayName":    p.load("categoryDisplayName", "Category A"),
                    "categoryVisible":        p.load("categoryVisible", "true"),
                    "categoryAudioEnabled":   p.load("categoryAudioEnabled", "true"),
                    "ttsLanguage":            p.load("ttsLanguage", "en"),
                    "displayLanguage":        p.load("displayLanguage", "en"),
                    "ttsEnabled":             p.load("ttsEnabled", "true"),
                    "audioMuted":             p.load("audioMuted", "false"),
                    "audioVolumeStep":        p.load("audioVolumeStep", "3"),
                    "audioPlaying":           getattr(audio_engine, 'playing', False),
                    "categories":             categories,
                    "mqttConnected":          getattr(mqtt_client, 'connected', False),
                    "mqttStatus":             getattr(mqtt_client, 'status', 'N/A'),
                }
            except Exception as e:
                logger.error(f"Error building state: {e}", exc_info=True)
                # Return minimal valid state so admin.html can load
                return {
                    "currentNumber": "001",
                    "nextUp": [],
                    "layoutType": "Centered",
                    "accentColor": "#FFB84D",
                    "accentGradientEnabled": "false",
                    "accentGradientDirection": "top-to-bottom",
                    "bannerText": "Welcome — please wait for your number to be called",
                    "bannerEnabled": "true",
                    "facilityName": "CandyBar Service Centre",
                    "fontSize": 120,
                    "numberFontSize": 120,
                    "categoryFontSize": 60,
                    "facilityFontSize": 60,
                    "bannerFontSize": 60,
                    "nowServingFontSize": 60,
                    "logoSize": 48,
                    "numberFont": "DM Mono",
                    "categoryFont": "DM Mono",
                    "facilityFont": "DM Mono",
                    "bannerFont": "DM Mono",
                    "nowServingFont": "DM Mono",
                    "numberColor": "#FFB84D",
                    "categoryColor": "#FFB84D",
                    "facilityColor": "#FFB84D",
                    "bannerColor": "#FFFFFF",
                    "nowServingColor": "#FFFFFF",
                    "logoUrl": "",
                    "logoVisible": "true",
                    "logoPosition": "top-left",
                    "facilityVisible": "true",
                    "backgroundImage": "qrc:/app/res/image/ff_burger_pattern.jpg",
                    "backgroundFitMode": "crop",
                    "backgroundScale": "1.0",
                    "backgroundOffsetX": "0",
                    "backgroundOffsetY": "0",
                    "backgroundOrientation": "portrait",
                    "backgroundType": "image",
                    "backgroundVideoSource": "",
                    "category": "A",
                    "categoryDisplayName": "Category A",
                    "categoryVisible": "true",
                    "categoryAudioEnabled": "true",
                    "ttsLanguage": "en",
                    "displayLanguage": "en",
                    "ttsEnabled": "true",
                    "audioMuted": "false",
                    "audioVolumeStep": "3",
                    "categories": ["Category A"],
                    "mqttConnected": False,
                    "mqttStatus": "Error",
                }

        # ── low-level helpers ─────────────────────────────────────────────────

        def _serve_qrc(self, qrc_path: str, mime: str):
            if qrc_path in _qrc_cache:
                data = _qrc_cache[qrc_path]
            else:
                qf = QFile(qrc_path)
                if qf.open(QFile.OpenModeFlag.ReadOnly):
                    data = qf.readAll().data()
                    qf.close()
                    _qrc_cache[qrc_path] = data
                else:
                    logger.warning(f"Failed to open QRC resource: {qrc_path}")
                    self._send(404, "text/plain", b"Not found")
                    return
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
            self.end_headers()
            self.wfile.write(data)

        def _serve_file(self, name: str):
            self._serve_static(os.path.join(SERVE_DIR, name))

        def _serve_static(self, fpath: str):
            if not os.path.isfile(fpath):
                self._send(404, "text/plain", b"Not found")
                return
            
            file_size = os.path.getsize(fpath)
            mime, _ = mimetypes.guess_type(fpath)
            range_header = self.headers.get("Range")
            
            if range_header:
                # Parse Range header (e.g., bytes=0-100)
                match = re.match(r"bytes=(\d+)-(\d*)", range_header)
                if match:
                    start = int(match.group(1))
                    end_str = match.group(2)
                    end = int(end_str) if end_str else file_size - 1
                    
                    if start >= file_size:
                        self._send(416, "text/plain", b"Requested Range Not Satisfiable")
                        return
                    
                    end = min(end, file_size - 1)
                    length = end - start + 1
                    
                    with open(fpath, "rb") as f:
                        f.seek(start)
                        data = f.read(length)
                    
                    self.send_response(206)  # Partial Content
                    self.send_header("Content-Type", mime or "application/octet-stream")
                    self.send_header("Content-Length", str(length))
                    self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                    self.send_header("Accept-Ranges", "bytes")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(data)
                    return
            
            # No range requested, send entire file
            with open(fpath, "rb") as f:
                data = f.read()
            
            self.send_response(200)
            self.send_header("Content-Type", mime or "application/octet-stream")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)

        def _json_response(self, obj: dict):
            self._send(200, "application/json", json.dumps(obj).encode())

        def _send(self, code: int, mime: str, body: bytes):
            self.send_response(code)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", len(body))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def _read_json(self):
            try:
                length = int(self.headers.get("Content-Length", 0))
                return json.loads(self.rfile.read(length))
            except Exception:
                self._send(400, "text/plain", b"Bad JSON")
                return None

        def _handle_websocket(self):
            sock = self.connection
            sock.settimeout(60)  # ping/pong or client traffic must arrive within 60s
            with _ws_clients_lock:
                _ws_clients.add(sock)
            logger.info(f"[ws] client connected: {self.address_string()}")

            try:
                sock.sendall(_ws_encode_frame(
                    json.dumps({"type": "state", "data": self._build_state()}).encode()
                ))
                while True:
                    try:
                        header = sock.recv(2)
                    except socket.timeout:
                        # Idle client — send a ping to check it's alive
                        try:
                            sock.sendall(_ws_encode_frame(b"", opcode=0x9))
                            continue
                        except Exception:
                            break
                    if len(header) < 2:
                        break
                    try:
                        b1, b2 = header
                        opcode = b1 & 0x0F
                        if opcode == 0x8:
                            break
                        masked = b2 & 0x80
                        plen = b2 & 0x7F
                        if plen == 126:
                            plen = struct.unpack(">H", sock.recv(2))[0]
                        elif plen == 127:
                            plen = struct.unpack(">Q", sock.recv(8))[0]
                        if masked:
                            mask = sock.recv(4)
                            raw = sock.recv(plen)
                            data = bytes(b ^ mask[i % 4] for i, b in enumerate(raw))
                        else:
                            data = sock.recv(plen)
                        if opcode == 0x9:
                            sock.sendall(_ws_encode_frame(data, opcode=0xA))
                        elif opcode == 0x1:
                            # Text frame - process JSON message
                            try:
                                msg = json.loads(data.decode("utf-8"))
                                logger.debug(f"[ws] Received message: {msg}")
                                if msg.get("type") == "publish":
                                    key = msg.get("key")
                                    payload = msg.get("value")
                                    if key is not None and payload is not None:
                                        logger.info(f"[ws] Processing publish: {key}={payload}")
                                        self._persist_and_publish(key, payload)
                            except Exception as json_err:
                                logger.debug(f"[ws] JSON parse error: {json_err}")
                    except Exception as frame_err:
                        # One malformed frame shouldn't kill the whole
                        # connection thread — log and drop the connection cleanly.
                        logger.debug(f"[ws] frame parse error, closing: {frame_err}")
                        break
            except Exception as e:
                logger.info(f"[ws] client error: {e}")
            finally:
                with _ws_clients_lock:
                    _ws_clients.discard(sock)
                logger.info(f"[ws] client disconnected: {self.address_string()}")

    return Handler


def run(mqtt_client, display_persistence, usage_stats, font_manager, audio_engine, original_argv):
    """Start the HTTP server. Runs forever — call from a daemon thread."""
    upload_dir = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppLocalDataLocation
    )
    os.makedirs(upload_dir, exist_ok=True)

    # Seed static assets the admin UI references via /uploads/
    for qrc_path, fname in [(":/app/res/image/noise_texture.png", "noise_texture.png")]:
        dest = os.path.join(upload_dir, fname)
        if not os.path.exists(dest):
            qf = QFile(qrc_path)
            if qf.open(QFile.OpenModeFlag.ReadOnly):
                with open(dest, "wb") as f:
                    f.write(qf.readAll().data())
                qf.close()

    local_ip = _get_local_ip()
    logger.info(f"[admin-web] Starting server on http://0.0.0.0:{PORT}  (LAN: http://{local_ip}:{PORT})")

    Handler = create_handler(upload_dir, mqtt_client, display_persistence, usage_stats, font_manager, audio_engine, original_argv)
    http.server.ThreadingHTTPServer.allow_reuse_address = True
    try:
        with http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler) as httpd:
            logger.info(f"[admin-web] Server successfully bound to port {PORT}")
            httpd.serve_forever()
    except OSError as e:
        logger.error(f"[admin-web] Failed to bind server to port {PORT}: {e}")
        raise
    except Exception as e:
        logger.error(f"[admin-web] Server error: {e}", exc_info=True)
        raise
