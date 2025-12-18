# Bibe Plugins Workspace

This directory mirrors the layout of `anthonyhab/noctalia-plugins`. Each plugin
lives in its own folder (homeassistant, appletv, omarchy) with the exact files
we ship to GitHub. The idea:

1. Develop plugins inside `noctalia-shell/dev/plugins/<name>`.
2. When ready to publish, copy/rsync that folder into `bibe-plugins/<name>`
   (avoiding private `settings.json` etc.).
3. Commit/push from the `bibe-plugins` repo (or copy these folders into your
   checkout of `anthonyhab/noctalia-plugins`).
4. Keep `registry.json` in sync with the plugins you expose.

Because this directory only contains distributable assets, you can safely run
`git add . && git push github main` from inside `bibe-plugins` without pulling
in the rest of the shell.
