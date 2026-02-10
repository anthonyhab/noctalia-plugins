#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_commands=(qmllint jq bash git)
for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "error: required command not found: $cmd"
    exit 1
  fi
done

plugins=(
  homeassistant
  omarchy
  polkit-auth
  swww-picker
)

echo "[validate] running qmllint"
for plugin in "${plugins[@]}"; do
  if compgen -G "$plugin/*.qml" > /dev/null; then
    qml_output="$(qmllint "$plugin"/*.qml 2>&1 || true)"
    if [[ -n "$qml_output" ]]; then
      echo "$qml_output"
      echo "error: qmllint reported issues for $plugin"
      exit 1
    fi
  fi
done

echo "[validate] checking json syntax"
jq empty "registry.json"
for plugin in "${plugins[@]}"; do
  jq empty "$plugin/manifest.json"
done

echo "[validate] checking manifest compliance"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-manifests.js"
else
  echo "warning: node not found, skipping manifest compliance check"
fi

if [[ -f "omarchy/i18n/en.json" ]]; then
  jq empty "omarchy/i18n/en.json"
fi

if [[ -f "omarchy/scheme-cache.json" ]]; then
  jq empty "omarchy/scheme-cache.json"
fi

echo "[validate] checking translation key coverage"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-i18n-keys.js"
else
  echo "warning: node not found, skipping translation key coverage check"
fi

echo "[validate] checking shell script syntax"
shell_files=(
  scripts/validate-plugins.sh
  omarchy/omarchy-theme-set-fast
  omarchy/execute-hooks.sh
  omarchy/omarchy-hook-async
  omarchy/omarchy-hook-processor
)
for file in "${shell_files[@]}"; do
  if [[ -f "$file" ]]; then
    bash -n "$file"
  fi
done

echo "[validate] ensuring runtime settings are not tracked"
tracked_settings="$(git ls-files '*/settings.json' || true)"
if [[ -n "$tracked_settings" ]]; then
  echo "error: tracked runtime settings detected:"
  echo "$tracked_settings"
  exit 1
fi

echo "[validate] checking release hygiene warnings"
dev_artifacts=(
  omarchy/benchmark-theme-set.sh
  omarchy/qs-dev
  omarchy/IMPLEMENTATION_SUMMARY.md
  omarchy/FileCacheManager.qml
  omarchy/ThemeOperationManager.qml
  omarchy/convert-legacy-themes.js
)

dev_warnings=()
for file in "${dev_artifacts[@]}"; do
  if [[ -f "$file" ]]; then
    if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
      dev_warnings+=("$file is tracked; keep only if intentionally shipped")
    else
      dev_warnings+=("$file is local artifact; ensure it stays untracked")
    fi
  fi
done

if [[ ${#dev_warnings[@]} -gt 0 ]]; then
  echo "[validate] release hygiene warnings:"
  for warning in "${dev_warnings[@]}"; do
    echo "  - $warning"
  done
fi

echo "[validate] checking omarchy cache consistency"
if command -v node > /dev/null 2>&1; then
  node "omarchy/check-cache-consistency.js"
else
  echo "warning: node not found, skipping omarchy cache consistency check"
fi

echo "[validate] all checks passed"
