import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property var pluginMain
    property var toplevel
    property var windowData
    property var monitorData
    property real windowScale: 1
    property real positionScaleX: 1
    property real positionScaleY: 1
    property var availableWorkspaceWidth: 100
    property var availableWorkspaceHeight: 100
    property bool restrictToWorkspace: true
    property bool overviewOpen: false
    property int windowRounding: 0
    property real centeringX: 0
    property real centeringY: 0
    property real xOffset: 0
    property real yOffset: 0
    property bool useSimplifiedPreview: false
    property string visualMode: "live"
    property string shaderPreset: "classic"
    property real shaderPresetStrength: 0.7
    property real simplifiedPixelDensity: 0.5
    property real simplifiedColorDepth: 6
    property real simplifiedSaturation: 1.1
    property real simplifiedContrast: 1.1
    property int windowBorderSize: 1
    property color activeBorderColor: Color.mPrimary
    property color inactiveBorderColor: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)
    property bool isActiveWorkspaceWindow: false
    property bool isFocusedWindow: false
    property bool showWindowIcons: true
    property bool showFocusedGlow: true
    property bool showUrgencyBadge: true
    property bool showFloatingBadge: true
    property bool showFullscreenBadge: false
    property bool showMonitorBadge: false
    property real inactiveWorkspaceDimAmount: 0.35
    property real inactiveWorkspaceSaturation: 0.75
    property real hoverLiftAmount: 4
    property string previewCornerMode: "hyprland"
    property int previewFixedCornerRadius: 10
    property bool useBorderGradient: true
    property bool showTitleStrip: true
    property int titleStripHeight: 20
    property string titleStripMode: "auto"
    property string titleStripMeta: "class"
    property string animationProfile: "hyprlike"
    property int animationDurationMs: 200
    // === DRAG STATE PROPERTIES ===
    property bool isDragging: false
    property real dragVelocity: 0
    property real previousX: 0
    property real dragTilt: 0
    property real dragScale: isDragging ? 1.12 : 1
    property real dragYOffset: isDragging ? -4 : 0
    // === RETILING SHIFT PROPERTIES ===
    property real proximityShiftX: 0
    property real proximityShiftY: 0
    property string retilingDirection: ""
    property bool isRetileTarget: false
    // Calculate window position within the workspace cell
    // Win pos is global. Monitor pos is global.
    // We want pos relative to monitor (0,0), then scaled, then centered.
    readonly property real rawPosX: ((windowData && windowData.at[0]) || 0) - ((monitorData && monitorData.x) || 0)
    readonly property real rawPosY: ((windowData && windowData.at[1]) || 0) - ((monitorData && monitorData.y) || 0)
    // Scale position
    readonly property real scaledPosX: (rawPosX + centeringX) * positionScaleX
    readonly property real scaledPosY: (rawPosY + centeringY) * positionScaleY
    // For fullscreen/maximized: position at top-left of workspace cell (or respect shifts? usually FS fills monitor)
    // If FS, we want it filling the whole cell (monitor).
    property real initX: (isFullscreen || isMaximized) ? xOffset : Math.max(0, Math.min(scaledPosX, availableWorkspaceWidth - width)) + xOffset
    property real initY: (isFullscreen || isMaximized) ? yOffset : Math.max(0, Math.min(scaledPosY, availableWorkspaceHeight - height)) + yOffset
    property int widgetMonitorId: 0
    property var targetWindowWidth: width
    property var targetWindowHeight: height
    property bool hovered: false
    property bool pressed: false
    property real iconToWindowRatio: 0.25
    property real iconToWindowRatioCompact: 0.45
    property var retilingTarget: null
    property string ownAddress: ""
    readonly property real presetStrength: clamp(shaderPresetStrength, 0, 1)
    readonly property bool useCinematicPreset: visualMode === "cinematic" || shaderPreset === "cinematic"
    readonly property real effectivePixelDensity: useCinematicPreset ? clamp(simplifiedPixelDensity * (0.9 - presetStrength * 0.35), 0.1, 1) : simplifiedPixelDensity
    readonly property real effectiveColorDepth: useCinematicPreset ? clamp(simplifiedColorDepth - presetStrength * 2.5, 1, 8) : simplifiedColorDepth
    readonly property real effectiveSaturation: useCinematicPreset ? clamp(simplifiedSaturation + presetStrength * 0.25, 0.5, 2) : simplifiedSaturation
    readonly property real effectiveContrast: useCinematicPreset ? clamp(simplifiedContrast + presetStrength * 0.35, 0.5, 2) : simplifiedContrast
    readonly property real inactiveDimClamped: clamp(inactiveWorkspaceDimAmount, 0, 0.8)
    readonly property real workspaceOpacityFactor: isActiveWorkspaceWindow ? 1 : (1 - inactiveDimClamped)
    readonly property real monitorOpacityFactor: ((windowData && windowData.monitor) || -1) == widgetMonitorId ? 1 : 0.4
    readonly property real inactiveDesaturationAlpha: isActiveWorkspaceWindow ? 0 : clamp(1 - clamp(inactiveWorkspaceSaturation, 0.3, 1), 0, 0.65)
    property real hoverYOffset: (!isDragging && hovered) ? (-Math.max(0, hoverLiftAmount) * windowScale) : 0
    readonly property real effectiveCornerRadius: previewCornerMode === "fixed" ? Math.max(0, previewFixedCornerRadius * windowScale) : Math.max(0, windowRounding * windowScale)
    readonly property color baseBorderColor: isFocusedWindow ? activeBorderColor : inactiveBorderColor
    readonly property color workspaceAdjustedBorderColor: {
        if (!isFocusedWindow && isActiveWorkspaceWindow)
            return Qt.rgba(baseBorderColor.r, baseBorderColor.g, baseBorderColor.b, 1.0);

        if (!isFocusedWindow)
            return Qt.rgba(baseBorderColor.r, baseBorderColor.g, baseBorderColor.b, 1.0);

        return baseBorderColor;
    }
    readonly property color effectiveBorderColor: {
        if (root.isDragging)
            return Qt.rgba(workspaceAdjustedBorderColor.r, workspaceAdjustedBorderColor.g, workspaceAdjustedBorderColor.b, 1.0);

        if (root.hovered || root.pressed)
            return Qt.rgba(workspaceAdjustedBorderColor.r, workspaceAdjustedBorderColor.g, workspaceAdjustedBorderColor.b, 1.0);

        return workspaceAdjustedBorderColor;
    }
    readonly property real scaledBorderWidth: windowBorderSize <= 0 ? 0 : Math.max(1, windowBorderSize * windowScale)
    readonly property real titleStripTargetHeight: Math.max(10, Math.min(28, titleStripHeight * windowScale * ((monitorData && monitorData.scale) || 1)))
    readonly property bool titleStripEnabled: {
        if (titleStripMode === "off")
            return false;

        if (titleStripMode === "always")
            return true;

        return showTitleStrip;
    }
    readonly property bool canShowTitleStrip: titleStripEnabled && !isFullscreen && !isMaximized && (titleStripMode === "always" || height >= (titleStripTargetHeight + 10))
    readonly property string displayTitle: {
        var value = (windowData && windowData.title) || "";
        if (value !== "")
            return value;

        if (pluginMain && pluginMain.pluginApi && pluginMain.pluginApi.tr)
            return pluginMain.pluginApi.tr("overview.title.unknown") || "Untitled";

        return "Untitled";
    }
    readonly property string displayClass: (windowData && windowData.class) || ""
    readonly property string titleStripMetaText: {
        if (titleStripMeta === "none")
            return "";

        var classPart = displayClass;
        if (titleStripMeta === "class")
            return classPart;

        var pid = (windowData && windowData.pid) || 0;
        if (classPart !== "" && pid > 0)
            return classPart + " pid:" + pid;

        if (classPart !== "")
            return classPart;

        if (pid > 0)
            return "pid:" + pid;

        return "";
    }
    readonly property bool isUrgentWindow: !!(windowData && (windowData.urgent || windowData.attention))
    // Icon resolution with Steam game support
    property var entry: DesktopEntries.heuristicLookup(windowData && windowData.class)
    property string windowClass: (windowData && windowData.class) || ""
    // Try to resolve Steam game icons
    property string steamAppId: {
        if (!windowClass)
            return "";

        // Steam games often have class like "steam_app_123456"
        if (windowClass.startsWith("steam_app_"))
            return windowClass.substring(10);

        return "";
    }
    // Normalize class name for icon lookup (remove .exe, lowercase, etc)
    property string normalizedClass: {
        if (!windowClass)
            return "";

        var name = windowClass.toLowerCase();
        if (name.endsWith(".exe"))
            name = name.substring(0, name.length - 4);

        return name;
    }
    property string resolvedIcon: {
        // 1. Use desktop entry icon if available
        if (entry && entry.icon)
            return entry.icon;

        // 2. For Steam games, try the icon theme first
        if (steamAppId !== "")
            return "steam";

        // 3. Try normalized class name (e.g., "firefox" instead of "Firefox")
        if (normalizedClass !== "")
            return normalizedClass;

        // 4. Fall back to generic executable
        return "application-x-executable";
    }
    // Default icon source (icon theme based). Steam logos are discovered asynchronously.
    property var iconPath: Quickshell.iconPath(resolvedIcon, "application-x-executable")
    property bool compactMode: 48 > targetWindowHeight || 48 > targetWindowWidth
    // ScreencopyView wrapper that fills the parent and clips
    // For fullscreen apps, we fill the entire workspace cell
    // For regular windows, we preserve aspect ratio
    readonly property bool isFullscreen: !!(windowData && windowData.fullscreen)
    readonly property bool isMaximized: !!(windowData && windowData.maximized)
    // Calculate shift when this window is the retiling target
    // The target shifts AWAY from where the dragged window will land
    // Shift is proportional to the size change (50% split = 25% shift to show movement)
    readonly property real calculatedShiftX: {
        if (!isRetileTarget || isDragging || isFullscreen || isMaximized)
            return 0;

        var shiftAmount = width * 0.25;
        switch (retilingDirection) {
        case "l":
            return shiftAmount;
        case "r":
            return -shiftAmount;
        case "u":
        case "d":
            return 0;
        default:
            return 0;
        }
    }
    readonly property real calculatedShiftY: {
        if (!isRetileTarget || isDragging || isFullscreen || isMaximized)
            return 0;

        var shiftAmount = height * 0.25;
        switch (retilingDirection) {
        case "u":
            return shiftAmount;
        case "d":
            return -shiftAmount;
        default:
            return 0;
        }
    }

    function clamp(value, minValue, maxValue) {
        if (value < minValue)
            return minValue;

        if (value > maxValue)
            return maxValue;

        return value;
    }

    function animationDuration(kind) {
        if (animationProfile === "none")
            return 0;

        if (animationProfile === "custom")
            return clamp(animationDurationMs, 80, 400);

        if (animationProfile === "fast")
            return kind === "fast" ? 90 : 140;

        if (animationProfile === "slow")
            return kind === "fast" ? 190 : 300;

        return kind === "fast" ? 120 : 200;
    }

    x: initX + calculatedShiftX
    y: initY + calculatedShiftY
    opacity: monitorOpacityFactor * workspaceOpacityFactor
    clip: true
    // For fullscreen/maximized: fill the workspace cell exactly
    // For regular windows: preserve aspect ratio
    width: (isFullscreen || isMaximized) ? availableWorkspaceWidth : Math.min(((windowData && windowData.size[0]) || 100) * windowScale, availableWorkspaceWidth)
    height: (isFullscreen || isMaximized) ? availableWorkspaceHeight : Math.min(((windowData && windowData.size[1]) || 100) * windowScale, availableWorkspaceHeight)
    // Trigger Steam icon search when we have a steamAppId and the window is visible
    onOverviewOpenChanged: {
        if (overviewOpen && root.steamAppId !== "" && !steamIconFinder.hasRun) {
            steamIconFinder.hasRun = true;
            steamIconFinder.running = true;
        }
    }
    // Transform for Y-axis rotation (tilt)
    transform: [
        Scale {
            xScale: root.dragScale
            yScale: root.dragScale
            origin.x: root.width / 2
            origin.y: root.height / 2
        },
        Rotation {
            angle: root.dragTilt
            axis.x: 0
            axis.y: 1
            axis.z: 0
            origin.x: root.width / 2
            origin.y: root.height / 2
        },
        Translate {
            y: root.dragYOffset + root.hoverYOffset
        }
    ]

    ScreencopyView {
        id: windowPreview

        anchors.fill: parent
        captureSource: root.overviewOpen ? root.toplevel : null
        live: true
        visible: !root.useSimplifiedPreview || !root.overviewOpen
    }

    // === SIMPLIFIED PREVIEW SHADER ===
    ShaderEffect {
        id: simplifiedPreview

        property var source
        property real sourceWidth: width
        property real sourceHeight: height
        property real intensity: 1
        property real pixelDensity: root.effectivePixelDensity
        property real colorDepth: root.effectiveColorDepth
        property real saturation: root.effectiveSaturation
        property real contrast: root.effectiveContrast

        anchors.fill: parent
        visible: root.useSimplifiedPreview && root.overviewOpen
        fragmentShader: root.shaderPreset === "mac" ? Qt.resolvedUrl("../shaders/qsb/window_mac_classic.frag.qsb") : Qt.resolvedUrl("../shaders/qsb/window_simplify.frag.qsb")

        source: ShaderEffectSource {
            sourceItem: windowPreview
            hideSource: true
        }

    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, inactiveDesaturationAlpha)
        visible: inactiveDesaturationAlpha > 0.001
    }

    // Window overlay (decoration fidelity + interactive states) - sits above preview
    Rectangle {
        id: decorationFrame

        anchors.fill: parent
        radius: root.effectiveCornerRadius
        color: "transparent"
        border.width: root.scaledBorderWidth
        border.color: root.useBorderGradient ? Qt.rgba(root.effectiveBorderColor.r, root.effectiveBorderColor.g, root.effectiveBorderColor.b, 1.0) : root.effectiveBorderColor

        Rectangle {
            visible: root.useBorderGradient && root.scaledBorderWidth > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(1, root.scaledBorderWidth)
            radius: parent.radius

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(root.activeBorderColor.r, root.activeBorderColor.g, root.activeBorderColor.b, 0.92)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(root.inactiveBorderColor.r, root.inactiveBorderColor.g, root.inactiveBorderColor.b, 0.92)
                }

            }

        }

        Rectangle {
            id: interactionOverlay

            anchors.fill: parent
            radius: parent.radius
            color: {
                if (root.isDragging)
                    return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.38);

                if (root.pressed)
                    return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.46);

                if (root.hovered)
                    return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.24);

                return "transparent";
            }
        }

        // Glow effect during drag
        Rectangle {
            id: dragGlow

            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: root.isDragging ? Qt.rgba(root.effectiveBorderColor.r, root.effectiveBorderColor.g, root.effectiveBorderColor.b, 0.32) : "transparent"
            border.width: root.isDragging ? Math.max(2, root.scaledBorderWidth * 2) : 0
            visible: root.isDragging
        }

        Rectangle {
            id: focusGlow

            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: root.showFocusedGlow && root.isFocusedWindow ? Qt.rgba(root.activeBorderColor.r, root.activeBorderColor.g, root.activeBorderColor.b, 0.5) : "transparent"
            border.width: root.showFocusedGlow && root.isFocusedWindow ? Math.max(2, root.scaledBorderWidth * 1.5) : 0
            visible: root.showFocusedGlow && root.isFocusedWindow
        }

        // App icon
        ColumnLayout {
            visible: root.showWindowIcons
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6
            anchors.bottomMargin: root.canShowTitleStrip ? (titleStrip.height * 0.35) : 0

            Image {
                id: windowIcon

                // Calculate max icon dimensions based on workspace size
                property real maxIconSize: {
                    return Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / ((root.monitorData && root.monitorData.scale) || 1);
                }
                // Detect if this is a Steam logo (wide image) vs a normal icon (square)
                property bool isSteamLogo: root.steamAppId !== ""

                Layout.alignment: Qt.AlignHCenter
                // For Steam logos, use maximum available width; for icons, constrain to square
                Layout.maximumWidth: isSteamLogo ? root.targetWindowWidth * 0.9 : maxIconSize
                Layout.maximumHeight: maxIconSize
                source: root.iconPath
                fillMode: Image.PreserveAspectFit

                Behavior on width {
                    NumberAnimation {
                        duration: root.isDragging ? 140 : 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: root.isDragging ? 140 : 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        Row {
            id: stateBadges

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Math.max(4, parent.height * 0.05)
            anchors.rightMargin: Math.max(4, parent.width * 0.04)
            spacing: 4
            visible: urgencyBadge.visible || floatingBadge.visible || fullscreenBadge.visible || monitorBadge.visible

            Rectangle {
                id: urgencyBadge

                visible: root.showUrgencyBadge && root.isUrgentWindow
                color: Qt.rgba(0.96, 0.25, 0.2, 0.92)
                radius: 6
                width: urgencyLabel.implicitWidth + 8
                height: urgencyLabel.implicitHeight + 4

                Text {
                    id: urgencyLabel

                    anchors.centerIn: parent
                    text: "URGENT"
                    color: "#ffffff"
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(7, Math.min(10, root.height * 0.08))
                    font.weight: Style.fontWeightBold
                }

            }

            Rectangle {
                id: floatingBadge

                visible: root.showFloatingBadge && !!(root.windowData && root.windowData.floating)
                color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.82)
                border.width: 1
                border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.55)
                radius: 6
                width: floatingLabel.implicitWidth + 8
                height: floatingLabel.implicitHeight + 4

                Text {
                    id: floatingLabel

                    anchors.centerIn: parent
                    text: "FLOAT"
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(7, Math.min(10, root.height * 0.08))
                }

            }

            Rectangle {
                id: fullscreenBadge

                visible: root.showFullscreenBadge && (root.isFullscreen || root.isMaximized)
                color: Qt.rgba(root.activeBorderColor.r, root.activeBorderColor.g, root.activeBorderColor.b, 0.82)
                radius: 6
                width: fullscreenLabel.implicitWidth + 8
                height: fullscreenLabel.implicitHeight + 4

                Text {
                    id: fullscreenLabel

                    anchors.centerIn: parent
                    text: "FULL"
                    color: "#ffffff"
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(7, Math.min(10, root.height * 0.08))
                }

            }

            Rectangle {
                id: monitorBadge

                visible: root.showMonitorBadge && !!root.windowData
                color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.82)
                border.width: 1
                border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
                radius: 6
                width: monitorLabel.implicitWidth + 8
                height: monitorLabel.implicitHeight + 4

                Text {
                    id: monitorLabel

                    anchors.centerIn: parent
                    text: "M" + (((root.windowData && root.windowData.monitor) || 0) + 1)
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(7, Math.min(10, root.height * 0.08))
                }

            }

        }

        Rectangle {
            id: titleStrip

            visible: root.canShowTitleStrip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.titleStripTargetHeight
            radius: parent.radius
            color: root.isDragging ? Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.78) : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.64)
            border.width: 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.rgba(root.effectiveBorderColor.r, root.effectiveBorderColor.g, root.effectiveBorderColor.b, 0.45)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.max(4, parent.height * 0.45)
                anchors.rightMargin: Math.max(4, parent.height * 0.45)
                spacing: Math.max(4, parent.height * 0.3)

                Text {
                    Layout.fillWidth: true
                    text: root.displayTitle
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(7, Math.min(13, titleStrip.height * 0.58))
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: root.titleStripMetaText !== "" && root.width > 120
                    text: root.titleStripMetaText
                    color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.95)
                    elide: Text.ElideRight
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(6, Math.min(11, titleStrip.height * 0.5))
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    Layout.maximumWidth: root.width * 0.34
                }

            }

        }

    }

    // Process to search for Steam icon in subdirectories (for games like Deadlock)
    // Some games store logo.png in a hashed subdirectory
    Process {
        id: steamIconFinder

        property bool hasRun: false

        command: ["find", Quickshell.env("HOME") + "/.local/share/Steam/appcache/librarycache/" + root.steamAppId, "-name", "logo.png", "-print", "-quit"]

        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path !== "")
                    windowIcon.source = "file://" + path;

            }
        }

    }

    Behavior on x {
        enabled: root.animationDuration("normal") > 0

        NumberAnimation {
            duration: root.isDragging ? root.animationDuration("fast") : (root.isRetileTarget || root.retilingDirection !== "") ? root.animationDuration("fast") : root.animationDuration("normal")
            easing.type: Easing.OutCubic
        }

    }

    Behavior on y {
        enabled: root.animationDuration("normal") > 0

        NumberAnimation {
            duration: root.isDragging ? root.animationDuration("fast") : (root.isRetileTarget || root.retilingDirection !== "") ? root.animationDuration("fast") : root.animationDuration("normal")
            easing.type: Easing.OutCubic
        }

    }

    Behavior on width {
        enabled: root.animationDuration("normal") > 0

        NumberAnimation {
            duration: root.isDragging ? root.animationDuration("fast") : root.animationDuration("normal")
            easing.type: Easing.OutCubic
        }

    }

    Behavior on height {
        enabled: root.animationDuration("normal") > 0

        NumberAnimation {
            duration: root.isDragging ? root.animationDuration("fast") : root.animationDuration("normal")
            easing.type: Easing.OutCubic
        }

    }

    // === DRAG ANIMATIONS ===
    Behavior on dragScale {
        SpringAnimation {
            spring: 3
            damping: 0.35
            mass: 0.45
        }

    }

    Behavior on dragTilt {
        enabled: root.animationDuration("fast") > 0

        NumberAnimation {
            duration: root.animationDuration("fast")
            easing.type: Easing.OutCubic
        }

    }

    Behavior on hoverYOffset {
        enabled: root.animationDuration("fast") > 0

        NumberAnimation {
            duration: root.animationDuration("fast")
            easing.type: Easing.OutCubic
        }

    }

    Behavior on dragYOffset {
        SpringAnimation {
            spring: 4
            damping: 0.45
            mass: 0.3
        }

    }

}
