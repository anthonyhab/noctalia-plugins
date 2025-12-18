import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property alias label: labelItem.text
  property alias value: spin.value
  property alias from: spin.from
  property alias to: spin.to
  property alias stepSize: spin.stepSize
  property alias enabled: spin.enabled

  spacing: Style.marginXS

  NText {
    id: labelItem
    text: ""
    color: Color.mOnSurface
  }

  SpinBox {
    id: spin
    Layout.fillWidth: true
    editable: true
    inputMethodHints: Qt.ImhDigitsOnly
    implicitHeight: Style.controlHeightM

    validator: IntValidator {
      bottom: spin.from
      top: spin.to
    }
  }
}
