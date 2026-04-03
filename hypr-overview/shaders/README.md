# Shader Assets

This plugin ships precompiled Qt shader packs (`.qsb`) under `shaders/qsb/`.

## Why `.qsb` files are committed

`ShaderEffect` in Qt 6 expects shader-pack assets (`.qsb`) at runtime. We commit these files so users do not need Qt ShaderTools installed when using the plugin.

## Source of truth

- Editable GLSL source: `shaders/frag/*.frag`
- Runtime artifact: `shaders/qsb/*.frag.qsb`

Always edit `.frag`, then regenerate `.qsb`.

## Rebuilding shaders

From `hypr-overview/`:

```bash
./scripts/rebuild-shaders.sh
```

The script uses:

- local `qsb` if available, or
- `nix shell nixpkgs#qt6.qtshadertools` fallback.

## Compatibility note

The build script compiles with `--qsbversion 64` (Qt 6.4 compatibility target).  
That is compatible with modern Qt 6 runtimes, including Qt 6.10.1 used by current Noctalia/Quickshell setups.

If runtime Qt is ever older than the selected QSB target, rebuild with a lower compatible `--qsbversion` and retest.
