import QtQuick
import QtQuick.Layouts
import Quickshell
import "PluginUi.js" as PluginUi
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real iconPointSize: Style.toOdd(capsuleHeight * 0.45)

  readonly property bool showVoxtype: pluginApi?.pluginSettings?.showVoxtype !== false
  readonly property bool showScreenRecording: pluginApi?.pluginSettings?.showScreenRecording !== false
  readonly property bool showIdleDisabled: pluginApi?.pluginSettings?.showIdleDisabled !== false
  readonly property bool showUpdateAvailable: pluginApi?.pluginSettings?.showUpdateAvailable !== false

  readonly property bool omarchyAvailable: mainInstance?.omarchyAvailable === true
  readonly property string voxtypeState: mainInstance?.voxtypeState || "idle"
  readonly property bool screenRecordingActive: mainInstance?.screenRecordingActive === true
  readonly property bool idleDisabledActive: mainInstance?.idleDisabledActive === true
  readonly property bool updateAvailable: mainInstance?.updateAvailable === true

  readonly property bool showVoxtypeRecording: omarchyAvailable && showVoxtype && voxtypeState === "recording"
  readonly property bool showVoxtypeTranscribing: omarchyAvailable && showVoxtype && voxtypeState === "transcribing"
  readonly property bool showScreenRecordingIndicator: omarchyAvailable && showScreenRecording && screenRecordingActive
  readonly property bool showIdleDisabledIndicator: omarchyAvailable && showIdleDisabled && idleDisabledActive
  readonly property bool showUpdateIndicator: omarchyAvailable && showUpdateAvailable && updateAvailable

  readonly property var indicatorModel: [
    {
      "visible": showVoxtypeRecording,
      "iconName": "voxtype-recording",
      "tooltip": tr("tooltips.voxtype-recording", "Voxtype recording"),
      "fgColor": iconColor("voxtype-recording"),
      "leftAction": "openVoxtypeModel",
      "rightAction": "openVoxtypeConfig",
      "hasRightAction": true
    },
    {
      "visible": showVoxtypeTranscribing,
      "iconName": "voxtype-transcribing",
      "tooltip": tr("tooltips.voxtype-transcribing", "Voxtype transcribing"),
      "fgColor": iconColor("voxtype-transcribing"),
      "leftAction": "openVoxtypeModel",
      "rightAction": "openVoxtypeConfig",
      "hasRightAction": true
    },
    {
      "visible": showScreenRecordingIndicator,
      "iconName": "screen-recording",
      "tooltip": tr("tooltips.screen-recording", "Screen recording active"),
      "fgColor": iconColor("screen-recording"),
      "leftAction": "toggleScreenRecording",
      "rightAction": "",
      "hasRightAction": false
    },
    {
      "visible": showIdleDisabledIndicator,
      "iconName": "idle-disabled",
      "tooltip": tr("tooltips.idle-disabled", "Idle lock disabled"),
      "fgColor": iconColor("idle-disabled"),
      "leftAction": "toggleIdle",
      "rightAction": "",
      "hasRightAction": false
    },
    {
      "visible": showUpdateIndicator,
      "iconName": "update-available",
      "tooltip": tr("tooltips.update-available", "Omarchy update available"),
      "fgColor": iconColor("update-available"),
      "leftAction": "runOmarchyUpdate",
      "rightAction": "",
      "hasRightAction": false
    }
  ].filter(item => item.visible)

  readonly property int activeCount: indicatorModel.length
  readonly property bool hasActiveIndicators: activeCount > 0

  readonly property real contentMainSize: hasActiveIndicators ? capsuleHeight * activeCount : 0

  implicitWidth: hasActiveIndicators ? (isBarVertical ? capsuleHeight : contentMainSize) : 0
  implicitHeight: hasActiveIndicators ? (isBarVertical ? contentMainSize : capsuleHeight) : 0

  function tr(key, fallback) {
    return PluginUi.tr(pluginApi, key, fallback);
  }

  function combinedTooltip() {
    return indicatorModel.map(item => item.tooltip).filter(text => text !== "").join("\n");
  }

  function iconColor(kind) {
    if (kind === "update-available")
      return Color.mPrimary;
    if (kind === "voxtype-transcribing")
      return Color.mPrimary;
    return Color.mError;
  }

  function runIndicatorAction(action) {
    if (action === "openVoxtypeModel") {
      mainInstance?.openVoxtypeModel();
    } else if (action === "openVoxtypeConfig") {
      mainInstance?.openVoxtypeConfig();
    } else if (action === "toggleScreenRecording") {
      mainInstance?.toggleScreenRecording();
    } else if (action === "toggleIdle") {
      mainInstance?.toggleIdle();
    } else if (action === "runOmarchyUpdate") {
      mainInstance?.runOmarchyUpdate();
    }
  }

  function openPluginSettings() {
    if (!pluginApi || !screen)
      return;
    BarService.openPluginSettings(screen, pluginApi.manifest);
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": tr("menu.refresh", "Refresh indicators"),
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": tr("menu.settings", "Open plugin settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "refresh") {
        mainInstance?.refresh();
      } else if (action === "settings") {
        openPluginSettings();
      }
    }
  }

  Rectangle {
    id: capsule

    visible: hasActiveIndicators
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: isBarVertical ? capsuleHeight : contentMainSize
    height: isBarVertical ? contentMainSize : capsuleHeight
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    ColumnLayout {
      anchors.fill: parent
      spacing: 0
      visible: isBarVertical

      Repeater {
        model: indicatorModel
        delegate: IndicatorIcon {
          required property var modelData

          iconName: modelData.iconName
          fgColor: modelData.fgColor
          tooltip: modelData.tooltip
          hasRightAction: modelData.hasRightAction
          onLeftClicked: root.runIndicatorAction(modelData.leftAction)
          onRightClicked: root.runIndicatorAction(modelData.rightAction)
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      spacing: 0
      visible: !isBarVertical

      Repeater {
        model: indicatorModel
        delegate: IndicatorIcon {
          required property var modelData

          iconName: modelData.iconName
          fgColor: modelData.fgColor
          tooltip: modelData.tooltip
          hasRightAction: modelData.hasRightAction
          onLeftClicked: root.runIndicatorAction(modelData.leftAction)
          onRightClicked: root.runIndicatorAction(modelData.rightAction)
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: hasActiveIndicators
    hoverEnabled: true
    acceptedButtons: Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      const text = combinedTooltip();
      if (text !== "")
        TooltipService.show(root, text, BarService.getTooltipDirection(screen?.name));
    }

    onExited: TooltipService.hide()

    onClicked: mouse => {
      TooltipService.hide();
      if (mouse.button === Qt.RightButton)
        PanelService.showContextMenu(contextMenu, capsule, screen);
    }
  }

  component IndicatorIcon: Item {
    id: indicator

    required property string iconName
    required property color fgColor
    required property string tooltip
    property bool hasRightAction: false
    signal leftClicked
    signal rightClicked

    implicitWidth: capsuleHeight
    implicitHeight: capsuleHeight
    Layout.preferredWidth: visible ? implicitWidth : 0
    Layout.preferredHeight: visible ? implicitHeight : 0
    Layout.alignment: Qt.AlignCenter

    NNerdIcon {
      anchors.fill: parent
      icon: indicator.iconName
      color: indicator.fgColor
      pointSize: iconPointSize
      applyUiScale: false
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        if (indicator.tooltip !== "")
          TooltipService.show(indicator, indicator.tooltip, BarService.getTooltipDirection(screen?.name));
      }

      onExited: TooltipService.hide()

      onClicked: mouse => {
        TooltipService.hide();
        if (mouse.button === Qt.LeftButton) {
          indicator.leftClicked();
        } else if (mouse.button === Qt.RightButton) {
          if (indicator.hasRightAction)
            indicator.rightClicked();
          else
            PanelService.showContextMenu(contextMenu, capsule, screen);
        }
      }
    }
  }

  component NNerdIcon: Text {
    id: nerdIcon

    required property string icon
    property real pointSize: Style.fontSizeL
    property bool applyUiScale: true
    readonly property real inkCenterOffset: {
      const inkWidth = glyphMetrics.tightBoundingRect.width;
      if (inkWidth <= 0)
        return 0;
      const advanceCenter = glyphMetrics.advanceWidth / 2;
      const inkCenter = glyphMetrics.tightBoundingRect.x + (inkWidth / 2);
      return advanceCenter - inkCenter;
    }

    function glyphFor(name) {
      const glyphs = {
        "voxtype-recording": "󰍬",
        "voxtype-transcribing": "󰔟",
        "screen-recording": "󰻂",
        "idle-disabled": "󱫖",
        "update-available": ""
      };

      if (glyphs[name] !== undefined)
        return glyphs[name];

      Logger.w("OmarchyFeedback", "Unknown Nerd icon", name);
      return "";
    }

    visible: icon !== ""
    text: glyphFor(icon)
    font.family: "0xProto Nerd Font"
    font.pointSize: Math.max(1, applyUiScale ? pointSize * Style.uiScaleRatio : pointSize)
    font.weight: Font.Medium
    lineHeightMode: Text.FixedHeight
    lineHeight: height
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    transform: Translate {
      x: nerdIcon.inkCenterOffset
    }

    TextMetrics {
      id: glyphMetrics

      text: nerdIcon.text
      font: nerdIcon.font
    }
  }
}
