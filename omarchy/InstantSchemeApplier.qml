// qmllint disable signal-handler-parameters
import QtQuick
import Quickshell.Io
import "SchemeCache.js" as SchemeCache
import "ThemeIdentity.js" as ThemeIdentity
import qs.Commons
import qs.Services.Theming

// Instant color scheme application from cache and generated Omarchy palettes.
Item {
  id: root

  property string schemeDisplayName: "Omarchy"
  property var pluginApi: null
  readonly property string schemeKey: {
    const name = schemeDisplayName || "Omarchy";
    return name.replace(/[\\/]/g, "-").trim();
  }
  readonly property string schemeFolder: {
    const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
    const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
    return normalizedBase + "/" + schemeKey;
  }
  readonly property string schemeOutputPath: schemeFolder + "/" + schemeKey + ".json"
  readonly property string schemeOutputDir: schemeFolder

  property var cachedSchemes: ({})
  property var pendingApplyCallback: null

  function preloadCache() {
    const schemes = SchemeCache.getAllSchemes ? SchemeCache.getAllSchemes() : null;
    if (schemes) {
      cachedSchemes = schemes;
      Logger.i("InstantSchemeApplier", "Preloaded", Object.keys(schemes).length, "schemes");
    }
  }

  function colorSchemeSetting(key, fallback) {
    const colorSchemes = Settings.data.colorSchemes;
    if (!colorSchemes)
      return fallback;
    const value = colorSchemes[key];
    return (value === undefined || value === null) ? fallback : value;
  }

  function setColorSchemeSetting(key, value) {
    Settings.data.colorSchemes[key] = value;
  }

  function applyScheme(themeName) {
    const startTime = Date.now();
    if (!themeName)
      return {
        "success": false,
        "error": "No theme name",
        "duration": 0
      };

    const cacheKey = ThemeIdentity.normalizeThemeKey(themeName);
    var cached = cachedSchemes[cacheKey];
    if (!cached && SchemeCache.getScheme)
      cached = SchemeCache.getScheme(cacheKey);

    if (!cached || !cached.palette || !cached.mode) {
      Logger.w("InstantSchemeApplier", "Cache miss for theme:", themeName, "key:", cacheKey);
      return {
        "success": false,
        "error": "Cache miss",
        "duration": Date.now() - startTime,
        "cacheHit": false
      };
    }

    try {
      const started = writeAndApplyScheme(cached, null);
      if (!started)
        throw new Error("Invalid scheme data or output path");
      const duration = Date.now() - startTime;
      Logger.i("InstantSchemeApplier", "Applied scheme in", duration, "ms:", themeName);
      return {
        "success": true,
        "duration": duration,
        "cacheHit": true
      };
    } catch (e) {
      Logger.e("InstantSchemeApplier", "Failed to apply scheme:", String(e));
      return {
        "success": false,
        "error": String(e),
        "duration": Date.now() - startTime,
        "cacheHit": true
      };
    }
  }

  function updateNoctaliaDarkMode(mode) {
    const isDarkMode = mode === "dark";
    const schedulingMode = colorSchemeSetting("schedulingMode", "off");
    if (schedulingMode !== "off" || colorSchemeSetting("darkMode", false) === isDarkMode)
      return;

    Logger.i("InstantSchemeApplier", "Updating dark mode:", isDarkMode);
    const wasWallpaper = !!colorSchemeSetting("useWallpaperColors", false);
    setColorSchemeSetting("useWallpaperColors", true);
    setColorSchemeSetting("darkMode", isDarkMode);
    setColorSchemeSetting("useWallpaperColors", wasWallpaper);
  }

  function writeAndApplyScheme(result, callback) {
    const mode = result?.mode;
    const scheme = result?.palette;
    if (!scheme || !mode || !schemeOutputPath || !schemeOutputDir) {
      Logger.e("InstantSchemeApplier", "writeAndApplyScheme missing scheme data or output path");
      return false;
    }

    updateNoctaliaDarkMode(mode);

    const wrappedScheme = {
      "dark": scheme,
      "light": scheme
    };
    const jsonContent = JSON.stringify(wrappedScheme, null, 2);
    pendingApplyCallback = callback || null;
    writeSchemeFile(jsonContent);
    return true;
  }

  function finishPendingApply(success) {
    const callback = pendingApplyCallback;
    pendingApplyCallback = null;
    if (callback)
      Qt.callLater(function () {
        callback(success);
      });
  }

  function writeSchemeFile(jsonContent) {
    const writeCmd = "mkdir -p \"" + schemeOutputDir + "\" && cat > \"" + schemeOutputPath + "\" << 'OMARCHY_SCHEME_EOF'\n" + jsonContent + "\nOMARCHY_SCHEME_EOF\n";
    schemeWriteProcess.command = ["sh", "-c", writeCmd];
    schemeWriteProcess.running = true;
  }

  Component.onCompleted: {
    preloadCache();
  }

  Process {
    id: schemeWriteProcess

    running: false
    onExited: function (code) {
      if (code === 0) {
        Logger.i("InstantSchemeApplier", "Scheme file written:", schemeOutputPath);
        Settings.data.colorSchemes.predefinedScheme = schemeKey;
        Settings.data.colorSchemes.useWallpaperColors = false;
        ColorSchemeService.applyScheme(schemeOutputPath);
        finishPendingApply(true);
      } else {
        Logger.e("InstantSchemeApplier", "Failed to write scheme file, exit code:", code);
        finishPendingApply(false);
      }
    }
  }
}
