pragma Singleton

import QtQuick 2.15

// ── CandyBarV2 DisplayState ──────────────────────────────────────────────
// Single source of truth for all display properties.
// All changes persist to disk immediately via DisplayPersistence.
// applyMqttCommand() is the sole write path — used by both the Connections
// block in MainWindow and by any future local control surface.

QtObject {
    id: root

    // ── queue ──────────────────────────────────────────────────────────
    property string currentNumber: "001"
    property var    nextUp: []          // array of upcoming number strings

    // ── branding ───────────────────────────────────────────────────────
    property string logoSource:   "qrc:/example/res/image/genical.jpg"
    property string facilityName: "CandyBar Service Centre"
    property string bannerText:   "Welcome — please wait for your number to be called"

    // ── design tokens ──────────────────────────────────────────────────
    // Dark-first. Background is always ~#0b0d10; accent touches 1-2 elements.
    property color  bgColor:      "#0b0d10"
    property color  accentColor:  "#0078D4"
    property color  textPrimary:  "#FFFFFF"    // full opacity
    property color  textSecondary:"#FFFFFF"    // rendered at 0.42 opacity in QML
    property color  textTertiary: "#FFFFFF"    // rendered at 0.30 opacity

    // ── layout ─────────────────────────────────────────────────────────
    property string layoutType:   "Classic"   // "Classic" | "Split"

    // ── typography ─────────────────────────────────────────────────────
    // DM Mono for the number (tabular figures), system font for everything else
    property string numberFont:   "DM Mono"
    property string uiFont:       Qt.application.font.family
    property int    fontSize:     72

    // ── URLs (set at startup from NetworkHelper) ────────────────────────
    property string publicUrl:  "http://localhost:8080/"
    property string adminUrl:   "http://localhost:8080/admin"

    // ── MQTT / connection state (read-only from QML) ────────────────────
    property bool   mqttConnected: false
    property string mqttStatus:    "Connecting…"

    // ── internal: whether persistence has been loaded ───────────────────
    property bool _loaded: false

    // ── load saved state from disk ─────────────────────────────────────
    function loadFromDisk() {
        if (_loaded) return
        _loaded = true
        var p = DisplayPersistence   // context property from Python
        currentNumber = p.load("currentNumber", "001")
        var nu = p.get_next_up()
        nextUp        = Array.isArray(nu) ? nu : []
        layoutType    = p.load("layoutType",   "Classic")
        accentColor   = p.load("accentColor",  "#0078D4")
        bannerText    = p.load("bannerText",   "Welcome — please wait for your number to be called")
        facilityName  = p.load("facilityName", "CandyBar Service Centre")
        fontSize      = parseInt(p.load("fontSize", "72")) || 72
        var lp = p.logo_path()
        if (lp && lp.length > 0)
            logoSource = "file://" + lp
    }

    // ── MQTT command dispatcher ─────────────────────────────────────────
    function applyMqttCommand(key, value) {
        var p = DisplayPersistence
        if (key === "currentNumber") {
            currentNumber = value
            p.save("currentNumber", value)
        } else if (key === "nextUp") {
            // value is comma-separated: "043,044,045"
            var arr = value.length > 0 ? value.split(",").map(function(s){ return s.trim() }) : []
            nextUp = arr
            p.save("nextUp", value)
        } else if (key === "layoutType") {
            layoutType = value
            p.save("layoutType", value)
        } else if (key === "accentColor") {
            accentColor = value
            p.save("accentColor", value)
        } else if (key === "bannerText") {
            bannerText = value
            p.save("bannerText", value)
        } else if (key === "facilityName") {
            facilityName = value
            p.save("facilityName", value)
        } else if (key === "fontSize") {
            var fs = parseInt(value)
            if (fs > 0) { fontSize = fs; p.save("fontSize", fs) }
        } else if (key === "logoSource") {
            // Absolute path sent by server after upload
            logoSource = value.startsWith("file://") ? value : "file://" + value
            p.save("logoPath", value.replace("file://", ""))
        } else if (key === "adminPin") {
            p.set_pin(value)
        }
    }
}
