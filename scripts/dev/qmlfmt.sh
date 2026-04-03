#!/usr/bin/env bash
set -euo pipefail

# QML Formatter Script
# Ported from noctalia-shell/Scripts/dev/qmlfmt.sh

# Suppress Qt debug logging from qmlformat
export QT_LOGGING_RULES="qt.qmldom.*=false"

# Find qmlformat binary
QMLFORMAT=""
for path in "/usr/lib64/qt6/bin/qmlformat" "/usr/lib/qt6/bin/qmlformat"; do
    if [ -x "$path" ]; then
        QMLFORMAT="$path"
        break
    fi
done

# Fallback to PATH
if [ -z "$QMLFORMAT" ] && command -v qmlformat &>/dev/null; then
    QMLFORMAT="qmlformat"
fi

if [ -z "$QMLFORMAT" ]; then
    echo "No 'qmlformat' found in standard locations or PATH." >&2
    echo "To proceed, install it via 'qt6-tools', 'qt6-declarative-tools' or 'qt6-qtdeclarative-devel'" >&2
    exit 1
fi

# Detect qmlformat version for flag compatibility
EXTRA_FLAGS=""
if version=$("$QMLFORMAT" --version 2>&1) && [[ "$version" =~ ([0-9]+\.[0-9]+) ]]; then
    if [[ "$(printf '%s\n6.10\n' "${BASH_REMATCH[1]}" | sort -V | head -1)" == "6.10" ]]; then
        EXTRA_FLAGS="-S --semicolon-rule always"
    fi
fi

format_file() {
    ${QMLFORMAT} -w 2 -W 360 ${EXTRA_FLAGS} -i "$1" || { echo "Failed: $1" >&2; return 1; }
}

export -f format_file
export QMLFORMAT EXTRA_FLAGS

# Use provided files or find all .qml files in repo
if [ $# -gt 0 ]; then
    files=("$@")
else
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    mapfile -t files < <(find "$repo_root" -name "*.qml" -type f)
fi

[ ${#files[@]} -eq 0 ] && { echo "No QML files found"; exit 0; }

echo "Formatting ${#files[@]} files..."
printf '%s\0' "${files[@]}" | \
    xargs -0 -P "${QMLFMT_JOBS:-$(nproc)}" -I {} bash -c 'format_file "$@"' _ {} \
    && echo "Done" || { echo "Errors occurred" >&2; exit 1; }
