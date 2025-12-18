import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
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

  readonly property string bundledHelper: pluginApi?.pluginDir ? pluginApi.pluginDir + "/helper/appletv_helper.py" : ""

  property string valueFriendlyName: pluginApi?.pluginSettings?.displayName || ""
  property string valueDeviceIdentifier: pluginApi?.pluginSettings?.deviceIdentifier || ""
  property string valueDeviceAddress: pluginApi?.pluginSettings?.deviceAddress || ""
  property string valueDeviceName: pluginApi?.pluginSettings?.deviceName || ""
  property string valuePythonPath: pluginApi?.pluginSettings?.pythonPath || "python3"
  property string valueHelperPath: pluginApi?.pluginSettings?.helperScriptPath || bundledHelper
  property string valueMrpCredentials: pluginApi?.pluginSettings?.mrpCredentials || ""
  property string valueCompanionCredentials: pluginApi?.pluginSettings?.companionCredentials || ""
  property string valueAirplayCredentials: pluginApi?.pluginSettings?.airplayCredentials || ""
  property int valuePollInterval: pluginApi?.pluginSettings?.pollInterval || 5000
  property int valueScanTimeout: pluginApi?.pluginSettings?.scanTimeout || 8

  property bool testingHelper: false
  property string testResult: ""
  property bool testSuccess: false

  readonly property var pluginMain: pluginApi?.mainInstance

  function saveSettings() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.displayName = valueFriendlyName.trim();
    pluginApi.pluginSettings.deviceIdentifier = valueDeviceIdentifier.trim();
    pluginApi.pluginSettings.deviceAddress = valueDeviceAddress.trim();
    pluginApi.pluginSettings.deviceName = valueDeviceName.trim();
    pluginApi.pluginSettings.pythonPath = valuePythonPath.trim();
    pluginApi.pluginSettings.helperScriptPath = valueHelperPath.trim() || bundledHelper;
    pluginApi.pluginSettings.mrpCredentials = valueMrpCredentials.trim();
    pluginApi.pluginSettings.companionCredentials = valueCompanionCredentials.trim();
    pluginApi.pluginSettings.airplayCredentials = valueAirplayCredentials.trim();
    pluginApi.pluginSettings.pollInterval = valuePollInterval;
    pluginApi.pluginSettings.scanTimeout = valueScanTimeout;
    pluginApi.saveSettings();
    pluginMain?.refresh();
  }

  function buildHelperArgs() {
    var args = [valuePythonPath, valueHelperPath || bundledHelper, "--command", "state", "--scan-timeout", String(valueScanTimeout)];
    if (valueDeviceIdentifier)
      args.push("--identifier", valueDeviceIdentifier.trim());
    if (valueDeviceAddress)
      args.push("--address", valueDeviceAddress.trim());
    if (valueDeviceName)
      args.push("--name", valueDeviceName.trim());
    if (valueMrpCredentials)
      args.push("--mrp-credentials", valueMrpCredentials.trim());
    if (valueCompanionCredentials)
      args.push("--companion-credentials", valueCompanionCredentials.trim());
    if (valueAirplayCredentials)
      args.push("--airplay-credentials", valueAirplayCredentials.trim());
    return args;
  }

  function testHelper() {
    if (!valuePythonPath || !(valueHelperPath || bundledHelper)) {
      testResult = "Set python path and helper script first.";
      testSuccess = false;
      return;
    }
    testingHelper = true;
    testResult = pluginApi?.tr("status.connecting") || "Connecting...";
    testSuccess = false;
    const proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', root);
    proc.command = buildHelperArgs();
    proc.stdout = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stdout");
    proc.stderr = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stderr");
    proc.exited.connect(function (exitCode) {
      testingHelper = false;
      const out = String(proc.stdout.text || "");
      const err = String(proc.stderr.text || "");
      let payload = null;
      try {
        payload = JSON.parse(out);
      } catch (e) {
        payload = null;
      }
      const success = payload && payload.success !== undefined ? payload.success : exitCode === 0;
      testSuccess = success;
      if (success) {
        const title = payload?.state?.title || "Success";
        testResult = `Connected: ${title}`;
      } else {
        testResult = payload?.error || err || "Helper failed";
      }
      proc.destroy();
    });
    proc.running = true;
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Control Apple TV devices directly via pyatv."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.helper-hint") || "Install pyatv (pip install pyatv) and pair your Apple TV. The bundled helper script expects valid MRP credentials."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NTextInput {
    label: "Display name"
    placeholderText: "Living Room Apple TV"
    text: valueFriendlyName
    onTextChanged: valueFriendlyName = text
  }

  NTextInput {
    label: "Device identifier"
    placeholderText: "0x0000000000000000"
    text: valueDeviceIdentifier
    onTextChanged: valueDeviceIdentifier = text
  }

  NTextInput {
    label: "Device IP address"
    placeholderText: "192.168.1.50"
    text: valueDeviceAddress
    onTextChanged: valueDeviceAddress = text
  }

  NTextInput {
    label: "Device name"
    placeholderText: "Apple TV"
    text: valueDeviceName
    onTextChanged: valueDeviceName = text
  }

  NTextInput {
    label: "Python executable"
    placeholderText: "python3"
    text: valuePythonPath
    onTextChanged: valuePythonPath = text
  }

  NTextInput {
    label: "Helper script path"
    placeholderText: bundledHelper
    text: valueHelperPath
    onTextChanged: valueHelperPath = text
  }

  NTextInput {
    label: "MRP credentials"
    placeholderText: "Paste output from atvremote pair"
    text: valueMrpCredentials
    wrapMode: TextEdit.Wrap
    onTextChanged: valueMrpCredentials = text
  }

  NTextInput {
    label: "Companion credentials"
    placeholderText: "Optional"
    text: valueCompanionCredentials
    wrapMode: TextEdit.Wrap
    onTextChanged: valueCompanionCredentials = text
  }

  NTextInput {
    label: "AirPlay credentials"
    placeholderText: "Optional"
    text: valueAirplayCredentials
    wrapMode: TextEdit.Wrap
    onTextChanged: valueAirplayCredentials = text
  }

  RowLayout {
    spacing: Style.marginM

    NNumberInput {
      Layout.fillWidth: true
      label: "Polling interval (ms)"
      value: valuePollInterval
      from: 2000
      to: 15000
      stepSize: 500
      onValueChanged: valuePollInterval = value
    }

    NNumberInput {
      Layout.fillWidth: true
      label: "Scan timeout (s)"
      value: valueScanTimeout
      from: 3
      to: 30
      stepSize: 1
      onValueChanged: valueScanTimeout = value
    }
  }

  RowLayout {
    spacing: Style.marginM

    NButton {
      text: testingHelper ? (pluginApi?.tr("status.connecting") || "Connecting...") : "Test helper"
      enabled: !testingHelper
      onClicked: testHelper()
    }

    NText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      visible: testResult !== ""
      text: testResult
      color: testSuccess ? Color.mPrimary : Color.mError
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
