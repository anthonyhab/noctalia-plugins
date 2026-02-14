import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    // === PREDICTIVE FIT CALCULATION ===
    // Calculate whether current settings would fit on the primary screen
    // This updates in real-time as the user adjusts settings

    id: root

    property var pluginApi: null
    readonly property var defaultSettings: (pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings) || ({
    })
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    // Get primary screen info (or first available screen)
    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenWidth: primaryScreen ? primaryScreen.width : 1920
    readonly property real screenHeight: primaryScreen ? primaryScreen.height : 1080
    readonly property real screenScale: primaryScreen ? (primaryScreen.scale || 1) : 1
    // Bar-aware margins (simplified - uses default bar height estimate)
    readonly property real barHeightEstimate: 40
    readonly property real marginXL: Style.marginXL
    readonly property real marginM: Style.marginM
    readonly property real barAwareMargin: {
        var pos = overviewPosition;
        // Conservative estimate: if bar is at same position as overview, add bar height
        if (pos === "top" || pos === "bottom")
            return marginXL + barHeightEstimate + marginM;

        return marginXL;
    }
    // Available space for the grid
    readonly property real availableWidth: (screenWidth / screenScale) - barAwareMargin * 2
    readonly property real availableHeight: (screenHeight / screenScale) - barAwareMargin * 2
    // Predicted workspace cell size (simplified calculation)
    readonly property real predictedCellWidth: (screenWidth / screenScale) * gridScale
    readonly property real predictedCellHeight: (screenHeight / screenScale) * gridScale
    readonly property real workspaceSpacing: gridSpacing
    readonly property real padding: 40 // 20px each side

    // Predicted grid natural size
    readonly property real predictedGridWidth: gridColumns * predictedCellWidth + (gridColumns - 1) * workspaceSpacing + padding
    readonly property real predictedGridHeight: gridRows * predictedCellHeight + (gridRows - 1) * workspaceSpacing + padding
    // Predicted fit scale (will the grid fit?)
    readonly property real predictedFitScale: Math.min(1, Math.min(availableWidth / Math.max(1, predictedGridWidth), availableHeight / Math.max(1, predictedGridHeight)))
    // True if settings would require shrinking to fit
    readonly property bool willRequireFitScaling: predictedFitScale < 0.999
    // Local state
    property int gridRows: 2
    property int gridColumns: 5
    property real gridScale: 0.16
    property bool hideEmptyRows: true

    property bool showScratchpadWorkspaces: false
    property int gridSpacing: 0
    property string overviewPosition: "top"


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

        gridRows = parseInt(getSetting("rows", 2)) || 2;
        gridColumns = parseInt(getSetting("columns", 5)) || 5;
        gridScale = parseFloat(getSetting("scale", 0.16)) || 0.16;
        hideEmptyRows = !!getSetting("hideEmptyRows", true);
        showScratchpadWorkspaces = !!getSetting("showScratchpadWorkspaces", false);
        gridSpacing = parseInt(getSetting("gridSpacing", 0)) || 0;
        overviewPosition = getSetting("position", "top") || "top";
    }


    function saveSettings() {
        if (!pluginApi)
            return ;

        var settings = pluginApi.pluginSettings || {
        };
        settings.rows = gridRows;
        settings.columns = gridColumns;
        settings.scale = gridScale;
        settings.hideEmptyRows = hideEmptyRows;
        settings.showScratchpadWorkspaces = showScratchpadWorkspaces;
        settings.gridSpacing = gridSpacing;
        settings.position = overviewPosition;
        pluginApi.pluginSettings = settings;

        pluginApi.saveSettings();
        pluginMain && pluginMain.refresh();
    }

    spacing: Style.marginL
    Layout.fillWidth: true
    Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)
    Layout.preferredWidth: Layout.minimumWidth
    onPluginApiChanged: syncFromPlugin()
    Component.onCompleted: syncFromPlugin()

    // Description
    NText {
        text: pluginApi && pluginApi.tr("plugin.description") || "Visual workspace overview with live window previews for Hyprland"
        wrapMode: Text.WordWrap
        color: Color.mOnSurface
    }

    NDivider {
        Layout.fillWidth: true
    }

    // === Workspace Grid ===
    NHeader {
        label: pluginApi && pluginApi.tr("settings.grid.title") || "Workspace Grid"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NSpinBox {
            Layout.fillWidth: true
            label: pluginApi && pluginApi.tr("settings.grid.rows.label") || "Rows"
            description: pluginApi && pluginApi.tr("settings.grid.rows.description") || "Number of workspace rows"
            from: 1
            to: 10
            value: root.gridRows
            onValueChanged: {
                if (root.gridRows !== value) {
                    root.gridRows = value;
                    root.saveSettings();
                }
            }
        }

        NSpinBox {
            Layout.fillWidth: true
            label: pluginApi && pluginApi.tr("settings.grid.columns.label") || "Columns"
            description: pluginApi && pluginApi.tr("settings.grid.columns.description") || "Number of workspace columns"
            from: 1
            to: 20
            value: root.gridColumns
            onValueChanged: {
                if (root.gridColumns !== value) {
                    root.gridColumns = value;
                    root.saveSettings();
                }
            }
        }

    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi && pluginApi.tr("settings.grid.scale.label") || "Scale"
        description: pluginApi && pluginApi.tr("settings.grid.scale.description") || "Overview scale factor"
        from: 0.05
        to: 0.5
        stepSize: 0.01
        value: root.gridScale
        text: value.toFixed(2)
        onMoved: (value) => {
            if (Math.abs(root.gridScale - value) > 0.001) {
                root.gridScale = value;
                root.saveSettings();
            }
        }
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi && pluginApi.tr("settings.grid.spacing.label") || "Grid Spacing"
        description: pluginApi && pluginApi.tr("settings.grid.spacing.description") || "Gap between workspace thumbnails"
        from: 0
        to: 50
        stepSize: 1
        value: root.gridSpacing
        text: value + "px"
        onMoved: (value) => {
            if (root.gridSpacing !== value) {
                root.gridSpacing = value;
                root.saveSettings();
            }
        }
    }


    NText {
        text: {
            var total = root.gridRows * root.gridColumns;
            return total + " total workspaces";
        }
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
    }

    // Warning when overview would be auto-shrunk to fit (predictive)
    NText {
        visible: root.willRequireFitScaling
        text: (pluginApi && pluginApi.tr("settings.grid.scale-warning")) || "Current settings exceed screen size. Overview will be scaled down to fit."
        color: Color.mError
        wrapMode: Text.WordWrap
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
    }

    NDivider {
        Layout.fillWidth: true
    }

    // === Behavior ===
    NHeader {
        label: pluginApi && pluginApi.tr("settings.behavior.title") || "Behavior"
    }

    NToggle {
        label: pluginApi && pluginApi.tr("settings.behavior.hide-empty-rows.label") || "Hide empty rows"
        description: pluginApi && pluginApi.tr("settings.behavior.hide-empty-rows.description") || "Automatically hide workspace rows with no windows"
        checked: root.hideEmptyRows
        onToggled: (checked) => {
            root.hideEmptyRows = checked;
            root.saveSettings();
        }
    }

    NToggle {
        label: pluginApi && pluginApi.tr("settings.behavior.show-scratchpad.label") || "Show scratchpad windows"
        description: pluginApi && pluginApi.tr("settings.behavior.show-scratchpad.description") || "Include special/scratchpad workspace windows in the overview"
        checked: root.showScratchpadWorkspaces
        onToggled: (checked) => {
            root.showScratchpadWorkspaces = checked;
            root.saveSettings();
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // === Layout ===
    NHeader {
        label: pluginApi && pluginApi.tr("settings.layout.title") || "Layout"
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi && pluginApi.tr("settings.layout.position.label") || "Position"
        description: pluginApi && pluginApi.tr("settings.layout.position.description") || "Where the overview appears on screen"
        model: [{
            "key": "top",
            "name": pluginApi && pluginApi.tr("settings.layout.position.top") || "Top"
        }, {
            "key": "center",
            "name": pluginApi && pluginApi.tr("settings.layout.position.center") || "Center"
        }, {
            "key": "bottom",
            "name": pluginApi && pluginApi.tr("settings.layout.position.bottom") || "Bottom"
        }]
        currentKey: root.overviewPosition
        onSelected: (key) => {
            root.overviewPosition = key;
            root.saveSettings();
        }
    }

    Item {
        Layout.fillHeight: true
    }

}
