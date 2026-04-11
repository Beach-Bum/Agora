pragma Singleton
import QtQuick 2.15

// DSTheme.qml — Centralized theme system for Logos Basecamp modules
// 5 themes: default, solarized, nord, dracula, monokai
// Usage: DSTheme.bg, DSTheme.blue, DSTheme.setTheme("nord")
QtObject {
    id: root

    property string currentTheme: "default"

    // ── Exposed color properties (bound to current theme) ─────────
    readonly property color bg:            _t.bg
    readonly property color fg:            _t.white
    readonly property color red:           _t.red
    readonly property color green:         _t.green
    readonly property color yellow:        _t.yellow
    readonly property color blue:          _t.blue
    readonly property color magenta:       _t.magenta
    readonly property color cyan:          _t.cyan
    readonly property color white:         _t.white
    readonly property color dimFg:         _t.brightBlack
    readonly property color statusBg:      _t.statusBg
    readonly property color activeBg:      _t.activeBg
    readonly property color border:        _t.border
    readonly property color altBg:         Qt.lighter(_t.bg, 1.08)

    // ── Theme names list ──────────────────────────────────────────
    readonly property var themeNames: ["default", "solarized", "nord", "dracula", "monokai", "ayu-dark", "ayu-light"]

    // ── Switch theme ──────────────────────────────────────────────
    function setTheme(name) {
        if (_themes[name]) currentTheme = name
    }

    // ── Internal: resolved theme object ───────────────────────────
    readonly property var _t: _themes[currentTheme] || _themes["default"]

    // ── Theme palettes (from WeeChat-Org ThemeContext.tsx) ─────────
    readonly property var _themes: ({
        "default": {
            bg:          "#1b1d1e",
            red:         "#cc6666",
            green:       "#b5bd68",
            yellow:      "#f0c674",
            blue:        "#81a2be",
            magenta:     "#b294bb",
            cyan:        "#8abeb7",
            white:       "#c5c8c6",
            brightBlack: "#636363",
            statusBg:    "#2a2d2e",
            activeBg:    "#3a3d3e",
            border:      "#4a4d4e"
        },
        "solarized": {
            bg:          "#002b36",
            red:         "#dc322f",
            green:       "#859900",
            yellow:      "#b58900",
            blue:        "#268bd2",
            magenta:     "#d33682",
            cyan:        "#2aa198",
            white:       "#93a1a1",
            brightBlack: "#586e75",
            statusBg:    "#073642",
            activeBg:    "#094959",
            border:      "#2a5a6a"
        },
        "nord": {
            bg:          "#2e3440",
            red:         "#bf616a",
            green:       "#a3be8c",
            yellow:      "#ebcb8b",
            blue:        "#81a1c1",
            magenta:     "#b48ead",
            cyan:        "#88c0d0",
            white:       "#eceff4",
            brightBlack: "#4c566a",
            statusBg:    "#3b4252",
            activeBg:    "#434c5e",
            border:      "#4c566a"
        },
        "dracula": {
            bg:          "#282a36",
            red:         "#ff5555",
            green:       "#50fa7b",
            yellow:      "#f1fa8c",
            blue:        "#bd93f9",
            magenta:     "#ff79c6",
            cyan:        "#8be9fd",
            white:       "#f8f8f2",
            brightBlack: "#6272a4",
            statusBg:    "#343746",
            activeBg:    "#44475a",
            border:      "#6272a4"
        },
        "monokai": {
            bg:          "#272822",
            red:         "#f92672",
            green:       "#a6e22e",
            yellow:      "#e6db74",
            blue:        "#66d9ef",
            magenta:     "#ae81ff",
            cyan:        "#a1efe4",
            white:       "#f8f8f2",
            brightBlack: "#75715e",
            statusBg:    "#3e3d32",
            activeBg:    "#49483e",
            border:      "#75715e"
        },
        "ayu-dark": {
            bg:          "#0a0e14",
            red:         "#f07178",
            green:       "#aad94c",
            yellow:      "#e6b450",
            blue:        "#39bae6",
            magenta:     "#d2a6ff",
            cyan:        "#95e6cb",
            white:       "#bfbdb6",
            brightBlack: "#565b66",
            statusBg:    "#131721",
            activeBg:    "#1a1f29",
            border:      "#2d3640"
        },
        "ayu-light": {
            bg:          "#fafafa",
            red:         "#f07171",
            green:       "#86b300",
            yellow:      "#f2ae49",
            blue:        "#399ee6",
            magenta:     "#a37acc",
            cyan:        "#4cbf99",
            white:       "#5c6166",
            brightBlack: "#8a9199",
            statusBg:    "#eff0f1",
            activeBg:    "#e8e9eb",
            border:      "#d4d5d6"
        }
    })
}
