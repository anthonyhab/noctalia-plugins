#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_commands=(jq bash git)
for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "error: required command not found: $cmd"
    exit 1
  fi
done

# Dynamically discover all plugin directories (those with manifest.json)
plugins=()
for dir in */; do
  dir="${dir%/}"
  if [[ -f "$dir/manifest.json" ]]; then
    plugins+=("$dir")
  fi
done

if [[ ${#plugins[@]} -eq 0 ]]; then
  echo "error: no plugin directories found"
  exit 1
fi

echo "[validate] found ${#plugins[@]} plugin(s): ${plugins[*]}"

noctalia_path="${1:-}"

# Find qmllint binary
QMLLINT=""
for path in "/usr/lib64/qt6/bin/qmllint" "/usr/lib/qt6/bin/qmllint"; do
  if [ -x "$path" ]; then
    QMLLINT="$path"
    break
  fi
done
if [ -z "$QMLLINT" ] && command -v qmllint &>/dev/null; then
  QMLLINT="qmllint"
fi

if [[ -n "$QMLLINT" ]]; then
  echo "[validate] running qmllint"
  export QT_LOGGING_RULES="qt.qmldom.*=false"
  for plugin in "${plugins[@]}"; do
    qml_files=("$plugin"/*.qml)
    if [[ -f "${qml_files[0]}" ]]; then
      qmllint_args=(-s)
      if [[ -n "$noctalia_path" ]]; then
        qmllint_args+=(-I "$noctalia_path")
      fi
      if ! $QMLLINT "${qmllint_args[@]}" "${qml_files[@]}" 2>&1; then
        echo "error: qmllint reported issues for $plugin"
        exit 1
      fi
    fi
    # Also lint subdirectories
    if [[ -d "$plugin/components" ]]; then
      if ! $QMLLINT -s "$plugin/components"/*.qml 2>/dev/null; then
        true  # warnings in components are non-fatal
      fi
    fi
    if [[ -d "$plugin/helpers" ]]; then
      if ! $QMLLINT -s "$plugin/helpers"/*.qml 2>/dev/null; then
        true
      fi
    fi
  done
else
  echo "[validate] qmllint not found, skipping"
fi

echo "[validate] checking json syntax"
jq empty "registry.json"
for plugin in "${plugins[@]}"; do
  jq empty "$plugin/manifest.json"
  # Also validate i18n files
  if [[ -d "$plugin/i18n" ]]; then
    for locale_file in "$plugin/i18n"/*.json; do
      if [[ -f "$locale_file" ]]; then
        jq empty "$locale_file"
      fi
    done
  fi
done

echo "[validate] checking manifest compliance"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-manifests.js"
else
  echo "warning: node not found, skipping manifest compliance check"
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
  scripts/dev/*.sh
)
for plugin in "${plugins[@]}"; do
  while IFS= read -r -d '' sh_file; do
    shell_files+=("$sh_file")
  done < <(find "$plugin" -maxdepth 1 -name "*.sh" -print0 2>/dev/null || true)
done
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
if command -v node > /dev/null 2>&1 && [[ -f "omarchy/check-cache-consistency.js" ]]; then
  node "omarchy/check-cache-consistency.js"
else
  echo "warning: node not found or script missing, skipping omarchy cache consistency check"
fi

echo "[validate] all checks passed"
