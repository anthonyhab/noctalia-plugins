#!/usr/bin/env bash
set -euo pipefail

# QML Lint Runner
# Runs qmllint on specified QML files (errors only, warnings pass)

if [ $# -eq 0 ]; then
    echo "No QML files to lint"
    exit 0
fi

# Find qmllint binary
QMLLINT=""
for path in "/usr/lib64/qt6/bin/qmllint" "/usr/lib/qt6/bin/qmllint"; do
    if [ -x "$path" ]; then
        QMLLINT="$path"
        break
    fi
done

# Fallback to PATH
if [ -z "$QMLLINT" ] && command -v qmllint &>/dev/null; then
    QMLLINT="qmllint"
fi

if [ -z "$QMLLINT" ]; then
    echo "warning: qmllint not found — install qt6-tools or qt6-declarative-tools" >&2
    exit 0
fi

# Suppress Qt dom logging
export QT_LOGGING_RULES="qt.qmldom.*=false"

errors=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        continue
    fi
    if ! $QMLLINT -s "$file" >/dev/null 2>&1; then
        echo "error: qmllint reported issues in $file"
        $QMLLINT -s "$file" 2>&1 || true
        errors=$((errors + 1))
    fi
done

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "qmllint check failed: $errors file(s) with errors" >&2
    exit 1
fi

echo "qmllint check passed: ${#} file(s)"
