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

    x: initX
    y: initY
    opacity: ((windowData && windowData.monitor) || -1) == widgetMonitorId ? 1 : 0.4
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

    ScreencopyView {
        id: windowPreview

        anchors.fill: parent
        captureSource: root.overviewOpen ? root.toplevel : null
        live: true

        // Window overlay (hover/press states + border)
        Rectangle {
            anchors.fill: parent
            radius: root.windowRounding * root.windowScale
            color: root.pressed ? Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.5) : root.hovered ? Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.3) : "transparent"
            border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
            border.width: Style.borderS
        }

        // App icon
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

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
                        duration: 400
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }

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
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }

    }

    Behavior on y {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }

    }

    Behavior on width {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }

    }

    Behavior on height {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }

    }

}
