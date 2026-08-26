// qmllint disable signal-handler-parameters
import QtQuick
import Quickshell
import Quickshell.Io
import "ColorsConvert.js" as ColorsConvert
import "OmarchyCommands.js" as OmarchyCommands
import "SchemeCache.js" as SchemeCache
import "ThemeFiles.js" as ThemeFiles
import "ThemeIdentity.js" as ThemeIdentity
import "ThemePipeline.js" as ThemePipeline
import qs.Commons
import qs.Services.Theming
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  visible: false

  // Core properties
  property bool available: false
  property bool applying: false
  property bool pendingApplyAfterCurrent: false
  property string themeName: ""
  property var availableThemes: []
  property bool suppressSettingsSignal: false
  property var pendingAlacrittyColors: null
  property var pendingHyprlandThemePaths: []
  property string pendingHyprlandThemePath: ""
  property bool ignoreNextPluginSettingsChanged: false

  // Operation manager state (replaces old pending operations)
  property bool operationInProgress: false
  property string operationThemeName: ""
  property int operationId: 0
  readonly property bool isBusy: applying || operationInProgress

  // Reload/apply coordination to avoid race conditions
  property bool pendingReloadApply: false
  property bool pendingReloadApplyAvailabilityReady: false
  property bool pendingReloadApplyThemeReady: false

  property bool observedActive: false
  property string observedConfigDir: ""
  property string observedThemeSetCommand: ""

  readonly property bool debugLogging: pluginApi?.pluginSettings?.debugLogging === true

  readonly property string schemeDisplayName: pluginApi?.manifest?.metadata?.schemeName || "Omarchy"
  readonly property string schemeBaseDir: {
    const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
    return baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
  }
  readonly property string schemeKey: {
    const name = schemeDisplayName || "Omarchy";
    return name.replace(/[\\/]/g, "-").trim();
  }
  readonly property string schemeFolder: {
    return schemeBaseDir + "/" + schemeKey;
  }
  readonly property string legacySchemeKey: (schemeKey || "").toLowerCase()
  property bool legacyCleanupChecked: false

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
      return "";
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
  readonly property string omarchyHyprlandLuaPath: omarchyConfigDir + "current/theme/hyprland.lua"
  readonly property string omarchyHyprlandConfPath: omarchyConfigDir + "current/theme/hyprland.conf"
  readonly property string omarchyThemeNamePath: omarchyConfigDir + "current/theme.name"
  readonly property string omarchyThemesDir: omarchyConfigDir + "themes"
  readonly property string omarchyPath: {
    const envPath = Quickshell.env("OMARCHY_PATH");
    if (envPath && envPath.trim() !== "")
      return expandHome(envPath.trim());
    const home = Quickshell.env("HOME");
    if (home && home !== "")
      return home + "/.local/share/omarchy";
    return "~/.local/share/omarchy";
  }

  // Async operation helpers
  AsyncThemeSetter {
    id: asyncThemeSetter
    themeSetCommand: root.themeSetCommand
    legacyThemeSetCommand: root.legacyThemeSetCommand
    omarchyPath: root.omarchyPath

    timeoutMs: 3000
  }

  InstantSchemeApplier {
    id: instantSchemeApplier
    schemeDisplayName: root.schemeDisplayName
    pluginApi: root.pluginApi
  }

  // Computed property for display name
  readonly property string themeDisplayName: ThemeIdentity.formatThemeName(themeName)

  function logDebug() {
    if (!debugLogging)
      return;
    Logger.d.apply(Logger, ["Omarchy"].concat(Array.prototype.slice.call(arguments)));
  }

  function isDaytime() {
    // Only valid when location-based scheduling is enabled
    const schedulingMode = Settings.data.colorSchemes.schedulingMode;
    if (schedulingMode !== "location") {
      return null;  // Unknown
    }
    return !Settings.data.colorSchemes.darkMode;
  }

  function getFilteredThemes() {
    const themes = root.availableThemes || [];
    const filteringEnabled = pluginApi?.pluginSettings?.timeBasedThemeFiltering === true;
    if (!filteringEnabled)
      return themes;

    // Check if location-based scheduling is enabled
    const schedulingMode = Settings.data.colorSchemes.schedulingMode;
    if (schedulingMode !== "location") {
      Logger.w("Omarchy", "Time-based filtering enabled but location-based scheduling not active in Noctalia");
      return themes;  // Return all themes when we can't determine time
    }

    const isDay = isDaytime();
    if (isDay === null) {
      return themes;  // Fallback if time unknown
    }

    const filtered = themes.filter(theme => {
      const mode = theme.mode || "dark";
      return isDay ? mode === "light" : mode === "dark";
    });

    if (filtered.length === 0) {
      Logger.w("Omarchy", "No themes match current time of day, falling back to all themes");
      return themes;
    }
    return filtered;
  }

  function runShell(process, shell, script, args) {
    if (!process)
      return false;
    if (!shell || !script)
      return false;
    var command = [shell, "-c", script];
    if (args && args.length > 0)
      command = command.concat(["--"].concat(args));
    process.command = command;
    process.running = true;
    return true;
  }

  readonly property string themeSetCommand: {
    const configured = pluginApi?.pluginSettings?.themeSetCommand;
    if (configured && typeof configured === "string" && configured.trim() !== "")
      return expandHome(configured.trim());
    return "";
  }
  readonly property string legacyThemeSetCommand: omarchyPath + "/bin/omarchy-theme-set"
  readonly property string legacyThemeListCommand: omarchyPath + "/bin/omarchy-theme-list"

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
      return;
    if (!colorPreferencesPath) {
      savedPreferencesLoaded = true;
      maybeAutoApply();
      return;
    }
    runShell(stateReadProcess, "sh", "cat \"$1\" 2>/dev/null || true", [colorPreferencesPath]);
  }

  function persistColorPreferences(useWallpaperColors, predefinedScheme) {
    if (!colorPreferencesPath)
      return;
    const payload = {
      "useWallpaperColors": !!useWallpaperColors,
      "predefinedScheme": predefinedScheme || ""
    };
    const jsonContent = JSON.stringify(payload, null, 2);
    const writeCmd = "mkdir -p \"$1\" && cat > \"$2\" << 'OMARCHY_PREFS_EOF'\n" + jsonContent + "\nOMARCHY_PREFS_EOF\n";
    runShell(stateWriteProcess, "sh", writeCmd, [colorPreferencesDir, colorPreferencesPath]);
  }

  function clearSavedColorPreferences() {
    if (!colorPreferencesPath)
      return;
    runShell(stateClearProcess, "sh", "rm -f \"$1\"", [colorPreferencesPath]);
  }

  function rememberColorPreferences() {
    if (!pluginApi)
      return false;
    if (hasSavedColorPreferences)
      return false;

    const useWallpaper = !!Settings.data.colorSchemes.useWallpaperColors;
    const scheme = Settings.data.colorSchemes.predefinedScheme || "";

    if (!savedPreferencesLoaded) {
      pendingRememberPreferences = true;
      pendingRememberWallpaper = useWallpaper;
      pendingRememberScheme = scheme;
      loadSavedColorPreferences();
      return true;
    }

    hasSavedColorPreferences = true;
    savedUseWallpaperColors = useWallpaper;
    savedPredefinedScheme = scheme;
    persistColorPreferences(useWallpaper, scheme);
    return true;
  }

  function restoreColorPreferences() {
    if (!pluginApi)
      return false;
    if (!hasSavedColorPreferences && !pendingRememberPreferences)
      return false;

    const prevWallpaper = hasSavedColorPreferences ? savedUseWallpaperColors : pendingRememberWallpaper;
    const prevScheme = hasSavedColorPreferences ? savedPredefinedScheme : pendingRememberScheme;

    hasSavedColorPreferences = false;
    savedUseWallpaperColors = false;
    savedPredefinedScheme = "";
    pendingRememberPreferences = false;
    pendingRememberWallpaper = false;
    pendingRememberScheme = "";

    clearSavedColorPreferences();

    Settings.data.colorSchemes.useWallpaperColors = prevWallpaper;
    Settings.data.colorSchemes.predefinedScheme = prevScheme || Settings.data.colorSchemes.predefinedScheme;

    if (prevWallpaper) {
      AppThemeService.generate();
    } else if (Settings.data.colorSchemes.predefinedScheme) {
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
    }
    return true;
  }

  function refresh() {
    checkAvailability();
    scanThemes();
    refreshThemeName();
  }

  function scheduleReloadApply(includeThemeScan) {
    pendingReloadApply = true;
    pendingReloadApplyAvailabilityReady = false;
    pendingReloadApplyThemeReady = false;

    checkAvailability();
    refreshThemeName();
    if (includeThemeScan)
      scanThemes();
  }

  function maybeRunPendingReloadApply() {
    if (!pendingReloadApply)
      return;
    if (!pendingReloadApplyAvailabilityReady || !pendingReloadApplyThemeReady)
      return;
    pendingReloadApply = false;
    if (pluginApi?.pluginSettings?.active)
      applyCurrentTheme();
  }

  function reloadPluginState() {
    if (pluginApi?.pluginSettings?.active) {
      scheduleReloadApply(true);
    } else {
      refresh();
    }
  }

  function maybeAutoApply() {
    if (autoAppliedOnStartup)
      return;
    if (!savedPreferencesLoaded)
      return;
    if (!pluginApi?.pluginSettings?.active)
      return;
    if (!available)
      return;
    autoAppliedOnStartup = true;
    Logger.i("Omarchy", "Auto-applying theme on startup");
    Qt.callLater(applyCurrentTheme);
  }

  function captureObservedSettings() {
    const settings = pluginApi?.pluginSettings || ({});
    observedActive = !!settings.active;
    observedConfigDir = (settings.omarchyConfigDir || "").trim();
    observedThemeSetCommand = (settings.themeSetCommand || "").trim();
  }

  function checkAvailability() {
    const cmd = OmarchyCommands.availabilityScript();
    runShell(availabilityProcess, "bash", cmd, [omarchyConfigPath, omarchyThemeNamePath, themeSetCommand, legacyThemeSetCommand, legacyThemeListCommand, omarchyPath]);
  }

  function scanThemes() {
    logDebug("Scanning themes using Omarchy theme list");
    // Output format: display_name|dir_name|mode
    const cmd = OmarchyCommands.themeListScript();
    logDebug("Theme scan command:", cmd);
    runShell(themesProcess, "bash", cmd, [omarchyThemesDir, omarchyPath + "/themes", legacyThemeListCommand, omarchyPath]);
  }

  function refreshThemeName() {
    runShell(themeNameProcess, "sh", "cat \"$1\" 2>/dev/null || true", [omarchyThemeNamePath]);
  }

  function activate() {
    if (!pluginApi)
      return false;
    rememberColorPreferences();
    mutatePluginSettings(s => s.active = true);
    ignoreNextPluginSettingsChanged = true;
    pluginApi.saveSettings();
    return applyCurrentTheme();
  }

  function activateAndSetTheme(nextThemeName) {
    if (!nextThemeName)
      return false;
    if (!pluginApi)
      return false;
    if (!available) {
      ToastService.showError("Omarchy", pluginApi?.tr("errors.missing-config"));
      return false;
    }

    if (!pluginApi?.pluginSettings?.active) {
      rememberColorPreferences();
      mutatePluginSettings(s => s.active = true);
      ignoreNextPluginSettingsChanged = true;
      pluginApi.saveSettings();
    }

    return setTheme(nextThemeName);
  }

  function deactivate() {
    if (!pluginApi)
      return;
    mutatePluginSettings(s => s.active = false);
    restoreColorPreferences();
    ignoreNextPluginSettingsChanged = true;
    pluginApi.saveSettings();
  }

  function applyCurrentTheme() {
    if (!available) {
      ToastService.showError("Omarchy", pluginApi?.tr("errors.missing-config"));
      return false;
    }

    if (applying) {
      pendingApplyAfterCurrent = true;
      return true;
    }

    rememberColorPreferences();
    applying = true;

    const cacheCompatible = SchemeCache.isCompatible(ThemePipeline.PIPELINE_VERSION);
    if (themeName && cacheCompatible) {
      const cacheKey = ThemeIdentity.normalizeThemeKey(themeName);
      const cached = cacheKey ? SchemeCache.getScheme(cacheKey) : null;
      if (cached?.palette && cached?.mode) {
        Logger.i("Omarchy", "Using cached scheme for:", themeName);
        writeSchemeResult(cached);
        return true;
      }
    } else if (!cacheCompatible) {
      Logger.w("Omarchy", "Scheme cache version mismatch; falling back to live conversion");
    }

    alacrittyReadProcess.command = ["cat", omarchyConfigPath];
    alacrittyReadProcess.running = true;
    return true;
  }

  // NEW: Async setTheme with optimistic UI updates
  function setTheme(nextThemeName) {
    if (!nextThemeName)
      return false;

    // Debounce: cancel previous operation if in progress
    if (operationInProgress) {
      Logger.d("Omarchy", "Cancelling previous operation");
      asyncThemeSetter.cancelOperation();
    }

    const previousThemeName = themeName;
    const opId = ++operationId;
    operationInProgress = true;
    operationThemeName = nextThemeName;

    Logger.i("Omarchy", "Starting async theme change:", nextThemeName, "opId:", opId);

    // Phase 1: Optimistic UI update (instant)
    themeName = nextThemeName;

    // Phase 2: Apply scheme from cache (instant)
    const schemeResult = instantSchemeApplier.applyScheme(nextThemeName);
    if (!schemeResult.success) {
      Logger.w("Omarchy", "Cache miss, colors will apply after theme-set completes");
    }

    // Phase 3: Start async theme-set
    const promise = asyncThemeSetter.setTheme(nextThemeName, opId);

    promise.then(function (result) {
      if (result.operationId !== operationId) {
        Logger.d("Omarchy", "Stale operation ignored");
        return;
      }

      operationInProgress = false;
      operationThemeName = "";

      if (result.success) {
        Logger.i("Omarchy", "Theme change completed:", nextThemeName);
        // Refresh theme name to confirm
        refreshThemeName();

        // If cache miss occurred, generate scheme from files now
        if (!schemeResult.success) {
          Logger.i("Omarchy", "Cache miss detected, generating scheme from files");
          Qt.callLater(function () {
            if (opId !== operationId || root.themeName !== nextThemeName) {
              Logger.d("Omarchy", "Skipping stale cache-miss apply for:", nextThemeName);
              return;
            }
            applyCurrentTheme();
          });
        }
      } else {
        Logger.e("Omarchy", "Theme change failed:", result.error);
        themeName = previousThemeName;
        refreshThemeName();
        Qt.callLater(function () {
          if (opId !== operationId || root.themeName !== previousThemeName) {
            Logger.d("Omarchy", "Skipping stale failure recovery for:", nextThemeName);
            return;
          }
          applyCurrentTheme();
        });
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-theme-set"));
      }
    });

    return true;
  }

  function beginHyprlandThemeRead(parsed) {
    pendingAlacrittyColors = parsed;
    pendingHyprlandThemePaths = [omarchyHyprlandLuaPath, omarchyHyprlandConfPath];
    pendingHyprlandThemePath = "";
    readNextHyprlandThemeFile();
  }

  function readNextHyprlandThemeFile() {
    if (!pendingAlacrittyColors) {
      applying = false;
      Logger.e("Omarchy", "No pending theme colors for Hyprland theme read");
      return;
    }

    if (!pendingHyprlandThemePaths || pendingHyprlandThemePaths.length === 0) {
      Logger.w("Omarchy", "Could not read a Hyprland theme border color, using default border color");
      finishSchemeGeneration(pendingAlacrittyColors);
      return;
    }

    const nextPath = pendingHyprlandThemePaths[0];
    pendingHyprlandThemePaths = pendingHyprlandThemePaths.slice(1);
    pendingHyprlandThemePath = nextPath;
    hyprlandReadProcess.command = ["cat", nextPath];
    hyprlandReadProcess.running = true;
  }

  function finishSchemeGeneration(parsed) {
    pendingAlacrittyColors = null;
    pendingHyprlandThemePaths = [];
    pendingHyprlandThemePath = "";

    Logger.i("Omarchy", "Generating color scheme");
    const schemeResult = ThemePipeline.generateScheme(parsed, ColorsConvert);
    logDebug("Detected mode:", schemeResult.mode);

    writeSchemeResult(schemeResult);
  }

  function writeSchemeResult(result) {
    if (!instantSchemeApplier.writeAndApplyScheme(result, handleSchemeApplyFinished))
      handleSchemeApplyFinished(false);
  }

  function handleSchemeApplyFinished(success) {
    applying = false;
    if (!success) {
      Logger.e("Omarchy", "Failed to write or apply scheme");
      ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-apply"));
    }

    if (pendingApplyAfterCurrent) {
      pendingApplyAfterCurrent = false;
      Qt.callLater(applyCurrentTheme);
    }
  }

  function cleanupLegacySchemeFolder() {
    if (legacyCleanupChecked)
      return;
    legacyCleanupChecked = true;

    if (!schemeBaseDir || !schemeKey)
      return;
    if (!legacySchemeKey || legacySchemeKey === schemeKey)
      return;
    const cleanupCmd = "if [ -d \"$1/$2\" ] && [ -f \"$1/$3/$3.json\" ]; then rm -rf \"$1/$2\" && printf 'removed'; fi";
    runShell(legacySchemeCleanupProcess, "sh", cleanupCmd, [schemeBaseDir, legacySchemeKey, schemeKey]);
  }

  // Process definitions
  Process {
    id: availabilityProcess
    running: false
    onExited: function (code) {
      available = (code === 0);
      if (root.pendingReloadApply) {
        root.pendingReloadApplyAvailabilityReady = true;
        root.maybeRunPendingReloadApply();
      }
      maybeAutoApply();
    }
  }

  Process {
    id: stateReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      const output = (stdout.text || "").trim();
      savedPreferencesLoaded = true;

      if (output !== "") {
        try {
          const parsed = JSON.parse(output);
          if (parsed && typeof parsed === "object") {
            hasSavedColorPreferences = true;
            savedUseWallpaperColors = !!parsed.useWallpaperColors;
            savedPredefinedScheme = parsed.predefinedScheme || "";
            pendingRememberPreferences = false;
          }
        } catch (e) {
          Logger.w("Omarchy", "Failed to parse saved color preferences:", String(e));
        }
      } else if (pendingRememberPreferences) {
        hasSavedColorPreferences = true;
        savedUseWallpaperColors = pendingRememberWallpaper;
        savedPredefinedScheme = pendingRememberScheme;
        pendingRememberPreferences = false;
        persistColorPreferences(savedUseWallpaperColors, savedPredefinedScheme);
      }

      maybeAutoApply();
    }
  }

  Process {
    id: stateWriteProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("Omarchy", "Failed to persist color preferences, exit code:", code);
      }
    }
  }

  Process {
    id: stateClearProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("Omarchy", "Failed to clear saved color preferences, exit code:", code);
      }
    }
  }

  Process {
    id: themesProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      logDebug("themesProcess exited with code:", code);

      if (code !== 0) {
        Logger.e("Omarchy", "Theme scanning failed, exit code:", code);
        availableThemes = [];
        return;
      }

      const output = stdout.text || "";
      logDebug("Theme scan output length:", output.length);

      if (!output) {
        Logger.w("Omarchy", "Theme scan returned empty output");
        availableThemes = [];
        return;
      }

      const themeLines = output.trim().split("\n").filter(line => line && line.trim());
      const themes = [];
      for (var i = 0; i < themeLines.length; i++) {
        const line = themeLines[i];
        const parts = line.split("|");
        // New format: display_name|dir_name|mode
        const displayName = parts[0]?.trim();
        const dirName = parts[1]?.trim();
        const detectedMode = parts[2]?.trim();

        if (!displayName || !dirName)
          continue;

        const normalizedName = ThemeIdentity.normalizeThemeKey(dirName);
        const cachedScheme = SchemeCache.getScheme(normalizedName);
        const mode = cachedScheme?.mode || detectedMode || "dark";

        themes.push({
                      "name": displayName      // Display name for UI (e.g., "Catppuccin Latte")
                              ,
                      "dirName": dirName       // Directory name for operations (e.g., "catppuccin-latte")
                                 ,
                      "colors": [],
                      "mode": mode
                    });
      }

      Logger.i("Omarchy", "Found", themes.length, "themes");
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
        root.pendingReloadApplyThemeReady = true;
        root.maybeRunPendingReloadApply();
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
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-read"));
        return;
      }

      const content = stdout.text || "";
      logDebug("Read", content.length, "bytes from", omarchyConfigPath);

      const parsed = ThemeFiles.parseColorsToml(content);
      if (!parsed) {
        applying = false;
        Logger.e("Omarchy", "parseColorsToml returned null");
        ToastService.showError("Omarchy", pluginApi?.tr("errors.failed-read"));
        return;
      }

      Logger.i("Omarchy", "Successfully parsed theme colors, now reading Hyprland theme files");
      beginHyprlandThemeRead(parsed);
    }
  }

  Process {
    id: hyprlandReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      Logger.i("Omarchy", "hyprlandReadProcess exited with code:", code);

      const parsed = pendingAlacrittyColors;

      if (!parsed) {
        applying = false;
        pendingHyprlandThemePaths = [];
        pendingHyprlandThemePath = "";
        Logger.e("Omarchy", "No pending alacritty colors");
        return;
      }

      if (code === 0) {
        const content = stdout.text || "";
        const borderColor = ThemeFiles.parseHyprlandBorderColor(content);
        if (borderColor) {
          parsed.hyprlandBorder = borderColor;
          Logger.i("Omarchy", "Using Hyprland border color:", borderColor);
          finishSchemeGeneration(parsed);
          return;
        }
        logDebug("No Hyprland border color found in:", pendingHyprlandThemePath);
      } else {
        logDebug("Could not read Hyprland theme file:", pendingHyprlandThemePath, "exit code:", code);
      }

      readNextHyprlandThemeFile();
    }
  }

  Process {
    id: legacySchemeCleanupProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      if (code !== 0)
        return;
      if ((stdout.text || "").indexOf("removed") !== -1) {
        Logger.i("Omarchy", "Removed legacy omarchy colorscheme directory to prevent duplicates");
        if (ColorSchemeService.loadColorSchemes)
          ColorSchemeService.loadColorSchemes();
      }
    }
  }

  function cycleTheme() {
    const filteringMode = pluginApi?.pluginSettings?.themeFilteringMode || "random-only";
    const themes = filteringMode === "random-and-cycle" ? getFilteredThemes() : (root.availableThemes || []);
    if (themes.length === 0)
      return;

    let currentIndex = -1;
    const currentKey = ThemeIdentity.normalizeThemeKey(root.themeName);
    for (let i = 0; i < themes.length; i++) {
      const entry = themes[i];
      const entryKey = ThemeIdentity.themeEntryKey(entry);
      if (entryKey === currentKey) {
        currentIndex = i;
        break;
      }
    }

    const nextIndex = (currentIndex + 1) % themes.length;
    const nextTheme = themes[nextIndex];
    // Use dirName for operations, not display name
    const nextName = ThemeIdentity.themeEntryDirName(nextTheme);
    Logger.d("Omarchy", "cycleTheme: current:", root.themeName, "-> next:", nextName);
    root.setTheme(nextName);
  }

  function randomTheme() {
    const themes = getFilteredThemes();
    if (themes.length === 0)
      return;

    const currentKey = ThemeIdentity.normalizeThemeKey(root.themeName);
    const otherThemes = themes.filter(theme => {
      const themeKey = ThemeIdentity.themeEntryKey(theme);
      return themeKey !== currentKey;
    });

    if (otherThemes.length === 0)
      return;

    const randomIndex = Math.floor(Math.random() * otherThemes.length);
    const randomTheme = otherThemes[randomIndex];
    // Use dirName for operations, not display name
    const randomName = ThemeIdentity.themeEntryDirName(randomTheme);
    Logger.d("Omarchy", "randomTheme: selected theme dirName:", randomName);
    root.setTheme(randomName);
  }

  function ipcReload() {
    root.reloadPluginState();
  }

  function ipcToggle() {
    if (pluginApi?.pluginSettings?.active)
      root.deactivate();
    else
      root.activate();
  }

  function ipcSetTheme(themeName) {
    root.setTheme(themeName);
  }

  function ipcCycleTheme() {
    root.cycleTheme();
  }

  function ipcRandomTheme() {
    root.randomTheme();
  }

  IpcHandler {
    target: "omarchy"

    function reload() {
      root.ipcReload();
    }

    function toggle() {
      root.ipcToggle();
    }

    function setTheme(themeName: string) {
      root.ipcSetTheme(themeName);
    }

    function cycleTheme() {
      root.ipcCycleTheme();
    }

    function randomTheme() {
      root.ipcRandomTheme();
    }
  }

  IpcHandler {
    target: "plugin:omarchy"

    function reload() {
      root.ipcReload();
    }

    function toggle() {
      root.ipcToggle();
    }

    function setTheme(themeName: string) {
      root.ipcSetTheme(themeName);
    }

    function cycleTheme() {
      root.ipcCycleTheme();
    }

    function randomTheme() {
      root.ipcRandomTheme();
    }
  }

  Component.onCompleted: {
    loadSavedColorPreferences();
    refresh();
    cleanupLegacySchemeFolder();
    captureObservedSettings();
    maybeAutoApply();
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      if (root.ignoreNextPluginSettingsChanged) {
        root.ignoreNextPluginSettingsChanged = false;
        root.captureObservedSettings();
        return;
      }
      if (root.suppressSettingsSignal)
        return;

      const settings = pluginApi?.pluginSettings || ({});
      const nextActive = !!settings.active;
      const nextConfigDir = (settings.omarchyConfigDir || "").trim();
      const nextThemeSetCommand = (settings.themeSetCommand || "").trim();

      const activeChanged = nextActive !== root.observedActive;
      const configDirChanged = nextConfigDir !== root.observedConfigDir;
      const themeSetCommandChanged = nextThemeSetCommand !== root.observedThemeSetCommand;

      root.observedActive = nextActive;
      root.observedConfigDir = nextConfigDir;
      root.observedThemeSetCommand = nextThemeSetCommand;

      if (activeChanged) {
        if (nextActive) {
          rememberColorPreferences();
          root.scheduleReloadApply(true);
        } else {
          restoreColorPreferences();
        }
        return;
      }

      if (configDirChanged) {
        if (nextActive) {
          root.scheduleReloadApply(true);
        } else {
          root.refresh();
        }
        return;
      }

      if (themeSetCommandChanged) {
        return;
      }
    }
  }
}
