# Repository Maintenance

This repository ships installable Noctalia plugins. `main` is the stable distribution branch.

## Branch Policy

- `main` contains only stable plugins that are ready for users.
- WIP plugins must live on dedicated branches such as `dev/<plugin-id>` or `feature/<topic>`.
- Do not add WIP plugins to `registry.json`.
- Merge a WIP plugin into `main` only when it passes the release checklist below.

## Plugin Lifecycle

1. Build and iterate in `dev/<plugin-id>`.
2. Add or finalize plugin docs (`README.md`, preview image, i18n).
3. Validate metadata (`manifest.json`) and entry points.
4. Run QML checks (`qmllint`, optional `qmlformat`).
5. Merge to `main`.
6. Add plugin to `registry.json` in the same release change.

## Stable Plugin Release Checklist

Before releasing to users:

- Manifest fields are complete and accurate.
- `minNoctaliaVersion` is correct.
- Version bump follows semver.
- Plugin README is user-facing and current.
- `i18n/en.json` contains keys used by plugin UI.
- QML files pass lint checks for changed files.
- `registry.json` entry exists (or is updated) and matches manifest `id`, `name`, `version`, and description.

## Registry Rules

- `registry.json` is the install index for stable plugins.
- Every stable plugin directory listed in this repo must have a matching registry entry.
- Registry version must exactly match `manifest.json` version.
- Do not list experimental plugins in registry.

## Versioning Rules

- Patch: bug fixes and polish.
- Minor: new features and behavior additions.
- Major: breaking changes.
- Bump versions only when preparing a release to users.

## Worktree Hygiene

- Use isolated worktrees under `.worktrees/` for large refactors.
- Keep nested worktree directories out of plugin folders.
- Ensure worktree paths are ignored by git.
