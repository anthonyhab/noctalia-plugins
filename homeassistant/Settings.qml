import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  // Local state - track changes before saving
  property string valueHaUrl: pluginApi?.pluginSettings?.haUrl || pluginApi?.manifest?.metadata?.defaultSettings?.haUrl || ""
  property string valueHaToken: pluginApi?.pluginSettings?.haToken || pluginApi?.manifest?.metadata?.defaultSettings?.haToken || ""
  property string valueDefaultMediaPlayer: pluginApi?.pluginSettings?.defaultMediaPlayer || pluginApi?.manifest?.metadata?.defaultSettings?.defaultMediaPlayer || ""
  property bool testingConnection: false
  property string testResult: ""
  property bool testSuccess: true

  readonly property var pluginMain: pluginApi?.mainInstance

  Component.onCompleted: {
    Logger.i("HomeAssistant", "Settings UI loaded");
  }

  // This function is called by the dialog to save settings
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("HomeAssistant", "Cannot save settings: pluginApi is null");
      return;
    }

    // Update the plugin settings object
    pluginApi.pluginSettings.haUrl = root.valueHaUrl.trim().replace(/\/+$/, ""); // Remove trailing slashes
    pluginApi.pluginSettings.haToken = root.valueHaToken.trim();
    pluginApi.pluginSettings.defaultMediaPlayer = root.valueDefaultMediaPlayer;

    // Save to disk
    pluginApi.saveSettings();

    // Reconnect if main instance exists
    if (pluginMain) {
      pluginMain.reconnect();
    }

    Logger.i("HomeAssistant", "Settings saved successfully");
  }

  function testConnection() {
    if (!valueHaUrl || !valueHaToken) {
      testResult = pluginApi?.tr("errors.no-url") || "Please configure URL and token";
      testSuccess = false;
      return;
    }

    testingConnection = true;
    testResult = "";
    testSuccess = true;

    // Use XMLHttpRequest to test the REST API
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        testingConnection = false;
        if (xhr.status === 200) {
          testResult = pluginApi?.tr("settings.connection-success") || "Connected successfully";
          testSuccess = true;
        } else if (xhr.status === 401) {
          testResult = pluginApi?.tr("errors.auth-invalid") || "Invalid access token";
          testSuccess = false;
        } else {
          testResult = pluginApi?.tr("settings.connection-failed") || "Connection failed";
          testSuccess = false;
        }
      }
    };

    xhr.onerror = function () {
      testingConnection = false;
      testResult = pluginApi?.tr("settings.connection-failed") || "Connection failed";
      testSuccess = false;
    };

    const testUrl = valueHaUrl.trim().replace(/\/+$/, "") + "/api/";
    xhr.open("GET", testUrl);
    xhr.setRequestHeader("Authorization", "Bearer " + valueHaToken.trim());
    xhr.timeout = 10000;
    xhr.send();
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Connect to your Home Assistant instance to control media players."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.token-hint") || "Create a Long-Lived Access Token at Profile > Security in Home Assistant."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NTextInput {
    label: pluginApi?.tr("settings.url") || "Home Assistant URL"
    placeholderText: pluginApi?.tr("settings.url-placeholder") || "http://homeassistant.local:8123"
    text: root.valueHaUrl
    onTextChanged: {
      root.valueHaUrl = text;
    }
  }

  NTextInput {
    label: pluginApi?.tr("settings.token") || "Access Token"
    placeholderText: "eyJ0eXAiOiJKV1..."
    text: root.valueHaToken
    inputItem.echoMode: TextInput.Password
    onTextChanged: {
      root.valueHaToken = text;
    }
  }

  RowLayout {
    spacing: Style.marginM

    NButton {
      text: testingConnection ? (pluginApi?.tr("status.connecting") || "Connecting...") : (pluginApi?.tr("settings.test-connection") || "Test Connection")
      enabled: !testingConnection && valueHaUrl !== "" && valueHaToken !== ""
      onClicked: testConnection()
    }

    NText {
      visible: testResult !== ""
      text: testResult
      color: testSuccess ? Color.mPrimary : Color.mError
      pointSize: Style.fontSizeS
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: pluginApi?.tr("settings.default-player") || "Default Media Player"
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.default-player-hint") || "Select the media player to control by default."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NComboBox {
    Layout.fillWidth: true
    enabled: pluginMain?.mediaPlayers?.length > 0

    model: {
      const players = pluginMain?.mediaPlayers || [];
      if (players.length === 0) {
        return [
              {
                key: "",
                name: pluginApi?.tr("settings.no-players") || "No media players found"
              }
            ];
      }
      return players.map(p => ({
                                 key: p.entity_id,
                                 name: p.friendly_name || p.entity_id
                               }));
    }

    currentKey: {
      const players = pluginMain?.mediaPlayers || [];
      if (players.length === 0)
        return "";
      const player = players.find(p => p.entity_id === root.valueDefaultMediaPlayer);
      return player ? player.entity_id : "";
    }

    onSelected: key => {
                  root.valueDefaultMediaPlayer = key;
                }
  }

  Item {
    Layout.fillHeight: true
  }
}
