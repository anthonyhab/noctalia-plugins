# Third-Party Plugin Repository

This repository now doubles as a Noctalia plugin source. The root contains
individual plugin directories (`homeassistant`, `omarchy`) alongside a
`registry.json` file that follows the format used by the official
`noctalia-plugins` repo.  You can add this repository inside Noctalia →
Plugins → Sources → `+ Add custom repository` by entering
`https://github.com/habibe/noctalia-shell` (or the URL of your fork).

When the shell fetches plugins it performs a sparse checkout that pulls only
`registry.json` and the requested plugin directory, so keeping the plugin
folders at the root keeps the install/update flow working.

## Developing locally

The runtime still expects plugins under `dev/plugins/…`. Those paths are now
symlinks that point back to the root-level plugin directories so there is only
one copy of each plugin. Work on `homeassistant` or `omarchy` at the root and
Noctalia will automatically pick up the changes.

## Publishing elsewhere

If you prefer a dedicated plugin repository instead of reusing the shell
repository, copy the following into a new git repo:

```text
registry.json
homeassistant/
omarchy/
```

Update the `repository` field in `registry.json` to match the new repository
URL and push it. Anyone can then add that URL under Plugins → Sources to fetch
and install the plugins.
