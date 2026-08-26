import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  visible: false

  property var pluginApi: null

  // State properties
  property bool available: false
  property bool applying: false
  property var wallpaperList: []
  property int currentIndex: -1
  property string currentWallpaper: ""
  property var historyStack: []
  property string resolvedWallpapersDir: ""
  property bool resolvedDirReady: false
  property string lastWallpapersDirSetting: ""
  property bool rescanPending: false

  // Default settings from manifest
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Settings accessors with fallbacks
  readonly property string wallpapersDir: {
    const configured = pluginApi?.pluginSettings?.wallpapersDir;
    if (configured && typeof configured === "string" && configured.trim() !== "") {
      return expandHome(configured.trim());
    }
    return expandHome(defaultSettings.wallpapersDir || "~/Pictures/Wallpapers");
  }

  readonly property bool autoCycleEnabled: pluginApi?.pluginSettings?.autoCycleEnabled ?? defaultSettings.autoCycleEnabled ?? false

  readonly property int autoCycleInterval: ((pluginApi?.pluginSettings?.autoCycleInterval ?? defaultSettings.autoCycleInterval ?? 30) * 60000)

  readonly property string transitionType: pluginApi?.pluginSettings?.transitionType ?? defaultSettings.transitionType ?? "grow"

  readonly property real transitionDuration: pluginApi?.pluginSettings?.transitionDuration ?? defaultSettings.transitionDuration ?? 1

  readonly property int transitionFps: pluginApi?.pluginSettings?.transitionFps ?? defaultSettings.transitionFps ?? 60

  readonly property int transitionStep: pluginApi?.pluginSettings?.transitionStep ?? defaultSettings.transitionStep ?? 90

  readonly property string transitionBezier: pluginApi?.pluginSettings?.transitionBezier ?? defaultSettings.transitionBezier ?? ".4,0,.2,1"

  readonly property bool shuffleMode: pluginApi?.pluginSettings?.shuffleMode ?? defaultSettings.shuffleMode ?? false

  readonly property bool showWallpaperName: pluginApi?.pluginSettings?.showWallpaperName !== false

  readonly property int gridColumns: pluginApi?.pluginSettings?.gridColumns ?? defaultSettings.gridColumns ?? 2

  // Helper: expand ~ to $HOME
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

  // Helper to mutate settings
  function mutatePluginSettings(mutator) {
    if (!pluginApi)
      return null;
    var settings = pluginApi.pluginSettings || {};
    mutator(settings);
    pluginApi.pluginSettings = settings;
    return settings;
  }

  // Check if awww daemon is running
  function checkAvailability() {
    availabilityProcess.command = ["awww", "query"];
    availabilityProcess.running = true;
  }

  // Scan wallpapers directory
  function scanWallpapers() {
    if (!wallpapersDir) {
      wallpaperList = [];
      return;
    }

    if (scanProcess.running) {
      rescanPending = true;
      return;
    }

    const dirEsc = wallpapersDir.replace(/'/g, "'\\''");
    const cmd = "find '" + dirEsc + "' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort";

    scanProcess.command = ["bash", "-c", cmd];
    scanProcess.running = true;
  }

  // Helper to get transition type (handles random exclusion of 'none')
  function getEffectiveTransition() {
    const types = ["simple", "fade", "grow", "center", "outer", "wipe", "wave", "left", "right", "top", "bottom"];

    let selected;
    if (transitionType === "random") {
      selected = types[Math.floor(Math.random() * types.length)];
    } else {
      selected = transitionType;
    }

    // Ensure we never return "none" or invalid values
    return types.includes(selected) ? selected : "grow";
  }

  // Set wallpaper with awww
  function setWallpaper(imagePath) {
    if (!imagePath || !available) {
      Logger.w("SwwwPicker", "Cannot set wallpaper: imagePath=" + imagePath + " available=" + available);
      return false;
    }

    // Verify file exists before trying to set it
    fileCheckProcess.command = ["test", "-f", imagePath];
    fileCheckProcess.running = true;

    // Store the path for use after file check completes
    fileCheckProcess.targetPath = imagePath;

    return true;
  }

  // Internal: actually apply wallpaper after file check
  function applyWallpaperInternal(imagePath) {
    applying = true;

    // Push current to history before changing
    if (currentWallpaper && currentWallpaper !== imagePath) {
      historyStack.push(currentWallpaper);
      if (historyStack.length > 50)
        historyStack.shift();
    }

    awwwProcess.command = ["awww", "img", imagePath, "--transition-type", getEffectiveTransition(), "--transition-duration", transitionDuration.toString(), "--transition-fps", transitionFps.toString(), "--transition-step", transitionStep.toString(), "--transition-bezier", transitionBezier || ".4,0,.2,1"];
    awwwProcess.running = true;

    currentWallpaper = imagePath;
    currentIndex = wallpaperList.indexOf(imagePath);

    // Save current wallpaper to settings
    mutatePluginSettings(s => s.lastWallpaper = imagePath);
    pluginApi.saveSettings();
  }

  // Navigation: next wallpaper
  function next() {
    if (wallpaperList.length === 0)
      return;

    if (shuffleMode) {
      random();
      return;
    }

    const nextIndex = (currentIndex + 1) % wallpaperList.length;
    setWallpaper(wallpaperList[nextIndex]);
  }

  // Navigation: previous wallpaper (from history or sequential)
  function previous() {
    if (historyStack.length > 0) {
      const prev = historyStack.pop();
      // Use setWallpaper to ensure file existence check
      setWallpaper(prev);
      return;
    }

    // Fall back to sequential previous
    if (wallpaperList.length === 0)
      return;
    const prevIndex = currentIndex <= 0 ? wallpaperList.length - 1 : currentIndex - 1;
    setWallpaper(wallpaperList[prevIndex]);
  }

  // Navigation: random wallpaper
  function random() {
    if (wallpaperList.length === 0)
      return;

    let randomIndex;
    do {
      randomIndex = Math.floor(Math.random() * wallpaperList.length);
    } while (randomIndex === currentIndex && wallpaperList.length > 1)

    setWallpaper(wallpaperList[randomIndex]);
  }

  // Refresh: re-check availability and rescan wallpapers
  function refresh() {
    checkAvailability();
    if (resolvedDirReady) {
      scanWallpapers();
    } else {
      checkResolvedWallpapersDir();
    }
  }

  function checkResolvedWallpapersDir() {
    if (!wallpapersDir)
      return;
    if (resolveDirProcess.running)
      return;
    const dirEsc = wallpapersDir.replace(/'/g, "'\\''");
    resolveDirProcess.command = ["bash", "-c", "readlink -f '" + dirEsc + "' 2>/dev/null || true"];
    resolveDirProcess.running = true;
  }

  // Toggle auto-cycle
  function toggleAutoCycle() {
    mutatePluginSettings(s => s.autoCycleEnabled = !autoCycleEnabled);
    pluginApi.saveSettings();
  }

  // Toggle shuffle mode
  function toggleShuffleMode() {
    mutatePluginSettings(s => s.shuffleMode = !shuffleMode);
    pluginApi.saveSettings();
  }

  // Toggle grid columns
  function toggleGridColumns() {
    mutatePluginSettings(s => {
      let current = s.gridColumns ?? 2;
      s.gridColumns = (current % 3) + 1;
    });
    pluginApi.saveSettings();
  }

  // Auto-cycle timer
  Timer {
    id: autoCycleTimer
    interval: root.autoCycleInterval
    repeat: true
    running: root.autoCycleEnabled && root.available && root.wallpaperList.length > 1
    onTriggered: root.next()
  }

  // Theme watcher (re-check the resolved wallpaper directory in case a symlink target changes)
  Timer {
    id: themeWatchTimer
    interval: 5000
    repeat: true
    running: !!wallpapersDir
    onTriggered: checkResolvedWallpapersDir()
  }

  // NOTE: themeApplyTimer removed - theme-bg-next applies wallpaper directly now
  // Plugin only needs to track state for UI updates

  // Process: Check awww availability
  Process {
    id: availabilityProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      available = (code === 0);
      if (!available) {
        Logger.w("SwwwPicker", "awww daemon not running. Start with: awww-daemon");
      } else {
        Logger.i("SwwwPicker", "awww daemon available");
      }
    }
  }

  // Process: Scan wallpapers directory
  Process {
    id: scanProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      if (code !== 0) {
        Logger.e("SwwwPicker", "Failed to scan wallpapers directory");
        wallpaperList = [];
        if (rescanPending) {
          rescanPending = false;
          Qt.callLater(scanWallpapers);
        }
        return;
      }

      const output = (stdout.text || "").trim();
      if (!output) {
        Logger.w("SwwwPicker", "No wallpapers found in " + wallpapersDir);
        wallpaperList = [];
        if (rescanPending) {
          rescanPending = false;
          Qt.callLater(scanWallpapers);
        }
        return;
      }

      // Filter wallpaper list to only include files that actually exist
      const allPaths = output.split("\n").filter(p => p.length > 0);
      const existingPaths = allPaths.filter(path => {
        // Quick check - we'll do proper verification when setting wallpaper
        return path.startsWith("/") && path.length > 0;
      });

      if (existingPaths.length !== allPaths.length) {
        Logger.w("SwwwPicker", "Filtered out " + (allPaths.length - existingPaths.length) + " non-existent files");
      }

      wallpaperList = existingPaths;
      Logger.i("SwwwPicker", "Found " + wallpaperList.length + " wallpapers");

      // Restore last wallpaper or set current index
      const last = pluginApi?.pluginSettings?.lastWallpaper;
      if (last && wallpaperList.includes(last)) {
        currentWallpaper = last;
        currentIndex = wallpaperList.indexOf(last);
      } else if (wallpaperList.length > 0) {
        currentIndex = 0;
        const firstWallpaper = wallpaperList[0];
        currentWallpaper = firstWallpaper;
        // Theme changed - wallpaper was applied by theme-bg-next
        // Just update our internal state, no delay needed
        Logger.i("SwwwPicker", "Theme change detected, updated state: " + firstWallpaper);
      }

      if (rescanPending) {
        rescanPending = false;
        Qt.callLater(scanWallpapers);
      }
    }
  }

  // Process: Resolve wallpapers directory target for theme changes
  Process {
    id: resolveDirProcess
    running: false
    stdout: StdioCollector {}
    onExited: function (code) {
      if (code !== 0)
        return;
      const resolved = (stdout.text || "").trim();
      if (!resolved)
        return;
      if (!resolvedDirReady) {
        resolvedDirReady = true;
        resolvedWallpapersDir = resolved;
        scanWallpapers();
        return;
      }
      if (resolvedWallpapersDir !== resolved) {
        resolvedWallpapersDir = resolved;
        scanWallpapers();
      }
    }
  }

  // Process: Check if file exists before setting wallpaper
  Process {
    id: fileCheckProcess
    property string targetPath: ""
    running: false
    onExited: function (code) {
      if (code === 0) {
        // File exists, proceed with setting wallpaper
        applyWallpaperInternal(targetPath);
      } else {
        Logger.w("SwwwPicker", "Wallpaper file does not exist: " + targetPath);
        applying = false;
      }
    }
  }

  // Process: Set wallpaper with awww
  Process {
    id: awwwProcess
    running: false
    onExited: function (code) {
      applying = false;
      if (code !== 0) {
        Logger.e("SwwwPicker", "Failed to set wallpaper, exit code: " + code);
        ToastService.showError("Awww Picker", pluginApi?.tr("errors.failed-set"));
      }
    }
  }

  IpcHandler {
    target: "plugin:swww-picker"

    function refresh() {
      Logger.i("SwwwPicker", "IPC refresh triggered (async)");
      // Wallpaper was already applied by theme-bg-next
      // Just refresh state asynchronously for UI updates
      Qt.callLater(() => {
        root.refresh();
      });
    }

    function togglePanel() {
      if (!pluginApi)
        return;
      pluginApi.withCurrentScreen(screen => {
        if (pluginApi.panelOpenScreen) {
          pluginApi.closePanel(pluginApi.panelOpenScreen);
          return;
        }

        // No sourceItem provided => opens centered on the target screen.
        pluginApi.openPanel(screen);
      });
    }
  }

  Component.onCompleted: {
    refresh();
    checkResolvedWallpapersDir();
    lastWallpapersDirSetting = wallpapersDir;

    // Restore last wallpaper after a brief delay to ensure daemon is ready
    Qt.callLater(() => {
      const last = pluginApi?.pluginSettings?.lastWallpaper;
      if (last && available) {
        Logger.i("SwwwPicker", "Restoring last wallpaper: " + last);
        setWallpaper(last);
      }
    });
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      const newDir = wallpapersDir;
      if (lastWallpapersDirSetting !== newDir) {
        lastWallpapersDirSetting = newDir;
        resolvedDirReady = false;
        resolvedWallpapersDir = "";
        checkResolvedWallpapersDir();
      }
    }
  }
}
