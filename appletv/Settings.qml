import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  spacing: Style.marginL
  implicitWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth

  readonly property string bundledHelper: pluginApi?.pluginDir ? pluginApi.pluginDir + "/helper/appletv_helper.py" : ""
  readonly property string bundledHelperProject: pluginApi?.pluginDir ? pluginApi.pluginDir + "/helper" : ""

  property string valueFriendlyName: ""
  property string valueDeviceIdentifier: ""
  property string valueDeviceAddress: ""
  property string valueDeviceName: ""
  property bool valueUseUvHelper: true
  property string valueUvPath: "uv"
  property string valuePythonPath: "python3"
  property string valueHelperPath: ""
  property string valueMrpCredentials: ""
  property string valueCompanionCredentials: ""
  property string valueAirplayCredentials: ""
  property int valuePollInterval: 5000
  property int valueScanTimeout: 8

  property bool testingHelper: false
  property string testResult: ""
  property bool testSuccess: false

  readonly property var pluginMain: pluginApi?.mainInstance

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined && pluginApi.pluginSettings[key] !== null)
      return pluginApi.pluginSettings[key];
    if (defaultSettings && defaultSettings[key] !== undefined && defaultSettings[key] !== null)
      return defaultSettings[key];
    return fallback;
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return;
    valueFriendlyName = getSetting("displayName", "") || "";
    valueDeviceIdentifier = getSetting("deviceIdentifier", "") || "";
    valueDeviceAddress = getSetting("deviceAddress", "") || "";
    valueDeviceName = getSetting("deviceName", "") || "";
    valueUseUvHelper = getSetting("useUvHelper", true) !== false;
    valueUvPath = getSetting("uvPath", "uv") || "uv";
    valuePythonPath = getSetting("pythonPath", "python3") || "python3";
    valueHelperPath = getSetting("helperScriptPath", bundledHelper) || bundledHelper;
    valueMrpCredentials = getSetting("mrpCredentials", "") || "";
    valueCompanionCredentials = getSetting("companionCredentials", "") || "";
    valueAirplayCredentials = getSetting("airplayCredentials", "") || "";
    valuePollInterval = getSetting("pollInterval", 5000) || 5000;
    valueScanTimeout = getSetting("scanTimeout", 8) || 8;
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
    var changed = false;

    function updateSetting(key, newValue) {
      if (settings[key] !== newValue) {
        settings[key] = newValue;
        changed = true;
      }
    }

    updateSetting("displayName", valueFriendlyName.trim());
    updateSetting("deviceIdentifier", valueDeviceIdentifier.trim());
    updateSetting("deviceAddress", valueDeviceAddress.trim());
    updateSetting("deviceName", valueDeviceName.trim());
    updateSetting("useUvHelper", !!valueUseUvHelper);
    updateSetting("uvPath", (valueUvPath || "").trim() || "uv");
    updateSetting("pythonPath", (valuePythonPath || "").trim() || "python3");
    updateSetting("helperScriptPath", (valueHelperPath || "").trim() || bundledHelper);
    updateSetting("mrpCredentials", valueMrpCredentials.trim());
    updateSetting("companionCredentials", valueCompanionCredentials.trim());
    updateSetting("airplayCredentials", valueAirplayCredentials.trim());
    updateSetting("pollInterval", Math.max(2000, Math.min(15000, Number(valuePollInterval) || 5000)));
    updateSetting("scanTimeout", Math.max(3, Math.min(30, Number(valueScanTimeout) || 8)));

    if (!changed)
      return;

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();
    pluginMain?.refresh();
  }

  function buildHelperArgs() {
    var args = [];
    if (valueUseUvHelper) {
      args = [valueUvPath || "uv", "run", "--project", bundledHelperProject, "appletv-helper", "--command", "state", "--scan-timeout", String(valueScanTimeout)];
    } else {
      args = [valuePythonPath || "python3", valueHelperPath || bundledHelper, "--command", "state", "--scan-timeout", String(valueScanTimeout)];
    }
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
    if (valueUseUvHelper && !(valueUvPath && bundledHelperProject)) {
      testResult = "Set uv path or disable uv usage.";
      testSuccess = false;
      return;
    }
    if (!valueUseUvHelper && (!valuePythonPath || !(valueHelperPath || bundledHelper))) {
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
    text: pluginApi?.tr("settings.helper-hint") || "Install uv (https://github.com/astral-sh/uv) once, then Noctalia will automatically manage the helper environment and pyatv dependency."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NCheckBox {
    text: "Use uv helper runtime (recommended)"
    checked: valueUseUvHelper
    onToggled: valueUseUvHelper = checked
  }

  NTextInput {
    visible: valueUseUvHelper
    label: "uv executable"
    placeholderText: "uv"
    text: valueUvPath
    onTextChanged: valueUvPath = text
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

  ColumnLayout {
    visible: !valueUseUvHelper
    spacing: Style.marginS

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

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: "Polling interval (ms)"
        color: Color.mOnSurface
      }

      SpinBox {
        Layout.fillWidth: true
        editable: true
        inputMethodHints: Qt.ImhDigitsOnly
        from: 2000
        to: 15000
        stepSize: 500
        value: valuePollInterval
        onValueChanged: valuePollInterval = value
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: "Scan timeout (s)"
        color: Color.mOnSurface
      }

      SpinBox {
        Layout.fillWidth: true
        editable: true
        inputMethodHints: Qt.ImhDigitsOnly
        from: 3
        to: 30
        stepSize: 1
        value: valueScanTimeout
        onValueChanged: valueScanTimeout = value
      }
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
