function omarchyBootstrapSnippet() {
  return "if [ -n \"$omarchy_root\" ]; then export OMARCHY_PATH=\"$omarchy_root\"; export PATH=\"$OMARCHY_PATH/bin:$PATH\"; fi; ";
}

function availabilityScript() {
  return "config_path=\"$1\"; theme_name_path=\"$2\"; custom_theme_set=\"$3\"; legacy_theme_set=\"$4\"; legacy_theme_list=\"$5\"; omarchy_root=\"$6\"; "
    + "[ -f \"$config_path\" ] && [ -f \"$theme_name_path\" ] || exit 1; "
    + omarchyBootstrapSnippet()
    + "if [ -n \"$custom_theme_set\" ]; then [ -x \"$custom_theme_set\" ] || exit 1; "
    + "elif ! command -v omarchy >/dev/null 2>&1 && [ ! -x \"$legacy_theme_set\" ]; then exit 1; fi; "
    + "if command -v omarchy >/dev/null 2>&1 || [ -x \"$legacy_theme_list\" ] || command -v omarchy-theme-list >/dev/null 2>&1; then exit 0; fi; "
    + "exit 1";
}

function themeListScript() {
  return "set -o pipefail; themes_dir=\"$1\"; stock_dir=\"$2\"; legacy_theme_list=\"$3\"; omarchy_root=\"$4\"; "
    + omarchyBootstrapSnippet()
    + "(if command -v omarchy >/dev/null 2>&1; then omarchy theme list; "
    + "elif [ -x \"$legacy_theme_list\" ]; then \"$legacy_theme_list\"; "
    + "elif command -v omarchy-theme-list >/dev/null 2>&1; then omarchy-theme-list; "
    + "else exit 127; fi) | while IFS= read -r name; do "
    + "[ -z \"$name\" ] && continue; "
    + "theme_dir=$(printf '%s\\n' \"$name\" | sed -E 's/<[^>]+>//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); "
    + "if [ -f \"$themes_dir/$theme_dir/light.mode\" ] || [ -f \"$stock_dir/$theme_dir/light.mode\" ]; then mode=light; else mode=dark; fi; "
    + "printf '%s|%s|%s\\n' \"$name\" \"$theme_dir\" \"$mode\"; "
    + "done";
}

function themeSetFallbackScript() {
  return "omarchy_root=\"$2\"; legacy_command=\"$3\"; "
    + omarchyBootstrapSnippet()
    + "if command -v omarchy >/dev/null 2>&1; then exec omarchy theme set \"$1\"; "
    + "elif [ -x \"$legacy_command\" ]; then exec \"$legacy_command\" \"$1\"; "
    + "else exit 127; fi";
}

function themeSetFallbackCommand(themeName, omarchyPath, legacyCommand) {
  return ["sh", "-c", themeSetFallbackScript(), "--", themeName, omarchyPath || "", legacyCommand || ""];
}

function feedbackDetectScript() {
  return "env_path=\"$1\"; fallback_path=\"$2\"; if [ -n \"$env_path\" ] && [ -d \"$env_path\" ]; then printf '%s' \"$env_path\"; exit 0; fi; if [ -d \"$fallback_path\" ]; then printf '%s' \"$fallback_path\"; exit 0; fi; if command -v omarchy >/dev/null 2>&1; then exit 0; fi; exit 1";
}

function feedbackCommandScript(dispatcherCommand) {
  return "legacy_name=\"$2\"; shift 2; "
    + "if command -v omarchy >/dev/null 2>&1; then exec " + dispatcherCommand + "; "
    + "elif [ -n \"$OMARCHY_PATH\" ] && [ -x \"$OMARCHY_PATH/bin/$legacy_name\" ]; then exec \"$OMARCHY_PATH/bin/$legacy_name\" \"$@\"; "
    + "elif command -v \"$legacy_name\" >/dev/null 2>&1; then exec \"$legacy_name\" \"$@\"; "
    + "else exit 127; fi";
}

if (typeof module !== "undefined") {
  module.exports = {
    omarchyBootstrapSnippet,
    availabilityScript,
    themeListScript,
    themeSetFallbackScript,
    themeSetFallbackCommand,
    feedbackDetectScript,
    feedbackCommandScript
  };
}
