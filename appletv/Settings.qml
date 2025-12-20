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
  property string valueCompanionCredentials: ""
  property string valueAirplayCredentials: ""
  property int valuePollInterval: 5000
  property int valueScanTimeout: 8
  property string valuePairProtocol: "companion"
  property string valuePairPin: ""

  property bool testingHelper: false
  property string testResult: ""
  property bool testSuccess: false
  property bool scanningDevices: false
  property string scanResult: ""
  property bool scanSuccess: false
  property var scanResults: []
  property int selectedScanIndex: -1
  property bool pairingDevice: false
  property string pairResult: ""
  property bool pairSuccess: false
  property var pairingProcess: null
  property bool waitingForPairPin: false

  readonly property var pluginMain: pluginApi?.mainInstance

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined && pluginApi.pluginSettings[key] !== null)
      return pluginApi.pluginSettings[key];
    if (defaultSettings && defaultSettings[key] !== undefined && defaultSettings[key] !== null)
      return defaultSettings[key];
    return fallback;
  }

  function trOrFallback(key, fallback, interpolations) {
    if (!pluginApi || !pluginApi.tr)
      return fallback;
    const value = pluginApi.tr(key, interpolations);
    if (!value || String(value).startsWith("##"))
      return fallback;
    return value;
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
      args = [valueUvPath || "uv", "run", "--project", bundledHelperProject, "--", "python", bundledHelper, "--command", "state", "--scan-timeout", String(valueScanTimeout)];
    } else {
      args = [valuePythonPath || "python3", valueHelperPath || bundledHelper, "--command", "state", "--scan-timeout", String(valueScanTimeout)];
    }
    if (valueDeviceIdentifier)
      args.push("--identifier", valueDeviceIdentifier.trim());
    if (valueDeviceAddress)
      args.push("--address", valueDeviceAddress.trim());
    if (valueDeviceName)
      args.push("--name", valueDeviceName.trim());
    if (valueCompanionCredentials)
      args.push("--companion-credentials", valueCompanionCredentials.trim());
    if (valueAirplayCredentials)
      args.push("--airplay-credentials", valueAirplayCredentials.trim());
    return args;
  }

  function buildScanArgs() {
    if (valueUseUvHelper) {
      return [valueUvPath || "uv", "run", "--project", bundledHelperProject, "--", "python", bundledHelper, "--command", "scan", "--scan-timeout", String(valueScanTimeout)];
    }
    return [valuePythonPath || "python3", valueHelperPath || bundledHelper, "--command", "scan", "--scan-timeout", String(valueScanTimeout)];
  }

  function buildPairArgs(includePin) {
    var args = [];
    if (valueUseUvHelper) {
      args = [valueUvPath || "uv", "run", "--project", bundledHelperProject, "--", "python", bundledHelper, "--command", "pair"];
    } else {
      args = [valuePythonPath || "python3", valueHelperPath || bundledHelper, "--command", "pair"];
    }
    args.push("--protocol", valuePairProtocol || "companion");
    if (includePin && valuePairPin)
      args.push("--pin", valuePairPin.trim());
    if (valueDeviceIdentifier)
      args.push("--identifier", valueDeviceIdentifier.trim());
    if (valueDeviceAddress)
      args.push("--address", valueDeviceAddress.trim());
    if (valueDeviceName)
      args.push("--name", valueDeviceName.trim());
    return args;
  }

  function testHelper() {
    if (valueUseUvHelper && !(valueUvPath && bundledHelperProject)) {
      testResult = trOrFallback("errors.uv-missing", "Set uv path or disable uv usage.");
      testSuccess = false;
      return;
    }
    if (!valueUseUvHelper && (!valuePythonPath || !(valueHelperPath || bundledHelper))) {
      testResult = trOrFallback("errors.python-missing", "Set python path and helper script first.");
      testSuccess = false;
      return;
    }
    testingHelper = true;
    testResult = trOrFallback("status.connecting", "Connecting...");
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
        testResult = trOrFallback("status.connected-to", `Connected: ${title}`, {
                                    "title": title
                                  });
      } else {
        testResult = payload?.error || err || trOrFallback("errors.helper-failed", "Helper failed");
      }
      proc.destroy();
    });
    proc.running = true;
  }

  function scanDevices() {
    if (valueUseUvHelper && !(valueUvPath && bundledHelperProject)) {
      scanResult = trOrFallback("errors.uv-missing", "Set uv path or disable uv usage.");
      scanSuccess = false;
      return;
    }
    if (!valueUseUvHelper && (!valuePythonPath || !(valueHelperPath || bundledHelper))) {
      scanResult = trOrFallback("errors.python-missing", "Set python path and helper script first.");
      scanSuccess = false;
      return;
    }
    scanningDevices = true;
    scanResult = trOrFallback("settings.scan.in-progress", "Scanning...");
    scanSuccess = false;
    scanResults = [];
    selectedScanIndex = -1;
    const proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', root);
    proc.command = buildScanArgs();
    proc.stdout = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stdout");
    proc.stderr = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stderr");
    proc.exited.connect(function (exitCode) {
      scanningDevices = false;
      const out = String(proc.stdout.text || "");
      const err = String(proc.stderr.text || "");
      let payload = null;
      try {
        payload = JSON.parse(out);
      } catch (e) {
        payload = null;
      }
      const success = payload && payload.success !== undefined ? payload.success : exitCode === 0;
      scanSuccess = success;
      if (success) {
        scanResults = payload?.devices || [];
        selectedScanIndex = scanResults.length > 0 ? 0 : -1;
        scanResult = scanResults.length > 0
            ? (trOrFallback("settings.scan.found", `Found ${scanResults.length} devices`, { "count": scanResults.length }))
            : trOrFallback("settings.scan.no-devices", "No devices found");
      } else {
        scanResult = payload?.error || err || trOrFallback("errors.scan-failed", "Scan failed");
      }
      proc.destroy();
    });
    proc.running = true;
  }

  function applySelectedDevice() {
    if (!scanResults || selectedScanIndex < 0 || selectedScanIndex >= scanResults.length)
      return;
    const device = scanResults[selectedScanIndex];
    valueDeviceIdentifier = device.identifier || "";
    valueDeviceAddress = device.address || "";
    valueDeviceName = device.name || "";
    if (!valueFriendlyName && device.name)
      valueFriendlyName = device.name;
  }

  function startPairing() {
    if (pairingDevice || pairingProcess)
      return;
    pairingDevice = true;
    waitingForPairPin = true;
    pairResult = trOrFallback("settings.pair.waiting", "Waiting for PIN...");
    pairSuccess = false;
    const proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', root);
    proc.stdinEnabled = true;
    proc.command = buildPairArgs(false);
    proc.stdout = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stdout");
    proc.stderr = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stderr");
    pairingProcess = proc;
    proc.exited.connect(function (exitCode) {
      pairingDevice = false;
      waitingForPairPin = false;
      pairingProcess = null;
      const out = String(proc.stdout.text || "");
      const err = String(proc.stderr.text || "");
      let payload = null;
      try {
        payload = JSON.parse(out);
      } catch (e) {
        payload = null;
      }
      const success = payload && payload.success !== undefined ? payload.success : exitCode === 0;
      pairSuccess = success;
      if (success) {
        const credentials = payload?.credentials || "";
        if (valuePairProtocol === "companion") {
          valueCompanionCredentials = credentials;
        } else if (valuePairProtocol === "airplay") {
          valueAirplayCredentials = credentials;
        }
        pairResult = trOrFallback("settings.pair.success", "Pairing complete. Credentials saved.");
      } else {
        pairResult = payload?.error || err || trOrFallback("errors.pair-failed", "Pairing failed");
      }
      proc.destroy();
    });
    proc.running = true;
  }

  function submitPairPin() {
    if (!pairingProcess)
      return;
    if (!valuePairPin || valuePairPin.trim() === "") {
      pairResult = trOrFallback("errors.pair-pin-missing", "Pairing pin is required.");
      pairSuccess = false;
      return;
    }
    pairResult = trOrFallback("settings.pair.in-progress", "Pairing...");
    try {
      pairingProcess.write(valuePairPin.trim() + "\n");
      pairingProcess.stdinEnabled = false;
    } catch (e) {
      pairResult = trOrFallback("errors.pair-failed", "Pairing failed");
      pairSuccess = false;
    }
  }

  function formatScanLabel(device) {
    if (!device)
      return "";
    const parts = [];
    if (device.name)
      parts.push(device.name);
    if (device.address)
      parts.push(device.address);
    if (device.identifier)
      parts.push(device.identifier);
    return parts.join(" - ");
  }

  NText {
    text: trOrFallback("settings.description", "Control Apple TV devices directly via pyatv.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: trOrFallback("settings.helper-hint", "Install uv (https://github.com/astral-sh/uv) once, then Noctalia will automatically manage the helper environment and pyatv dependency.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NCollapsible {
    Layout.fillWidth: true
    label: trOrFallback("settings.section.connection", "Connection")
    description: trOrFallback("settings.section.connection-hint", "Helper runtime and advanced options.")
    expanded: true

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        label: trOrFallback("settings.use-uv", "Use uv helper runtime (recommended)")
        checked: valueUseUvHelper
        onToggled: checked => valueUseUvHelper = checked
      }

      NTextInput {
        visible: valueUseUvHelper
        label: trOrFallback("settings.uv-executable", "uv executable")
        placeholderText: trOrFallback("settings.uv-executable.placeholder", "uv")
        text: valueUvPath
        onTextChanged: valueUvPath = text
      }

      ColumnLayout {
        visible: !valueUseUvHelper
        spacing: Style.marginS

        NTextInput {
          label: trOrFallback("settings.python-executable", "Python executable")
          placeholderText: trOrFallback("settings.python-executable.placeholder", "python3")
          text: valuePythonPath
          onTextChanged: valuePythonPath = text
        }

        NTextInput {
          label: trOrFallback("settings.helper-script-path", "Helper script path")
          placeholderText: bundledHelper
          text: valueHelperPath
          onTextChanged: valueHelperPath = text
        }
      }

      RowLayout {
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: trOrFallback("settings.polling-interval", "Polling interval (ms)")
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
            text: trOrFallback("settings.scan-timeout", "Scan timeout (s)")
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
          text: testingHelper ? trOrFallback("status.connecting", "Connecting...") : trOrFallback("settings.test-helper", "Test helper")
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
    }
  }

  NCollapsible {
    Layout.fillWidth: true
    label: trOrFallback("settings.section.device", "Device")
    description: trOrFallback("settings.section.device-hint", "Scan to find devices or enter details manually.")
    expanded: true

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      RowLayout {
        spacing: Style.marginM

        NButton {
          text: scanningDevices ? trOrFallback("settings.scan.in-progress", "Scanning...") : trOrFallback("settings.scan.label", "Scan for devices")
          enabled: !scanningDevices
          onClicked: scanDevices()
        }

        NText {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          visible: scanResult !== ""
          text: scanResult
          color: scanSuccess ? Color.mPrimary : Color.mError
          pointSize: Style.fontSizeS
        }
      }

      NComboBox {
        Layout.fillWidth: true
        enabled: scanResults?.length > 0

        model: {
          const results = scanResults || [];
          if (results.length === 0) {
            return [
                  {
                    key: "-1",
                    name: trOrFallback("settings.scan.no-devices", "No devices found")
                  }
                ];
          }
          return results.map((d, idx) => ({
                                            key: String(idx),
                                            name: formatScanLabel(d)
                                          }));
        }

        currentKey: selectedScanIndex >= 0 ? String(selectedScanIndex) : "-1"

        onSelected: key => {
                      const index = Number(key);
                      selectedScanIndex = isNaN(index) ? -1 : index;
                    }
      }

      RowLayout {
        spacing: Style.marginM

        NButton {
          text: trOrFallback("settings.scan.apply", "Use selected device")
          enabled: selectedScanIndex >= 0
          onClicked: applySelectedDevice()
        }
      }

      NTextInput {
        label: trOrFallback("settings.display-name", "Display name")
        placeholderText: trOrFallback("settings.display-name.placeholder", "Living Room Apple TV")
        text: valueFriendlyName
        onTextChanged: valueFriendlyName = text
      }

      NTextInput {
        label: trOrFallback("settings.device-identifier", "Device identifier")
        placeholderText: trOrFallback("settings.device-identifier.placeholder", "0x0000000000000000")
        text: valueDeviceIdentifier
        onTextChanged: valueDeviceIdentifier = text
      }

      NTextInput {
        label: trOrFallback("settings.device-address", "Device IP address")
        placeholderText: trOrFallback("settings.device-address.placeholder", "192.168.1.50")
        text: valueDeviceAddress
        onTextChanged: valueDeviceAddress = text
      }

      NTextInput {
        label: trOrFallback("settings.device-name", "Device name")
        placeholderText: trOrFallback("settings.device-name.placeholder", "Apple TV")
        text: valueDeviceName
        onTextChanged: valueDeviceName = text
      }
    }
  }

  NCollapsible {
    Layout.fillWidth: true
    label: trOrFallback("settings.section.credentials", "Credentials")
    description: trOrFallback("settings.section.credentials-hint", "Companion is recommended. AirPlay is optional.")
    expanded: false

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NComboBox {
        Layout.fillWidth: true
        model: [
        {
          key: "companion",
          name: trOrFallback("settings.pair.protocol.companion", "Companion (recommended)")
        },
        {
          key: "airplay",
          name: trOrFallback("settings.pair.protocol.airplay", "AirPlay (optional)")
        }
      ]
      currentKey: valuePairProtocol || "companion"
        onSelected: key => valuePairProtocol = key
      }

      NTextInput {
        label: trOrFallback("settings.pair.pin", "Pairing PIN")
        placeholderText: trOrFallback("settings.pair.pin.placeholder", "1234")
        text: valuePairPin
        onTextChanged: valuePairPin = text
      }

      RowLayout {
        spacing: Style.marginM

        NButton {
          text: trOrFallback("settings.pair.start", "Start pairing")
          enabled: !pairingDevice && !pairingProcess
          onClicked: startPairing()
        }

        NButton {
          text: trOrFallback("settings.pair.submit", "Submit PIN")
          enabled: !!pairingProcess && !pairingDevice
          onClicked: submitPairPin()
        }

        NText {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          visible: pairResult !== ""
          text: pairResult
          color: pairSuccess ? Color.mPrimary : Color.mError
          pointSize: Style.fontSizeS
        }
      }

      NTextInput {
        label: trOrFallback("settings.companion-credentials", "Companion credentials")
        placeholderText: trOrFallback("settings.optional", "Optional")
        text: valueCompanionCredentials
        onTextChanged: valueCompanionCredentials = text
      }

      NTextInput {
        label: trOrFallback("settings.airplay-credentials", "AirPlay credentials")
        placeholderText: trOrFallback("settings.optional", "Optional")
        text: valueAirplayCredentials
        onTextChanged: valueAirplayCredentials = text
      }
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
