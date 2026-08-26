import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: root

  property var previewModel: null
  property bool showPreview: false
  property real previewOpacityScale: 0.55
  property string layerRole: "base"
  readonly property string mode: previewModel && previewModel.mode ? previewModel.mode : "none"
  readonly property string activeDirection: previewModel && previewModel.activeDirection ? previewModel.activeDirection : ""
  readonly property var targetRect: previewModel && previewModel.targetRect ? previewModel.targetRect : null
  readonly property var draggedResultRect: previewModel && previewModel.draggedResultRect ? previewModel.draggedResultRect : null
  readonly property var targetResultRect: previewModel && previewModel.targetResultRect ? previewModel.targetResultRect : null
  readonly property string actionLabel: previewModel && previewModel.label ? previewModel.label : ""
  readonly property string draggedSlotLabel: previewModel && previewModel.draggedSlotLabel ? previewModel.draggedSlotLabel : ""
  readonly property string targetSlotLabel: previewModel && previewModel.targetSlotLabel ? previewModel.targetSlotLabel : ""
  readonly property color accent: Color.mPrimary
  readonly property bool hasTarget: !!targetRect && targetRect.w > 0 && targetRect.h > 0
  readonly property bool isSplit: mode === "split"
  readonly property bool isSwap: mode === "swap"
  readonly property bool isBaseLayer: layerRole === "base"
  readonly property bool isForegroundLayer: layerRole === "foreground"
  readonly property real swapBadgeScale: Math.max(0.75, Style.uiScaleRatio)
  readonly property real swapBadgeTargetWidth: root.rectW(root.targetRect) * 0.78
  readonly property real swapBadgeTargetHeight: root.rectH(root.targetRect) * 0.62
  readonly property real swapBadgeWidth: Math.max(Math.min(84 * root.swapBadgeScale, root.swapBadgeTargetWidth), Math.min(root.swapBadgeTargetWidth, 180 * root.swapBadgeScale))
  readonly property real swapBadgeHeight: Math.max(Math.min(40 * root.swapBadgeScale, root.swapBadgeTargetHeight), Math.min(root.swapBadgeTargetHeight, 62 * root.swapBadgeScale))
  readonly property real swapBadgeIconSize: Math.max(20 * root.swapBadgeScale, Math.min(34 * root.swapBadgeScale, Math.min(root.swapBadgeWidth, root.swapBadgeHeight) * 0.42))
  readonly property real swapBadgeFontSize: Math.max(11 * root.swapBadgeScale, Math.min(16 * root.swapBadgeScale, Math.min(root.swapBadgeWidth, root.swapBadgeHeight) * 0.24))

  function rectX(rect) {
    return rect ? rect.x : 0;
  }

  function rectY(rect) {
    return rect ? rect.y : 0;
  }

  function rectW(rect) {
    return rect ? rect.w : 0;
  }

  function rectH(rect) {
    return rect ? rect.h : 0;
  }

  function iconFor(direction) {
    switch (direction) {
    case "l":
      return "\ue314";
    case "r":
      return "\ue315";
    case "u":
      return "\ue316";
    case "d":
      return "\ue313";
    case "swap":
      return "\ue8d4";
    default:
      return "";
    }
  }

  visible: showPreview && hasTarget && mode !== "none"

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.22 * root.previewOpacityScale)
    visible: root.visible && root.isBaseLayer
  }

  Rectangle {
    id: quietTargetFill

    x: root.rectX(root.targetRect)
    y: root.rectY(root.targetRect)
    width: root.rectW(root.targetRect)
    height: root.rectH(root.targetRect)
    radius: Style.radiusM
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.56 * root.previewOpacityScale)
    border.width: Math.max(2, Math.round(2 * Style.uiScaleRatio))
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.95)
    visible: root.visible && root.isBaseLayer
    layer.enabled: true

    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
      shadowBlur: 0.36
      shadowVerticalOffset: 1
      shadowHorizontalOffset: 1
    }
  }

  Rectangle {
    id: targetShade

    anchors.fill: quietTargetFill
    anchors.margins: Math.max(4, Math.round(5 * Style.uiScaleRatio))
    radius: Math.max(0, quietTargetFill.radius - anchors.margins)
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.34)
    border.width: 1
    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.5)
    visible: root.visible && root.isBaseLayer
  }

  Rectangle {
    id: draggedSlot

    x: root.rectX(root.draggedResultRect)
    y: root.rectY(root.draggedResultRect)
    width: root.rectW(root.draggedResultRect)
    height: root.rectH(root.draggedResultRect)
    radius: Style.radiusM
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28 * root.previewOpacityScale)
    border.width: Math.max(2, Math.round(2 * Style.uiScaleRatio))
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.95)
    visible: root.visible && root.isBaseLayer && root.isSplit && !!root.draggedResultRect

    Text {
      anchors.centerIn: parent
      width: Math.max(0, parent.width - 10)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WordWrap
      text: root.draggedSlotLabel
      color: Color.mOnSurface
      font.pixelSize: Math.max(9, Math.min(13, Math.min(parent.width, parent.height) * 0.13))
    }
  }

  Rectangle {
    id: targetSlot

    x: root.rectX(root.targetResultRect)
    y: root.rectY(root.targetResultRect)
    width: root.rectW(root.targetResultRect)
    height: root.rectH(root.targetResultRect)
    radius: Style.radiusM
    color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.28 * root.previewOpacityScale)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72)
    visible: root.visible && root.isBaseLayer && root.isSplit && !!root.targetResultRect

    Text {
      anchors.centerIn: parent
      width: Math.max(0, parent.width - 10)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WordWrap
      text: root.targetSlotLabel
      color: Color.mOnSurface
      font.pixelSize: Math.max(9, Math.min(13, Math.min(parent.width, parent.height) * 0.13))
    }
  }

  Rectangle {
    id: foregroundTargetContour

    x: root.rectX(root.targetRect)
    y: root.rectY(root.targetRect)
    width: root.rectW(root.targetRect)
    height: root.rectH(root.targetRect)
    radius: Style.radiusM
    color: "transparent"
    border.width: Math.max(3, Math.round(3 * Style.uiScaleRatio))
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
    visible: root.visible && root.isForegroundLayer
    layer.enabled: true

    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
      shadowBlur: 0.42
      shadowVerticalOffset: 1
      shadowHorizontalOffset: 1
    }
  }

  Rectangle {
    id: swapBadge

    width: root.swapBadgeWidth
    height: root.swapBadgeHeight
    x: root.rectX(root.targetRect) + (root.rectW(root.targetRect) - width) / 2
    y: root.rectY(root.targetRect) + (root.rectH(root.targetRect) - height) / 2
    radius: Style.radiusM
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.92)
    border.width: Math.max(2, Math.round(2 * Style.uiScaleRatio))
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
    visible: root.visible && root.isForegroundLayer && root.isSwap

    Row {
      anchors.centerIn: parent
      spacing: Math.max(8, Math.round(8 * Style.uiScaleRatio))

      Text {
        text: root.iconFor("swap")
        color: root.accent
        font.family: "Material Symbols Outlined"
        font.pixelSize: root.swapBadgeIconSize
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: actionText

        text: root.actionLabel
        color: Color.mOnSurface
        font.pixelSize: root.swapBadgeFontSize
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Rectangle {
    id: actionBadge

    x: root.rectX(root.targetRect) + Math.max(8, root.rectW(root.targetRect) * 0.03)
    y: root.rectY(root.targetRect) + Math.max(8, root.rectH(root.targetRect) * 0.03)
    width: Math.min(root.rectW(root.targetRect) - 16, actionLabelText.implicitWidth + 30)
    height: actionLabelText.implicitHeight + 12
    radius: Style.radiusS
    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.9)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72)
    visible: root.visible && root.isForegroundLayer && root.isSplit

    Row {
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: root.iconFor(root.activeDirection)
        color: root.accent
        font.family: "Material Symbols Outlined"
        font.pixelSize: actionLabelText.font.pixelSize + 3
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: actionLabelText

        text: root.actionLabel
        color: Color.mOnSurface
        font.pixelSize: Math.max(10, Math.min(13, Math.min(root.rectW(root.targetRect), root.rectH(root.targetRect)) * 0.08))
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Behavior on opacity {
    NumberAnimation {
      duration: 80
      easing.type: Easing.OutCubic
    }
  }
}
