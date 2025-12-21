import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var pluginMain: pluginApi?.mainInstance

  // Local state
  property string wallpapersDir: ""
  property bool autoCycleEnabled: false
  property string autoCycleInterval: "30"
  property string transitionType: "grow"
  property string transitionDuration: "1"
  property string transitionFps: "60"
  property string transitionStep: "90"
  property bool shuffleMode: false
  property bool showWallpaperName: true

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined) {
      return pluginApi.pluginSettings[key];
    }
    if (defaultSettings && defaultSettings[key] !== undefined) {
      return defaultSettings[key];
    }
    return fallback;
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return;
    wallpapersDir = getSetting("wallpapersDir", "~/Pictures/Wallpapers") || "";
    autoCycleEnabled = !!getSetting("autoCycleEnabled", false);
    autoCycleInterval = (getSetting("autoCycleInterval", 30) || 30).toString();
    transitionType = getSetting("transitionType", "grow") || "grow";
    transitionDuration = (getSetting("transitionDuration", 1) || 1).toString();
    transitionFps = (getSetting("transitionFps", 60) || 60).toString();
    transitionStep = (getSetting("transitionStep", 90) || 90).toString();
    shuffleMode = !!getSetting("shuffleMode", false);
    showWallpaperName = getSetting("showWallpaperName", true) !== false;
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  function saveSettings() {
    if (!pluginApi)
      return;

    var settings = pluginApi.pluginSettings || {};

    settings.wallpapersDir = wallpapersDir.trim();
    settings.autoCycleEnabled = autoCycleEnabled;
    settings.autoCycleInterval = parseInt(autoCycleInterval, 10) || 30;
    settings.transitionType = transitionType;
    settings.transitionDuration = parseFloat(transitionDuration) || 1;
    settings.transitionFps = parseInt(transitionFps, 10) || 60;
    settings.transitionStep = parseInt(transitionStep, 10) || 90;
    settings.shuffleMode = shuffleMode;
    settings.showWallpaperName = showWallpaperName;

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();

    // Trigger rescan
    pluginMain?.refresh();
  }

  // Header
  NText {
    text: pluginApi?.tr("settings.description") || "Configure wallpaper cycling with swww."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  // Directory settings
  NTextInput {
    label: pluginApi?.tr("settings.wallpapers-dir") || "Wallpapers directory"
    description: pluginApi?.tr("settings.wallpapers-dir-desc") || "Path to the directory containing your wallpaper images."
    placeholderText: "~/Pictures/Wallpapers"
    text: root.wallpapersDir
    onTextChanged: root.wallpapersDir = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Auto-cycle section
  NText {
    text: pluginApi?.tr("settings.auto-cycle.title") || "Auto-cycle"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.auto-cycle.enabled") || "Enable auto-cycling"
    description: pluginApi?.tr("settings.auto-cycle.enabled-desc") || "Automatically change wallpaper at regular intervals."
    checked: root.autoCycleEnabled
    onToggled: checked => root.autoCycleEnabled = checked
  }

  NTextInput {
    label: pluginApi?.tr("settings.auto-cycle.interval") || "Interval (minutes)"
    description: pluginApi?.tr("settings.auto-cycle.interval-desc") || "How often to change the wallpaper when auto-cycling is enabled."
    placeholderText: "30"
    text: root.autoCycleInterval
    enabled: root.autoCycleEnabled
    inputItem.inputMethodHints: Qt.ImhDigitsOnly
    onTextChanged: root.autoCycleInterval = text
  }

  NToggle {
    label: pluginApi?.tr("settings.shuffle-mode") || "Shuffle mode"
    description: pluginApi?.tr("settings.shuffle-desc") || "Pick random wallpapers instead of sequential order."
    checked: root.shuffleMode
    onToggled: checked => root.shuffleMode = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Transition settings
  NText {
    text: pluginApi?.tr("settings.transitions.title") || "Transitions"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.transitions.type") || "Transition type"
    model: [
      { "key": "simple", "name": "Simple fade" },
      { "key": "fade", "name": "Bezier fade" },
      { "key": "grow", "name": "Grow (circle)" },
      { "key": "center", "name": "Center grow" },
      { "key": "outer", "name": "Outer shrink" },
      { "key": "wipe", "name": "Wipe" },
      { "key": "wave", "name": "Wave" },
      { "key": "left", "name": "Slide left" },
      { "key": "right", "name": "Slide right" },
      { "key": "top", "name": "Slide top" },
      { "key": "bottom", "name": "Slide bottom" },
      { "key": "random", "name": "Random" },
      { "key": "none", "name": "None (instant)" }
    ]
    currentKey: root.transitionType
    onSelected: key => root.transitionType = key
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.duration") || "Duration (seconds)"
      placeholderText: "1"
      text: root.transitionDuration
      inputItem.inputMethodHints: Qt.ImhFormattedNumbersOnly
      onTextChanged: root.transitionDuration = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.fps") || "FPS"
      placeholderText: "60"
      text: root.transitionFps
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: root.transitionFps = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.step") || "Step"
      placeholderText: "90"
      text: root.transitionStep
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: root.transitionStep = text
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Bar widget settings
  NText {
    text: pluginApi?.tr("settings.bar-widget.title") || "Bar widget"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.show-name") || "Show wallpaper name"
    description: pluginApi?.tr("settings.show-name-desc") || "Display the current wallpaper filename in the bar."
    checked: root.showWallpaperName
    onToggled: checked => root.showWallpaperName = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Status section
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.status.title") || "Status"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: {
        const available = pluginMain?.available || false;
        const count = pluginMain?.wallpaperList?.length || 0;
        const status = available
          ? (pluginApi?.tr("status.daemon-running") || "swww daemon running")
          : (pluginApi?.tr("status.daemon-stopped") || "swww daemon not running");
        return status + " | " + count + " " + (pluginApi?.tr("status.wallpapers") || "wallpapers");
      }
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    NButton {
      text: pluginApi?.tr("actions.refresh") || "Refresh"
      onClicked: pluginMain?.refresh()
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
