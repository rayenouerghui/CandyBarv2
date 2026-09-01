pragma Singleton

import QtQuick 2.15

// ── CandyBarV2 DisplayState ──────────────────────────────────────────────
// Single source of truth for all display properties.
// All changes persist to disk immediately via DisplayStorage.
// applyMqttCommand() is the sole write path.

QtObject {
    id: root

    // ── queue ──────────────────────────────────────────────────────────
    property string currentNumber: "00"
    property var    nextUp: []

    // ── audio / TTS ────────────────────────────────────────────────────
    property bool   audioMuted: false
    property int    audioVolumeStep: 4
    property string ttsLanguage: "fr"
    property bool   ttsEnabled: true

    // ── validation whitelists (fail-safe guards, no architecture change) ──
    readonly property var _validTtsLanguages:         ["en", "fr", "ar"]
    readonly property var _validLayoutTypes:           ["Split1", "Split2", "Centered"]
    readonly property var _validCadreTypes:            ["glass", "dark", "custom", "none"]
    readonly property var _validBackgroundFitModes:    ["crop", "fit", "stretch", "auto"]
    readonly property var _validBackgroundOrientations:["landscape", "portrait"]
    readonly property var _validBackgroundTypes:       ["image", "video"]
    readonly property var _validGradientDirections:    ["top-to-bottom", "corner-to-edge"]
    // NEW: logoPosition previously had zero validation on either load or
    // write, unlike every other enum-like property here. This is the same
    // choice set the admin UI's dropdown actually offers.
    readonly property var _validLogoPositions:          ["top-left", "top-center", "top-right", "hidden"]

    function _isValidColorValue(v) {
        return typeof v === "string" && v.length > 0
    }

    // ── property descriptor table & helpers (sections 4.2–4.4) ─────────────
    // Each entry: {key, default, coerce(v), validate(v), save(v)}
    // Used by loadFromDisk() and applyMqttCommand() to unify validation
    // and coercion logic that was previously duplicated across both.
    readonly property var _propDesc: (function() {
        function boolCoerce(v) { return v === "true" || v === true }
        function boolSave(v) { return v ? "true" : "false" }
        function intCoerce(v) { var n = parseInt(v); return !isNaN(n) ? n : null }
        function floatCoerce(v) { var n = parseFloat(v); return !isNaN(n) ? n : null }
        function enumCoerce(whitelist) {
            return function(v) { return whitelist.indexOf(v) !== -1 ? v : null }
        }
        function colorCoerce(v) { return _isValidColorValue(v) ? v : null }
        function stringCoerce(v) { return typeof v === "string" && v.length > 0 ? v : null }

        // Helper: clamp integer to [lo, hi] or return null
        function intClamp(lo, hi) {
            return function(v) {
                var n = parseInt(v)
                return !isNaN(n) && n >= lo && n <= hi ? n : null
            }
        }
        // Helper: clamp float to [lo, hi] or return null
        function floatClamp(lo, hi) {
            return function(v) {
                var n = parseFloat(v)
                return !isNaN(n) && n >= lo && n <= hi ? n : null
            }
        }

        return [
            // ── queue ────────────────────────────────────────────────────────
            {key: "currentNumber", default: "00", coerce: stringCoerce, validate: stringCoerce},
            {key: "nextUp", default: [], coerce: null, validate: null}, // special case in loadFromDisk

            // ── audio / TTS ────────────────────────────────────────────────────
            {key: "audioMuted", default: false, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "audioVolumeStep", default: 4, coerce: intCoerce, validate: intCoerce},
            {key: "ttsLanguage", default: "fr", coerce: enumCoerce(_validTtsLanguages), validate: enumCoerce(_validTtsLanguages)},
            {key: "ttsEnabled", default: true, coerce: boolCoerce, validate: boolCoerce, save: boolSave},

            // ── category ────────────────────────────────────────────────────────
            {key: "category", default: "pizza", coerce: stringCoerce, validate: stringCoerce},
            {key: "categoryDisplayName", default: "pizza", coerce: stringCoerce, validate: stringCoerce},
            {key: "categoryVisible", default: false, coerce: boolCoerce, validate: boolCoerce, save: boolSave},

            // ── branding ────────────────────────────────────────────────────────
            {key: "logoSource", default: "qrc:/app/res/image/genical.jpg", coerce: null, validate: null}, // special case
            {key: "facilityName", default: "CandyBar Service Centre", coerce: stringCoerce, validate: stringCoerce},
            {key: "bannerText", default: "Welcome — please wait for your number to be called", coerce: stringCoerce, validate: stringCoerce},
            {key: "nowServingText", default: "NOW SERVING", coerce: stringCoerce, validate: stringCoerce},
            {key: "backgroundImage", default: "qrc:/app/res/image/5P.png", coerce: null, validate: null}, // special case
            {key: "backgroundFitMode", default: "crop", coerce: enumCoerce(_validBackgroundFitModes), validate: enumCoerce(_validBackgroundFitModes)},
            {key: "backgroundScale", default: 1.0, coerce: floatCoerce, validate: floatCoerce},
            {key: "backgroundOffsetX", default: 0, coerce: intCoerce, validate: intCoerce},
            {key: "backgroundOffsetY", default: 0, coerce: intCoerce, validate: intCoerce},
            {key: "backgroundOrientation", default: "portrait", coerce: enumCoerce(_validBackgroundOrientations), validate: enumCoerce(_validBackgroundOrientations)},
            {key: "backgroundType", default: "image", coerce: enumCoerce(_validBackgroundTypes), validate: enumCoerce(_validBackgroundTypes)},
            {key: "backgroundVideoSource", default: "", coerce: null, validate: null}, // special case
            {key: "logoPosition", default: "top-center", coerce: enumCoerce(_validLogoPositions), validate: enumCoerce(_validLogoPositions)},
            {key: "bannerEnabled", default: true, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "logoVisible", default: false, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "facilityVisible", default: true, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "nowServingVisible", default: true, coerce: boolCoerce, validate: boolCoerce, save: boolSave},

            // ── design tokens ──────────────────────────────────────────────────
            {key: "bgColor", default: "#0b0d10", coerce: colorCoerce, validate: colorCoerce},
            {key: "accentColor", default: "#8D6E63", coerce: colorCoerce, validate: colorCoerce},
            {key: "accentGradientEnabled", default: true, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "accentGradientDirection", default: "top-to-bottom", coerce: enumCoerce(_validGradientDirections), validate: enumCoerce(_validGradientDirections)},

            // ── layout ─────────────────────────────────────────────────────────
            {key: "layoutType", default: "Centered", coerce: enumCoerce(_validLayoutTypes), validate: enumCoerce(_validLayoutTypes)},

            // ── cadre (frame) ───────────────────────────────────────────────────
            {key: "cadreEnabled", default: false, coerce: boolCoerce, validate: boolCoerce, save: boolSave},
            {key: "cadreType", default: "glass", coerce: function(v) { var c = v === "color" ? "custom" : v; return enumCoerce(_validCadreTypes)(c) }, validate: function(v) { var c = v === "color" ? "custom" : v; return enumCoerce(_validCadreTypes)(c) }},
            {key: "cadreColor", default: "#FFB84D", coerce: colorCoerce, validate: colorCoerce},
            {key: "cadreOpacity", default: 0.85, coerce: floatClamp(0, 1), validate: floatClamp(0, 1)},
            {key: "cadreBlur", default: 32, coerce: floatClamp(0, 100), validate: floatClamp(0, 100)},
            {key: "cadrecornerRadius", default: 24, coerce: floatClamp(0, 64), validate: floatClamp(0, 64)},
            {key: "cadreBorderWidth", default: 1.5, coerce: floatClamp(0, 10), validate: floatClamp(0, 10)},
            {key: "cadrePadding", default: 32, coerce: floatClamp(0, 100), validate: floatClamp(0, 100)},

            // ── typography ─────────────────────────────────────────────────────
            {key: "numberFont", default: "DM Mono", coerce: stringCoerce, validate: stringCoerce},
            {key: "categoryFont", default: "Barriecito", coerce: stringCoerce, validate: stringCoerce},
            {key: "facilityFont", default: "Manosque", coerce: stringCoerce, validate: stringCoerce},
            {key: "bannerFont", default: "Manosque", coerce: stringCoerce, validate: stringCoerce},
            {key: "nowServingFont", default: "Barriecito", coerce: stringCoerce, validate: stringCoerce},
            {key: "fontSize", default: 96, coerce: intClamp(48, 200), validate: intClamp(48, 200)},
            {key: "numberFontSize", default: 315, coerce: intCoerce, validate: intCoerce},
            {key: "categoryFontSize", default: 51, coerce: intCoerce, validate: intCoerce},
            {key: "facilityFontSize", default: 61, coerce: intCoerce, validate: intCoerce},
            {key: "bannerFontSize", default: 41, coerce: intCoerce, validate: intCoerce},
            {key: "nowServingFontSize", default: 38, coerce: intCoerce, validate: intCoerce},
            {key: "logoSize", default: 48, coerce: intClamp(24, 120), validate: intClamp(24, 120)},
            {key: "numberColor", default: "#bb00ff", coerce: colorCoerce, validate: colorCoerce},
            {key: "categoryColor", default: "#ffffff", coerce: colorCoerce, validate: colorCoerce},
            {key: "facilityColor", default: "#ffffff", coerce: colorCoerce, validate: colorCoerce},
            {key: "bannerColor", default: "#FFFFFF", coerce: colorCoerce, validate: colorCoerce},
            {key: "nowServingColor", default: "#FFFFFF", coerce: colorCoerce, validate: colorCoerce},
        ]
    })()

    // Helper: look up descriptor by key
    function _desc(key) {
        for (var i = 0; i < _propDesc.length; ++i) {
            if (_propDesc[i].key === key) return _propDesc[i]
        }
        return null
    }

    // ── category ────────────────────────────────────────────────────────
    property string category: "pizza"
    property string categoryDisplayName: "pizza"
    // Show/hide the category badge on the display
    property bool   categoryVisible: false

    // ── branding ────────────────────────────────────────────────────────
    property string logoSource:   "qrc:/app/res/image/genical.jpg"
    property string facilityName: "CandyBar Service Centre"
    property string bannerText:   "Welcome — please wait for your number to be called"
    property string nowServingText: "NOW SERVING"
    property string backgroundImage: "qrc:/app/res/image/5P.png"
    // "crop" | "fit" | "stretch" | "auto"
    property string backgroundFitMode: "crop"
    property real backgroundScale: 1.0
    property int backgroundOffsetX: 0
    property int backgroundOffsetY: 0
    // "landscape" → PreserveAspectCrop normally
    // "portrait"  → rotate 90° then crop to fill (phone wallpapers on a wide screen)
    property string backgroundOrientation: "portrait"
    property string backgroundType: "image"        // "image" | "video"
    property string backgroundVideoSource: ""       // url to an mp4 template
    property string logoPosition: "top-center"   // top-left | top-center | top-right | hidden
    property bool   bannerEnabled: true
    property bool   logoVisible: false
    property bool   facilityVisible: true
    property bool   nowServingVisible: true

    // ── design tokens ──────────────────────────────────────────────────
    property color  bgColor:      "#0b0d10"
    property color  accentColor:  "#8D6E63"
    property bool   accentGradientEnabled: true
    property string accentGradientDirection: "top-to-bottom"  // top-to-bottom | corner-to-edge

    // ── layout ─────────────────────────────────────────────────────────
    property string layoutType: "Centered"   // "Split1" | "Split2" | "Centered"

    // ── cadre (frame) ───────────────────────────────────────────────────
    property bool   cadreEnabled: false
    property string cadreType: "glass"        // "glass" | "color" | "dark" | "light" | "gradient" | "none"
    property color  cadreColor: "#FFB84D"
    property real   cadreOpacity: 0.85
    property real   cadreBlur: 32
    property real   cadrecornerRadius: 24
    property real   cadreBorderWidth: 1.5
    property real   cadrePadding: 32

    // ── typography ─────────────────────────────────────────────────────
    // fontSize: continuous 48–200px, set directly via slider — no preset enum
    property string numberFont: "DM Mono"
    property string categoryFont: "Barriecito"
    property string facilityFont: "Manosque"
    property string bannerFont: "Manosque"
    property string nowServingFont: "Barriecito"
    property string uiFont:     Qt.application.font.family
    property int    fontSize:   96
    property int    numberFontSize: 315
    property int    categoryFontSize: 51
    property int    facilityFontSize: 61
    property int    bannerFontSize: 41
    property int    nowServingFontSize: 38
    // Per-element colors for individual text customization
    property color  numberColor: "#bb00ff"
    property color  categoryColor: "#ffffff"
    property color  facilityColor: "#ffffff"
    property color  bannerColor: "#FFFFFF"
    property color  nowServingColor: "#FFFFFF"

    // ── logo ────────────────────────────────────────────────────────────
    // logoSize: logo container height in px, 24–120, aspect ratio preserved
    property int    logoSize:   48

    // ── URLs (set at startup from NetworkHelper) ────────────────────────
    property string publicUrl: "http://localhost:8080/"
    property string adminUrl:  "http://localhost:8080/admin"
    property string siteUrl:   "https://candybarv2.app"

    // ── MQTT / connection state ─────────────────────────────────────────
    property bool   mqttConnected: false
    property string mqttStatus:    "Connecting…"

    property bool   _loaded: false

    function accentAlpha(a) {
        return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, a)
    }

    function _bgSource(path) {
        if (typeof path !== "string" || !path || path.length === 0) return "qrc:/app/res/image/1P.png"
        if (path === "qrc:/app/res/image/0.jpg") {
            return "qrc:/app/res/image/1P.png"
        }
        if (path.startsWith("qrc:") || path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return path
    }

    function _videoSource(url) {
        if (!url || url.length === 0) return ""
        if (url.startsWith("file://") || url.startsWith("http://") || url.startsWith("https://")) return url
        if (url.startsWith("/")) return publicUrl.replace(/\/$/, "") + url
        return url
    }

    function _syncAudioEngine() {
        if (typeof AudioEngine === 'undefined') return
        try {
            AudioEngine.muted      = audioMuted
            AudioEngine.volumeStep = audioVolumeStep
            AudioEngine.language   = ttsLanguage
            AudioEngine.ttsEnabled = ttsEnabled
        } catch (e) {
            console.warn("DisplayState: _syncAudioEngine failed:", e)
        }
    }

    function loadFromDisk() {
        if (_loaded) return
        _loaded = true
        try {
            var p = DisplayStorage

            // Special cases not covered by the descriptor table
            currentNumber = p.load("currentNumber", "00")
            var nu = p.get_next_up()
            nextUp = Array.isArray(nu) ? nu : []

            // Load all descriptor-backed properties
            for (var i = 0; i < _propDesc.length; ++i) {
                var d = _propDesc[i]
                if (!d.coerce) continue // skip special cases (logoSource, backgroundImage, backgroundVideoSource, nextUp)

                var raw = p.load(d.key, String(d.default))
                var coerced = d.coerce(raw)
                if (coerced !== null) {
                    root[d.key] = coerced
                } else {
                    console.warn("DisplayState: loadFromDisk: invalid value for", d.key, "using default:", d.default)
                    root[d.key] = d.default
                }
            }

            // Special cases with custom logic
            logoSource = _bgSource(p.load("logoSource", "qrc:/app/res/image/genical.jpg"))
            backgroundImage = _bgSource(p.load("backgroundImage", "qrc:/app/res/image/5P.png"))
            backgroundVideoSource = _videoSource(p.load("backgroundVideoSource", ""))

            _syncAudioEngine()
        } catch (e) {
            console.warn("DisplayState: loadFromDisk failed, using safe defaults:", e)
            // Properties already carry their declared defaults, so the app
            // remains in a valid (if not fully restored) state.
        }
    }

    function applyMqttCommand(key, value) {
        try {
            var p = DisplayStorage

            // ── special cases with custom logic ───────────────────────────────
            if (key === "currentNumber") {
                var skipAudio = value.includes("|nosound")
                var cleanValue = value.replace("|nosound", "")
                currentNumber = cleanValue
                p.save("currentNumber", cleanValue)
                if (!skipAudio && ttsEnabled && !audioMuted && typeof AudioEngine !== 'undefined') {
                    AudioEngine.announceNumber(cleanValue)
                }
                return
            }

            if (key === "nextUp") {
                nextUp = value.length > 0 ? value.split(",").map(function(s){ return s.trim() }) : []
                p.save("nextUp", value)
                return
            }

            if (key === "adminPin") {
                p.set_pin(value)
                return
            }

            if (key === "categoryDisplayName") {
                categoryDisplayName = value
                p.save("categoryDisplayName", value)
                _syncAudioEngine()
                return
            }

            if (key === "logoSource") {
                if (!value || value.length === 0) {
                    logoSource = ""
                    logoVisible = false
                } else {
                    var resolved = _bgSource(value)
                    logoSource = ""
                    logoSource = resolved
                }
                p.save("logoSource", value)
                return
            }

            if (key === "backgroundImage") {
                backgroundImage = _bgSource(value)
                p.save("backgroundImage", value)
                return
            }

            if (key === "backgroundVideoSource") {
                backgroundVideoSource = _videoSource(value)
                p.save("backgroundVideoSource", value)
                return
            }

            if (key === "fontSize") {
                var fs = parseInt(value)
                if (!isNaN(fs) && fs >= 120 && fs <= 800) {
                    fontSize = fs
                    numberFontSize = fs
                    p.save("fontSize", fs)
                    p.save("numberFontSize", fs)
                } else {
                    console.warn("DisplayState: ignored invalid fontSize:", value)
                }
                return
            }

            // ── descriptor-table-backed properties ─────────────────────────────
            var d = _desc(key)
            if (d) {
                var validated = d.validate ? d.validate(value) : d.coerce ? d.coerce(value) : value
                if (validated !== null && validated !== undefined) {
                    root[key] = validated
                    p.save(key, d.save ? d.save(validated) : String(validated))
                    // Sync audio engine for audio-related keys
                    if (key === "ttsLanguage" || key === "ttsEnabled" || key === "audioMuted" || key === "audioVolumeStep") {
                        _syncAudioEngine()
                    }
                } else {
                    console.warn("DisplayState: ignored invalid value for", key, ":", value)
                }
                return
            }

            console.warn("DisplayState: unknown MQTT key ignored:", key)
        } catch (e) {
            console.warn("DisplayState: applyMqttCommand failed for key:", key, "value:", value, "error:", e)
            // Swallow the error — a bad command must never crash the app
            // or leave a property/persistence layer in a corrupted state.
        }
    }
}