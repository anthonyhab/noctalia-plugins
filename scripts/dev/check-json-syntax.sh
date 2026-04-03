#!/usr/bin/env bash
set -euo pipefail

# JSON Syntax Checker
# Validates JSON syntax on staged files using jq

if [ $# -eq 0 ]; then
    echo "No JSON files to check"
    exit 0
fi

errors=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        continue
    fi
    if ! jq empty "$file" 2>/dev/null; then
        echo "error: invalid JSON syntax in $file"
        errors=$((errors + 1))
    fi
done

if [ "$errors" -gt 0 ]; then
    echo "JSON syntax check failed: $errors file(s) with errors" >&2
    exit 1
fi

echo "JSON syntax check passed: ${#} file(s)"
