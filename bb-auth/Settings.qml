import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property int basePreferredWidth: Math.round(520 * Style.uiScaleRatio)
    readonly property int fontSafePreferredWidth: Math.round(appFontMetrics.averageCharacterWidth * 56 + Style.marginL * 2)
    readonly property var defaultSettings: (pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings) || {
    }
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    // Local state
    property string valueSettingsPanelMode: "centered"
    property bool valueCloseInstantly: false
    property bool valueColorizeIcons: true
    property bool isLoading: false

    // --- i18n helper (catches !!key!! and ##key## markers) ---
    function tr(key, fallback) {
        if (!pluginApi || !pluginApi.tr)
            return fallback;

        var translated = pluginApi.tr(key);
        if (!translated)
            return fallback;

        if (typeof translated === "string" && translated.length >= 4) {
            var prefix = translated.slice(0, 2);
            var suffix = translated.slice(translated.length - 2);
            if ((prefix === "##" && suffix === "##") || (prefix === "!!" && suffix === "!!"))
                return fallback;

        }
        return translated;
    }

    // --- Settings helpers ---
    function getSetting(key, fallback) {
        if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
            return pluginApi.pluginSettings[key];

        if (defaultSettings && defaultSettings[key] !== undefined)
            return defaultSettings[key];

        return fallback;
    }

    function syncFromPlugin() {
        if (!pluginApi)
            return ;

        isLoading = true;
        valueSettingsPanelMode = getSetting("settingsPanelMode", "centered") || "centered";
        valueCloseInstantly = getSetting("closeInstantly", false) === true;
        valueColorizeIcons = getSetting("colorizeIcons", true) !== false;
        isLoading = false;
    }

    function saveSettings() {
        if (!pluginApi)
            return ;

        var settings = pluginApi.pluginSettings || {
        };
        settings.settingsPanelMode = valueSettingsPanelMode;
        settings.closeInstantly = valueCloseInstantly;
        settings.colorizeIcons = valueColorizeIcons;
        pluginApi.pluginSettings = settings;
        pluginApi.saveSettings();
        pluginMain && pluginMain.refresh();
    }

    spacing: Style.marginL
    Layout.fillWidth: true
    Layout.minimumWidth: Math.round(360 * Style.uiScaleRatio)
    Layout.preferredWidth: Math.max(basePreferredWidth, fontSafePreferredWidth)
    onPluginApiChanged: syncFromPlugin()
    Component.onCompleted: syncFromPlugin()

    FontMetrics {
        id: appFontMetrics

        font: Qt.application.font
    }

    Connections {
        function onPluginSettingsChanged() {
            syncFromPlugin();
        }

        target: pluginApi
    }

    // --- Header ---
    NText {
        text: tr("settings.description", "Polkit and GPG authentication agent for Noctalia.")
        wrapMode: Text.WordWrap
        color: Color.mOnSurface
        Layout.fillWidth: true
    }

    NDivider {
        Layout.fillWidth: true
    }

    // --- Section 1: Dialog Behavior ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Dialog behavior"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
        }

        NText {
            text: "Configure how the authentication dialog appears and behaves."
            wrapMode: Text.WordWrap
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
        }

    }

    NComboBox {
        Layout.fillWidth: true
        label: tr("settings.panel-mode", "Panel mode")
        description: tr("settings.panel-mode-desc", "Choose how the authentication dialog appears.")
        model: [{
            "key": "attached",
            "name": tr("settings.panel-mode-attached", "Panel attached to bar")
        }, {
            "key": "centered",
            "name": tr("settings.panel-mode-centered", "Centered panel")
        }, {
            "key": "window",
            "name": tr("settings.panel-mode-window", "Separate window")
        }]
        currentKey: root.valueSettingsPanelMode
        onSelected: function(key) {
            if (root.isLoading)
                return ;

            root.valueSettingsPanelMode = key;
            root.saveSettings();
        }
    }

    NToggle {
        label: tr("settings.close-instantly", "Close instantly on success")
        description: tr("settings.close-instantly-desc", "Skip the success animation and close the panel immediately after verification.")
        checked: root.valueCloseInstantly
        Layout.fillWidth: true
        onToggled: function(checked) {
            if (root.isLoading)
                return ;

            root.valueCloseInstantly = checked;
            root.saveSettings();
        }
    }

    NToggle {
        label: tr("settings.colorize-icons", "Colorize icons")
        description: tr("settings.colorize-icons-desc", "Apply theme colors to requestor icons in the auth dialog.")
        checked: root.valueColorizeIcons
        Layout.fillWidth: true
        onToggled: function(checked) {
            if (root.isLoading)
                return ;

            root.valueColorizeIcons = checked;
            root.saveSettings();
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // --- Section 2: Status ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Status"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
        }

        // Provider status row
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
                width: Math.round(8 * Style.uiScaleRatio)
                height: width
                radius: width / 2
                color: {
                    if (!(pluginMain && pluginMain.providerRegistered))
                        return Color.mError;

                    if (!(pluginMain && pluginMain.providerActivityKnown))
                        return Color.mTertiary;

                    return (pluginMain && pluginMain.providerActive) || true ? Color.mPrimary : Color.mOutline;
                }
                Layout.alignment: Qt.AlignVCenter
            }

            NText {
                text: {
                    if (!(pluginMain && pluginMain.providerRegistered))
                        return "Disconnected from auth daemon";

                    if (!(pluginMain && pluginMain.providerActivityKnown))
                        return "Negotiating with auth daemon";

                    return (pluginMain && pluginMain.providerActive) || true ? "Active — ready to handle requests" : "Standby — another agent is active";
                }
                color: Color.mOnSurface
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

        }

        // Conflict policy
        NText {
            Layout.fillWidth: true
            text: "Conflict policy: " + ((pluginMain && pluginMain.agentConflictMode) || "session")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

    }

    NDivider {
        Layout.fillWidth: true
    }

    // --- Section 3: About ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "About"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
        }

        NText {
            Layout.fillWidth: true
            text: (pluginApi && pluginApi.manifest && pluginApi.manifest.name || "BB Auth") + " v" + (pluginApi && pluginApi.manifest && pluginApi.manifest.version || "0.0.0")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
        }

        NText {
            Layout.fillWidth: true
            text: (pluginApi && pluginApi.manifest && pluginApi.manifest.description) || ""
            visible: text !== ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

    }

    Item {
        Layout.fillHeight: true
    }

}
