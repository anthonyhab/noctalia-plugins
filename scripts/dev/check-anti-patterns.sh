#!/usr/bin/env bash
set -euo pipefail

# Anti-Pattern Checker for QML files
# Catches common mistakes that violate Noctalia coding standards

if [ $# -eq 0 ]; then
    echo "No QML files to check"
    exit 0
fi

errors=0
warnings=0

check_file() {
    local file="$1"
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # HIGH: Qt5Compat usage (forbidden)
        if echo "$line" | grep -q "Qt5Compat"; then
            echo "error: $file:$line_num: Qt5Compat is forbidden — use QtQuick.Effects with MultiEffect instead"
            echo "  $line"
            errors=$((errors + 1))
        fi

        # HIGH: console.log/warn instead of Logger
        if echo "$line" | grep -qE "console\.(log|warn|error)"; then
            echo "error: $file:$line_num: Use Logger instead of console.log/warn/error"
            echo "  $line"
            errors=$((errors + 1))
        fi

        # HIGH: iconColor property (doesn't exist, should be colorFg)
        if echo "$line" | grep -qE "iconColor\s*[:=]"; then
            echo "error: $file:$line_num: 'iconColor' does not exist — use 'colorFg' instead"
            echo "  $line"
            errors=$((errors + 1))
        fi

        # MEDIUM: Translation fallback anti-pattern
        if echo "$line" | grep -qE '\.tr\([^)]+\)\s*(\?\?|\|\|)\s*["'"'"']'; then
            echo "warning: $file:$line_num: Translation fallback is unnecessary — tr() returns the key if missing"
            echo "  $line"
            warnings=$((warnings + 1))
        fi

        # MEDIUM: BarPill usage (deprecated)
        if echo "$line" | grep -qE "^\s*BarPill\s*\{"; then
            echo "warning: $file:$line_num: BarPill is deprecated — use NIconButton instead"
            echo "  $line"
            warnings=$((warnings + 1))
        fi

    done < "$file"
}

for file in "$@"; do
    if [ ! -f "$file" ]; then
        continue
    fi
    check_file "$file"
done

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Anti-pattern check failed: $errors error(s), $warnings warning(s)" >&2
    exit 1
fi

if [ "$warnings" -gt 0 ]; then
    echo ""
    echo "Anti-pattern check passed with $warnings warning(s)"
else
    echo "Anti-pattern check passed"
fi
