import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(400 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: {
    const baseHeight = authContent.implicitHeight;
    const minHeight = Math.round(280 * Style.uiScaleRatio);
    const maxHeight = Math.round(520 * Style.uiScaleRatio);
    return Math.max(minHeight, Math.min(baseHeight, maxHeight));
  }

  readonly property var pluginMain: pluginApi?.mainInstance ?? null

  AuthContent {
    id: authContent
    anchors.fill: parent
    pluginMain: root.pluginMain
    request: pluginMain?.currentRequest ?? null
    busy: pluginMain?.responseInFlight ?? false
    agentAvailable: pluginMain?.agentAvailable ?? true
    statusText: pluginMain?.agentStatus ?? ""
    errorText: pluginMain?.lastError ?? ""
    onCloseRequested: pluginApi?.closePanel(root.screen)
  }
}
