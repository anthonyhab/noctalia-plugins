import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen

  // Widget properties passed from Bar.qml
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property bool isPlaying: pluginMain?.isPlaying || false
  property bool hasEverConnected: false

  onIsConnectedChanged: {
    if (isConnected) {
      hasEverConnected = true;
    }
  }

  readonly property string mediaTitle: pluginMain?.mediaTitle || ""
  readonly property string mediaArtist: pluginMain?.mediaArtist || ""
  readonly property string friendlyName: pluginMain?.friendlyName || ""

  readonly property string labelText: {
    if (!isConnected) {
      return pluginApi?.tr("title") || "Home Assistant";
    }
    if (isPlaying && mediaTitle) {
      return mediaTitle;
    }
    return friendlyName || (pluginApi?.tr("title") || "Home Assistant");
  }

  readonly property string pillText: isBarVertical ? "" : labelText

  readonly property string iconName: {
    if (isConnecting)
      return "home-search";
    if (!isConnected)
      return "home-off";
    if (isPlaying)
      return "player-play";
    return "home";
  }

  readonly property string tooltipText: {
    if (isConnecting) {
      return pluginApi?.tr("status.connecting") || "Connecting...";
    }
    if (!isConnected) {
      return pluginApi?.tr("tooltips.disconnected") || "Home Assistant (disconnected)\nClick to configure";
    }
    if (isPlaying && mediaTitle) {
      let tooltip = mediaTitle;
      if (mediaArtist)
        tooltip += "\n" + mediaArtist;
      tooltip += "\n" + (pluginApi?.tr("tooltips.click-hint") || "Click to control");
      return tooltip;
    }
    return pluginApi?.tr("tooltips.connected", {
                           count: pluginMain?.mediaPlayers?.length || 0
                         }) || "Home Assistant\n" + (pluginMain?.mediaPlayers?.length || 0) + " devices available";
  }

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property int maxWidthSetting: {
    const settingValue = pluginApi?.pluginSettings?.barWidgetMaxWidth;
    const fallbackValue = defaultSettings.barWidgetMaxWidth;
    const value = settingValue !== undefined ? settingValue : fallbackValue;
    return value !== undefined ? value : 200;
  }
  readonly property bool useFixedWidth: pluginApi?.pluginSettings?.barWidgetUseFixedWidth !== undefined
                                       ? pluginApi?.pluginSettings?.barWidgetUseFixedWidth
                                       : (defaultSettings.barWidgetUseFixedWidth || false)
  readonly property string scrollingMode: pluginApi?.pluginSettings?.barWidgetScrollingMode || defaultSettings.barWidgetScrollingMode || "hover"

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play"),
        "action": "play-pause",
        "icon": isPlaying ? "player-pause" : "player-play",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.next") || "Next",
        "action": "next",
        "icon": "player-track-next",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.previous") || "Previous",
        "action": "previous",
        "icon": "player-track-prev",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.refresh") || "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
                   var popupMenuWindow = popupWindow();
                   if (popupMenuWindow) {
                     popupMenuWindow.close();
                   }
                   if (action === "play-pause") {
                     pluginMain?.mediaPlayPause();
                   } else if (action === "next") {
                     pluginMain?.mediaNext();
                   } else if (action === "previous") {
                     pluginMain?.mediaPrevious();
                   } else if (action === "refresh") {
                     pluginMain?.refresh();
                   } else if (action === "settings") {
                     openPluginSettings();
                   }
                 }
  }

  readonly property var palette: typeof Color !== "undefined" ? Color : null
  readonly property color fallbackSurfaceLow: "#1f1f1f"
  readonly property color fallbackOnSurface: "#f0f0f0"

  readonly property color pillBackgroundColor: {
    if (!isConnected && hasEverConnected)
      return palette?.mSurfaceContainerLow ?? fallbackSurfaceLow;
    return Qt.rgba(0, 0, 0, 0);
  }
  readonly property color pillTextIconColor: !isConnected && hasEverConnected
                                           ? (palette?.mOnSurface ?? fallbackOnSurface)
                                           : Qt.rgba(0, 0, 0, 0)

  property var settingsPopupComponent: null

  readonly property real capsuleHeight: Style.capsuleHeight
  readonly property real iconPixelSize: {
    switch (Settings.data.bar.density) {
    case "compact":
      return Math.max(1, Math.round(capsuleHeight * 0.65));
    default:
      return Math.max(1, Math.round(capsuleHeight * 0.48));
    }
  }
  readonly property real textPointSize: {
    switch (Settings.data.bar.density) {
    case "compact":
      return Math.max(1, Math.round(capsuleHeight * 0.45));
    default:
      return Math.max(1, Math.round(capsuleHeight * 0.33));
    }
  }
  readonly property bool showText: !isBarVertical && pillText !== ""
  property bool hovered: false

  function calculateContentWidth() {
    if (!showText) {
      return capsuleHeight;
    }
    var contentWidth = 0;
    var margins = Style.marginS * scaling * 2;
    contentWidth += margins;
    contentWidth += iconPixelSize + (Style.marginS * scaling);
    contentWidth += Math.ceil(fullTitleMetrics.contentWidth || 0);
    contentWidth += Style.marginXXS * 2;
    return Math.ceil(contentWidth);
  }

  readonly property real dynamicWidth: {
    if (!showText)
      return capsuleHeight;
    if (useFixedWidth)
      return maxWidthSetting;
    return Math.min(calculateContentWidth(), maxWidthSetting);
  }

  implicitWidth: dynamicWidth
  implicitHeight: capsuleHeight

  function popupWindow() {
    if (!screen)
      return null;
    return PanelService.getPopupMenuWindow(screen);
  }

  NText {
    id: fullTitleMetrics
    visible: false
    text: pillText
    pointSize: textPointSize
    applyUiScale: false
  }

  Rectangle {
    id: pill

    width: dynamicWidth
    height: capsuleHeight
    radius: Style.radiusM
    color: hovered ? Color.mHover : (pillBackgroundColor.a > 0 ? pillBackgroundColor : Style.capsuleColor)
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }

    Item {
      id: mainContainer
      anchors.fill: parent
      anchors.leftMargin: Style.marginS * scaling
      anchors.rightMargin: Style.marginS * scaling

      RowLayout {
        id: rowLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.marginS * scaling
        visible: !isBarVertical

        Item {
          Layout.preferredWidth: iconPixelSize
          Layout.preferredHeight: iconPixelSize
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            anchors.fill: parent
            icon: iconName
            pointSize: iconPixelSize
            applyUiScale: false
            color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
          }
        }

        Item {
          id: titleContainer
          Layout.preferredWidth: {
            var iconWidth = iconPixelSize + (Style.marginS * scaling);
            var totalMargins = Style.marginXXS * 2;
            var availableWidth = mainContainer.width - iconWidth - totalMargins;
            return Math.max(20, availableWidth);
          }
          Layout.maximumWidth: Layout.preferredWidth
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredHeight: titleText.height
          visible: showText
          clip: true

          property bool isScrolling: false
          property bool isResetting: false
          property real textWidth: Math.ceil(fullTitleMetrics.contentWidth || 0)
          property real containerWidth: width
          property bool needsScrolling: textWidth > containerWidth

      Timer {
        id: scrollStartTimer
        interval: 1000
        repeat: false
        onTriggered: {
          if (scrollingMode === "always" && titleContainer.needsScrolling) {
            titleContainer.isScrolling = true;
            titleContainer.isResetting = false;
          }
        }
      }

      property var updateScrollingState: function () {
        if (scrollingMode === "never") {
          isScrolling = false;
          isResetting = false;
        } else if (scrollingMode === "always") {
          if (needsScrolling) {
            if (mouseArea.containsMouse) {
              isScrolling = false;
              isResetting = true;
            } else {
              scrollStartTimer.restart();
            }
          } else {
            scrollStartTimer.stop();
            isScrolling = false;
            isResetting = false;
          }
        } else if (scrollingMode === "hover") {
          if (mouseArea.containsMouse && needsScrolling) {
            isScrolling = true;
            isResetting = false;
          } else {
            isScrolling = false;
            if (needsScrolling) {
              isResetting = true;
            }
          }
        }
      }

      onWidthChanged: updateScrollingState()
      Component.onCompleted: updateScrollingState()

      Connections {
        target: mouseArea
        function onContainsMouseChanged() {
          titleContainer.updateScrollingState();
        }
      }

          Item {
            id: scrollContainer
            height: parent.height
            width: childrenRect.width

            property real scrollX: 0
            x: scrollX

            RowLayout {
              spacing: 50

              NText {
                id: titleText
                text: pillText
                pointSize: textPointSize
                applyUiScale: false
                verticalAlignment: Text.AlignVCenter
                color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
                onTextChanged: {
                  if (scrollingMode === "always") {
                    titleContainer.isScrolling = false;
                    titleContainer.isResetting = false;
                    scrollContainer.scrollX = 0;
                    scrollStartTimer.restart();
                  }
                }
              }

              NText {
                text: pillText
                font: titleText.font
                pointSize: textPointSize
                applyUiScale: false
                verticalAlignment: Text.AlignVCenter
                color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
                visible: titleContainer.needsScrolling && titleContainer.isScrolling
              }
            }

            NumberAnimation on scrollX {
              running: titleContainer.isResetting
              to: 0
              duration: 300
              easing.type: Easing.OutQuad
              onFinished: {
                titleContainer.isResetting = false;
              }
            }

            NumberAnimation on scrollX {
              id: infiniteScroll
              running: titleContainer.isScrolling && !titleContainer.isResetting
              from: 0
              to: -(titleContainer.textWidth + 50)
              duration: Math.max(4000, pillText.length * 100)
              loops: Animation.Infinite
              easing.type: Easing.Linear
            }
          }
        }
      }

      Item {
        id: verticalLayout
        anchors.centerIn: parent
        width: parent.width - Style.marginM * 2
        height: parent.height - Style.marginM * 2
        visible: isBarVertical

        Item {
          width: iconPixelSize
          height: width
          anchors.centerIn: parent

          NIcon {
            anchors.fill: parent
            icon: iconName
            pointSize: iconPixelSize
            applyUiScale: false
            color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
          }
        }
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        hovered = true;
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection(), Style.tooltipDelayLong);
      }
      onExited: {
        hovered = false;
        TooltipService.hide();
      }
      onClicked: mouse => {
                   TooltipService.hide();
                   if (mouse.button === Qt.LeftButton) {
                     openPanel();
                   } else if (mouse.button === Qt.RightButton) {
                     var popupMenuWindow = popupWindow();
                     if (popupMenuWindow) {
                       popupMenuWindow.showContextMenu(contextMenu);
                       contextMenu.openAtItem(pill, screen);
                     }
                   } else if (mouse.button === Qt.MiddleButton) {
                     pluginMain?.mediaPlayPause();
                   }
                 }
      onWheel: wheel => {
                 TooltipService.hide();
                 if (!isConnected)
                   return;
                 if (wheel.angleDelta.y > 0) {
                   pluginMain?.volumeUp();
                 } else {
                   pluginMain?.volumeDown();
                 }
               }
    }
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.withCurrentScreen(s => {
                                  pluginApi.openPanel(s, pill);
                                });
  }

  function openPluginSettings() {
    if (!pluginApi)
      return;

    var popupMenuWindow = popupWindow();

    function instantiateDialog(component) {
      var parentItem = popupMenuWindow ? popupMenuWindow.dialogParent : Overlay.overlay;
      var dialog = component.createObject(parentItem, {
                                            "showToastOnSave": true
                                          });
      if (!dialog) {
        Logger.e("HomeAssistantWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
        return;
      }

      dialog.openPluginSettings(pluginApi.manifest);

      if (popupMenuWindow) {
        popupMenuWindow.hasDialog = true;
        popupMenuWindow.open();
        dialog.closed.connect(() => {
                                popupMenuWindow.hasDialog = false;
                                popupMenuWindow.close();
                              });
      }

      dialog.closed.connect(() => dialog.destroy());
    }

    function handleReady(component) {
      instantiateDialog(component);
    }

    if (!settingsPopupComponent) {
      settingsPopupComponent = Qt.createComponent(Quickshell.shellDir + "/Widgets/NPluginSettingsPopup.qml");
    }

    if (settingsPopupComponent.status === Component.Ready) {
      handleReady(settingsPopupComponent);
    } else if (settingsPopupComponent.status === Component.Loading) {
      var handler = function settingsComponentStatusChanged() {
        if (settingsPopupComponent.status === Component.Ready) {
          settingsPopupComponent.statusChanged.disconnect(handler);
          handleReady(settingsPopupComponent);
        } else if (settingsPopupComponent.status === Component.Error) {
          Logger.e("HomeAssistantWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("HomeAssistantWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
