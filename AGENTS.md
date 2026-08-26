# Noctalia Plugin Repo - Agent Guide

This file is the operational guide for working in this repository.

For API details, widget properties, and deep QML patterns, use the references and project rules below.

## Scope

- Repository purpose: ship stable, installable Noctalia plugins.
- Platform: Noctalia Shell, Quickshell, Qt6/QML on Hyprland/Wayland.
- Stable plugins are listed in `registry.json`.

## Source Of Truth

- Operational workflow and release policy: `docs/MAINTENANCE.md`
- API reference: `docs/NOCTALIA_API.md`
- Plugin manifests: `*/manifest.json`
- Stable distribution index: `registry.json`

## Branch Policy

- `main` is stable distribution only.
- WIP plugins belong in dedicated branches (`dev/<plugin-id>` or `feature/<topic>`).
- Do not add WIP plugins to `registry.json`.

## Core Engineering Rules

### QML And Noctalia

- Use Qt6-native modules only. Do not use `Qt5Compat`.
- Keep UI declarative; avoid imperative `onCompleted` rewiring unless required.
- Use `Logger` (not `console.log`).
- Prefer `N*` widgets before custom controls.
- Keep delegates lightweight; avoid heavy nested layouts in list delegates.

### pluginApi Safety

- Declare `property var pluginApi: null` in every entry point.
- Use defensive access (`pluginApi?.pluginSettings`).
- In settings UIs, buffer local state and save via explicit `saveSettings()`.

### Translations

- Use `pluginApi?.tr("key.path")` for UI strings.
- Do not hardcode visible strings in plugin UI.
- Keep `i18n/en.json` in sync with used keys.

### Widget Pitfalls

- `NIconButton` icon color property is `colorFg` (not `iconColor`).
- Include required BarWidget injected properties:
  - `screen`, `widgetId`, `section`, `sectionWidgetIndex`, `sectionWidgetsCount`

## Manifest And Registry Rules

- Manifest fields must stay accurate (`id`, `name`, `version`, `minNoctaliaVersion`, entry points).
- `registry.json` entries must match stable plugin manifests for:
  - `id`
  - `name`
  - `version`
  - `description`
- If a manifest version changes for a stable plugin, update `registry.json` in the same release change.

## Verification

Run verification before claiming completion:

- Changed QML files: `qmllint <file.qml>`
- Optional formatting: `qmlformat -i <file.qml>`
- Repo metadata sanity:
  - Validate `registry.json` consistency with manifests
  - Check docs links and references are still valid

## Commit Discipline

- Do not push unless explicitly instructed.
- Keep commits scoped to one logical change.
- Avoid destructive git operations unless explicitly requested.
- Prefer small, reviewable diffs over broad rewrites.

## Directory Conventions

Each plugin directory should include only files needed for distribution:

- `manifest.json`
- Entry points (`Main.qml`, optional `BarWidget.qml`, `Panel.qml`, `Settings.qml`, etc.)
- `i18n/en.json`
- `README.md`
- `preview.png` (when available)

Do not keep nested worktrees or scratch artifacts inside plugin directories.

## Quick Links

- `README.md`
- `docs/MAINTENANCE.md`
- `docs/NOCTALIA_API.md`
