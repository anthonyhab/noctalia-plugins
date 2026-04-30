import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool editShowGrid: true
  property bool editSnapToWindows: true
  property bool editCopyToClipboard: true
  property bool editOpenAfterCapture: false
  property int editResetTimeoutMinutes: 5

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

  function settingValue(key, fallback) {
    const value = cfg[key];
    if (value !== undefined && value !== null)
      return value;

    const defaultValue = defaults[key];
    if (defaultValue !== undefined && defaultValue !== null)
      return defaultValue;

    return fallback;
  }

  function syncFromPlugin() {
    editShowGrid = settingValue("showGrid", true);
    editSnapToWindows = settingValue("snapToWindows", true);
    editCopyToClipboard = settingValue("copyToClipboard", true);
    editOpenAfterCapture = settingValue("openAfterCapture", false);
    editResetTimeoutMinutes = settingValue("resetTimeoutMinutes", 5);
  }

  function clampTimeout(value) {
    return Math.max(1, Math.min(30, value));
  }

  function saveSettings() {
    if (!pluginApi)
      return;
    const settings = pluginApi.pluginSettings || ({});
    settings.showGrid = editShowGrid;
    settings.snapToWindows = editSnapToWindows;
    settings.copyToClipboard = editCopyToClipboard;
    settings.openAfterCapture = editOpenAfterCapture;
    settings.resetTimeoutMinutes = clampTimeout(editResetTimeoutMinutes);

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin();
    }
  }

  NText {
    text: pluginApi?.tr("settings.title")
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.description")
    wrapMode: Text.WordWrap
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
  }

  NBox {
    Layout.fillWidth: true
    color: Color.mSurface
    radius: Style.radiusL

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NText {
        text: pluginApi?.tr("settings.visual.title")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NToggle {
        label: pluginApi?.tr("settings.show-grid.label")
        description: pluginApi?.tr("settings.show-grid.desc")
        checked: root.editShowGrid
        Layout.fillWidth: true
        onToggled: checked => {
                     root.editShowGrid = checked;
                     saveSettings();
                   }
      }

      NToggle {
        label: pluginApi?.tr("settings.snap-to-windows.label")
        description: pluginApi?.tr("settings.snap-to-windows.desc")
        checked: root.editSnapToWindows
        Layout.fillWidth: true
        onToggled: checked => {
                     root.editSnapToWindows = checked;
                     saveSettings();
                   }
      }

      NDivider {
        Layout.fillWidth: true
      }

      NText {
        text: pluginApi?.tr("settings.capture.title")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NToggle {
        label: pluginApi?.tr("settings.copy-to-clipboard.label")
        description: pluginApi?.tr("settings.copy-to-clipboard.desc")
        checked: root.editCopyToClipboard
        Layout.fillWidth: true
        onToggled: checked => {
                     root.editCopyToClipboard = checked;
                     saveSettings();
                   }
      }

      NToggle {
        label: pluginApi?.tr("settings.open-after-capture.label")
        description: pluginApi?.tr("settings.open-after-capture.desc")
        checked: root.editOpenAfterCapture
        Layout.fillWidth: true
        onToggled: checked => {
                     root.editOpenAfterCapture = checked;
                     saveSettings();
                   }
      }

      NDivider {
        Layout.fillWidth: true
      }

      NText {
        text: pluginApi?.tr("settings.reset-timeout.title")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NText {
        text: pluginApi?.tr("settings.reset-timeout.desc")
        wrapMode: Text.WordWrap
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
      }

      RowLayout {
        spacing: Style.marginM

        NComboBox {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.reset-timeout.combo-label")
          model: [
            {
              "key": "1",
              "name": "1"
            },
            {
              "key": "2",
              "name": "2"
            },
            {
              "key": "3",
              "name": "3"
            },
            {
              "key": "4",
              "name": "4"
            },
            {
              "key": "5",
              "name": "5"
            },
            {
              "key": "10",
              "name": "10"
            },
            {
              "key": "15",
              "name": "15"
            },
            {
              "key": "20",
              "name": "20"
            },
            {
              "key": "25",
              "name": "25"
            },
            {
              "key": "30",
              "name": "30"
            }
          ]
          currentKey: root.editResetTimeoutMinutes.toString()
          onSelected: key => {
                        root.editResetTimeoutMinutes = parseInt(key, 10);
                        saveSettings();
                      }
        }

        NButton {
          text: pluginApi?.tr("settings.reset-timeout.reset")
          onClicked: root.editResetTimeoutMinutes = root.settingValue("resetTimeoutMinutes", 5)
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      NText {
        text: pluginApi?.tr("settings.shortcuts.title")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NBox {
        Layout.fillWidth: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("settings.shortcuts.quick-capture")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: pluginApi?.tr("settings.shortcuts.open-selector")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: pluginApi?.tr("settings.shortcuts.capture-current")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: pluginApi?.tr("settings.shortcuts.cancel")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
