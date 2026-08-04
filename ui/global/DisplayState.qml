pragma Singleton

import QtQuick 2.15

// ── CandyBarV2 DisplayState ──────────────────────────────────────────────
// Single source of truth for all display properties.
// All changes persist to disk immediately via DisplayPersistence.
// applyMqttCommand() is the sole write path.

QtObject {
    id: root

    // ── queue ──────────────────────────────────────────────────────────
    property string currentNumber: "001"
    property var    nextUp: []

    // ── audio / TTS ────────────────────────────────────────────────────
    property bool   audioMuted: false
    property int    audioVolumeStep: 3
    property string ttsLanguage: "en"
    property bool   ttsEnabled: true

    // ── display language ────────────────────────────────────────────────
    // Controls all on-screen text (NOW SERVING, NEXT UP, Visit our website…).
    // Independent from ttsLanguage — you can display in French while
    // announcing in Arabic, or use any combination.
    // Values: "en" | "fr"
    property string displayLanguage: "en"

    // Translations for every on-screen string, keyed by displayLanguage.
    readonly property var _tr: ({
        "en": {
            now_serving:   "NOW SERVING",
            next_up:       "NEXT UP",
            visit_website: "Visit our website",
            proceed:       "Please proceed to your counter",
            connecting:    "Connecting…",
            reconnecting:  "Reconnecting…"
        },
        "fr": {
            now_serving:   "EN SERVICE",
            next_up:       "PROCHAINS",
            visit_website: "Visitez notre site",
            proceed:       "Veuillez vous rendre à votre guichet",
            connecting:    "Connexion…",
            reconnecting:  "Reconnexion…"
        }
    })

    // Convenience accessor — always returns a valid string even if the key
    // or language is missing.
    function tr(key) {
        var lang = _tr[displayLanguage] ? displayLanguage : "en"
        return _tr[lang][key] || _tr["en"][key] || key
    }

    // ── validation whitelists (fail-safe guards, no architecture change) ──
    readonly property var _validLanguages:            ["en", "fr"]
    readonly property var _validTtsLanguages:         ["en", "fr", "ar"]
    readonly property var _validLayoutTypes:           ["Split", "Centered"]
    readonly property var _validBackgroundFitModes:    ["crop", "fit", "stretch", "auto"]
    readonly property var _validBackgroundOrientations:["landscape", "portrait"]
    readonly property var _validBackgroundTypes:       ["image", "video"]
    readonly property var _validGradientDirections:    ["top-to-bottom", "corner-to-edge"]

    function _isValidColorValue(v) {
        return typeof v === "string" && v.length > 0
    }

    // ── category ────────────────────────────────────────────────────────
    property string category: "A"
    property string categoryDisplayName: "Category A"
    // Show/hide the category badge on the display
    property bool   categoryVisible: true
    // Announce category name in TTS before the number ("Chicken... 12")
    property bool   categoryAudioEnabled: true

    // ── branding ────────────────────────────────────────────────────────
    property string logoSource:   "qrc:/app/res/image/genical.jpg"
    property string facilityName: "CandyBar Service Centre"
    property string bannerText:   "Welcome — please wait for your number to be called"
    property string backgroundImage: "qrc:/app/res/image/ff_burger_pattern.jpg"
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
    property string logoPosition: "top-left"   // top-left | top-center | hidden
    property bool   bannerEnabled: true
    property bool   logoVisible: true
    property bool   facilityVisible: true

    // ── design tokens ──────────────────────────────────────────────────
    property color  bgColor:      "#0b0d10"
    property color  accentColor:  "#FFB84D"
    property bool   accentGradientEnabled: false
    property string accentGradientDirection: "top-to-bottom"  // top-to-bottom | corner-to-edge

    // ── layout ─────────────────────────────────────────────────────────
    property string layoutType: "Centered"   // "Split" | "Centered"

    // ── typography ─────────────────────────────────────────────────────
    // fontSize: continuous 48–200px, set directly via slider — no preset enum
    property string numberFont: "DM Mono"
    property string categoryFont: "LC Mogi"
    property string facilityFont: "Manosque"
    property string bannerFont: "Manosque"
    property string nowServingFont: "Barriecito"
    property string uiFont:     Qt.application.font.family
    property int    fontSize:   96
    property int    numberFontSize: 96
    property int    categoryFontSize: 34
    property int    facilityFontSize: 24
    property int    bannerFontSize: 24
    property int    nowServingFontSize: 16
    // Per-element colors for individual text customization
    property color  numberColor: accentColor
    property color  categoryColor: accentColor
    property color  facilityColor: accentColor
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
        if (!path || path.length === 0) return "qrc:/app/res/image/ff_burger_pattern.jpg"
        if (path === "qrc:/app/res/image/0.jpg") {
            return "qrc:/app/res/image/ff_burger_pattern.jpg"
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
            AudioEngine.muted                = audioMuted
            AudioEngine.volumeStep           = audioVolumeStep
            AudioEngine.language             = ttsLanguage
            AudioEngine.ttsEnabled           = ttsEnabled
            AudioEngine.categoryAudioEnabled = categoryAudioEnabled
            AudioEngine.set_category_display_name(categoryDisplayName)
        } catch (e) {
            console.warn("DisplayState: _syncAudioEngine failed:", e)
        }
    }

    function loadFromDisk() {
        if (_loaded) return
        _loaded = true
        try {
            var p = DisplayPersistence
            currentNumber         = p.load("currentNumber", "001")
            var nu                = p.get_next_up()
            nextUp                = Array.isArray(nu) ? nu : []

            var lt = p.load("layoutType", "Centered")
            layoutType = _validLayoutTypes.indexOf(lt) !== -1 ? lt : "Centered"

            accentColor           = p.load("accentColor", "#FFB84D")
            accentGradientEnabled    = p.load("accentGradientEnabled", "false") === "true"

            var agd = p.load("accentGradientDirection", "top-to-bottom")
            accentGradientDirection = _validGradientDirections.indexOf(agd) !== -1 ? agd : "top-to-bottom"

            bgColor               = p.load("bgColor", "#0b0d10")

            bannerText            = p.load("bannerText", "Welcome — please wait for your number to be called")
            facilityName          = p.load("facilityName", "CandyBar Service Centre")
            category              = p.load("category", "A")
            categoryDisplayName   = p.load("categoryDisplayName", "Category A")
            categoryVisible       = p.load("categoryVisible", "true") !== "false"
            categoryAudioEnabled  = p.load("categoryAudioEnabled", "true") !== "false"
            logoPosition          = p.load("logoPosition", "top-left")
            bannerEnabled         = p.load("bannerEnabled", "true") !== "false"
            logoVisible           = p.load("logoVisible", "true") !== "false"
            facilityVisible       = p.load("facilityVisible", "true") !== "false"

            numberFont            = p.load("numberFont", "DM Mono")
            categoryFont          = p.load("categoryFont", "LC Mogi")
            facilityFont          = p.load("facilityFont", "Manosque")
            bannerFont            = p.load("bannerFont", "Manosque")
            nowServingFont        = p.load("nowServingFont", "Barriecito")

            var ttsl = p.load("ttsLanguage", "en")
            ttsLanguage = _validLanguages.indexOf(ttsl) !== -1 ? ttsl : "en"

            ttsEnabled            = p.load("ttsEnabled", "true") !== "false"

            var dl = p.load("displayLanguage", "en")
            displayLanguage = _validLanguages.indexOf(dl) !== -1 ? dl : "en"

            audioMuted            = p.load("audioMuted", "false") === "true"

            var avs = parseInt(p.load("audioVolumeStep", "3"))
            audioVolumeStep = !isNaN(avs) ? avs : 3

            var fs                = parseInt(p.load("fontSize", "96"))
            fontSize              = (!isNaN(fs) && fs >= 48 && fs <= 200) ? fs : 96

            var nfs = parseInt(p.load("numberFontSize", fontSize))
            numberFontSize = !isNaN(nfs) ? nfs : fontSize

            var cfs = parseInt(p.load("categoryFontSize", 120))
            categoryFontSize = !isNaN(cfs) ? cfs : 120

            var ffs = parseInt(p.load("facilityFontSize", 120))
            facilityFontSize = !isNaN(ffs) ? ffs : 120

            var bfs = parseInt(p.load("bannerFontSize", 120))
            bannerFontSize = !isNaN(bfs) ? bfs : 120

            var sfs = parseInt(p.load("nowServingFontSize", 120))
            nowServingFontSize = !isNaN(sfs) ? sfs : 120

            // Per-element colors — must be loaded, previously missing entirely.
            var nc = p.load("numberColor", accentColor.toString())
            numberColor = _isValidColorValue(nc) ? nc : accentColor

            var cc = p.load("categoryColor", accentColor.toString())
            categoryColor = _isValidColorValue(cc) ? cc : accentColor

            var fc = p.load("facilityColor", accentColor.toString())
            facilityColor = _isValidColorValue(fc) ? fc : accentColor

            var bc = p.load("bannerColor", "#FFFFFF")
            bannerColor = _isValidColorValue(bc) ? bc : "#FFFFFF"

            var nsc = p.load("nowServingColor", "#FFFFFF")
            nowServingColor = _isValidColorValue(nsc) ? nsc : "#FFFFFF"

            var ls                = parseInt(p.load("logoSize", "48"))
            logoSize              = (!isNaN(ls) && ls >= 24 && ls <= 120) ? ls : 48

            var lp                = p.logo_path()
            if (lp && lp.length > 0)
                logoSource = "file://" + lp

            backgroundImage       = _bgSource(p.load("backgroundImage", "qrc:/app/res/image/ff_burger_pattern.jpg"))

            var bfm = p.load("backgroundFitMode", "crop")
            backgroundFitMode = _validBackgroundFitModes.indexOf(bfm) !== -1 ? bfm : "crop"

            var bs = parseFloat(p.load("backgroundScale", "1.0"))
            backgroundScale = !isNaN(bs) ? bs : 1.0

            var bx = parseInt(p.load("backgroundOffsetX", "0"))
            backgroundOffsetX = !isNaN(bx) ? bx : 0

            var by = parseInt(p.load("backgroundOffsetY", "0"))
            backgroundOffsetY = !isNaN(by) ? by : 0

            var bo = p.load("backgroundOrientation", "portrait")
            backgroundOrientation = _validBackgroundOrientations.indexOf(bo) !== -1 ? bo : "portrait"

            var bt = p.load("backgroundType", "image")
            backgroundType = _validBackgroundTypes.indexOf(bt) !== -1 ? bt : "image"

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
            var p = DisplayPersistence
            if (key === "currentNumber") {
                var prev = currentNumber
                currentNumber = value
                p.save("currentNumber", value)
                if (ttsEnabled && !audioMuted && prev !== value
                        && typeof AudioEngine !== 'undefined') {
                    AudioEngine.announceNumber(value)
                }
            } else if (key === "nextUp") {
                nextUp = value.length > 0 ? value.split(",").map(function(s){ return s.trim() }) : []
                p.save("nextUp", value)
            } else if (key === "layoutType") {
                if (_validLayoutTypes.indexOf(value) !== -1) {
                    layoutType = value
                    p.save("layoutType", value)
                } else {
                    console.warn("DisplayState: ignored invalid layoutType:", value)
                }
            } else if (key === "accentColor") {
                if (_isValidColorValue(value)) {
                    accentColor = value
                    p.save("accentColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid accentColor:", value)
                }
            } else if (key === "accentGradientEnabled") {
                accentGradientEnabled = value === "true" || value === true
                p.save("accentGradientEnabled", accentGradientEnabled ? "true" : "false")
            } else if (key === "accentGradientDirection") {
                if (_validGradientDirections.indexOf(value) !== -1) {
                    accentGradientDirection = value
                    p.save("accentGradientDirection", value)
                } else {
                    console.warn("DisplayState: ignored invalid accentGradientDirection:", value)
                }
            } else if (key === "bgColor") {
                if (_isValidColorValue(value)) {
                    bgColor = value
                    p.save("bgColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid bgColor:", value)
                }
            } else if (key === "bannerText") {
                bannerText = value
                p.save("bannerText", value)
            } else if (key === "facilityName") {
                facilityName = value
                p.save("facilityName", value)
            } else if (key === "fontSize") {
                var fs = parseInt(value)
                if (!isNaN(fs) && fs >= 48 && fs <= 200) { fontSize = fs; numberFontSize = fs; p.save("fontSize", fs); p.save("numberFontSize", fs) }
                else console.warn("DisplayState: ignored invalid fontSize:", value)
            } else if (key === "numberFontSize") {
                var nfs = parseInt(value)
                if (!isNaN(nfs) && nfs >= 120 && nfs <= 800) { numberFontSize = nfs; p.save("numberFontSize", nfs) }
                else console.warn("DisplayState: ignored invalid numberFontSize:", value)
            } else if (key === "categoryFontSize") {
                var cfs = parseInt(value)
                if (!isNaN(cfs) && cfs >= 120 && cfs <= 800) { categoryFontSize = cfs; p.save("categoryFontSize", cfs) }
                else console.warn("DisplayState: ignored invalid categoryFontSize:", value)
            } else if (key === "facilityFontSize") {
                var ffs = parseInt(value)
                if (!isNaN(ffs) && ffs >= 120 && ffs <= 800) { facilityFontSize = ffs; p.save("facilityFontSize", ffs) }
                else console.warn("DisplayState: ignored invalid facilityFontSize:", value)
            } else if (key === "bannerFontSize") {
                var bfs = parseInt(value)
                if (!isNaN(bfs) && bfs >= 120 && bfs <= 800) { bannerFontSize = bfs; p.save("bannerFontSize", bfs) }
                else console.warn("DisplayState: ignored invalid bannerFontSize:", value)
            } else if (key === "nowServingFontSize") {
                var sfs = parseInt(value)
                if (!isNaN(sfs) && sfs >= 120 && sfs <= 800) { nowServingFontSize = sfs; p.save("nowServingFontSize", sfs) }
                else console.warn("DisplayState: ignored invalid nowServingFontSize:", value)
            } else if (key === "logoSize") {
                var ls = parseInt(value)
                if (!isNaN(ls) && ls >= 24 && ls <= 120) { logoSize = ls; p.save("logoSize", ls) }
                else console.warn("DisplayState: ignored invalid logoSize:", value)
            } else if (key === "numberFont") {
                numberFont = value
                p.save("numberFont", value)
            } else if (key === "categoryFont") {
                categoryFont = value
                p.save("categoryFont", value)
            } else if (key === "facilityFont") {
                facilityFont = value
                p.save("facilityFont", value)
            } else if (key === "bannerFont") {
                bannerFont = value
                p.save("bannerFont", value)
            } else if (key === "nowServingFont") {
                nowServingFont = value
                p.save("nowServingFont", value)
            } else if (key === "logoSource") {
                logoSource = value.startsWith("file://") ? value : "file://" + value
                p.save("logoPath", value.replace("file://", ""))
            } else if (key === "backgroundImage") {
                backgroundImage = _bgSource(value)
                p.save("backgroundImage", value.replace("file://", ""))
            } else if (key === "backgroundFitMode") {
                if (_validBackgroundFitModes.indexOf(value) !== -1) {
                    backgroundFitMode = value
                    p.save("backgroundFitMode", value)
                } else {
                    console.warn("DisplayState: ignored invalid backgroundFitMode:", value)
                }
            } else if (key === "backgroundScale") {
                var bsv = parseFloat(value)
                if (!isNaN(bsv)) { backgroundScale = bsv; p.save("backgroundScale", String(backgroundScale)) }
                else console.warn("DisplayState: ignored invalid backgroundScale:", value)
            } else if (key === "backgroundOffsetX") {
                var bxv = parseInt(value)
                if (!isNaN(bxv)) { backgroundOffsetX = bxv; p.save("backgroundOffsetX", String(backgroundOffsetX)) }
                else console.warn("DisplayState: ignored invalid backgroundOffsetX:", value)
            } else if (key === "backgroundOffsetY") {
                var byv = parseInt(value)
                if (!isNaN(byv)) { backgroundOffsetY = byv; p.save("backgroundOffsetY", String(backgroundOffsetY)) }
                else console.warn("DisplayState: ignored invalid backgroundOffsetY:", value)
            } else if (key === "backgroundOrientation") {
                if (_validBackgroundOrientations.indexOf(value) !== -1) {
                    backgroundOrientation = value
                    p.save("backgroundOrientation", value)
                } else {
                    console.warn("DisplayState: ignored invalid backgroundOrientation:", value)
                }
            } else if (key === "backgroundType") {
                if (_validBackgroundTypes.indexOf(value) !== -1) {
                    backgroundType = value
                    p.save("backgroundType", value)
                } else {
                    console.warn("DisplayState: ignored invalid backgroundType:", value)
                }
            } else if (key === "backgroundVideoSource") {
                backgroundVideoSource = _videoSource(value); p.save("backgroundVideoSource", value)
            } else if (key === "adminPin") {
                p.set_pin(value)
            } else if (key === "category") {
                category = value
                p.save("category", value)
            } else if (key === "categoryDisplayName") {
                categoryDisplayName = value
                p.save("categoryDisplayName", value)
                _syncAudioEngine()
            } else if (key === "categoryVisible") {
                categoryVisible = value === "true" || value === true
                p.save("categoryVisible", categoryVisible ? "true" : "false")
            } else if (key === "categoryAudioEnabled") {
                categoryAudioEnabled = value === "true" || value === true
                p.save("categoryAudioEnabled", categoryAudioEnabled ? "true" : "false")
                _syncAudioEngine()
            } else if (key === "logoPosition") {
                logoPosition = value
                p.save("logoPosition", value)
            } else if (key === "numberColor") {
                if (_isValidColorValue(value)) {
                    numberColor = value
                    p.save("numberColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid numberColor:", value)
                }
            } else if (key === "categoryColor") {
                if (_isValidColorValue(value)) {
                    categoryColor = value
                    p.save("categoryColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid categoryColor:", value)
                }
            } else if (key === "facilityColor") {
                if (_isValidColorValue(value)) {
                    facilityColor = value
                    p.save("facilityColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid facilityColor:", value)
                }
            } else if (key === "bannerColor") {
                if (_isValidColorValue(value)) {
                    bannerColor = value
                    p.save("bannerColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid bannerColor:", value)
                }
            } else if (key === "nowServingColor") {
                if (_isValidColorValue(value)) {
                    nowServingColor = value
                    p.save("nowServingColor", value)
                } else {
                    console.warn("DisplayState: ignored invalid nowServingColor:", value)
                }
            } else if (key === "bannerEnabled") {
                bannerEnabled = value === "true" || value === true
                p.save("bannerEnabled", bannerEnabled ? "true" : "false")
            } else if (key === "logoVisible") {
                logoVisible = value === "true" || value === true
                p.save("logoVisible", logoVisible ? "true" : "false")
            } else if (key === "facilityVisible") {
                facilityVisible = value === "true" || value === true
                p.save("facilityVisible", facilityVisible ? "true" : "false")
            } else if (key === "ttsLanguage") {
                if (_validTtsLanguages.indexOf(value) !== -1) {
                    ttsLanguage = value
                    p.save("ttsLanguage", value)
                    _syncAudioEngine()
                } else {
                    console.warn("DisplayState: ignored invalid ttsLanguage:", value)
                }
            } else if (key === "displayLanguage") {
                if (_validLanguages.indexOf(value) !== -1) {
                    displayLanguage = value
                    p.save("displayLanguage", value)
                } else {
                    console.warn("DisplayState: ignored invalid displayLanguage:", value)
                }
            } else if (key === "ttsEnabled") {
                ttsEnabled = value === "true" || value === true
                p.save("ttsEnabled", ttsEnabled ? "true" : "false")
                _syncAudioEngine()
            } else if (key === "audioMuted") {
                audioMuted = value === "true" || value === true
                p.save("audioMuted", audioMuted ? "true" : "false")
                _syncAudioEngine()
            } else if (key === "audioVolumeStep") {
                var avs = parseInt(value)
                audioVolumeStep = !isNaN(avs) ? avs : audioVolumeStep
                p.save("audioVolumeStep", audioVolumeStep)
                _syncAudioEngine()
            } else {
                console.warn("DisplayState: unknown MQTT key ignored:", key)
            }
        } catch (e) {
            console.warn("DisplayState: applyMqttCommand failed for key:", key, "value:", value, "error:", e)
            // Swallow the error — a bad command must never crash the app
            // or leave a property/persistence layer in a corrupted state.
        }
    }
}