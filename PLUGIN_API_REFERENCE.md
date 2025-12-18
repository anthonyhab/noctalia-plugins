# Noctalia Plugin Development Reference

This document distills everything we use internally (plus the bits defined in
`Services/Noctalia/PluginService.qml`) into a practical reference when building
or reviewing plugins. It is meant to live inside the repository that we hand to
AI copilots so they always have the same baseline knowledge.

---

## 1. Plugin layout

Every plugin folder mirrors the structure below. Entry points can be omitted if
they are not needed, but the manifest must list the ones that exist.

```
plugins/<id>/
├── manifest.json         # core metadata + entry points
├── Main.qml              # long‑running backend (required for state/storage)
├── Panel.qml             # panel UI (optional)
├── BarWidget.qml         # bar widget entry point (optional)
├── Settings.qml          # settings page (optional but strongly recommended)
├── README.md             # human instructions
└── i18n/<lang>.json      # translations (en.json at minimum)
```

Best practices:

* Declare `property var pluginApi: null` at the top of every entry point.
* Keep helper scripts in a `helper/` subfolder so packaging remains simple.
* Use `manifest.metadata.defaultSettings` for sensible defaults that can be
  referenced from QML (see `dev/plugins/homeassistant/manifest.json`).

---

## 2. `pluginApi` object

Created in `PluginService.createPluginAPI` and injected into every entry point.
The table below lists the stable properties/methods that we rely on today.

| Property / method | Type | Description |
|-------------------|------|-------------|
| `pluginId` | string | Folder/manifest id (e.g. `homeassistant`). |
| `pluginDir` | string | Absolute path to the plugin folder. Useful for locating helper scripts/templates packaged with the plugin. |
| `pluginSettings` | object | Persistent JSON blob stored in `~/.config/noctalia/plugins/<id>.json`. Always mutate fields on this object before calling `saveSettings()`. |
| `manifest` | object | Raw manifest content (so you can read metadata/defaults). |
| `mainInstance` | var | Reference to the `Main.qml` item. Entry points can talk to each other through functions exposed here. |
| `barWidget`, `desktopWidget` | var | References that PluginService sets after loading each entry point (handy for cross‑component coordination). |
| `pluginTranslations` | object | Map produced from `i18n/<lang>.json`. |
| `currentLanguage` | string | Current locale (e.g. `en`). |
| `saveSettings()` | function | Persists `pluginSettings` to disk and re‑emits bindings. Always call this after mutating settings. |
| `openPanel(screen, [sourceItem])` | function | Asks the panel manager to show this plugin’s `Panel.qml` on the given screen. |
| `closePanel(screen)` | function | Requests the active panel (if any) be closed. |
| `withCurrentScreen(callback)` | function | Provides the screen under the cursor, falling back to primary if detection is unavailable. |
| `tr(key, interpolations)` | function | Fetches a translation string from `pluginTranslations`. Returns `## key ##` if missing so missing keys are obvious. |
| `trp(key, count, defaultSingular, defaultPlural, interpolations)` | function | Same as `tr` but handles `_plural` expansion with a count placeholder. |
| `hasTranslation(key)` | function | Boolean helper for conditional UI. |

### Settings workflow

1. Bind local fields in `Settings.qml` to `pluginApi.pluginSettings` and/or
   `manifest.metadata.defaultSettings`.
2. When the user clicks “Save”, update `pluginApi.pluginSettings`, call
   `pluginApi.saveSettings()`, and trigger any runtime refresh you need
   (`pluginApi.mainInstance?.refresh()`).
3. Runtime components should watch for changes via a
   `Connections { target: pluginApi; function onPluginSettingsChanged() { ... } }`
   block.

### Translation workflow

* Store language files under `i18n/<lang>.json`.
* Use `pluginApi.tr("foo.bar")` everywhere. The placeholder format is `{name}`
  (see `PluginService.tr()` implementation).

---

## 3. State & helper processes

The main entry point typically owns:

* long‑running timers (polling, reconnection, debounced saves),
* cached state that panels/widgets bind to,
* wrapper functions that talk to helper scripts (`Quickshell.Io.Process`).

Guidelines:

1. **Always guard helper commands.** Check that the helper path exists and return
   a friendly error in QML before spawning a `Process`.
2. **Use optimistic UI updates.** Update cached state immediately (e.g. local
   volume slider) and then refresh from the helper/Home Assistant when the call
   completes. See `homeassistant/Main.qml:updateSelectedPlayerAttribute`.
3. **Persist only plugin data.** `pluginApi.pluginSettings` is the only storage
   we expose today. If you need larger caches (e.g. binary), store them next to
   the plugin (`pluginDir`) but keep the path configurable.
4. **One helper per action.** The default sandbox limits long‑running daemons,
   so helper scripts should be idempotent CLI utilities (connect → do work →
   print JSON → exit). Our Apple TV helper in `dev/plugins/appletv/helper`
   demonstrates this pattern.

---

## 4. Manifest quick reference

```jsonc
{
  "id": "appletv",             // globally unique identifier
  "name": "Apple TV Direct",
  "version": "0.1.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "habibe",
  "license": "MIT",
  "repository": "https://github.com/anthonyhab/noctalia-plugins",
  "description": "Direct Apple TV/HomePod controls powered by pyatv",
  "entryPoints": {
    "main": "Main.qml",
    "panel": "Panel.qml",
    "barWidget": "BarWidget.qml",
    "settings": "Settings.qml"
  },
  "dependencies": { "plugins": [] },
  "metadata": {
    "defaultSettings": {
      "helperScriptPath": "",
      "pollInterval": 5000
    }
  }
}
```

* `entryPoints.main` is mandatory if the plugin exposes any UI. All other entry
  points are optional but must exist if referenced.
* `metadata.defaultSettings` is purely informational but we use it heavily for
  fallbacks (see `Settings.qml` examples).

---

## 5. Best practices & gotchas

1. **Always declare `pluginApi` in QML.** PluginService warns if a component
   omits `property var pluginApi: null`.
2. **Separate transport vs. UI.** Keep transport logic in `Main.qml` (or helper
   scripts) so panels/widgets only render state and invoke exposed methods.
3. **Expose refresh hooks.** Provide a `refresh()` function on `Main.qml`
   (called by panels and settings when they open) to re-sync state.
4. **Respect sandboxing.** Long‑running background helpers (daemons) should be
   avoided; spawn a `Process` per request. Always capture stdout/stderr using
   `StdioCollector` so errors are visible in logs/UI.
5. **Use translations even for internal tools.** This keeps AI copilots from
   hardcoding English strings.
6. **Document helper requirements.** Each plugin folder should include a
   README with install/pairing steps (e.g. `pip install pyatv`, `atvremote pair`).
7. **Version everything.** Bump `manifest.version` whenever you make compatible
   changes. Update `registry.json` so downstream shells can detect updates.
8. **Don’t check in secrets.** Never commit tokens to `pluginSettings`. For
   local development keep a `settings.sample.json` if needed.

---

## 6. Useful references

* `Services/Noctalia/PluginService.qml` — full plugin lifecycle and API creation.
* `Modules/Bar/Extras/BarWidgetLoader.qml` — how the shell injects `pluginApi`
  into widgets.
* `dev/plugins/homeassistant` — canonical example of a REST-driven plugin.
* `dev/plugins/appletv` — example of a plugin that wraps helper scripts.

Keep this file updated whenever we discover new helper functions or best
practices so future automation has everything it needs in one place.

