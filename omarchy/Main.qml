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

  visible: false

  property var pluginApi: null

  property bool available: false
  property bool applying: false
  property string themeName: ""
  property var availableThemes: []
  property bool suppressSettingsSignal: false

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string schemeDisplayName: pluginApi?.manifest?.metadata?.schemeName || "Omarchy"
  readonly property string schemeFolder: {
    const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
    const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
    const pluginId = pluginApi?.pluginId || "omarchy";
    return normalizedBase + "/" + pluginId;
  }
  readonly property string schemeOutputPath: schemeFolder + "/" + schemeDisplayName + ".json"
  readonly property string schemeOutputDir: schemeFolder
  readonly property string previousWallpaperKey: "_prevUseWallpaperColors"
  readonly property string previousSchemeKey: "_prevPredefinedScheme"

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

  readonly property string omarchyConfigPath: omarchyConfigDir + "current/theme/alacritty.toml"
  readonly property string omarchyThemePath: omarchyConfigDir + "current/theme"
  readonly property string omarchyThemesDir: omarchyConfigDir + "themes"

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

  function rememberColorPreferences() {
    if (!pluginApi)
      return false;
    var settings = pluginApi.pluginSettings || {};
    if (settings[previousWallpaperKey] !== undefined)
      return false;
    mutatePluginSettings(s => {
                           s[previousWallpaperKey] = Settings.data.colorSchemes.useWallpaperColors;
                           s[previousSchemeKey] = Settings.data.colorSchemes.predefinedScheme || "";
                         });
    return true;
  }

  function restoreColorPreferences() {
    if (!pluginApi)
      return false;
    var settings = pluginApi.pluginSettings || {};
    if (settings[previousWallpaperKey] === undefined)
      return false;
    var prevWallpaper = settings[previousWallpaperKey];
    var prevScheme = settings[previousSchemeKey] || "";
    mutatePluginSettings(s => {
                           delete s[previousWallpaperKey];
                           delete s[previousSchemeKey];
                         });

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

  function checkAvailability() {
    availabilityProcess.command = ["test", "-f", omarchyConfigPath];
    availabilityProcess.running = true;
  }

  function scanThemes() {
    const themesDirEsc = omarchyThemesDir.replace(/'/g, "'\\''");
    Logger.i("Omarchy", "Scanning themes in:", omarchyThemesDir);
    Logger.d("Omarchy", "Escaped path:", themesDirEsc);

    // Extract theme names and preview colors (background, green, yellow, red, blue)
    // Use -e instead of -f to properly handle symlinked theme directories
    const cmd = "cd '" + themesDirEsc
          + "' && for theme in */; do theme=${theme%/}; if [ -e \"$theme/alacritty.toml\" ]; then file=\"$theme/alacritty.toml\"; echo -n \"$theme:\"; grep -E '(background|green|yellow|red|blue)\\s*=' \"$file\" | sed \"s/.*['\\\"]\\(#\\|0x\\)\\([0-9a-fA-F]\\{6\\}\\).*/\\2/\" | sed 's/^/#/' | head -4 | tr '\\n' ',' | sed 's/,$//'; echo; fi; done";

    Logger.d("Omarchy", "Theme scan command:", cmd);
    themesProcess.command = ["bash", "-c", cmd];
    themesProcess.running = true;
  }

  function refreshThemeName() {
    const themePathEsc = omarchyThemePath.replace(/'/g, "'\\''");
    themeNameProcess.command = ["sh", "-c", "basename \"$(readlink -f '" + themePathEsc + "' 2>/dev/null)\" 2>/dev/null || true"];
    themeNameProcess.running = true;
  }

  function activate() {
    if (!pluginApi)
      return false;
    rememberColorPreferences();
    mutatePluginSettings(s => s.active = true);
    pluginApi.saveSettings();
    return applyCurrentTheme();
  }

  function deactivate() {
    if (!pluginApi)
      return;
    mutatePluginSettings(s => s.active = false);
    restoreColorPreferences();
    pluginApi.saveSettings();
  }

  function applyCurrentTheme() {
    if (!available) {
      ToastService.showError(pluginApi?.tr("title") || "Omarchy", pluginApi?.tr("errors.missing-config") || "Omarchy config not found");
      return false;
    }

    if (rememberColorPreferences()) {
      pluginApi.saveSettings();
    }
    Settings.data.colorSchemes.useWallpaperColors = false;

    applying = true;

    const cacheCompatible = SchemeCache.isCompatible(ThemePipeline.PIPELINE_VERSION);
    if (themeName && cacheCompatible) {
      const cached = SchemeCache.getScheme(themeName);
      if (cached?.palette && cached?.mode) {
        Logger.i("Omarchy", "Using cached scheme for:", themeName);
        const isDarkMode = cached.mode === "dark";
        if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
          Logger.i("Omarchy", "Auto-switching Noctalia dark mode to:", isDarkMode);
          Settings.data.colorSchemes.darkMode = isDarkMode;
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

    // Validate theme exists
    let themeExists = false;
    for (var i = 0; i < availableThemes.length; i++) {
      const theme = availableThemes[i];
      const name = typeof theme === 'string' ? theme : theme.name;
      if (name === nextThemeName) {
        themeExists = true;
        break;
      }
    }

    if (!themeExists) {
      ToastService.showError(pluginApi?.tr("title") || "Omarchy", `Theme not found: ${nextThemeName}`);
      return false;
    }

    themeSetProcess.command = [themeSetCommand, nextThemeName];
    themeSetProcess.running = true;
    return true;
  }

  function parseAlacrittyToml(content) {
    Logger.i("Omarchy", "Parsing Alacritty TOML, content length:", content.length);
    Logger.d("Omarchy", "First 500 chars:", content.slice(0, 500));

    function extractColorFromLine(line) {
      const colorMatch = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
      if (colorMatch) {
        const hex = colorMatch[1].toLowerCase();
        return "#" + hex.slice(-6);
      }
      return null;
    }

    const colors = {};
    const lines = content.split("\n");
    let currentSection = null;
    Logger.d("Omarchy", "Parsing", lines.length, "lines");

    for (var i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line)
        continue;
      if (line.startsWith("[colors.primary]")) {
        currentSection = "primary";
        Logger.d("Omarchy", "Entered [colors.primary] section");
        continue;
      } else if (line.startsWith("[colors.normal]")) {
        currentSection = "normal";
        Logger.d("Omarchy", "Entered [colors.normal] section");
        continue;
      } else if (line.startsWith("[colors.bright]")) {
        currentSection = "bright";
        Logger.d("Omarchy", "Entered [colors.bright] section");
        continue;
      } else if (line.startsWith("[colors.selection]")) {
        currentSection = "selection";
        Logger.d("Omarchy", "Entered [colors.selection] section");
        continue;
      } else if (line.startsWith("[")) {
        if (currentSection) {
          Logger.d("Omarchy", "Exited section", currentSection, "found colors:", Object.keys(colors).join(","));
        }
        currentSection = null;
        continue;
      }

      if (currentSection === "primary") {
        if (line.includes("background")) {
          const color = extractColorFromLine(line);
          if (color) {
            colors.background = color;
            Logger.d("Omarchy", "Found background:", color);
          } else {
            Logger.w("Omarchy", "Failed to extract background from:", line);
          }
        } else if (line.includes("foreground")) {
          const color = extractColorFromLine(line);
          if (color) {
            colors.foreground = color;
            Logger.d("Omarchy", "Found foreground:", color);
          } else {
            Logger.w("Omarchy", "Failed to extract foreground from:", line);
          }
        }
      } else if (currentSection === "normal") {
        const normalColors = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        for (const colorName of normalColors) {
          const nameMatch = line.match(new RegExp("^\\s*(" + colorName + ")\\s*="));
          if (nameMatch) {
            const color = extractColorFromLine(line);
            if (color) {
              colors[colorName] = color;
              Logger.d("Omarchy", "Found normal", colorName, ":", color);
            }
            break;
          }
        }
      } else if (currentSection === "bright") {
        const brightColors = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        for (const brightName of brightColors) {
          const nameMatch = line.match(new RegExp("^\\s*(" + brightName + ")\\s*="));
          if (nameMatch) {
            const color = extractColorFromLine(line);
            if (color) {
              const key = "bright" + brightName.charAt(0).toUpperCase() + brightName.slice(1);
              colors[key] = color;
              Logger.d("Omarchy", "Found bright", brightName, ":", color);
            }
            break;
          }
        }
      } else if (currentSection === "selection") {
        if (line.includes("background")) {
          const color = extractColorFromLine(line);
          if (color) {
            colors.selectionBackground = color;
            Logger.d("Omarchy", "Found selection background:", color);
          }
        }
      }
    }

    Logger.i("Omarchy", "Parsed colors:", Object.keys(colors).join(","));

    if (!colors.background) {
      Logger.e("Omarchy", "PARSE FAILED: No background color found");
      Logger.d("Omarchy", "First 500 chars of content:", content.slice(0, 500));
    }
    if (!colors.foreground) {
      Logger.e("Omarchy", "PARSE FAILED: No foreground color found");
      Logger.d("Omarchy", "First 500 chars of content:", content.slice(0, 500));
    }

    if (!colors.background || !colors.foreground)
      return null;
    return colors;
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
    Logger.d("Omarchy", "Writing scheme JSON, length:", jsonContent.length);
    const dirEsc = schemeOutputDir.replace(/'/g, "'\\''");
    const outPathEsc = schemeOutputPath.replace(/'/g, "'\\''");
    const writeCmd = "mkdir -p '" + dirEsc + "' && cat > '" + outPathEsc + "' << 'OMARCHY_SCHEME_EOF'\n" + jsonContent + "\nOMARCHY_SCHEME_EOF\n";
    Logger.d("Omarchy", "Scheme write command:", writeCmd);
    schemeWriteProcess.command = ["sh", "-c", writeCmd];
    schemeWriteProcess.running = true;
  }

  Process {
    id: availabilityProcess
    running: false
    onExited: function (code) {
      available = (code === 0);
    }
  }

  Process {
    id: themesProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      Logger.i("Omarchy", "themesProcess exited with code:", code);

      if (code !== 0) {
        Logger.e("Omarchy", "Theme scanning failed, exit code:", code);
        availableThemes = [];
        return;
      }

      const output = (stdout.text || "").trim();
      Logger.d("Omarchy", "Theme scan output length:", output.length);
      Logger.d("Omarchy", "Theme scan output:", output);

      if (!output) {
        Logger.w("Omarchy", "Theme scan returned empty output");
        availableThemes = [];
        return;
      }

      const themes = [];
      const lines = output.split("\n");
      Logger.d("Omarchy", "Processing", lines.length, "lines");

      for (var i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line)
          continue;
        Logger.d("Omarchy", "Processing line:", line);
        const parts = line.split(":");
        if (parts.length === 2) {
          const themeName = parts[0];
          const colorStr = parts[1];
          const colors = colorStr ? colorStr.split(",").filter(c => c.length === 7 && c.startsWith("#")).map(c => c.toLowerCase()).slice(0, 4) : [];
          Logger.d("Omarchy", "Theme:", themeName, "Colors:", colors.length, colors);
          themes.push({
                        "name": themeName,
                        "colors": colors
                      });
        } else {
          Logger.w("Omarchy", "Invalid line format (expected name:colors):", line);
        }
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
    }
  }

  Process {
    id: themeSetProcess
    running: false
    onExited: function (code) {
      if (code !== 0) {
        ToastService.showError(pluginApi?.tr("title") || "Omarchy", pluginApi?.tr("errors.failed-theme-set") || "Failed to switch theme");
        return;
      }
      refreshThemeName();
      if (pluginApi?.pluginSettings?.active)
        applyCurrentTheme();
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
        ToastService.showError(pluginApi?.tr("title") || "Omarchy", pluginApi?.tr("errors.failed-read") || "Failed to read theme colors");
        return;
      }

      const content = stdout.text || "";
      Logger.d("Omarchy", "Read", content.length, "bytes from", omarchyConfigPath);

      const parsed = parseAlacrittyToml(content);
      if (!parsed) {
        applying = false;
        Logger.e("Omarchy", "parseAlacrittyToml returned null");
        ToastService.showError(pluginApi?.tr("title") || "Omarchy", pluginApi?.tr("errors.failed-read") || "Failed to read theme colors");
        return;
      }

      Logger.i("Omarchy", "Successfully parsed theme colors");
      const schemeResult = ThemePipeline.generateScheme(parsed, ColorsConvert);
      Logger.d("Omarchy", "Detected mode:", schemeResult.mode);

      // Auto-sync dark mode setting
      const isDarkMode = schemeResult.mode === "dark";
      if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
        Logger.i("Omarchy", "Auto-switching Noctalia dark mode to:", isDarkMode);
        Settings.data.colorSchemes.darkMode = isDarkMode;
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
        ToastService.showError(pluginApi?.tr("title") || "Omarchy", pluginApi?.tr("errors.failed-apply") || "Failed to apply scheme");
        return;
      }

      Logger.i("Omarchy", "Scheme file written successfully to:", schemeOutputPath);
      // Trigger scheme application with a small delay
      applyDelayTimer.start();
    }
  }

  Timer {
    id: applyDelayTimer
    interval: 100
    repeat: false
    onTriggered: {
      Logger.d("Omarchy", "Applying color scheme after write delay");
      ColorSchemeService.loadColorSchemes();
      ColorSchemeService.applyScheme(schemeOutputPath);
      Settings.data.colorSchemes.useWallpaperColors = false;
      if (Settings.data.colorSchemes.predefinedScheme !== schemeDisplayName) {
        Settings.data.colorSchemes.predefinedScheme = schemeDisplayName;
      }
    }
  }

  IpcHandler {
    target: "omarchy"

    function reload() {
      root.refresh();
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
      const themes = root.availableThemes || [];
      if (themes.length === 0)
        return;

      let currentIndex = -1;
      for (let i = 0; i < themes.length; i++) {
        const entry = themes[i];
        const name = typeof entry === "string" ? entry : entry.name;
        if (name === root.themeName) {
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
      const randomIndex = Math.floor(Math.random() * themes.length);
      const randomTheme = themes[randomIndex];
      const randomName = typeof randomTheme === "string" ? randomTheme : randomTheme.name;
      root.setTheme(randomName);
    }
  }

  Component.onCompleted: {
    refresh();

    // Auto-apply theme if plugin is active on startup
    if (pluginApi?.pluginSettings?.active && available) {
      Logger.i("Omarchy", "Auto-applying theme on startup");
      Qt.callLater(applyCurrentTheme);
    }
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      if (root.suppressSettingsSignal)
        return;
      if (pluginApi?.pluginSettings?.active) {
        Qt.callLater(applyCurrentTheme);
      }
    }
  }
}
