import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

PanelWindow {
  id: previewRoot

  // Dependencies passed from Settings.qml
  property var pluginMain
  property var previewWorkspaceOptions: []
  property string previewWorkspaceKey: ""
  property var previewWorkspaceWindows: []
  property var previewMonitorData: null
  property int previewMonitorId: 0
  property real previewCenteringX: 0
  property real previewCenteringY: 0
  // Extracted settings
  property string visualMode: "live"
  property string shaderPreset: "pixelated"
  property real shaderPresetStrength: 0.7
  property real simplifiedPixelDensity: 0.5
  property real simplifiedColorDepth: 6
  property real simplifiedSaturation: 1.1
  property real simplifiedContrast: 1.1
  property string accentColorType: "secondary"
  property bool showWindowIcons: true
  property bool colorizeWindowIcons: false
  property string windowIconPlacement: "center"
  property bool showFocusedWindowGlow: true
  property bool showUrgencyBadge: true
  property bool showFloatingBadge: true
  property bool showFullscreenBadge: true
  property bool showMonitorBadge: true
  property real dimInactiveWorkspaces: 0.15
  property real inactiveWorkspaceSaturation: 0.8
  property real hoverLiftAmount: 8
  property string previewCornerMode: "hyprland"
  property real previewFixedCornerRadius: 12
  property bool useBorderGradient: true
  property bool showWindowTitleStrip: true
  property string titleStripPosition: "overlay-top"
  property int titleStripHeight: 20
  property string titleStripMode: "auto"
  property string titleStripMeta: "none"
  property real selectionBorderWidth: -1
  property bool showRowColumnGuides: true
  property bool showWorkspaceLabels: true
  property string specialWorkspaceStyle: "pill"
  property string previewWorkspaceWatermark: ""
  // Animation settings
  property string animationProfile: "standard"
  property int animationDurationMs: 250
  property var previewHyprConfig: ({})
  // Private selected option
  property var selectedPreviewWorkspaceOption: {
    for (var i = 0; i < previewRoot.previewWorkspaceOptions.length; i++) {
      if (previewRoot.previewWorkspaceOptions[i].key === previewRoot.previewWorkspaceKey)
        return previewRoot.previewWorkspaceOptions[i];
    }
    return null;
  }
  property string monitorKey: "__default__"
  property var targetScreen: null
  readonly property var fallbackScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  property string barPosition: Settings.data.bar.position || "bottom"
  property real windowX: Style.marginM
  property real windowY: Style.marginM
  property real pluginWindowX: -1
  property real pluginWindowY: -1
  property real persistedWindowX: -1
  property real persistedWindowY: -1
  property string persistedMonitorKey: ""
  readonly property real previewWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property real previewHeight: Math.round(200 * Style.uiScaleRatio)
  readonly property real titleBarHeight: Math.max(36, Math.round(34 * Style.uiScaleRatio))
  readonly property bool isDragging: dragHandler.active
  property real dragLiftScale: 1.0
  property bool committingDragPosition: false

  Behavior on dragLiftScale {
    enabled: !previewRoot.isDragging
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutBack
      easing.overshoot: 2.0
    }
  }

  Behavior on windowX {
    enabled: !previewRoot.isDragging && !previewRoot.committingDragPosition
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutBack
      easing.overshoot: 1.2
    }
  }

  Behavior on windowY {
    enabled: !previewRoot.isDragging && !previewRoot.committingDragPosition
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutBack
      easing.overshoot: 1.2
    }
  }

  signal positionSaved(string monitorKey, real xPos, real yPos)

  function isValidSavedPosition(xPos, yPos) {
    return isFinite(xPos) && isFinite(yPos) && xPos >= 0 && yPos >= 0;
  }

  function screenWidth() {
    return (previewRoot.screen && previewRoot.screen.width) || 1920;
  }

  function screenHeight() {
    return (previewRoot.screen && previewRoot.screen.height) || 1080;
  }

  function clampToScreen(xPos, yPos) {
    var frameWidth = previewRoot.previewWidth;
    var frameHeight = previewRoot.previewHeight;
    var minX = Style.marginL;
    var minY = Style.marginL;
    var maxX = Math.max(minX, screenWidth() - frameWidth - Style.marginL);
    var maxY = Math.max(minY, screenHeight() - frameHeight - Style.marginL);
    var clampedX = Math.max(minX, Math.min(maxX, xPos));
    var clampedY = Math.max(minY, Math.min(maxY, yPos));
    return {
      "x": clampedX,
      "y": clampedY
    };
  }

  function resolveDefaultPosition() {
    var defaultX = Style.marginM;
    var defaultY = Style.marginM;
    if (barPosition === "left")
      defaultX = Style.barHeight + Style.marginL;
    else if (barPosition === "top")
      defaultY = Style.barHeight + Style.marginL;
    else if (barPosition === "bottom")
      defaultY = screenHeight() - previewRoot.previewHeight - Style.barHeight - Style.marginL;
    return {
      "x": defaultX,
      "y": defaultY
    };
  }

  function applyInitialPosition() {
    var hasSavedPosition = isValidSavedPosition(previewRoot.pluginWindowX, previewRoot.pluginWindowY);
    var seed = hasSavedPosition ? {
                                    "x": previewRoot.pluginWindowX,
                                    "y": previewRoot.pluginWindowY
                                  } : resolveDefaultPosition();
    var clamped = clampToScreen(seed.x, seed.y);
    previewRoot.windowX = clamped.x;
    previewRoot.windowY = clamped.y;
    if (hasSavedPosition) {
      previewRoot.persistedWindowX = clamped.x;
      previewRoot.persistedWindowY = clamped.y;
    } else {
      previewRoot.persistedWindowX = -1;
      previewRoot.persistedWindowY = -1;
    }
    previewRoot.persistedMonitorKey = previewRoot.monitorKey;
  }

  function syncWithPersistedInput() {
    if (dragHandler.active)
      return;

    if (!isValidSavedPosition(previewRoot.pluginWindowX, previewRoot.pluginWindowY))
      return;

    var clamped = clampToScreen(previewRoot.pluginWindowX, previewRoot.pluginWindowY);
    if (Math.abs(clamped.x - previewRoot.windowX) > 0.5 || Math.abs(clamped.y - previewRoot.windowY) > 0.5) {
      previewRoot.windowX = clamped.x;
      previewRoot.windowY = clamped.y;
    }
    previewRoot.persistedWindowX = clamped.x;
    previewRoot.persistedWindowY = clamped.y;
    previewRoot.persistedMonitorKey = previewRoot.monitorKey;
  }

  function clampCurrentPosition() {
    if (dragHandler.active)
      return;

    var clamped = clampToScreen(previewRoot.windowX, previewRoot.windowY);
    if (Math.abs(clamped.x - previewRoot.windowX) > 0.5 || Math.abs(clamped.y - previewRoot.windowY) > 0.5) {
      previewRoot.windowX = clamped.x;
      previewRoot.windowY = clamped.y;
    }
  }

  function shouldPersistPosition(xPos, yPos) {
    if (previewRoot.persistedMonitorKey !== previewRoot.monitorKey)
      return true;

    if (!isValidSavedPosition(previewRoot.persistedWindowX, previewRoot.persistedWindowY))
      return true;

    return Math.abs(previewRoot.persistedWindowX - xPos) > 0.5 || Math.abs(previewRoot.persistedWindowY - yPos) > 0.5;
  }

  function snapPositionToScreenEdges(position) {
    var snapped = clampToScreen(position.x, position.y);
    var snapDist = Math.round(28 * Style.uiScaleRatio);
    if (snapped.x <= Style.marginL + snapDist)
      snapped.x = Style.marginL;
    else if (snapped.x + previewRoot.previewWidth >= previewRoot.screenWidth() - Style.marginL - snapDist)
      snapped.x = previewRoot.screenWidth() - previewRoot.previewWidth - Style.marginL;
    if (snapped.y <= Style.marginL + snapDist)
      snapped.y = Style.marginL;
    return snapped;
  }

  function finishDragPosition() {
    previewRoot.dragLiftScale = 1.0;
    var clamped = snapPositionToScreenEdges({
                                              "x": previewRoot.windowX,
                                              "y": previewRoot.windowY
                                            });
    previewRoot.committingDragPosition = true;
    previewRoot.windowX = clamped.x;
    previewRoot.windowY = clamped.y;
    previewRoot.committingDragPosition = false;
    if (previewRoot.shouldPersistPosition(clamped.x, clamped.y)) {
      previewRoot.persistedWindowX = clamped.x;
      previewRoot.persistedWindowY = clamped.y;
      previewRoot.persistedMonitorKey = previewRoot.monitorKey;
      previewRoot.positionSaved(previewRoot.monitorKey, clamped.x, clamped.y);
    }
  }

  function tr(key) {
    if (pluginMain && pluginMain.pluginApi && pluginMain.pluginApi.tr)
      return pluginMain.pluginApi.tr(key);

    return key;
  }

  // Window logic
  WlrLayershell.namespace: "plugin-workspace-preview"
  screen: previewRoot.targetScreen || previewRoot.fallbackScreen
  Component.onCompleted: applyInitialPosition()
  onMonitorKeyChanged: applyInitialPosition()
  onTargetScreenChanged: applyInitialPosition()
  onPluginWindowXChanged: syncWithPersistedInput()
  onPluginWindowYChanged: syncWithPersistedInput()
  onWidthChanged: clampCurrentPosition()
  onHeightChanged: clampCurrentPosition()
  onScreenChanged: clampCurrentPosition()
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1
  color: "transparent"
  // Only show if we actually have options to preview and the window is meant to be visible
  visible: previewRoot.previewWorkspaceOptions.length > 0
  // Size logic
  implicitWidth: screenWidth()
  implicitHeight: screenHeight()

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  Rectangle {
    id: windowFrame

    x: previewRoot.windowX
    y: previewRoot.windowY
    width: previewRoot.previewWidth
    height: previewRoot.previewHeight
    radius: Style.radiusL
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.95)
    border.width: Style.borderS
    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
    transform: Scale {
      xScale: previewRoot.dragLiftScale
      yScale: previewRoot.dragLiftScale
      origin.x: windowFrame.width / 2
      origin.y: windowFrame.height / 2
    }

    // Dimming effect since this isn't the primary focus
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 1)
      opacity: previewRoot.isDragging ? 0.45 : 0.3
      z: -1

      Behavior on opacity {
        NumberAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }

    Rectangle {
      id: titleBar

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: previewRoot.titleBarHeight
      radius: Style.radiusL
      color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, previewRoot.isDragging ? 0.7 : 0.5)
      border.width: 1
      border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, previewRoot.isDragging ? 0.7 : 0.4)

      Behavior on color {
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        spacing: Style.marginS

        Rectangle {
          width: 9
          height: 9
          radius: width / 2
          color: previewRoot.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary
        }

        NText {
          text: previewRoot.tr("settings.previewWindow.title")
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
        }

        Item {
          Layout.fillWidth: true
        }

        Rectangle {
          visible: previewRoot.previewMonitorData && previewRoot.previewMonitorData.name
          radius: 6
          color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.7)
          border.width: 1
          border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.4)
          implicitWidth: monitorChipText.implicitWidth + 10
          implicitHeight: monitorChipText.implicitHeight + 4

          NText {
            id: monitorChipText

            anchors.centerIn: parent
            text: previewRoot.previewMonitorData && previewRoot.previewMonitorData.name ? previewRoot.previewMonitorData.name : ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
          }
        }

        Rectangle {
          radius: 6
          color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.7)
          border.width: 1
          border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.4)
          implicitWidth: workspaceChipText.implicitWidth + 10
          implicitHeight: workspaceChipText.implicitHeight + 4

          NText {
            id: workspaceChipText

            anchors.centerIn: parent
            text: previewRoot.previewWorkspaceWatermark ? previewRoot.tr("settings.previewWindow.workspace-prefix") + previewRoot.previewWorkspaceWatermark : previewRoot.tr("settings.previewWindow.workspace")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
          }
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: 52
        height: 4
        radius: 3
        color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, previewRoot.isDragging ? 0.75 : 0.45)

        Behavior on color {
          ColorAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }

      MouseArea {
        id: dragArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      }

      DragHandler {
        id: dragHandler

        property real startWindowX: 0
        property real startWindowY: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        target: null
        snapMode: DragHandler.NoSnap
        dragThreshold: 0
        onActiveChanged: {
          if (active) {
            startWindowX = previewRoot.windowX;
            startWindowY = previewRoot.windowY;
            previewRoot.dragLiftScale = 1.018;
          } else {
            previewRoot.finishDragPosition();
          }
        }
        onTranslationChanged: {
          if (active) {
            var clamped = previewRoot.clampToScreen(startWindowX + dragHandler.translation.x, startWindowY + dragHandler.translation.y);
            previewRoot.windowX = clamped.x;
            previewRoot.windowY = clamped.y;
          }
        }
      }
    }

    Item {
      id: contentArea

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: titleBar.bottom
      anchors.bottom: parent.bottom
    }

    Item {
      id: previewWorkspaceViewport

      property real rawMonitorWidth: ((previewRoot.previewMonitorData && previewRoot.previewMonitorData.width) || 1920) / ((previewRoot.previewMonitorData && previewRoot.previewMonitorData.scale) || 1)
      property real rawMonitorHeight: ((previewRoot.previewMonitorData && previewRoot.previewMonitorData.height) || 1080) / ((previewRoot.previewMonitorData && previewRoot.previewMonitorData.scale) || 1)
      property real sourceMonitorWidth: (previewRoot.previewMonitorData && previewRoot.previewMonitorData.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
      property real sourceMonitorHeight: (previewRoot.previewMonitorData && previewRoot.previewMonitorData.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight
      property real aspectRatio: sourceMonitorWidth / Math.max(1, sourceMonitorHeight)

      anchors.centerIn: contentArea
      width: Math.min(Math.max(1, contentArea.width - Style.marginL * 2), Math.max(1, (contentArea.height - Style.marginL * 2) * aspectRatio))
      height: width / Math.max(0.01, aspectRatio)

      Rectangle {
        id: previewWorkspaceSurface

        anchors.fill: parent
        color: Color.mSurfaceVariant
        radius: Style.screenRadius * 0.35
        border.width: previewRoot.selectionBorderWidth >= 0 ? previewRoot.selectionBorderWidth : Style.borderM
        border.color: previewRoot.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary

        Rectangle {
          visible: previewRoot.showRowColumnGuides
          anchors.centerIn: parent
          width: parent.width * 0.8
          height: 1
          color: Qt.alpha(previewRoot.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary, Style.opacityLight)
        }

        Rectangle {
          visible: previewRoot.showRowColumnGuides
          anchors.centerIn: parent
          width: 1
          height: parent.height * 0.8
          color: Qt.alpha(previewRoot.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary, Style.opacityLight)
        }

        Text {
          anchors.centerIn: parent
          text: previewRoot.previewWorkspaceWatermark
          font.family: Settings.data.ui.fontDefault
          font.pixelSize: Math.max(40, parent.height * 0.42)
          font.weight: Style.fontWeightSemiBold
          color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)
        }

        Rectangle {
          visible: previewRoot.showWorkspaceLabels && previewRoot.selectedPreviewWorkspaceOption
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.leftMargin: Math.max(6, parent.width * 0.03)
          anchors.topMargin: Math.max(6, parent.height * 0.03)
          radius: previewRoot.specialWorkspaceStyle === "pill" ? Math.max(8, height / 2) : (previewRoot.specialWorkspaceStyle === "chip" ? 8 : 0)
          color: previewRoot.specialWorkspaceStyle === "plain" ? "transparent" : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.72)
          border.width: previewRoot.specialWorkspaceStyle === "plain" ? 0 : 1
          border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
          width: Math.min(parent.width * 0.78, workspaceLabelText.implicitWidth + 14)
          height: Math.max(20, Math.min(30, parent.height * 0.2))

          Text {
            id: workspaceLabelText

            anchors.centerIn: parent
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: (previewRoot.selectedPreviewWorkspaceOption && previewRoot.selectedPreviewWorkspaceOption.name) || previewRoot.tr("settings.previewWindow.workspace")
            font.family: Settings.data.ui.fontDefault
            font.pixelSize: Math.max(10, Math.min(13, parent.height * 0.52))
            color: Color.mOnSurface
          }
        }

        Repeater {
          model: previewRoot.previewWorkspaceWindows || []

          delegate: WindowPreview {
            required property var modelData
            required property int index
            property var previewWin: modelData && modelData.win ? modelData.win : ({})
            property int monitorId: (previewWin.monitor !== undefined && previewWin.monitor !== null) ? previewWin.monitor : previewRoot.previewMonitorId
            property var windowMonitor: {
              var monitors = previewRoot.pluginMain && previewRoot.pluginMain.monitors ? previewRoot.pluginMain.monitors : [];
              for (var i = 0; i < monitors.length; i++) {
                if (monitors[i] && monitors[i].id === monitorId)
                  return monitors[i];
              }
              return previewRoot.previewMonitorData;
            }
            property real rawMonitorWidth: ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1)
            property real rawMonitorHeight: ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1)
            property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
            property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight

            pluginMain: previewRoot.pluginMain
            toplevel: modelData && modelData.toplevel ? modelData.toplevel : null
            windowData: previewWin
            monitorData: windowMonitor
            windowScale: Math.min(previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth), previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight))
            positionScaleX: previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth)
            positionScaleY: previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight)
            availableWorkspaceWidth: previewWorkspaceViewport.width
            availableWorkspaceHeight: previewWorkspaceViewport.height
            centeringX: previewRoot.previewCenteringX
            centeringY: previewRoot.previewCenteringY
            xOffset: 0
            yOffset: 0
            widgetMonitorId: previewRoot.previewMonitorId
            overviewOpen: true
            useSimplifiedPreview: previewRoot.visualMode === "simplified"
            visualMode: previewRoot.visualMode
            shaderPreset: previewRoot.shaderPreset
            shaderPresetStrength: previewRoot.shaderPresetStrength
            simplifiedPixelDensity: previewRoot.simplifiedPixelDensity
            simplifiedColorDepth: previewRoot.simplifiedColorDepth
            simplifiedSaturation: previewRoot.simplifiedSaturation
            simplifiedContrast: previewRoot.simplifiedContrast
            hyprGapsIn: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.gapsIn !== undefined) ? previewRoot.previewHyprConfig.gapsIn : 5
            hyprBorderSize: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.borderSize !== undefined) ? previewRoot.previewHyprConfig.borderSize : 1
            windowBorderSize: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.borderSize !== undefined) ? previewRoot.previewHyprConfig.borderSize : 1
            activeBorderColor: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.activeBorderColor) ? previewRoot.previewHyprConfig.activeBorderColor : Color.mPrimary
            inactiveBorderColor: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.inactiveBorderColor) ? previewRoot.previewHyprConfig.inactiveBorderColor : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)
            isActiveWorkspaceWindow: true
            isFocusedWindow: !!(previewRoot.pluginMain && previewRoot.pluginMain.activeWindowAddress && previewWin.address && previewWin.address === previewRoot.pluginMain.activeWindowAddress)
            showWindowIcons: previewRoot.showWindowIcons
            colorizeWindowIcons: previewRoot.colorizeWindowIcons
            windowIconPlacement: previewRoot.windowIconPlacement
            showFocusedGlow: previewRoot.showFocusedWindowGlow
            showUrgencyBadge: previewRoot.showUrgencyBadge
            showFloatingBadge: previewRoot.showFloatingBadge
            showFullscreenBadge: previewRoot.showFullscreenBadge
            showMonitorBadge: previewRoot.showMonitorBadge
            inactiveWorkspaceDimAmount: previewRoot.dimInactiveWorkspaces
            inactiveWorkspaceSaturation: previewRoot.inactiveWorkspaceSaturation
            hoverLiftAmount: previewRoot.hoverLiftAmount
            previewCornerMode: previewRoot.previewCornerMode
            previewFixedCornerRadius: previewRoot.previewFixedCornerRadius
            useBorderGradient: previewRoot.useBorderGradient
            showTitleStrip: previewRoot.showWindowTitleStrip
            titleStripPosition: previewRoot.titleStripPosition
            titleStripHeight: previewRoot.titleStripHeight
            titleStripMode: previewRoot.titleStripMode
            titleStripMeta: previewRoot.titleStripMeta
            windowRounding: (previewRoot.previewHyprConfig && previewRoot.previewHyprConfig.rounding !== undefined) ? previewRoot.previewHyprConfig.rounding : 0
            animationProfile: previewRoot.animationProfile
            animationDurationMs: previewRoot.animationDurationMs
            z: index + 1
            hovered: false
            pressed: false
          }
        }

        NText {
          anchors.centerIn: parent
          visible: (previewRoot.previewWorkspaceWindows || []).length === 0
          text: previewRoot.tr("settings.previewWindow.empty")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }
      }
    }
  }

  mask: Region {
    item: previewRoot.visible ? windowFrame : null
  }
}
