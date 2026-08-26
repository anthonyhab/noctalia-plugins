function omarchyBootstrapSnippet() {
  return "omarchy_root=\"$1\"; if [ -n \"$omarchy_root\" ]; then export OMARCHY_PATH=\"$omarchy_root\"; export PATH=\"$OMARCHY_PATH/bin:$PATH\"; fi; ";
}

function detectScript() {
  return "env_path=\"$1\"; fallback_path=\"$2\"; if [ -n \"$env_path\" ] && [ -d \"$env_path\" ]; then printf '%s' \"$env_path\"; exit 0; fi; if [ -d \"$fallback_path\" ]; then printf '%s' \"$fallback_path\"; exit 0; fi; if command -v omarchy >/dev/null 2>&1; then exit 0; fi; exit 1";
}

function commandScript(dispatcherCommand) {
  return "legacy_name=\"$2\"; shift 2; "
    + "if command -v omarchy >/dev/null 2>&1; then exec " + dispatcherCommand + "; "
    + "elif [ -n \"$OMARCHY_PATH\" ] && [ -x \"$OMARCHY_PATH/bin/$legacy_name\" ]; then exec \"$OMARCHY_PATH/bin/$legacy_name\" \"$@\"; "
    + "elif command -v \"$legacy_name\" >/dev/null 2>&1; then exec \"$legacy_name\" \"$@\"; "
    + "else exit 127; fi";
}

if (typeof module !== "undefined") {
  module.exports = {
    omarchyBootstrapSnippet,
    detectScript,
    commandScript
  };
}
