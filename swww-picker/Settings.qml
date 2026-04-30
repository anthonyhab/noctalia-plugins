import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  FontMetrics {
    id: appFontMetrics
    font: Qt.application.font
  }

  readonly property int basePreferredWidth: Math.round(520 * Style.uiScaleRatio)
  readonly property int fontSafePreferredWidth: Math.round(appFontMetrics.averageCharacterWidth * 56 + Style.marginL * 2)

  spacing: Style.marginL
  Layout.minimumWidth: Math.round(360 * Style.uiScaleRatio)
  Layout.preferredWidth: Math.max(basePreferredWidth, fontSafePreferredWidth)
  Layout.maximumWidth: Layout.preferredWidth

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var pluginMain: pluginApi?.mainInstance

  // Local state
  property string wallpapersDir: ""
  property bool autoCycleEnabled: false
  property string autoCycleInterval: "30"
  property string transitionType: "fade"
  property string transitionDuration: "0.8"
  property string transitionFps: "80"
  property string transitionStep: "28"
  property string transitionBezier: ".4,0,.2,1"
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
    transitionType = getSetting("transitionType", "fade") || "fade";
    transitionDuration = (getSetting("transitionDuration", 0.8) || 0.8).toString();
    transitionFps = (getSetting("transitionFps", 80) || 80).toString();
    transitionStep = (getSetting("transitionStep", 28) || 28).toString();
    transitionBezier = getSetting("transitionBezier", ".4,0,.2,1") || ".4,0,.2,1";
    shuffleMode = !!getSetting("shuffleMode", false);
    showWallpaperName = getSetting("showWallpaperName", true) !== false;
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin();
    }
  }

  function saveSettings() {
    if (!pluginApi)
      return;

    var settings = pluginApi.pluginSettings || {};

    settings.wallpapersDir = wallpapersDir.trim();
    settings.autoCycleEnabled = autoCycleEnabled;
    settings.autoCycleInterval = parseInt(autoCycleInterval, 10) || 30;
    settings.transitionType = transitionType;
    settings.transitionDuration = parseFloat(transitionDuration) || 0.8;
    settings.transitionFps = parseInt(transitionFps, 10) || 80;
    settings.transitionStep = parseInt(transitionStep, 10) || 28;
    settings.transitionBezier = transitionBezier.trim() || ".4,0,.2,1";
    settings.shuffleMode = shuffleMode;
    settings.showWallpaperName = showWallpaperName;

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();

    // Trigger rescan
    pluginMain?.refresh();
  }

  // Header
  NText {
    text: pluginApi?.tr("settings.description")
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  // Directory settings
  NTextInput {
    label: pluginApi?.tr("settings.wallpapers-dir")
    description: pluginApi?.tr("settings.wallpapers-dir-desc")
    placeholderText: "~/Pictures/Wallpapers"
    text: root.wallpapersDir
    onTextChanged: root.wallpapersDir = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Auto-cycle section
  NText {
    text: pluginApi?.tr("settings.auto-cycle.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.auto-cycle.enabled")
    description: pluginApi?.tr("settings.auto-cycle.enabled-desc")
    checked: root.autoCycleEnabled
    onToggled: checked => root.autoCycleEnabled = checked
  }

  NTextInput {
    label: pluginApi?.tr("settings.auto-cycle.interval")
    description: pluginApi?.tr("settings.auto-cycle.interval-desc")
    placeholderText: "30"
    text: root.autoCycleInterval
    enabled: root.autoCycleEnabled
    inputItem.inputMethodHints: Qt.ImhDigitsOnly
    onTextChanged: root.autoCycleInterval = text
  }

  NToggle {
    label: pluginApi?.tr("settings.shuffle-mode")
    description: pluginApi?.tr("settings.shuffle-desc")
    checked: root.shuffleMode
    onToggled: checked => root.shuffleMode = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Transition settings
  NText {
    text: pluginApi?.tr("settings.transitions.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.transitions.type")
    model: [
      {
        "key": "simple",
        "name": "Simple fade"
      },
      {
        "key": "fade",
        "name": "Bezier fade"
      },
      {
        "key": "grow",
        "name": "Grow (circle)"
      },
      {
        "key": "center",
        "name": "Center grow"
      },
      {
        "key": "outer",
        "name": "Outer shrink"
      },
      {
        "key": "wipe",
        "name": "Wipe"
      },
      {
        "key": "wave",
        "name": "Wave"
      },
      {
        "key": "left",
        "name": "Slide left"
      },
      {
        "key": "right",
        "name": "Slide right"
      },
      {
        "key": "top",
        "name": "Slide top"
      },
      {
        "key": "bottom",
        "name": "Slide bottom"
      },
      {
        "key": "random",
        "name": "Random"
      }
    ]
    currentKey: root.transitionType
    onSelected: key => root.transitionType = key
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.duration")
      placeholderText: "1"
      text: root.transitionDuration
      inputItem.inputMethodHints: Qt.ImhFormattedNumbersOnly
      onTextChanged: root.transitionDuration = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.fps")
      placeholderText: "60"
      text: root.transitionFps
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: root.transitionFps = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.transitions.step")
      placeholderText: "90"
      text: root.transitionStep
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: root.transitionStep = text
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Bezier curve settings
  NText {
    text: pluginApi?.tr("settings.bezier.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.bezier.description")
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  // Preset buttons row
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: pluginApi?.tr("settings.bezier.snappy")
      highlighted: transitionBezier === ".4,0,.2,1"
      onClicked: transitionBezier = ".4,0,.2,1"
    }

    NButton {
      text: pluginApi?.tr("settings.bezier.natural")
      highlighted: transitionBezier === ".17,.67,.83,.67"
      onClicked: transitionBezier = ".17,.67,.83,.67"
    }

    NButton {
      text: pluginApi?.tr("settings.bezier.linear")
      highlighted: transitionBezier === "0,0,1,1"
      onClicked: transitionBezier = "0,0,1,1"
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.transitions.bezier")
    description: pluginApi?.tr("settings.transitions.bezier-desc")
    placeholderText: ".4,0,.2,1"
    text: root.transitionBezier
    onTextChanged: root.transitionBezier = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Bar widget settings
  NText {
    text: pluginApi?.tr("settings.bar-widget.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.show-name")
    description: pluginApi?.tr("settings.show-name-desc")
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
      text: pluginApi?.tr("settings.status.title")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: {
        const available = pluginMain?.available || false;
        const count = pluginMain?.wallpaperList?.length || 0;
        const status = available ? (pluginApi?.tr("status.daemon-running")) : (pluginApi?.tr("status.daemon-stopped"));
        return status + " | " + count + " " + (pluginApi?.tr("status.wallpapers"));
      }
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    NButton {
      text: pluginApi?.tr("actions.refresh")
      onClicked: pluginMain?.refresh()
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
