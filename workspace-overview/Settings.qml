import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property var defaultSettings: (pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings) || ({
    })
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    // Local state
    property int gridRows: 2
    property int gridColumns: 5
    property real gridScale: 0.16
    property bool hideEmptyRows: true
    property bool showScratchpadWorkspaces: false
    property int gridSpacing: 0
    property string overviewPosition: "top"
    property int barMargin: 0
    property bool useSlideAnimation: true
    property int containerBorderWidth: -1
    property int selectionBorderWidth: -1
    property string accentColorType: "secondary"
    // Get primary screen info for predictive fit calculation
    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenWidth: primaryScreen ? primaryScreen.width : 1920
    readonly property real screenHeight: primaryScreen ? primaryScreen.height : 1080
    readonly property real screenScale: primaryScreen ? (primaryScreen.scale || 1) : 1
    readonly property real barHeightEstimate: 40
    readonly property real marginXL: Style.marginXL
    readonly property real marginM: Style.marginM
    readonly property real barAwareMargin: {
        var pos = overviewPosition;
        if (pos === "top" || pos === "bottom")
            return marginXL + barHeightEstimate + marginM;

        return marginXL;
    }
    readonly property real availableWidth: (screenWidth / screenScale) - barAwareMargin * 2
    readonly property real availableHeight: (screenHeight / screenScale) - barAwareMargin * 2
    readonly property real predictedCellWidth: (screenWidth / screenScale) * gridScale
    readonly property real predictedCellHeight: (screenHeight / screenScale) * gridScale
    readonly property real workspaceSpacing: gridSpacing
    readonly property real padding: 40
    readonly property real predictedGridWidth: gridColumns * predictedCellWidth + (gridColumns - 1) * workspaceSpacing + padding
    readonly property real predictedGridHeight: gridRows * predictedCellHeight + (gridRows - 1) * workspaceSpacing + padding
    readonly property real predictedFitScale: Math.min(1, Math.min(availableWidth / Math.max(1, predictedGridWidth), availableHeight / Math.max(1, predictedGridHeight)))
    readonly property bool willRequireFitScaling: predictedFitScale < 0.999

    function getSetting(key, fallback) {
        if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
            return pluginApi.pluginSettings[key];

        if (defaultSettings && defaultSettings[key] !== undefined)
            return defaultSettings[key];

        return fallback;
    }

    function tr(key, fallback) {
        if (!pluginApi || !pluginApi.tr)
            return fallback;

        var translated = pluginApi.tr(key);
        if (!translated)
            return fallback;

        return translated;
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
        barMargin = parseInt(getSetting("barMargin", 0)) || 0;
        useSlideAnimation = !!getSetting("useSlideAnimation", true);
        containerBorderWidth = parseInt(getSetting("containerBorderWidth", -1)) || -1;
        selectionBorderWidth = parseInt(getSetting("selectionBorderWidth", -1)) || -1;
        accentColorType = getSetting("accentColorType", "secondary") || "secondary";
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
        settings.barMargin = barMargin;
        settings.useSlideAnimation = useSlideAnimation;
        settings.containerBorderWidth = containerBorderWidth;
        settings.selectionBorderWidth = selectionBorderWidth;
        settings.accentColorType = accentColorType;
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
        text: tr("plugin.description", "Visual workspace overview with live window previews for Hyprland")
        wrapMode: Text.WordWrap
        color: Color.mOnSurface
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Tab Bar
    NTabBar {
        id: tabBar

        Layout.fillWidth: true
        currentIndex: 0
        distributeEvenly: true

        NTabButton {
            text: tr("settings.tabs.grid", "Grid")
            tabIndex: 0
            checked: tabBar.currentIndex === 0
        }

        NTabButton {
            text: tr("settings.tabs.behavior", "Behavior")
            tabIndex: 1
            checked: tabBar.currentIndex === 1
        }

        NTabButton {
            text: tr("settings.tabs.layout", "Layout")
            tabIndex: 2
            checked: tabBar.currentIndex === 2
        }

        NTabButton {
            text: tr("settings.tabs.appearance", "Appearance")
            tabIndex: 3
            checked: tabBar.currentIndex === 3
        }

    }

    // Tab Content
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabBar.currentIndex

        // === Grid Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NSpinBox {
                    Layout.fillWidth: true
                    label: tr("settings.grid.rows.label", "Rows")
                    description: tr("settings.grid.rows.description", "Number of workspace rows")
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
                    label: tr("settings.grid.columns.label", "Columns")
                    description: tr("settings.grid.columns.description", "Number of workspace columns")
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
                label: tr("settings.grid.scale.label", "Scale")
                description: tr("settings.grid.scale.description", "Overview scale factor")
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
                label: tr("settings.grid.spacing.label", "Grid Spacing")
                description: tr("settings.grid.spacing.description", "Gap between workspace thumbnails")
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
                    return tr("settings.grid.total-workspaces", "{count} total workspaces").replace("{count}", total);
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }

            // Warning when overview would be auto-shrunk to fit (predictive)
            NText {
                visible: root.willRequireFitScaling
                text: tr("settings.grid.scale-warning", "Current settings exceed screen size. Overview will be scaled down to fit.")
                color: Color.mError
                wrapMode: Text.WordWrap
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightMedium
            }

            Item {
                Layout.fillHeight: true
            }

        }

        // === Behavior Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            NToggle {
                label: tr("settings.behavior.hide-empty-rows.label", "Hide empty rows")
                description: tr("settings.behavior.hide-empty-rows.description", "Automatically hide workspace rows with no windows")
                checked: root.hideEmptyRows
                onToggled: (checked) => {
                    root.hideEmptyRows = checked;
                    root.saveSettings();
                }
            }

            NToggle {
                label: tr("settings.behavior.show-scratchpad.label", "Show scratchpad windows")
                description: tr("settings.behavior.show-scratchpad.description", "Include special/scratchpad workspace windows in the overview")
                checked: root.showScratchpadWorkspaces
                onToggled: (checked) => {
                    root.showScratchpadWorkspaces = checked;
                    root.saveSettings();
                }
            }

            Item {
                Layout.fillHeight: true
            }

        }

        // === Layout Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.layout.position.label", "Position")
                description: tr("settings.layout.position.description", "Where the overview appears on screen")
                model: [{
                    "key": "top",
                    "name": tr("settings.layout.position.top", "Top")
                }, {
                    "key": "center",
                    "name": tr("settings.layout.position.center", "Center")
                }, {
                    "key": "bottom",
                    "name": tr("settings.layout.position.bottom", "Bottom")
                }]
                currentKey: root.overviewPosition
                onSelected: (key) => {
                    root.overviewPosition = key;
                    root.saveSettings();
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.layout.barMargin.label", "Bar Margin")
                description: tr("settings.layout.barMargin.description", "Additional margin between overview and bar (when positioned at same edge)")
                from: 0
                to: 100
                stepSize: 1
                value: root.barMargin
                text: value + "px"
                onMoved: (value) => {
                    if (root.barMargin !== value) {
                        root.barMargin = value;
                        root.saveSettings();
                    }
                }
            }

            NToggle {
                label: tr("settings.layout.slideAnimation.label", "Slide animation")
                description: tr("settings.layout.slideAnimation.description", "Animate overview sliding in from the bar (disable for instant popup)")
                checked: root.useSlideAnimation
                onToggled: (checked) => {
                    root.useSlideAnimation = checked;
                    root.saveSettings();
                }
            }

            Item {
                Layout.fillHeight: true
            }

        }

        // === Appearance Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.appearance.accentColor.label", "Accent color")
                description: tr("settings.appearance.accentColor.description", "Color used for selection indicator and special workspaces")
                model: [{
                    "key": "secondary",
                    "name": tr("settings.appearance.accentColor.secondary", "Secondary (default)")
                }, {
                    "key": "primary",
                    "name": tr("settings.appearance.accentColor.primary", "Primary")
                }]
                currentKey: root.accentColorType
                onSelected: (key) => {
                    root.accentColorType = key;
                    root.saveSettings();
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.appearance.containerBorder.label", "Container border")
                description: tr("settings.appearance.containerBorder.description", "Border thickness of the overview container (-1 for default)")
                from: -1
                to: 10
                stepSize: 1
                value: root.containerBorderWidth
                text: value < 0 ? "Default" : value + "px"
                onMoved: (value) => {
                    if (root.containerBorderWidth !== value) {
                        root.containerBorderWidth = value;
                        root.saveSettings();
                    }
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.appearance.selectionBorder.label", "Selection border")
                description: tr("settings.appearance.selectionBorder.description", "Border thickness of the active workspace indicator (-1 for default)")
                from: -1
                to: 10
                stepSize: 1
                value: root.selectionBorderWidth
                text: value < 0 ? "Default" : value + "px"
                onMoved: (value) => {
                    if (root.selectionBorderWidth !== value) {
                        root.selectionBorderWidth = value;
                        root.saveSettings();
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

        }

    }

}
