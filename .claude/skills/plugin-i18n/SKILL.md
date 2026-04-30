---
name: plugin-i18n
description: Translation and localization guide for Noctalia plugin i18n files and runtime lookup. Use when adding translation keys, fallback behavior, or language-aware UI text.
---

# Noctalia Plugin Internationalization (i18n)

Translation system for multi-language plugin support.

## File Structure

```
my-plugin/
├── i18n/
│   ├── en.json      # English (required)
│   ├── es.json      # Spanish
│   └── ...
└── manifest.json
```

## Translation File Format

```json
{
  "title": "My Plugin",
  "status": {
    "online": "Connected",
    "offline": "Disconnected",
    "connecting": "Connecting..."
  },
  "actions": {
    "play": "Play",
    "pause": "Pause",
    "refresh": "Refresh"
  },
  "settings": {
    "title": "Settings",
    "url": "URL",
    "token": "Token"
  },
  "tooltips": {
    "widget": "Click to open panel"
  },
  "errors": {
    "connection": "Connection failed",
    "auth": "Authentication failed"
  },
  "menu": {
    "settings": "Settings",
    "refresh": "Refresh"
  }
}
```

## Using Translations in QML

### Basic Translation

```qml
text: pluginApi?.tr("status.online") || "Connected"
```

### With Fallback

```qml
tooltipText: pluginApi?.tr("tooltips.widget") || "Click to open"
```

### With Interpolation

```qml
// Translation: "connected": "{count} devices connected"
text: pluginApi?.tr("tooltips.connected", { count: deviceCount })
```

### Pluralization

```qml
// Translation file needs both:
// "device": "device"
// "device_plural": "devices"
text: pluginApi?.trp("device", count, "device", "devices", { count: count })
```

### Check Translation Exists

```qml
visible: pluginApi?.hasTranslation("key") ?? false
```

## Translation Key Conventions

| Namespace | Purpose | Example |
|-----------|---------|---------|
| `status.*` | Connection states | `status.online`, `status.connecting` |
| `actions.*` | Action labels | `actions.play`, `actions.refresh` |
| `settings.*` | Settings UI | `settings.url`, `settings.enabled` |
| `tooltips.*` | Hover hints | `tooltips.widget`, `tooltips.status` |
| `errors.*` | Error messages | `errors.connection`, `errors.auth` |
| `menu.*` | Context menu | `menu.settings`, `menu.refresh` |

## Best Practices

1. **Always provide fallbacks** - `|| "Default"`
2. **Use dot notation** - `category.subcategory.key`
3. **Keep keys descriptive** - `settings.refreshInterval` not `sri`
4. **Include at least en.json** - Required baseline
5. **Use interpolation** - `{count}`, `{name}` instead of concatenation
6. **Pluralize properly** - Use `trp()` for count-dependent strings
