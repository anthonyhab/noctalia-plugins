import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ScrollView {
  id: scrollView
  property var pluginApi: null

  implicitWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth
  Layout.fillHeight: true

  contentHeight: contentColumn.implicitHeight

  ColumnLayout {
    id: contentColumn
    width: scrollView.width
    spacing: Style.marginL

    property alias pluginApi: scrollView.pluginApi

  // Local state - track changes before saving
  property string valueHaUrl: pluginApi?.pluginSettings?.haUrl || pluginApi?.manifest?.metadata?.defaultSettings?.haUrl || ""
  property string valueHaToken: pluginApi?.pluginSettings?.haToken || pluginApi?.manifest?.metadata?.defaultSettings?.haToken || ""
  property string valueDefaultMediaPlayer: pluginApi?.pluginSettings?.defaultMediaPlayer || pluginApi?.manifest?.metadata?.defaultSettings?.defaultMediaPlayer || ""
  property string valueBarWidgetMaxWidth: (pluginApi?.pluginSettings?.barWidgetMaxWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetMaxWidth ?? 200).toString()
  property bool valueBarWidgetUseFixedWidth: pluginApi?.pluginSettings?.barWidgetUseFixedWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetUseFixedWidth ?? false
  property string valueBarWidgetScrollingMode: pluginApi?.pluginSettings?.barWidgetScrollingMode || pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetScrollingMode || "hover"
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
    pluginApi.pluginSettings.haUrl = contentColumn.valueHaUrl.trim().replace(/\/+$/, ""); // Remove trailing slashes
    pluginApi.pluginSettings.haToken = contentColumn.valueHaToken.trim();
    pluginApi.pluginSettings.defaultMediaPlayer = contentColumn.valueDefaultMediaPlayer;
    pluginApi.pluginSettings.barWidgetMaxWidth = parseInt(contentColumn.valueBarWidgetMaxWidth, 10) || pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetMaxWidth || 200;
    pluginApi.pluginSettings.barWidgetUseFixedWidth = contentColumn.valueBarWidgetUseFixedWidth;
    pluginApi.pluginSettings.barWidgetScrollingMode = contentColumn.valueBarWidgetScrollingMode;

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
    text: contentColumn.valueHaUrl
    onTextChanged: {
      contentColumn.valueHaUrl = text;
    }
  }

  NTextInput {
    label: pluginApi?.tr("settings.token") || "Access Token"
    placeholderText: "eyJ0eXAiOiJKV1..."
    text: contentColumn.valueHaToken
    inputItem.echoMode: TextInput.Password
    onTextChanged: {
      contentColumn.valueHaToken = text;
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
      const player = players.find(p => p.entity_id === contentColumn.valueDefaultMediaPlayer);
      return player ? player.entity_id : "";
    }

    onSelected: key => {
                  contentColumn.valueDefaultMediaPlayer = key;
                }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: pluginApi?.tr("settings.bar-widget.title") || "Bar widget"
    color: Color.mOnSurface
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
  }

  NText {
    text: pluginApi?.tr("settings.bar-widget.description") || "Adjust how the bar widget displays long titles."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NTextInput {
    label: pluginApi?.tr("settings.bar-widget.max-width.label") || "Maximum width"
    description: pluginApi?.tr("settings.bar-widget.max-width.description") || "Sets the maximum horizontal size of the widget. The widget will shrink to fit shorter content."
    placeholderText: pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetMaxWidth?.toString() || "200"
    text: contentColumn.valueBarWidgetMaxWidth
    inputItem.inputMethodHints: Qt.ImhDigitsOnly
    onTextChanged: contentColumn.valueBarWidgetMaxWidth = text
  }

  NToggle {
    label: pluginApi?.tr("settings.bar-widget.use-fixed-width.label") || "Use fixed width"
    description: pluginApi?.tr("settings.bar-widget.use-fixed-width.description") || "When enabled, the widget will always use the maximum width instead of dynamically adjusting to content."
    checked: contentColumn.valueBarWidgetUseFixedWidth
    onToggled: checked => contentColumn.valueBarWidgetUseFixedWidth = checked
  }

  NComboBox {
    label: pluginApi?.tr("settings.bar-widget.scrolling-mode.label") || "Scrolling mode"
    description: pluginApi?.tr("settings.bar-widget.scrolling-mode.description") || "Control when text scrolling is enabled for long titles."
    model: [
      {
        "key": "always",
        "name": pluginApi?.tr("options.scrolling-modes.always") || "Always scroll"
      },
      {
        "key": "hover",
        "name": pluginApi?.tr("options.scrolling-modes.hover") || "Scroll on hover"
      },
      {
        "key": "never",
        "name": pluginApi?.tr("options.scrolling-modes.never") || "Never scroll"
      }
    ]
    currentKey: contentColumn.valueBarWidgetScrollingMode
    onSelected: key => contentColumn.valueBarWidgetScrollingMode = key
  }

  }
}
