import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Widgets

PanelWindow {
    id: root

    // Dependencies passed from Settings.qml
    property var pluginMain
    property var previewWorkspaceOptions: []
    property string previewWorkspaceKey: ""
    property var previewWorkspaceWindows: []
    property var previewMonitorData: null
    property int previewMonitorId: 0
    property real previewCenteringX: 0
    property real previewCenteringY: 0
    // Extracted settings
    property string visualMode: "live"
    property string shaderPreset: "classic"
    property real shaderPresetStrength: 1
    property real simplifiedPixelDensity: 1
    property real simplifiedColorDepth: 8
    property real simplifiedSaturation: 1
    property real simplifiedContrast: 1
    property string accentColorType: "secondary"
    property bool showWindowIcons: true
    property bool colorizeWindowIcons: false
    property string windowIconPlacement: "center"
    property bool showFocusedWindowGlow: true
    property bool showUrgencyBadge: true
    property bool showFloatingBadge: true
    property bool showFullscreenBadge: true
    property bool showMonitorBadge: true
    property real dimInactiveWorkspaces: 0.15
    property real inactiveWorkspaceSaturation: 0.8
    property real hoverLiftAmount: 8
    property string previewCornerMode: "hyprland"
    property real previewFixedCornerRadius: 12
    property bool useBorderGradient: true
    property bool showWindowTitleStrip: true
    property string titleStripPosition: "overlay-top"
    property int titleStripHeight: 20
    property string titleStripMode: "auto"
    property string titleStripMeta: "none"
    property real selectionBorderWidth: -1
    property bool showRowColumnGuides: true
    property bool showWorkspaceLabels: true
    property string specialWorkspaceStyle: "pill"
    property string previewWorkspaceWatermark: ""
    // Animation settings
    property string animationProfile: "standard"
    property int animationDurationMs: 250
    property var previewHyprConfig: ({
    })
    // Private selected option
    property var selectedPreviewWorkspaceOption: {
        for (var i = 0; i < root.previewWorkspaceOptions.length; i++) {
            if (root.previewWorkspaceOptions[i].key === root.previewWorkspaceKey)
                return root.previewWorkspaceOptions[i];

        }
        return null;
    }
    property string monitorKey: "__default__"
    property var targetScreen: null
    readonly property var fallbackScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property string barPosition: Settings.data.bar.position || "bottom"
    property real windowX: Style.marginM
    property real windowY: Style.marginM
    property real pluginWindowX: -1
    property real pluginWindowY: -1
    property real persistedWindowX: -1
    property real persistedWindowY: -1
    property string persistedMonitorKey: ""
    readonly property real titleBarHeight: Math.max(36, Math.round(34 * Style.uiScaleRatio))
    readonly property bool isDragging: dragHandler.active
    property real dragLiftScale: 1.0

    Behavior on dragLiftScale {
        enabled: !root.isDragging
        NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutBack
            easing.overshoot: 2.0
        }
    }

    Behavior on windowX {
        enabled: !root.isDragging
        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Behavior on windowY {
        enabled: !root.isDragging
        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    signal positionSaved(string monitorKey, real xPos, real yPos)

    function isValidSavedPosition(xPos, yPos) {
        return isFinite(xPos) && isFinite(yPos) && xPos >= 0 && yPos >= 0;
    }

    function screenWidth() {
        return (root.screen && root.screen.width) || 1920;
    }

    function screenHeight() {
        return (root.screen && root.screen.height) || 1080;
    }

    function clampToScreen(xPos, yPos) {
        var frameWidth = root.width > 0 ? root.width : root.implicitWidth;
        var frameHeight = root.height > 0 ? root.height : root.implicitHeight;
        var minX = Style.marginL;
        var minY = Style.marginL;
        var maxX = Math.max(minX, screenWidth() - frameWidth - Style.marginL);
        var maxY = Math.max(minY, screenHeight() - frameHeight - Style.marginL);
        var clampedX = Math.max(minX, Math.min(maxX, xPos));
        var clampedY = Math.max(minY, Math.min(maxY, yPos));
        return {
            "x": clampedX,
            "y": clampedY
        };
    }

    function resolveDefaultPosition() {
        var defaultX = Style.marginM;
        var defaultY = Style.marginM;
        if (barPosition === "left")
            defaultX = Style.barHeight + Style.marginL;
        else if (barPosition === "top")
            defaultY = Style.barHeight + Style.marginL;
        else if (barPosition === "bottom")
            defaultY = screenHeight() - root.implicitHeight - Style.barHeight - Style.marginL;
        return {
            "x": defaultX,
            "y": defaultY
        };
    }

    function applyInitialPosition() {
        var hasSavedPosition = isValidSavedPosition(root.pluginWindowX, root.pluginWindowY);
        var seed = hasSavedPosition ? {
            "x": root.pluginWindowX,
            "y": root.pluginWindowY
        } : resolveDefaultPosition();
        var clamped = clampToScreen(seed.x, seed.y);
        root.windowX = clamped.x;
        root.windowY = clamped.y;
        if (hasSavedPosition) {
            root.persistedWindowX = clamped.x;
            root.persistedWindowY = clamped.y;
        } else {
            root.persistedWindowX = -1;
            root.persistedWindowY = -1;
        }
        root.persistedMonitorKey = root.monitorKey;
    }

    function syncWithPersistedInput() {
        if (dragHandler.active)
            return ;

        if (!isValidSavedPosition(root.pluginWindowX, root.pluginWindowY))
            return ;

        var clamped = clampToScreen(root.pluginWindowX, root.pluginWindowY);
        if (Math.abs(clamped.x - root.windowX) > 0.5 || Math.abs(clamped.y - root.windowY) > 0.5) {
            root.windowX = clamped.x;
            root.windowY = clamped.y;
        }
        root.persistedWindowX = clamped.x;
        root.persistedWindowY = clamped.y;
        root.persistedMonitorKey = root.monitorKey;
    }

    function clampCurrentPosition() {
        if (dragHandler.active)
            return ;

        var clamped = clampToScreen(root.windowX, root.windowY);
        if (Math.abs(clamped.x - root.windowX) > 0.5 || Math.abs(clamped.y - root.windowY) > 0.5) {
            root.windowX = clamped.x;
            root.windowY = clamped.y;
        }
    }

    function shouldPersistPosition(xPos, yPos) {
        if (root.persistedMonitorKey !== root.monitorKey)
            return true;

        if (!isValidSavedPosition(root.persistedWindowX, root.persistedWindowY))
            return true;

        return Math.abs(root.persistedWindowX - xPos) > 0.5 || Math.abs(root.persistedWindowY - yPos) > 0.5;
    }

    // Window logic
    WlrLayershell.namespace: "plugin-workspace-preview"
    screen: root.targetScreen || root.fallbackScreen
    Component.onCompleted: applyInitialPosition()
    onMonitorKeyChanged: applyInitialPosition()
    onTargetScreenChanged: applyInitialPosition()
    onPluginWindowXChanged: syncWithPersistedInput()
    onPluginWindowYChanged: syncWithPersistedInput()
    onWidthChanged: clampCurrentPosition()
    onHeightChanged: clampCurrentPosition()
    onScreenChanged: clampCurrentPosition()
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // Only show if we actually have options to preview and the window is meant to be visible
    visible: root.previewWorkspaceOptions.length > 0
    // Size logic
    implicitWidth: Math.round(340 * Style.uiScaleRatio)
    implicitHeight: Math.round(200 * Style.uiScaleRatio)

    // Use margins for absolute-like positioning in LayerShell
    anchors {
        top: true
        left: true
    }

    margins {
        top: root.windowY
        left: root.windowX
    }

    Rectangle {
        id: windowFrame

        anchors.fill: parent
        radius: Style.radiusL
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.95)
        border.width: Style.borderS
        border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
        transform: Scale {
            xScale: root.dragLiftScale
            yScale: root.dragLiftScale
            origin.x: windowFrame.width / 2
            origin.y: windowFrame.height / 2
        }

        // Dimming effect since this isn't the primary focus
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Color.mBackground.r, Color.mBackground.g, Color.mBackground.b, 1)
            opacity: root.isDragging ? 0.45 : 0.3
            z: -1

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: titleBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.titleBarHeight
            radius: Style.radiusL
            color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, root.isDragging ? 0.7 : 0.5)
            border.width: 1
            border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, root.isDragging ? 0.7 : 0.4)

            Behavior on color {
                ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginM
                spacing: Style.marginS

                Rectangle {
                    width: 9
                    height: 9
                    radius: width / 2
                    color: root.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary
                }

                NText {
                    text: "Live Preview"
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightSemiBold
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.previewMonitorData && root.previewMonitorData.name
                    radius: 6
                    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.7)
                    border.width: 1
                    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.4)
                    implicitWidth: monitorChipText.implicitWidth + 10
                    implicitHeight: monitorChipText.implicitHeight + 4

                    NText {
                        id: monitorChipText

                        anchors.centerIn: parent
                        text: root.previewMonitorData && root.previewMonitorData.name ? root.previewMonitorData.name : ""
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                    }

                }

                Rectangle {
                    radius: 6
                    color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.7)
                    border.width: 1
                    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.4)
                    implicitWidth: workspaceChipText.implicitWidth + 10
                    implicitHeight: workspaceChipText.implicitHeight + 4

                    NText {
                        id: workspaceChipText

                        anchors.centerIn: parent
                        text: root.previewWorkspaceWatermark ? ("WS " + root.previewWorkspaceWatermark) : "WS"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                    }

                }

            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: 52
                height: 4
                radius: 3
                color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, root.isDragging ? 0.75 : 0.45)

                Behavior on color {
                    ColorAnimation {
                        duration: Style.animationFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            }

            DragHandler {
                id: dragHandler

                property real startWindowX: 0
                property real startWindowY: 0
                property point startCursorScene: Qt.point(0, 0)

                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                target: null
                dragThreshold: 0
                onActiveChanged: {
                    if (active) {
                        startWindowX = root.windowX;
                        startWindowY = root.windowY;
                        startCursorScene = centroid.scenePosition;
                        root.dragLiftScale = 1.018;
                    } else {
                        root.dragLiftScale = 1.0;
                        var clamped = root.clampToScreen(root.windowX, root.windowY);
                        var snapDist = Math.round(28 * Style.uiScaleRatio);
                        if (clamped.x <= Style.marginL + snapDist)
                            clamped.x = Style.marginL;
                        else if (clamped.x + root.width >= root.screenWidth() - Style.marginL - snapDist)
                            clamped.x = root.screenWidth() - root.width - Style.marginL;
                        if (clamped.y <= Style.marginL + snapDist)
                            clamped.y = Style.marginL;
                        root.windowX = clamped.x;
                        root.windowY = clamped.y;
                        if (root.shouldPersistPosition(clamped.x, clamped.y)) {
                            root.persistedWindowX = clamped.x;
                            root.persistedWindowY = clamped.y;
                            root.persistedMonitorKey = root.monitorKey;
                            root.positionSaved(root.monitorKey, clamped.x, clamped.y);
                        }
                    }
                }
                onTranslationChanged: {
                    if (active) {
                        var dragX = startWindowX + (centroid.scenePosition.x - startCursorScene.x);
                        var dragY = startWindowY + (centroid.scenePosition.y - startCursorScene.y);
                        var clamped = root.clampToScreen(dragX, dragY);
                        root.windowX = clamped.x;
                        root.windowY = clamped.y;
                    }
                }
            }

        }

        Item {
            id: contentArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: parent.bottom
        }

        Item {
            id: previewWorkspaceViewport

            property real rawMonitorWidth: ((root.previewMonitorData && root.previewMonitorData.width) || 1920) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
            property real rawMonitorHeight: ((root.previewMonitorData && root.previewMonitorData.height) || 1080) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
            property real sourceMonitorWidth: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
            property real sourceMonitorHeight: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight
            property real aspectRatio: sourceMonitorWidth / Math.max(1, sourceMonitorHeight)

            anchors.centerIn: contentArea
            width: Math.min(Math.max(1, contentArea.width - Style.marginL * 2), Math.max(1, (contentArea.height - Style.marginL * 2) * aspectRatio))
            height: width / Math.max(0.01, aspectRatio)

            Rectangle {
                id: previewWorkspaceSurface

                anchors.fill: parent
                color: Color.mSurfaceVariant
                radius: Style.screenRadius * 0.35
                border.width: root.selectionBorderWidth >= 0 ? root.selectionBorderWidth : Style.borderM
                border.color: root.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary

                Rectangle {
                    visible: root.showRowColumnGuides
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    height: 1
                    color: Qt.alpha(root.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary, Style.opacityLight)
                }

                Rectangle {
                    visible: root.showRowColumnGuides
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height * 0.8
                    color: Qt.alpha(root.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary, Style.opacityLight)
                }

                Text {
                    anchors.centerIn: parent
                    text: root.previewWorkspaceWatermark
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(40, parent.height * 0.42)
                    font.weight: Style.fontWeightSemiBold
                    color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)
                }

                Rectangle {
                    visible: root.showWorkspaceLabels && root.selectedPreviewWorkspaceOption
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Math.max(6, parent.width * 0.03)
                    anchors.topMargin: Math.max(6, parent.height * 0.03)
                    radius: root.specialWorkspaceStyle === "pill" ? Math.max(8, height / 2) : (root.specialWorkspaceStyle === "chip" ? 8 : 0)
                    color: root.specialWorkspaceStyle === "plain" ? "transparent" : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.72)
                    border.width: root.specialWorkspaceStyle === "plain" ? 0 : 1
                    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
                    width: Math.min(parent.width * 0.78, workspaceLabelText.implicitWidth + 14)
                    height: Math.max(20, Math.min(30, parent.height * 0.2))

                    Text {
                        id: workspaceLabelText

                        anchors.centerIn: parent
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: (root.selectedPreviewWorkspaceOption && root.selectedPreviewWorkspaceOption.name) || "Workspace"
                        font.family: Settings.data.ui.fontDefault
                        font.pixelSize: Math.max(10, Math.min(13, parent.height * 0.52))
                        color: Color.mOnSurface
                    }

                }

                Repeater {
                    model: root.previewWorkspaceWindows || []

                    delegate: WindowPreview {
                        required property var modelData
                        required property int index
                        property int monitorId: ((modelData.win && modelData.win.monitor) || root.previewMonitorId)
                        property var windowMonitor: {
                            var monitors = root.pluginMain && root.pluginMain.monitors ? root.pluginMain.monitors : [];
                            for (var i = 0; i < monitors.length; i++) {
                                if (monitors[i] && monitors[i].id === monitorId)
                                    return monitors[i];

                            }
                            return root.previewMonitorData;
                        }
                        property real rawMonitorWidth: ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1)
                        property real rawMonitorHeight: ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1)
                        property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
                        property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight

                        pluginMain: root.pluginMain
                        toplevel: modelData.toplevel
                        windowData: modelData.win
                        monitorData: windowMonitor
                        windowScale: Math.min(previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth), previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight))
                        positionScaleX: previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth)
                        positionScaleY: previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight)
                        availableWorkspaceWidth: previewWorkspaceViewport.width
                        availableWorkspaceHeight: previewWorkspaceViewport.height
                        centeringX: root.previewCenteringX
                        centeringY: root.previewCenteringY
                        xOffset: 0
                        yOffset: 0
                        widgetMonitorId: root.previewMonitorId
                        overviewOpen: true
                        useSimplifiedPreview: root.visualMode !== "live"
                        visualMode: root.visualMode
                        shaderPreset: root.shaderPreset
                        shaderPresetStrength: root.shaderPresetStrength
                        simplifiedPixelDensity: root.simplifiedPixelDensity
                        simplifiedColorDepth: root.simplifiedColorDepth
                        simplifiedSaturation: root.simplifiedSaturation
                        simplifiedContrast: root.simplifiedContrast
                        hyprGapsIn: (root.previewHyprConfig && root.previewHyprConfig.gapsIn !== undefined) ? root.previewHyprConfig.gapsIn : 5
                        hyprBorderSize: (root.previewHyprConfig && root.previewHyprConfig.borderSize !== undefined) ? root.previewHyprConfig.borderSize : 1
                        windowBorderSize: (root.previewHyprConfig && root.previewHyprConfig.borderSize !== undefined) ? root.previewHyprConfig.borderSize : 1
                        activeBorderColor: (root.previewHyprConfig && root.previewHyprConfig.activeBorderColor) ? root.previewHyprConfig.activeBorderColor : Color.mPrimary
                        inactiveBorderColor: (root.previewHyprConfig && root.previewHyprConfig.inactiveBorderColor) ? root.previewHyprConfig.inactiveBorderColor : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)
                        isActiveWorkspaceWindow: true
                        isFocusedWindow: !!(root.pluginMain.hyprlandService && root.pluginMain.hyprlandService.activeWindowData && modelData.win && modelData.win.address === root.pluginMain.hyprlandService.activeWindowData.address)
                        showWindowIcons: root.showWindowIcons
                        colorizeWindowIcons: root.colorizeWindowIcons
                        windowIconPlacement: root.windowIconPlacement
                        showFocusedGlow: root.showFocusedWindowGlow
                        showUrgencyBadge: root.showUrgencyBadge
                        showFloatingBadge: root.showFloatingBadge
                        showFullscreenBadge: root.showFullscreenBadge
                        showMonitorBadge: root.showMonitorBadge
                        inactiveWorkspaceDimAmount: root.dimInactiveWorkspaces
                        inactiveWorkspaceSaturation: root.inactiveWorkspaceSaturation
                        hoverLiftAmount: root.hoverLiftAmount
                        previewCornerMode: root.previewCornerMode
                        previewFixedCornerRadius: root.previewFixedCornerRadius
                        useBorderGradient: root.useBorderGradient
                        showTitleStrip: root.showWindowTitleStrip
                        titleStripPosition: root.titleStripPosition
                        titleStripHeight: root.titleStripHeight
                        titleStripMode: root.titleStripMode
                        titleStripMeta: root.titleStripMeta
                        windowRounding: (root.previewHyprConfig && root.previewHyprConfig.rounding !== undefined) ? root.previewHyprConfig.rounding : 0
                        animationProfile: root.animationProfile
                        animationDurationMs: root.animationDurationMs
                        z: index + 1
                        hovered: false
                        pressed: false
                    }

                }

                NText {
                    anchors.centerIn: parent
                    visible: (root.previewWorkspaceWindows || []).length === 0
                    text: "Open windows to preview styles"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }

            }

        }

    }

}
