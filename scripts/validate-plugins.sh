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

echo "[validate] checking registry consistency"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-registry.js"
else
  echo "warning: node not found, skipping registry consistency check"
fi

echo "[validate] checking translation key coverage"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-i18n-keys.js"
else
  echo "warning: node not found, skipping translation key coverage check"
fi

echo "[validate] checking shell compatibility"
if command -v node > /dev/null 2>&1; then
  node "scripts/check-shell-compat.js"
else
  echo "warning: node not found, skipping shell compatibility check"
fi

echo "[validate] checking QML anti-patterns"
if [[ -f "scripts/dev/check-anti-patterns.sh" ]]; then
  qml_files=()
  for plugin in "${plugins[@]}"; do
    while IFS= read -r -d '' qml_file; do
      qml_files+=("$qml_file")
    done < <(find "$plugin" -name "*.qml" -not -path "*/.worktrees/*" -print0 2>/dev/null || true)
  done

  if [[ ${#qml_files[@]} -gt 0 ]]; then
    bash "scripts/dev/check-anti-patterns.sh" "${qml_files[@]}"
  else
    echo "warning: no QML files found for anti-pattern checks"
  fi
else
  echo "warning: scripts/dev/check-anti-patterns.sh not found, skipping anti-pattern checks"
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
tracked_runtime_outputs="$(git ls-files '*/omarchy-color-preferences.json' || true)"
if [[ -n "$tracked_runtime_outputs" ]]; then
  echo "error: tracked runtime output detected:"
  echo "$tracked_runtime_outputs"
  exit 1
fi
if [[ -n "$tracked_settings" ]]; then
  echo "error: tracked runtime settings detected:"
  echo "$tracked_settings"
  exit 1
fi

echo "[validate] checking release hygiene"
dev_artifacts=(
  bb-auth/test-auth.sh
  hypr-overview/.gitignore
  hypr-overview/0.54-plan.md
  hypr-overview/docs/superpowers/plans/2026-04-20-multi-monitor-workspace.md
  hypr-overview/docs/superpowers/specs/2026-04-20-multi-monitor-workspace-design.md
  hypr-overview/scripts/rebuild-shaders.sh
  hypr-overview/shaders/README.md
  hypr-overview/shaders/frag/window_mac_classic.frag
  hypr-overview/shaders/frag/window_simplify.frag
  omarchy/.gitignore
  omarchy/benchmark-theme-set.sh
  omarchy/check-cache-consistency.js
  omarchy/color_analysis_report.js
  omarchy/ColorAnalysis.js
  omarchy/convert-legacy-themes.js
  omarchy/execute-hooks.sh
  omarchy/FileCacheManager.qml
  omarchy/generate-scheme-cache.js
  omarchy/IMPLEMENTATION_SUMMARY.md
  omarchy/keyboard-return.svg
  omarchy/omarchy-hook-async
  omarchy/omarchy-hook-processor
  omarchy/omarchy-theme-set-fast
  omarchy/qs-dev
  omarchy/scheme-cache.json
  omarchy/ThemeOperationManager.qml
  omarchy/theme_comparison_analysis.js
  omarchy/update-scheme-cache-embedded.js
  omarchy/omarchy-color-preferences.json
  omarchy/test-conversion.js
  omarchy/test-golden-themes.js
)

dev_hygiene_errors=()
for file in "${dev_artifacts[@]}"; do
  if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
    dev_hygiene_errors+=("$file is tracked; remove from stable distribution")
  fi
done

if [[ ${#dev_hygiene_errors[@]} -gt 0 ]]; then
  echo "error: release hygiene check failed:"
  for message in "${dev_hygiene_errors[@]}"; do
    echo "  - $message"
  done
  exit 1
fi

echo "[validate] checking omarchy runtime cache artifacts"
omarchy_runtime_files=(
  omarchy/AsyncThemeSetter.qml
  omarchy/ColorsConvert.js
  omarchy/InstantSchemeApplier.qml
  omarchy/SchemeCache.js
  omarchy/ThemePipeline.js
)
for file in "${omarchy_runtime_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "error: missing omarchy runtime artifact: $file"
    exit 1
  fi
done

echo "[validate] all checks passed"
