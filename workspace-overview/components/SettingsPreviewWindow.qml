import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Wayland

import qs.Commons
import qs.Commons as Commons
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
    property real shaderPresetStrength: 1.0
    property real simplifiedPixelDensity: 1.0
    property real simplifiedColorDepth: 8.0
    property real simplifiedSaturation: 1.0
    property real simplifiedContrast: 1.0
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
    property var previewHyprConfig: ({})

    // Private selected option
    property var selectedPreviewWorkspaceOption: {
        for (var i = 0; i < root.previewWorkspaceOptions.length; i++) {
            if (root.previewWorkspaceOptions[i].key === root.previewWorkspaceKey) {
                return root.previewWorkspaceOptions[i];
            }
        }
        return null;
    }

    // Window logic
    WlrLayershell.namespace: "plugin-workspace-preview"
    property string barPosition: Settings.data.bar.position || "bottom"

    property real windowX: Style.marginM
    property real windowY: Style.marginM
    
    property real pluginWindowX: -1
    property real pluginWindowY: -1
    
    signal positionSaved(real xPos, real yPos)

    Component.onCompleted: {
        var defaultX = 0;
        var defaultY = 0;
        
        if (root.pluginWindowX >= 0 && root.pluginWindowY >= 0) {
            defaultX = root.pluginWindowX;
            defaultY = root.pluginWindowY;
        } else {
            // Try to position near the bar, but detached
            if (barPosition === "left") {
                defaultX = Style.barHeight + Style.marginL;
                defaultY = Style.marginM;
            } else if (barPosition === "right") {
                defaultX = Style.marginM; 
                defaultY = Style.marginM;
            } else if (barPosition === "top") {
                defaultX = Style.marginM;
                defaultY = Style.barHeight + Style.marginL;
            } else {
                defaultX = Style.marginM;
                defaultY = 1080 - Style.barHeight - implicitHeight - Style.marginL; // Rough guess for bottom
            }
        }
        
        windowX = defaultX;
        windowY = defaultY;
    }
    
    // Smooth movement for bouncing effect
    Behavior on windowX {
        enabled: !dragHandler.active
        SpringAnimation {
            spring: 3
            damping: 0.2
            mass: 1.0
        }
    }
    Behavior on windowY {
        enabled: !dragHandler.active
        SpringAnimation {
            spring: 3
            damping: 0.2
            mass: 1.0
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Use margins for absolute-like positioning in LayerShell
    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.round(root.windowY) | 0
        left: Math.round(root.windowX) | 0
    }
    
    color: "transparent"

    // Only show if we actually have options to preview and the window is meant to be visible
    visible: root.previewWorkspaceOptions.length > 0
    
    // Size logic
    implicitWidth: Math.round(340 * Style.uiScaleRatio)
    implicitHeight: Math.round(200 * Style.uiScaleRatio)

    Rectangle {
        id: windowFrame

        anchors.fill: parent
        radius: Style.radiusL
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.95)
        border.width: Style.borderS
        border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)

        // Dimming effect since this isn't the primary focus
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "black"
            opacity: 0.3
            z: -1
        }
        
        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        Item {
            id: dragTargetProxy
            anchors.fill: parent

            DragHandler {
                id: dragHandler
                target: null // Disable auto-translate so we can pipe it into Wayland margins
                
                property real startWindowX: 0
                property real startWindowY: 0
                
                onActiveChanged: {
                    if (active) {
                        startWindowX = root.windowX;
                        startWindowY = root.windowY;
                    } else {
                        // Release momentum projection
                        var velocityX = centroid.velocity.x;
                        var velocityY = centroid.velocity.y;
                        
                        // Prevent explosive throws if held still before drop
                        if (Math.abs(velocityX) < 50 && Math.abs(velocityY) < 50) {
                            velocityX = 0;
                            velocityY = 0;
                        }
                        
                        var projectedX = root.windowX + (velocityX * 0.2);
                        var projectedY = root.windowY + (velocityY * 0.2);
                        
                        var screenW = (root.screen && root.screen.width) || 1920;
                        var screenH = (root.screen && root.screen.height) || 1080;
                        
                        var minX = Style.marginL;
                        var minY = Style.marginL;
                        var maxX = screenW - root.width - Style.marginL;
                        var maxY = screenH - root.height - Style.marginL;
                        
                        if (projectedX < minX) projectedX = minX;
                        if (projectedX > maxX) projectedX = maxX;
                        if (projectedY < minY) projectedY = minY;
                        if (projectedY > maxY) projectedY = maxY;
        
                        root.windowX = projectedX;
                        root.windowY = projectedY;
                        
                        root.pluginWindowX = projectedX;
                        root.pluginWindowY = projectedY;
                        root.positionSaved(projectedX, projectedY);
                    }
                }
                
                onTranslationChanged: {
                    if (active) {
                        root.windowX = startWindowX + translation.x;
                        root.windowY = startWindowY + translation.y;
                    }
                }
            }
        }

        Item {
            id: previewWorkspaceViewport

            property real rawMonitorWidth: ((root.previewMonitorData && root.previewMonitorData.width) || 1920) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
            property real rawMonitorHeight: ((root.previewMonitorData && root.previewMonitorData.height) || 1080) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
            property real sourceMonitorWidth: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
            property real sourceMonitorHeight: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight
            property real aspectRatio: sourceMonitorWidth / Math.max(1, sourceMonitorHeight)

            anchors.centerIn: parent
            width: Math.min(parent.width - Style.marginL * 2, (parent.height - Style.marginL * 2) * aspectRatio)
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
                    color: Qt.rgba((root.accentColorType === "primary" ? Color.mPrimary.r : Color.mSecondary.r), (root.accentColorType === "primary" ? Color.mPrimary.g : Color.mSecondary.g), (root.accentColorType === "primary" ? Color.mPrimary.b : Color.mSecondary.b), 0.2)
                }

                Rectangle {
                    visible: root.showRowColumnGuides
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height * 0.8
                    color: Qt.rgba((root.accentColorType === "primary" ? Color.mPrimary.r : Color.mSecondary.r), (root.accentColorType === "primary" ? Color.mPrimary.g : Color.mSecondary.g), (root.accentColorType === "primary" ? Color.mPrimary.b : Color.mSecondary.b), 0.2)
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

                Text {
                    anchors.centerIn: parent
                    visible: (root.previewWorkspaceWindows || []).length === 0
                    text: "Open windows to preview styles"
                    color: Color.mOnSurfaceVariant
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeS
                }

            }

        }

    }
}
