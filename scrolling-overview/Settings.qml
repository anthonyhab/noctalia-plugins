import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    property var pluginApi: null
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    property int rowsValue: getSetting("rows", 10)
    property int columnsValue: getSetting("columns", 1)
    property real scaleValue: getSetting("scale", 0.16)
    property int spacingValue: getSetting("workspaceSpacing", 10)
    property real dimValue: getSetting("dimOpacity", 0.72)
    property bool labelsValue: getSetting("showWorkspaceLabels", true)
    property bool allMonitorsValue: getSetting("showAllMonitors", false)
    property bool specialWsValue: getSetting("includeSpecialWorkspaces", false)
    property bool livePreviewValue: getSetting("useLivePreviews", true)

    function getSetting(key, fallback) {
        if (!pluginApi)
            return fallback;

        try {
            var value = undefined;
            if (pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
                value = pluginApi.pluginSettings[key];
            else if (pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings[key] !== undefined)
                value = pluginApi.manifest.metadata.defaultSettings[key];
            return (value === undefined || value === null) ? fallback : value;
        } catch (e) {
            return fallback;
        }
    }

    function saveSetting(key, value) {
        if (pluginApi) {
            var settings = pluginApi.pluginSettings || ({
            });
            settings[key] = value;
            pluginApi.pluginSettings = settings;
        }
        if (pluginMain && pluginMain.refreshSettings)
            pluginMain.refreshSettings();

    }

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: root.width - Style.marginXL * 2
            spacing: Style.marginL
            anchors.margins: Style.marginL

            Text {
                text: "Scrolling Overview"
                color: Color.mOnSurface
                font.pixelSize: Style.fontSizeXL
                font.weight: Style.fontWeightSemiBold
            }

            Text {
                text: "A fresh vertical workspace overview with live window tiles and drag-to-move windows"
                color: Color.mOnSurfaceVariant
                font.pixelSize: Style.fontSizeM
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(Color.mOutline, 0.4)
            }

            GridLayout {
                columns: 3
                columnSpacing: Style.marginM
                rowSpacing: Style.marginM
                Layout.fillWidth: true

                Text {
                    text: "Rows"
                    color: Color.mOnSurface
                    font.pixelSize: Style.fontSizeM
                }

                SpinBox {
                    from: 1
                    to: 20
                    value: root.rowsValue
                    editable: true
                    onValueModified: {
                        root.rowsValue = value;
                        root.saveSetting("rows", value);
                    }
                }

                Text {
                    text: "How many workspaces are visible per group"
                    color: Color.mOnSurfaceVariant
                    font.pixelSize: Style.fontSizeS
                }

                Text {
                    text: "Columns"
                    color: Color.mOnSurface
                    font.pixelSize: Style.fontSizeM
                }

                SpinBox {
                    from: 1
                    to: 4
                    value: root.columnsValue
                    editable: true
                    onValueModified: {
                        root.columnsValue = value;
                        root.saveSetting("columns", value);
                    }
                }

                Text {
                    text: "Horizontal slots per row"
                    color: Color.mOnSurfaceVariant
                    font.pixelSize: Style.fontSizeS
                }

                Text {
                    text: "Scale"
                    color: Color.mOnSurface
                    font.pixelSize: Style.fontSizeM
                }

                Slider {
                    id: scaleSlider

                    from: 0.08
                    to: 0.35
                    stepSize: 0.01
                    value: root.scaleValue
                    Layout.fillWidth: true
                    onMoved: {
                        root.scaleValue = value;
                        root.saveSetting("scale", value);
                    }
                }

                Text {
                    text: Math.round(root.scaleValue * 100) + "%"
                    color: Color.mOnSurfaceVariant
                    font.pixelSize: Style.fontSizeS
                }

                Text {
                    text: "Spacing"
                    color: Color.mOnSurface
                    font.pixelSize: Style.fontSizeM
                }

                Slider {
                    from: 0
                    to: 28
                    stepSize: 1
                    value: root.spacingValue
                    Layout.fillWidth: true
                    onMoved: {
                        root.spacingValue = Math.round(value);
                        root.saveSetting("workspaceSpacing", root.spacingValue);
                    }
                }

                Text {
                    text: root.spacingValue + " px"
                    color: Color.mOnSurfaceVariant
                    font.pixelSize: Style.fontSizeS
                }

                Text {
                    text: "Backdrop opacity"
                    color: Color.mOnSurface
                    font.pixelSize: Style.fontSizeM
                }

                Slider {
                    from: 0.35
                    to: 0.9
                    stepSize: 0.01
                    value: root.dimValue
                    Layout.fillWidth: true
                    onMoved: {
                        root.dimValue = value;
                        root.saveSetting("dimOpacity", value);
                    }
                }

                Text {
                    text: Math.round(root.dimValue * 100) + "%"
                    color: Color.mOnSurfaceVariant
                    font.pixelSize: Style.fontSizeS
                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(Color.mOutline, 0.4)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Switch {
                    text: "Show workspace labels"
                    checked: root.labelsValue
                    onToggled: {
                        root.labelsValue = checked;
                        root.saveSetting("showWorkspaceLabels", checked);
                    }
                }

                Switch {
                    text: "Show on all monitors"
                    checked: root.allMonitorsValue
                    onToggled: {
                        root.allMonitorsValue = checked;
                        root.saveSetting("showAllMonitors", checked);
                    }
                }

                Switch {
                    text: "Include special workspaces"
                    checked: root.specialWsValue
                    onToggled: {
                        root.specialWsValue = checked;
                        root.saveSetting("includeSpecialWorkspaces", checked);
                    }
                }

                Switch {
                    text: "Use live previews"
                    checked: root.livePreviewValue
                    onToggled: {
                        root.livePreviewValue = checked;
                        root.saveSetting("useLivePreviews", checked);
                    }
                }

            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: Style.marginXL
            }

        }

    }

}
