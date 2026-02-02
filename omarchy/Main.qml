import QtQuick
import Quickshell
import Quickshell.Io
import "ColorsConvert.js" as ColorsConvert
import "ThemePipeline.js" as ThemePipeline
import "SchemeCache.js" as SchemeCache
import qs.Commons
import qs.Services.Theming
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  visible: false

  property bool available: false
  property bool applying: false
  property bool pendingApplyAfterCurrent: false
  property string themeName: ""
  property var availableThemes: []
  property bool suppressSettingsSignal: false
  property bool pendingReloadApply: false
  property bool pendingReloadApplyAvailabilityReady: false
  property bool pendingReloadApplyThemeReady: false
  property var pendingAlacrittyColors: null
  property bool ignoreNextPluginSettingsChanged: false

  property bool observedActive: false
  property string observedConfigDir: ""
  property string observedThemeSetCommand: ""

  readonly property bool debugLogging: pluginApi?.pluginSettings?.debugLogging === true

  readonly property string schemeDisplayName: pluginApi?.manifest?.metadata?.schemeName || "Omarchy"
  readonly property string schemeKey: {
    const name = schemeDisplayName || "Omarchy"
    return name.replace(/[\\/]/g, "-").trim()
  }
  readonly property string schemeFolder: {
    const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
    const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
    return normalizedBase + "/" + schemeKey;
  }
  readonly property string schemeOutputPath: schemeFolder + "/" + schemeKey + ".json"
  readonly property string schemeOutputDir: schemeFolder

  property bool savedPreferencesLoaded: false
  property bool hasSavedColorPreferences: false
  property bool savedUseWallpaperColors: false
  property string savedPredefinedScheme: ""
  property bool pendingRememberPreferences: false
  property bool pendingRememberWallpaper: false
  property string pendingRememberScheme: ""
  property bool autoAppliedOnStartup: false

  readonly property string colorPreferencesDir: {
    const baseDir = Settings.configDir || "";
    if (!baseDir)
      return ""
    const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
    const pluginId = pluginApi?.pluginId || "omarchy";
    return normalizedBase + "/plugins/" + pluginId;
  }
  readonly property string colorPreferencesPath: colorPreferencesDir ? (colorPreferencesDir + "/omarchy-color-preferences.json") : ""

  readonly property string omarchyConfigDir: {
    const configured = pluginApi?.pluginSettings?.omarchyConfigDir;
    if (configured && typeof configured === "string" && configured.trim() !== "") {
      const value = expandHome(configured.trim());
      return value.endsWith("/") ? value : value + "/";
    }
    const xdg = Quickshell.env("XDG_CONFIG_HOME");
    const home = Quickshell.env("HOME");
    if (xdg && xdg !== "")
      return xdg + "/omarchy/";
    if (home && home !== "")
      return home + "/.config/omarchy/";
    return "~/.config/omarchy/";
  }

  readonly property string omarchyConfigPath: omarchyConfigDir + "current/theme/colors.toml"
  readonly property string omarchyHyprlandPath: omarchyConfigDir + "current/theme/hyprland.conf"
  readonly property string omarchyThemeNamePath: omarchyConfigDir + "current/theme.name"
  readonly property string omarchyThemesDir: omarchyConfigDir + "themes"
  readonly property string omarchyPath: {
    const home = Quickshell.env("HOME");
    if (home && home !== "")
      return home + "/.local/share/omarchy";
    return "~/.local/share/omarchy";
  }

  function normalizeThemeKey(name) {
    if (!name || typeof name !== "string")
      return ""
    return name.replace(/<[^>]+>/g, "").trim().toLowerCase().replace(/\s+/g, "-")
  }

  function logDebug() {
    if (!debugLogging)
      return
    Logger.d.apply(Logger, ["Omarchy"].concat(Array.prototype.slice.call(arguments)))
  }

  function setNoctaliaDarkMode(isDarkMode) {
    if (Settings.data.colorSchemes.darkMode === isDarkMode)
      return false

    // Prevent ColorSchemeService's onDarkModeChanged handler from re-applying the
    // previous predefined scheme while we are mid-apply (it triggers template generation).
    const wasWallpaper = !!Settings.data.colorSchemes.useWallpaperColors
    Settings.data.colorSchemes.useWallpaperColors = true
    Settings.data.colorSchemes.darkMode = isDarkMode
    Settings.data.colorSchemes.useWallpaperColors = wasWallpaper
    return true
  }

  function runShell(process, shell, script, args) {
    if (!process)
      return false
    if (!shell || !script)
      return false
    var command = [shell, "-c", script]
    if (args && args.length > 0)
      command = command.concat(["--"].concat(args))
    process.command = command
    process.running = true
    return true
  }

  readonly property string themeSetCommand: {
    const configured = pluginApi?.pluginSettings?.themeSetCommand;
    if (configured && typeof configured === "string" && configured.trim() !== "") {
      return expandHome(configured.trim());
    }
    const home = Quickshell.env("HOME");
    if (home && home !== "")
      return home + "/.local/share/omarchy/bin/omarchy-theme-set";
    return "~/.local/share/omarchy/bin/omarchy-theme-set";
  }

  function expandHome(path) {
    if (!path || typeof path !== "string")
      return path;
    if (!path.startsWith("~"))
      return path;
    const home = Quickshell.env("HOME") || "";
    if (path === "~")
      return home;
    if (path.startsWith("~/"))
      return home + path.slice(1);
    return path;
  }

  function mutatePluginSettings(mutator) {
    if (!pluginApi)
      return null;
    var settings = pluginApi.pluginSettings || {};
    mutator(settings);
    suppressSettingsSignal = true;
    pluginApi.pluginSettings = settings;
    suppressSettingsSignal = false;
    return settings;
  }

  function loadSavedColorPreferences() {
    if (savedPreferencesLoaded || stateReadProcess.running)
      return
    if (!colorPreferencesPath) {
      savedPreferencesLoaded = true
      maybeAutoApply()
      return
    }
    runShell(stateReadProcess, "sh", "cat \"$1\" 2>/dev/null || true", [colorPreferencesPath])
  }

  function persistColorPreferences(useWallpaperColors, predefinedScheme) {
    if (!colorPreferencesPath)
      return
    const payload = {
      "useWallpaperColors": !!useWallpaperColors,
      "predefinedScheme": predefinedScheme || ""
    }
    const jsonContent = JSON.stringify(payload, null, 2)
    const writeCmd = "mkdir -p \"$1\" && cat > \"$2\" << 'OMARCHY_PREFS_EOF'\n" + jsonContent + "\nOMARCHY_PREFS_EOF\n"
    runShell(stateWriteProcess, "sh", writeCmd, [colorPreferencesDir, colorPreferencesPath])
  }

  function clearSavedColorPreferences() {
    if (!colorPreferencesPath)
      return
    runShell(stateClearProcess, "sh", "rm -f \"$1\"", [colorPreferencesPath])
  }

  function rememberColorPreferences() {
    if (!pluginApi)
      return false
    if (hasSavedColorPreferences)
      return false

    const useWallpaper = !!Settings.data.colorSchemes.useWallpaperColors
    const scheme = Settings.data.colorSchemes.predefinedScheme || ""

    if (!savedPreferencesLoaded) {
      pendingRememberPreferences = true
      pendingRememberWallpaper = useWallpaper
      pendingRememberScheme = scheme
      loadSavedColorPreferences()
      return true
    }

    hasSavedColorPreferences = true
    savedUseWallpaperColors = useWallpaper
    savedPredefinedScheme = scheme
    persistColorPreferences(useWallpaper, scheme)
    return true
  }

  function restoreColorPreferences() {
    if (!pluginApi)
      return false
    if (!hasSavedColorPreferences && !pendingRememberPreferences)
      return false

    const prevWallpaper = hasSavedColorPreferences ? savedUseWallpaperColors : pendingRememberWallpaper
    const prevScheme = hasSavedColorPreferences ? savedPredefinedScheme : pendingRememberScheme

    hasSavedColorPreferences = false
    savedUseWallpaperColors = false
    savedPredefinedScheme = ""
    pendingRememberPreferences = false
    pendingRememberWallpaper = false
    pendingRememberScheme = ""

    clearSavedColorPreferences()

    Settings.data.colorSchemes.useWallpaperColors = prevWallpaper
    Settings.data.colorSchemes.predefinedScheme = prevScheme || Settings.data.colorSchemes.predefinedScheme

    if (prevWallpaper) {
      AppThemeService.generate()
    } else if (Settings.data.colorSchemes.predefinedScheme) {
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme)
    }
    return true
  }

  function refresh() {
    checkAvailability();
    scanThemes();
    refreshThemeName();
  }

  function scheduleReloadApply(includeThemeScan) {
    pendingReloadApply = true
    pendingReloadApplyAvailabilityReady = false
    pendingReloadApplyThemeReady = false
    checkAvailability()
    if (includeThemeScan)
      scanThemes()
    refreshThemeName()
  }

  function maybeRunPendingReloadApply() {
    if (!pendingReloadApply)
      return
    if (!pendingReloadApplyAvailabilityReady || !pendingReloadApplyThemeReady)
      return
    pendingReloadApply = false
    if (pluginApi?.pluginSettings?.active)
      applyCurrentTheme()
  }

  function maybeAutoApply() {
    if (autoAppliedOnStartup)
      return
    if (!savedPreferencesLoaded)
      return
    if (!pluginApi?.pluginSettings?.active)
      return
    if (!available)
      return
    autoAppliedOnStartup = true
    Logger.i("Omarchy", "Auto-applying theme on startup")
    Qt.callLater(applyCurrentTheme)
  }

  function captureObservedSettings() {
    const settings = pluginApi?.pluginSettings || ({})
    observedActive = !!settings.active
    observedConfigDir = (settings.omarchyConfigDir || "").trim()
    observedThemeSetCommand = (settings.themeSetCommand || "").trim()
  }

  function checkAvailability() {
    // Check for both colors.toml and theme.name file
    runShell(availabilityProcess, "bash", "[ -f \"$1\" ] && [ -f \"$2\" ]", [omarchyConfigPath, omarchyThemeNamePath])
  }

  function scanThemes() {
    logDebug("Scanning themes using omarchy-theme-list")

    // Use omarchy-theme-list and derive light/dark mode from theme files
    const cmd = "themes_dir=\"$1\"; stock_dir=\"$2\"; " +
                "omarchy-theme-list | while IFS= read -r name; do " +
                "[ -z \"$name\" ] && continue; " +
                "theme_dir=$(echo \"$name\" | sed -E 's/<[^>]+>//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); " +
                "if [ -f \"$themes_dir/$theme_dir/light.mode\" ] || [ -f \"$stock_dir/$theme_dir/light.mode\" ]; then mode=light; else mode=dark; fi; " +
                "printf '%s|%s\\n' \"$name\" \"$mode\"; " +
                "done";
    logDebug("Theme scan command:", cmd)
    runShell(themesProcess, "bash", cmd, [omarchyThemesDir, omarchyPath + "/themes"])
  }

  function refreshThemeName() {
    runShell(themeNameProcess, "sh", "cat \"$1\" 2>/dev/null || true", [omarchyThemeNamePath])
  }

  function activate() {
    if (!pluginApi)
      return false;
    rememberColorPreferences();
    mutatePluginSettings(s => s.active = true);
    ignoreNextPluginSettingsChanged = true
    pluginApi.saveSettings();
    return applyCurrentTheme();
  }

  function deactivate() {
    if (!pluginApi)
      return;
    mutatePluginSettings(s => s.active = false);
    restoreColorPreferences();
    ignoreNextPluginSettingsChanged = true
    pluginApi.saveSettings();
  }

  function applyCurrentTheme() {
    if (!available) {
      ToastService.showError("Omarchy", pluginApi?.tr("errors.missing-config") || "Omarchy config not found");
      return false;
    }

    if (applying) {
      pendingApplyAfterCurrent = true
      return true
    }

    rememberColorPreferences()

    applying = true;

    const cacheCompatible = SchemeCache.isCompatible(ThemePipeline.PIPELINE_VERSION);
    if (themeName && cacheCompatible) {
      const cacheKey = normalizeThemeKey(themeName)
      const cached = cacheKey ? SchemeCache.getScheme(cacheKey) : null
      if (cached?.palette && cached?.mode) {
        Logger.i("Omarchy", "Using cached scheme for:", themeName);
        const isDarkMode = cached.mode === "dark";
        if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
          Logger.i("Omarchy", "Auto-switching Noctalia dark mode to:", isDarkMode);
          setNoctaliaDarkMode(isDarkMode)
        }
        writeSchemeFile(cached);
        return true;
      }
    } else if (!cacheCompatible) {
      Logger.w("Omarchy", "Scheme cache version mismatch; falling back to live conversion");
    }

    alacrittyReadProcess.command = ["cat", omarchyConfigPath];
    alacrittyReadProcess.running = true;
    return true;
  }

  function setTheme(nextThemeName) {
    if (!nextThemeName)
      return false;

    themeSetProcess.command = [themeSetCommand, nextThemeName];
    themeSetProcess.running = true;
    return true;
  }

  function parseColorsToml(content) {
    Logger.i("Omarchy", "Parsing colors.toml, content length:", content.length);
    logDebug("First 500 chars:", content.slice(0, 500))

    function extractColorFromLine(line) {
      // Match both formats: color = "#ffffff" and color = "0xffffff"
      const colorMatch = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
      if (colorMatch) {
        const hex = colorMatch[1].toLowerCase();
        return "#" + hex.slice(-6);
      }
      return null;
    }

    const colors = {};
    const lines = content.split("\n");
    logDebug("Parsing", lines.length, "lines")

    for (var i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line || line.startsWith("#") || line.startsWith("["))
        continue;

      const color = extractColorFromLine(line);
      if (color) {
        // Extract the key name (everything before the =)
        const keyMatch = line.match(/^([a-zA-Z0-9_]+)\s*=/);
        if (keyMatch) {
          const key = keyMatch[1];
          colors[key] = color;
          logDebug("Found", key, ":", color)
        }
      }
    }

    Logger.i("Omarchy", "Parsed colors:", Object.keys(colors).join(","));

    if (!colors.background) {
      Logger.e("Omarchy", "PARSE FAILED: No background color found");
      logDebug("First 500 chars of content:", content.slice(0, 500))
    }
    if (!colors.foreground) {
      Logger.e("Omarchy", "PARSE FAILED: No foreground color found");
      logDebug("First 500 chars of content:", content.slice(0, 500))
    }

    if (!colors.background || !colors.foreground)
      return null;
    return colors;
  }

  function parseHyprlandConf(content) {
    // Extract $activeBorderColor from hyprland.conf
    // Formats: rgb(RRGGBB), rgba(RRGGBBAA), rgba(...) rgba(...) 45deg (gradient)
    const lines = content.split("\n");
    for (var i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith("$activeBorderColor")) {
        // Extract the color value after the =
        const match = line.match(/=\s*(.+)/);
        if (!match) continue;

        const value = match[1].trim();
        // For gradients like "rgba(010401ee) rgba(518a51ee) 45deg", pick the second (brighter) color
        // For simple colors like "rgb(c6d0f5)", use that
        const colorMatches = value.match(/rgba?\(([a-fA-F0-9]{6,8})\)/g);
        if (colorMatches && colorMatches.length > 0) {
          // Use the last color in the list (usually brighter in gradients)
          const lastColor = colorMatches[colorMatches.length - 1];
          const hexMatch = lastColor.match(/rgba?\(([a-fA-F0-9]{6,8})\)/);
          if (hexMatch) {
            // Take first 6 chars for RGB, ignore alpha if present
            const hex = hexMatch[1].slice(0, 6);
            logDebug("Found Hyprland border color:", "#" + hex)
            return "#" + hex.toLowerCase();
          }
        }
      }
    }
    logDebug("No Hyprland border color found, using default")
    return null;
  }

  function writeSchemeFile(result) {
    const mode = result?.mode;
    const scheme = result?.palette;
    if (!scheme || !mode) {
      Logger.e("Omarchy", "writeSchemeFile missing scheme data or mode");
      applying = false;
      return;
    }

    if (!schemeOutputPath || !schemeOutputDir) {
      applying = false;
      return;
    }

    // Include both dark and light keys (native schemes have both)
    // Use the generated scheme for the active mode, copy it for the other mode as fallback
    const wrappedScheme = {
      "dark": scheme,
      "light": scheme
    };

    const jsonContent = JSON.stringify(wrappedScheme, null, 2);
    logDebug("Writing scheme JSON, length:", jsonContent.length)
    const writeCmd = "mkdir -p \"$1\" && cat > \"$2\" << 'OMARCHY_SCHEME_EOF'\n" + jsonContent + "\nOMARCHY_SCHEME_EOF\n";
    logDebug("Scheme write command:", writeCmd)
    runShell(schemeWriteProcess, "sh", writeCmd, [schemeOutputDir, schemeOutputPath])
  }

  Process {
    id: availabilityProcess
    running: false
    onExited: function (code) {
      available = (code === 0);
      maybeAutoApply()
      if (root.pendingReloadApply) {
        root.pendingReloadApplyAvailabilityReady = true
        root.maybeRunPendingReloadApply()
      }
    }
  }

  Process {
    id: stateReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      const output = (stdout.text || "").trim()
      savedPreferencesLoaded = true

      if (output !== "") {
        try {
          const parsed = JSON.parse(output)
          if (parsed && typeof parsed === "object") {
            hasSavedColorPreferences = true
            savedUseWallpaperColors = !!parsed.useWallpaperColors
            savedPredefinedScheme = parsed.predefinedScheme || ""
            pendingRememberPreferences = false
          }
        } catch (e) {
          Logger.w("Omarchy", "Failed to parse saved color preferences:", String(e))
        }
      } else if (pendingRememberPreferences) {
        hasSavedColorPreferences = true
        savedUseWallpaperColors = pendingRememberWallpaper
        savedPredefinedScheme = pendingRememberScheme
        pendingRememberPreferences = false
        persistColorPreferences(savedUseWallpaperColors, savedPredefinedScheme)
      }

      maybeAutoApply()
    }
  }

  Process {
    id: stateWriteProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("Omarchy", "Failed to persist color preferences, exit code:", code)
      }
    }
  }

  Process {
    id: stateClearProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("Omarchy", "Failed to clear saved color preferences, exit code:", code)
      }
    }
  }

  Process {
    id: themesProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      logDebug("themesProcess exited with code:", code)

      if (code !== 0) {
        Logger.e("Omarchy", "Theme scanning failed, exit code:", code);
        availableThemes = [];
        return;
      }

      const output = stdout.text || "";
      logDebug("Theme scan output length:", output.length)

      if (!output) {
        Logger.w("Omarchy", "Theme scan returned empty output");
        availableThemes = [];
        return;
      }

      const themeLines = output.trim().split("\n").filter(line => line && line.trim());
      const themeNames = [];

      // Create theme entries with just names (colors parsed by omarchy-theme-set)
      const themes = [];
      for (var i = 0; i < themeLines.length; i++) {
        const line = themeLines[i];
        const parts = line.split("|");
        const themeName = parts[0]?.trim();
        if (!themeName)
          continue;
        const detectedMode = parts[1]?.trim();
        const normalizedName = normalizeThemeKey(themeName)
        const cachedScheme = SchemeCache.getScheme(normalizedName);
        const mode = cachedScheme?.mode || detectedMode || "dark";
        themeNames.push(themeName);
        themes.push({
          "name": themeName,
          "colors": [],  // No preview colors needed
          "mode": mode
        });
      }

      Logger.i("Omarchy", "Found", themeNames.length, "themes")
      availableThemes = themes;
    }
  }

  Process {
    id: themeNameProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      themeName = (stdout.text || "").trim();
      if (root.pendingReloadApply) {
        root.pendingReloadApplyThemeReady = true
        root.maybeRunPendingReloadApply()
      }
    }
  }

  Process {
    id: themeSetProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-theme-set") || "Failed to switch theme");
        return;
      }
      if (pluginApi?.pluginSettings?.active) {
        scheduleReloadApply()
      } else {
        refreshThemeName()
      }
    }
  }

  Process {
    id: alacrittyReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      Logger.i("Omarchy", "alacrittyReadProcess exited with code:", code);

      if (code !== 0) {
        applying = false;
        Logger.e("Omarchy", "Failed to read alacritty config, exit code:", code);
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-read") || "Failed to read theme colors");
        return;
      }

      const content = stdout.text || "";
      logDebug("Read", content.length, "bytes from", omarchyConfigPath)

      const parsed = parseColorsToml(content);
      if (!parsed) {
        applying = false;
        Logger.e("Omarchy", "parseColorsToml returned null");
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-read") || "Failed to read theme colors");
        return;
      }

      Logger.i("Omarchy", "Successfully parsed theme colors, now reading Hyprland config");
      pendingAlacrittyColors = parsed;
      hyprlandReadProcess.command = ["cat", omarchyHyprlandPath];
      hyprlandReadProcess.running = true;
    }
  }

  Process {
    id: hyprlandReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      Logger.i("Omarchy", "hyprlandReadProcess exited with code:", code);

      const parsed = pendingAlacrittyColors;
      pendingAlacrittyColors = null;

      if (!parsed) {
        applying = false;
        Logger.e("Omarchy", "No pending alacritty colors");
        return;
      }

      // Parse Hyprland border color (optional - don't fail if missing)
      if (code === 0) {
        const content = stdout.text || "";
        const borderColor = parseHyprlandConf(content);
        if (borderColor) {
          parsed.hyprlandBorder = borderColor;
          Logger.i("Omarchy", "Using Hyprland border color:", borderColor);
        }
      } else {
        Logger.w("Omarchy", "Could not read hyprland.conf, using default border color");
      }

      Logger.i("Omarchy", "Generating color scheme");
      const schemeResult = ThemePipeline.generateScheme(parsed, ColorsConvert);
      logDebug("Detected mode:", schemeResult.mode)

      // Auto-sync dark mode setting
      const isDarkMode = schemeResult.mode === "dark";
      if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
        Logger.i("Omarchy", "Auto-switching Noctalia dark mode to:", isDarkMode);
        setNoctaliaDarkMode(isDarkMode)
      }
      writeSchemeFile(schemeResult);
    }
  }

  Process {
    id: schemeWriteProcess
    running: false
    onExited: function (code) {
      Logger.i("Omarchy", "schemeWriteProcess exited with code:", code);
      applying = false;
      if (code !== 0) {
        Logger.e("Omarchy", "Failed to write scheme file, exit code:", code);
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-apply") || "Failed to apply scheme");
        if (pendingApplyAfterCurrent) {
          pendingApplyAfterCurrent = false
          Qt.callLater(applyCurrentTheme)
        }
        return;
      }

      Logger.i("Omarchy", "Scheme file written successfully to:", schemeOutputPath);
      ColorSchemeService.applyScheme(schemeOutputPath)
      if (Settings.data.colorSchemes.useWallpaperColors) {
        Settings.data.colorSchemes.predefinedScheme = schemeOutputPath
        Settings.data.colorSchemes.useWallpaperColors = false
      }

      if (pendingApplyAfterCurrent) {
        pendingApplyAfterCurrent = false
        Qt.callLater(applyCurrentTheme)
      }
    }
  }

  function cycleTheme() {
    const themes = root.availableThemes || [];
    if (themes.length === 0)
      return;

    let currentIndex = -1;
    const currentKey = normalizeThemeKey(root.themeName)
    for (let i = 0; i < themes.length; i++) {
      const entry = themes[i];
      const name = typeof entry === "string" ? entry : entry.name;
      if (normalizeThemeKey(name) === currentKey) {
        currentIndex = i;
        break;
      }
    }

    const nextIndex = (currentIndex + 1) % themes.length;
    const nextTheme = themes[nextIndex];
    const nextName = typeof nextTheme === "string" ? nextTheme : nextTheme.name;
    root.setTheme(nextName);
  }

  function randomTheme() {
    const themes = root.availableThemes || [];
    if (themes.length === 0)
      return;

    // Filter out the currently active theme
    const currentKey = normalizeThemeKey(root.themeName)
    const otherThemes = themes.filter(theme => {
      const name = typeof theme === "string" ? theme : theme.name;
      return normalizeThemeKey(name) !== currentKey
    });

    // If no other themes available, can't pick a different one
    if (otherThemes.length === 0)
      return;

    const randomIndex = Math.floor(Math.random() * otherThemes.length);
    const randomTheme = otherThemes[randomIndex];
    const randomName = typeof randomTheme === "string" ? randomTheme : randomTheme.name;
    root.setTheme(randomName);
  }

  IpcHandler {
    target: "omarchy"

    function reload() {
      root.scheduleReloadApply()
    }

    function toggle() {
      if (pluginApi?.pluginSettings?.active) {
        root.deactivate();
      } else {
        root.activate();
      }
    }

    function setTheme(themeName: string) {
      root.setTheme(themeName);
    }

    function cycleTheme() {
      root.cycleTheme();
    }

    function randomTheme() {
      root.randomTheme();
    }
  }

  IpcHandler {
    target: "plugin:omarchy"

    function reload() {
      root.scheduleReloadApply()
    }

    function toggle() {
      if (pluginApi?.pluginSettings?.active) {
        root.deactivate()
      } else {
        root.activate()
      }
    }

    function setTheme(themeName: string) {
      root.setTheme(themeName)
    }

    function cycleTheme() {
      root.cycleTheme()
    }

    function randomTheme() {
      root.randomTheme()
    }
  }

  Component.onCompleted: {
    loadSavedColorPreferences()
    refresh();
    captureObservedSettings()
    maybeAutoApply()
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      if (root.ignoreNextPluginSettingsChanged) {
        root.ignoreNextPluginSettingsChanged = false
        root.captureObservedSettings()
        return
      }
      if (root.suppressSettingsSignal)
        return;

      const settings = pluginApi?.pluginSettings || ({})
      const nextActive = !!settings.active
      const nextConfigDir = (settings.omarchyConfigDir || "").trim()
      const nextThemeSetCommand = (settings.themeSetCommand || "").trim()

      const activeChanged = nextActive !== root.observedActive
      const configDirChanged = nextConfigDir !== root.observedConfigDir
      const themeSetCommandChanged = nextThemeSetCommand !== root.observedThemeSetCommand

      root.observedActive = nextActive
      root.observedConfigDir = nextConfigDir
      root.observedThemeSetCommand = nextThemeSetCommand

      if (activeChanged) {
        if (nextActive) {
          rememberColorPreferences()
          root.scheduleReloadApply()
        } else {
          restoreColorPreferences()
        }
        return
      }

      if (configDirChanged) {
        if (nextActive) {
          root.scheduleReloadApply(true)
        } else {
          root.refresh()
        }
        return
      }

      if (themeSetCommandChanged) {
        return
      }
    }
  }
}
