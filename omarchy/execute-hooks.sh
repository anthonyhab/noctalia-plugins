#!/bin/bash
# execute-hooks.sh - Optimized hook execution with parallelization
# Part of omarchy-theme-set-fast

THEME_NAME="$1"
LOG_FILE="${2:-/tmp/omarchy-hooks.log}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $1" >> "$LOG_FILE"
}

# Generate surface colors (critical dependency for other hooks)
generate_surface_colors() {
  log "[PHASE 1] Generating surface colors..."
  
  local colors_file="$HOME/.config/omarchy/current/theme/colors.toml"
  local cache_dir="$HOME/.cache/omarchy/surface-colors"
  local cache_file="$cache_dir/colors.env"
  local hash_file="$cache_dir/.current-hash"
  
  # Calculate current hash
  local current_hash=$(sha256sum "$colors_file" 2>/dev/null | cut -d' ' -f1)
  
  # Check if cache is valid
  if [ -f "$hash_file" ] && [ -f "$cache_file" ]; then
    local cached_hash=$(cat "$hash_file" 2>/dev/null)
    if [ "$current_hash" == "$cached_hash" ]; then
      log "  [CACHE] Surface colors up to date, skipping generation"
      return 0
    fi
  fi
  
  # Generate surface colors
  log "  [GEN] Generating surface colors..."
  mkdir -p "$cache_dir"
  
  # Source the surface-colors script to generate
  if [ -f "$HOME/.config/omarchy/hooks/surface-colors" ]; then
    # Execute in subshell to avoid polluting environment
    (
      source "$HOME/.config/omarchy/hooks/surface-colors" 2>/dev/null
      if [ -f "$cache_file" ]; then
        echo "$current_hash" > "$hash_file"
        log "  [GEN] Surface colors generated and cached"
        exit 0
      else
        log "  [ERROR] Surface colors generation failed"
        exit 1
      fi
    )
    return $?
  else
    log "  [WARN] surface-colors hook not found, skipping"
    return 0
  fi
}

# Run a hook and capture output
run_hook() {
  local script="$1"
  local name="$2"
  local log_prefix="$3"
  
  log "  [HOOK] Starting: $name"
  local start_time=$(date +%s%N)
  
  if [ -f "$HOME/.config/omarchy/hooks/$script" ]; then
    if "$HOME/.config/omarchy/hooks/$script" >> "$LOG_FILE" 2>&1; then
      local end_time=$(date +%s%N)
      local duration=$(( (end_time - start_time) / 1000000 ))
      log "  [HOOK] ✓ Success: $name (${duration}ms)"
      return 0
    else
      local exit_code=$?
      log "  [HOOK] ✗ Failed: $name (exit: $exit_code)"
      return 1
    fi
  else
    log "  [HOOK] ⚠ Not found: $name"
    return 0
  fi
}

# Special handling for pywalfox with socket retry
run_pywalfox() {
  log "  [HOOK] Starting: pywalfox"
  local start_time=$(date +%s%N)
  
  # First run pywalfox-gen.sh
  if run_hook "pywalfox-gen.sh" "pywalfox-gen" "  "; then
    # Wait for socket and run pywalfox-go
    local max_wait=10
    local socket="/tmp/pywalfox_socket"
    
    log "    [PYWALFOX] Waiting for socket (max ${max_wait}s)..."
    
    for ((i=0; i<max_wait; i++)); do
      if [ -S "$socket" ]; then
        log "    [PYWALFOX] Socket found, updating..."
        if command -v pywalfox-go >/dev/null 2>&1; then
          if pywalfox-go update >> "$LOG_FILE" 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            log "  [HOOK] ✓ Success: pywalfox (${duration}ms)"
            return 0
          else
            log "    [PYWALFOX] Update failed, will retry..."
            sleep 1
          fi
        else
          log "    [PYWALFOX] pywalfox-go not found, skipping update"
          return 0
        fi
      else
        sleep 1
      fi
    done
    
    log "    [PYWALFOX] Socket not found after ${max_wait}s"
    log "  [HOOK] ⚠ Partial: pywalfox (colors generated, update skipped)"
    return 0  # Non-critical failure
  else
    log "  [HOOK] ✗ Failed: pywalfox-gen"
    return 1
  fi
}

# Execute hooks with parallelization where safe
execute_hooks() {
  local failed_hooks=()
  local pids=()
  
  # Phase 1: Generate surface colors (blocking, critical)
  if ! generate_surface_colors; then
    failed_hooks+=("surface-colors")
  fi
  
  # Phase 2: File generators (parallel - independent)
  log "[PHASE 2] Running file generators in parallel..."
  
  # pywalfox (special handling with socket retry)
  run_pywalfox &
  pids+=($!)
  
  # firefox-radius (parallel)
  run_hook "firefox-radius-gen.sh" "firefox-radius" "  " &
  pids+=($!)
  
  # avatar-generator (parallel)
  run_hook "avatar-generator.sh" "avatar" "  " &
  pids+=($!)
  
  # Wait for all file generators
  for pid in "${pids[@]}"; do
    if ! wait $pid; then
      # Track failures (but we don't know which one failed)
      : # Non-critical, continue
    fi
  done
  pids=()
  
  # Phase 3: Config updaters (parallel - depends on surface-colors)
  log "[PHASE 3] Running config updaters..."
  
  # template-processor (parallel)
  run_hook "template-processor.sh" "template-processor" "  " &
  pids+=($!)
  
  # zed-theme-updater (parallel)
  run_hook "zed-theme-updater.sh" "zed-updater" "  " &
  pids+=($!)
  
  # opencode-theme-updater (parallel)
  run_hook "opencode-theme-updater.sh" "opencode-updater" "  " &
  pids+=($!)
  
  # Wait for config updaters
  for pid in "${pids[@]}"; do
    if ! wait $pid; then
      : # Non-critical
    fi
  done
  pids=()
  
  # Phase 4: Network operations (async, don't wait)
  log "[PHASE 4] Starting network operations..."
  
  # opencode-sync (fire and forget)
  if [ -f "$HOME/.local/bin/opencode-sync" ]; then
    (
      log "  [HOOK] Starting: opencode-sync"
      if opencode-sync >> "$LOG_FILE" 2>&1; then
        log "  [HOOK] ✓ Success: opencode-sync"
      else
        log "  [HOOK] ⚠ Failed: opencode-sync (non-critical)"
      fi
    ) &
  fi
  
  # Phase 5: Notifications (last, after file generators)
  log "[PHASE 5] Sending notifications..."
  sleep 0.1  # Brief pause to ensure files settled
  
  # noctalia-notifier (blocking - must complete)
  if ! run_hook "noctalia-notifier.sh" "noctalia-notify" "  "; then
    failed_hooks+=("noctalia-notify")
  fi
  
  # Summary
  log "========================================"
  if [ ${#failed_hooks[@]} -eq 0 ]; then
    log "[SUCCESS] All hooks completed"
  else
    log "[WARNING] Failed hooks: ${failed_hooks[*]}"
  fi
  log "========================================"
  
  return ${#failed_hooks[@]}
}

# Main execution
main() {
  log ""
  log "========================================"
  log "Executing hooks for theme: $THEME_NAME"
  log "========================================"
  
  execute_hooks
  local result=$?
  
  log "Hook execution complete"
  log ""
  
  return $result
}

main
