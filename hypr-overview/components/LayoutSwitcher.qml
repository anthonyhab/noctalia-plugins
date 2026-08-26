import QtQuick
import "../helpers/LayoutStrategy.js" as LayoutStrategy
import qs.Commons
import qs.Widgets

Item {
  id: switcher

  required property var pluginMain
  required property int workspaceId
  required property string currentLayout
  required property bool showBadge
  required property bool isSpecialSlot
  required property bool isActiveCell
  required property color accentColor

  signal badgeClicked(int wsId, string layout, real globalX, real globalY, real badgeWidth, real badgeHeight)
  signal layoutChanged(int wsId, string newLayout)

  visible: showBadge && !isSpecialSlot

  readonly property string badgeLabel: LayoutStrategy.allBadgeLabels[currentLayout] || "D"

  // Badge rectangle (top-right corner of workspace cell)
  Rectangle {
    id: badge

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: Math.max(6, parent.width * 0.04)
    anchors.topMargin: Math.max(6, parent.height * 0.04)
    width: Math.min(parent.width * 0.35, badgeText.implicitWidth + 12)
    height: Math.max(16, Math.min(26, parent.height * 0.18))
    radius: height / 2
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, switcher.isActiveCell ? 0.88 : 0.58)
    border.width: 1
    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, switcher.isActiveCell ? 0.5 : 0.28)
    z: 10

    NText {
      id: badgeText

      anchors.centerIn: parent
      text: switcher.badgeLabel
      pointSize: Math.max(6, Math.min(8, parent.height * 0.38))
      color: Color.mOnSurface
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      onClicked: mouse => {
        // Emit badge position in switcher-local coordinates so parent can mapToItem
        switcher.badgeClicked(switcher.workspaceId, switcher.currentLayout, badge.x, badge.y + badge.height + 3, badge.width, badge.height);
        mouse.accepted = true;
      }
    }
  }

  // Layout switching logic — session-only, no disk persistence
  function switchLayout(wsId, layoutName) {
    var validLayouts = LayoutStrategy.allLayouts;
    if (validLayouts.indexOf(layoutName) < 0)
      return;

    var activeWsId = (pluginMain && pluginMain.activeWorkspace && pluginMain.activeWorkspace.id) || -1;

    var commands = [];
    if (wsId == activeWsId) {
      commands.push("keyword general:layout " + layoutName);
    } else {
      commands.push("workspace " + wsId);
      commands.push("keyword general:layout " + layoutName);
      if (activeWsId >= 0)
        commands.push("workspace " + activeWsId);
    }

    if (pluginMain && pluginMain.runOverviewDispatch)
      pluginMain.runOverviewDispatch(commands, {
                                       "reason": "layout-switcher"
                                     });

    // Optimistic update
    if (pluginMain) {
      var updated = {};
      var old = pluginMain.workspaceLayouts || {};
      for (var k in old)
        updated[k] = old[k];
      updated[wsId] = layoutName;
      pluginMain.workspaceLayouts = updated;
      pluginMain.setPendingLayout(wsId, layoutName);
    }

    switcher.layoutChanged(wsId, layoutName);
  }
}
