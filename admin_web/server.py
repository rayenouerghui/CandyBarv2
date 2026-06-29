"""
admin_web/server.py — thin HTTP server for CandyBarV2 admin web app.

Routes:
  GET  /              → public.html  (read-only customer page)
  GET  /admin         → admin.html   (PIN-protected staff page)
  POST /api/pin       → {"pin":"XXXX"} → {"ok": true/false}
  POST /api/publish   → {"topic":"display/…","payload":"…"} → {"ok": true}
  POST /api/logo      → multipart file upload → {"ok": true, "path": "…"}
  GET  /api/state     → current display state JSON
  GET  /api/stats     → device health/usage JSON
  GET  /uploads/<f>   → serve uploaded logo files

File size limit for logo uploads: 2 MB
Reasoning: large enough for any reasonable logo at display resolution
(a 512×512 PNG is typically 50-200 KB; 2 MB is a comfortable ceiling),
small enough to transfer reliably over a congested LAN without risk of
exhausting RAM on a Pi-class device during decode.

No heavy frameworks — pure stdlib http.server with a custom handler.
"""

import cgi
import json
import mimetypes
import os
import socket

MAX_LOGO_BYTES = 2 * 1024 * 1024   # 2 MB

PORT      = 8080
SERVE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = None   # set at startup from DisplayPersistence data dir


def _get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def run(mqtt_client, display_persistence, usage_stats):
    """Start the HTTP server. Runs forever — call from a daemon thread."""
    import http.server

    global UPLOAD_DIR
    from PySide6.QtCore import QStandardPaths
    UPLOAD_DIR = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppLocalDataLocation
    )
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    class Handler(http.server.BaseHTTPRequestHandler):

        def log_message(self, fmt, *args):
            print(f"[admin-web] {self.address_string()} {fmt % args}")

        # ── routing ──────────────────────────────────────────────────────

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/" or path == "":
                self._serve_file("public.html")
            elif path == "/admin":
                self._serve_file("admin.html")
            elif path.startswith("/uploads/"):
                fname = path[len("/uploads/"):]
                fpath = os.path.join(UPLOAD_DIR, fname)
                self._serve_static(fpath)
            elif path == "/api/state":
                self._json_response(self._build_state())
            elif path == "/api/stats":
                self._json_response(usage_stats.as_dict())
            else:
                self._serve_file(path.lstrip("/"))

        def do_POST(self):
            path = self.path.split("?")[0]
            if path == "/api/pin":
                self._handle_pin()
            elif path == "/api/publish":
                self._handle_publish()
            elif path == "/api/logo":
                self._handle_logo()
            else:
                self._send(404, "text/plain", b"Not found")

        # ── handlers ─────────────────────────────────────────────────────

        def _handle_pin(self):
            body = self._read_json()
            if body is None:
                return
            entered = str(body.get("pin", ""))
            correct = display_persistence.get_pin()
            ok = entered == correct
            self._json_response({"ok": ok})

        def _handle_publish(self):
            body = self._read_json()
            if body is None:
                return
            topic   = str(body.get("topic", ""))
            payload = str(body.get("payload", ""))
            if not topic.startswith("display/"):
                self._json_response({"ok": False, "error": "bad topic"})
                return

            # Update persistence
            key = topic[len("display/"):]
            self._persist_key(key, payload)

            # Publish via MQTT — also updates display in real time
            mqtt_client.publish(topic, payload)

            # Track number changes for stats
            if key == "currentNumber":
                usage_stats.record_number_change()

            self._json_response({"ok": True})

        def _handle_logo(self):
            ctype = self.headers.get("Content-Type", "")
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length > MAX_LOGO_BYTES:
                self._json_response({"ok": False, "error": "file too large (max 2 MB)"})
                return

            # Parse multipart
            fs_env = {
                "REQUEST_METHOD": "POST",
                "CONTENT_TYPE": ctype,
                "CONTENT_LENGTH": str(content_length),
            }
            try:
                form = cgi.FieldStorage(
                    fp=self.rfile,
                    headers=self.headers,
                    environ=fs_env,
                    keep_blank_values=True,
                )
                file_item = form["logo"]
                if not hasattr(file_item, "filename") or not file_item.filename:
                    self._json_response({"ok": False, "error": "no file"})
                    return

                ext = os.path.splitext(file_item.filename)[1].lower()
                if ext not in (".png", ".jpg", ".jpeg", ".svg"):
                    self._json_response({"ok": False, "error": "unsupported format"})
                    return

                dest_path = os.path.join(UPLOAD_DIR, f"logo{ext}")
                data = file_item.file.read(MAX_LOGO_BYTES + 1)
                if len(data) > MAX_LOGO_BYTES:
                    self._json_response({"ok": False, "error": "file too large"})
                    return

                with open(dest_path, "wb") as f:
                    f.write(data)

                # Persist logo path and publish to display
                display_persistence.save("logoPath", dest_path)
                serve_url = f"/uploads/logo{ext}"
                mqtt_client.publish("display/logoSource", dest_path)
                self._json_response({"ok": True, "url": serve_url, "path": dest_path})

            except Exception as exc:
                self._json_response({"ok": False, "error": str(exc)})

        # ── state builder ─────────────────────────────────────────────────

        def _build_state(self) -> dict:
            p = display_persistence
            logo_path = p.logo_path()
            # Turn absolute path into a URL the browser can load
            logo_url = ""
            if logo_path and os.path.exists(logo_path):
                fname = os.path.basename(logo_path)
                logo_url = f"/uploads/{fname}"
            return {
                "currentNumber": p.get_current_number(),
                "nextUp":        p.get_next_up(),
                "layoutType":    p.get_layout(),
                "accentColor":   p.get_accent(),
                "bannerText":    p.get_banner(),
                "facilityName":  p.get_facility(),
                "fontSize":      p.get_font_size(),
                "logoUrl":       logo_url,
            }

        # ── persistence helper ────────────────────────────────────────────

        def _persist_key(self, key: str, value: str):
            p = display_persistence
            if key == "currentNumber":
                p.save("currentNumber", value)
            elif key == "layoutType":
                p.save("layoutType", value)
            elif key == "accentColor":
                p.save("accentColor", value)
            elif key == "bannerText":
                p.save("bannerText", value)
            elif key == "facilityName":
                p.save("facilityName", value)
            elif key == "fontSize":
                p.save("fontSize", int(value))
            elif key == "nextUp":
                p.save("nextUp", value)
            elif key == "adminPin":
                p.set_pin(value)

        # ── low-level helpers ─────────────────────────────────────────────

        def _serve_file(self, name: str):
            fpath = os.path.join(SERVE_DIR, name)
            self._serve_static(fpath)

        def _serve_static(self, fpath: str):
            if not os.path.isfile(fpath):
                self._send(404, "text/plain", b"Not found")
                return
            mime, _ = mimetypes.guess_type(fpath)
            mime = mime or "application/octet-stream"
            with open(fpath, "rb") as f:
                data = f.read()
            self._send(200, mime, data)

        def _json_response(self, obj: dict):
            data = json.dumps(obj).encode()
            self._send(200, "application/json", data)

        def _send(self, code: int, mime: str, body: bytes):
            self.send_response(code)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", len(body))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def _read_json(self) -> dict | None:
            try:
                length = int(self.headers.get("Content-Length", 0))
                raw = self.rfile.read(length)
                return json.loads(raw)
            except Exception:
                self._send(400, "text/plain", b"Bad JSON")
                return None

    local_ip = _get_local_ip()
    print(f"[admin-web] http://0.0.0.0:{PORT}  (LAN: http://{local_ip}:{PORT})")

    import http.server
    with http.server.HTTPServer(("0.0.0.0", PORT), Handler) as httpd:
        httpd.serve_forever()
