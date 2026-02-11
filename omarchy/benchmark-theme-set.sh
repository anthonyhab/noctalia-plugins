#!/bin/bash
# Benchmark theme switching scripts

set -e

echo "============================================"
echo "Theme Switching Benchmark"
echo "============================================"
echo ""

# Check if hyperfine is installed
if ! command -v hyperfine &> /dev/null; then
    echo "ERROR: hyperfine is not installed"
    echo "Install with: cargo install hyperfine"
    exit 1
fi

# Test theme
TEST_THEME="gruvbox"

# Scripts to benchmark
ORIGINAL_SCRIPT="$HOME/.local/share/omarchy/bin/omarchy-theme-set"
FAST_SCRIPT="$HOME/.local/bin/omarchy-theme-set-fast"

echo "Testing with theme: $TEST_THEME"
echo ""

# Verify scripts exist
if [ ! -f "$ORIGINAL_SCRIPT" ]; then
    echo "WARNING: Original script not found at $ORIGINAL_SCRIPT"
    echo "Skipping original benchmark"
    ORIGINAL_SCRIPT=""
fi

if [ ! -f "$FAST_SCRIPT" ]; then
    echo "ERROR: Fast script not found at $FAST_SCRIPT"
    exit 1
fi

echo "============================================"
echo "Benchmarking: omarchy-theme-set (original)"
echo "============================================"
if [ -n "$ORIGINAL_SCRIPT" ]; then
    hyperfine --warmup 1 --runs 3 \
        --prepare "echo 'Preparing...'" \
        --cleanup "echo 'Cleaning up...'" \
        "$ORIGINAL_SCRIPT $TEST_THEME"
else
    echo "SKIPPED - script not found"
fi
echo ""

echo "============================================"
echo "Benchmarking: omarchy-theme-set-fast"
echo "============================================"
hyperfine --warmup 1 --runs 5 \
    --prepare "echo 'Preparing...'" \
    --cleanup "echo 'Cleaning up...'" \
    "$FAST_SCRIPT $TEST_THEME"
echo ""

# Comparison
if [ -n "$ORIGINAL_SCRIPT" ]; then
    echo "============================================"
    echo "Comparison: Original vs Fast"
    echo "============================================"
    hyperfine --warmup 1 --runs 3 \
        --prepare "echo 'Preparing...'" \
        --cleanup "echo 'Cleaning up...'" \
        -n "original" "$ORIGINAL_SCRIPT $TEST_THEME" \
        -n "fast" "$FAST_SCRIPT $TEST_THEME"
fi

echo ""
echo "============================================"
echo "Benchmark Complete"
echo "============================================"
