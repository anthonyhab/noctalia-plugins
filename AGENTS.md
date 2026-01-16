# Plugin Development Guidelines

> **See also:** [docs/REFERENCE.md](docs/REFERENCE.md) for comprehensive QML, Quickshell, and Noctalia API documentation.

## Commit Discipline

- **NEVER push before I tell you to** - wait for explicit approval
- Keep commits tight and manageable for verification
- Never mention which agent is being used in commit messages
- One logical change per commit
- Test before commit to avoid rapid-fire fix commits
- If fixing a fix within minutes, squash or amend instead

## Version Bumping

Version numbers follow semantic versioning:
- **Patch (0.0.x)**: Bug fixes, UI/alignment fixes, typos
- **Minor (0.x.0)**: New features, new settings, behavior changes
- **Major (x.0.0)**: Breaking API changes

**Critical Rules:**
- **Only bump versions when pushing** - not during development
- Commits get squashed before release, so bump once at the end
- Never skip version numbers (0.1.0 → 0.1.1, not 0.1.2)
- Always update `registry.json` when bumping manifest version
- Version bump should be part of the final squashed commit

## Pre-Commit Checklist

Before committing any plugin changes:
1. Visual test the UI in Noctalia Shell
2. Verify manifest has all required fields (see below)
3. Check `registry.json` is updated if version was bumped
4. Run through all affected user flows
5. Test settings persistence and defaults

## Manifest Requirements

Every `manifest.json` must include these fields:

```json
{
  "id": "plugin-id",
  "name": "Plugin Display Name",
  "version": "0.1.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "habibe",
  "license": "MIT",
  "repository": "https://github.com/anthonyhab/noctalia-plugins",
  "description": "Brief explanation of functionality.",
  "tags": ["Bar", "System"],
  "entryPoints": {
    "main": "Main.qml",
    "panel": "Panel.qml",
    "barWidget": "BarWidget.qml",
    "settings": "Settings.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "settingKey": "defaultValue"
    }
  }
}
```

### Required Fields
| Field | Description |
|-------|-------------|
| `id` | Unique plugin identifier (lowercase, hyphens) |
| `name` | Human-readable display name |
| `version` | Semantic version (x.y.z) |
| `minNoctaliaVersion` | Minimum compatible Noctalia version |
| `author` | Creator name |
| `license` | License type (MIT) |
| `repository` | Source repository URL |
| `description` | Brief explanation of functionality |
| `tags` | Array of category tags |
| `entryPoints` | Map of component file paths |
| `dependencies` | Plugin dependencies object |
| `metadata.defaultSettings` | All user settings with defaults |

### Tag Categories

**Widget Types:** Bar, Desktop, Panel, Launcher

**Functional:** Productivity, System, Audio, Network, Privacy, Development, Fun, Gaming, Indicator

## Plugin File Structure

Each plugin directory must include:
- `manifest.json` (required)
- `Main.qml` (optional) - Primary component or IPC logic
- `BarWidget.qml` (optional) - Bar display component
- `Panel.qml` (optional) - Panel component
- `Settings.qml` (optional) - Settings interface
- `preview.png` (required for official repo) - Preview image
- `README.md` (required for official repo) - Plugin documentation

## Code Patterns

### Settings Access
Always use the fallback pattern:
```qml
property var pluginApi: null

function getSetting(key, fallback) {
    if (!pluginApi) return fallback
    var val = pluginApi.getSetting(key)
    return (val === undefined || val === null) ? fallback : val
}
```

### Entry Point Structure
Always declare `pluginApi` first in entry points:
```qml
import QtQuick
import QtQuick.Controls

Item {
    property var pluginApi: null

    // Component code...
}
```

### Logging
Use the Logger with plugin ID prefix:
```qml
Logger.d("PluginId", "Debug message")
Logger.i("PluginId", "Info message")
Logger.w("PluginId", "Warning message")
Logger.e("PluginId", "Error message")
```

### Translations
Use optional chaining for translations:
```qml
text: pluginApi?.tr("translationKey") ?? "Fallback"
```

## Common Pitfalls (from Official Repo)

Lessons from bugs fixed in `noctalia-dev/noctalia-plugins`:

### Race Conditions
- **Settings loading**: Don't assume settings are available immediately
- Use proper initialization checks before accessing `pluginApi.getSetting()`
- Avoid arbitrary delays (100ms timers) - use proper signals instead

### Parser Edge Cases
- Regex patterns must account for duplicates and edge cases
- Test with unusual input formats (special keys like XF86, modifiers)
- Validate parsed data before using it

### UI Issues
- **Z-index ordering**: Ensure overlays render above content (use `z: 1` or higher)
- **Element positioning**: Test with varying content sizes
- **Visual polish**: Remove unnecessary text labels, use clear icons

### Argument Handling
- Commands with arguments: capture full command strings, not just names
- Test spawn/exec commands with complex argument patterns

### User Experience
- New items in lists should appear at top, not bottom
- Use human-readable names (e.g., "Vol+" instead of "XF86AudioRaiseVolume")
- Provide clear error states with proper visibility

## Submitting to Official Repository

To get plugins merged into `noctalia-dev/noctalia-plugins`:

1. Fork the official repository
2. Create plugin directory with proper structure
3. Include complete `manifest.json` with all required fields
4. Add `preview.png` for website display
5. Add `README.md` documenting the plugin
6. Test thoroughly with Noctalia Shell
7. Submit pull request

The `registry.json` is automatically updated by GitHub Actions upon merge.
