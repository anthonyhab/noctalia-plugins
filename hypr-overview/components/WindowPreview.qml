import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../helpers/Utils.js" as Utils
import "../helpers/WorkspaceGeometry.js" as WorkspaceGeometry
import qs.Commons

Item {
  id: root

  property var pluginMain
  property var toplevel
  property var windowData
  property var retileTransitionFrame: null
  property bool retileTransitionActive: false
  property int positionResyncRevision: 0
  property string pendingCaptureRebindReason: ""
  property var monitorData
  property real windowScale: 1
  property real positionScaleX: 1
  property real positionScaleY: 1
  property real workAreaX: 0
  property real workAreaY: 0
  property real workAreaWidth: 0
  property real workAreaHeight: 0
  property var availableWorkspaceWidth: 100
  property var availableWorkspaceHeight: 100
  property bool restrictToWorkspace: true
  property bool overviewOpen: false
  property int captureRevision: 0
  property bool captureSourceEnabled: true
  property int windowRounding: 0
  property real centeringX: 0
  property real centeringY: 0
  property real xOffset: 0
  property real yOffset: 0
  property real workspaceExclusiveGap: 0
  property bool useSimplifiedPreview: false
  property string visualMode: "live"
  property string shaderPreset: "pixelated"
  property real shaderPresetStrength: 0.7
  property real simplifiedPixelDensity: 0.5
  property real simplifiedColorDepth: 6
  property real simplifiedSaturation: 1.1
  property real simplifiedContrast: 1.1
  property int windowBorderSize: 1
  property int hyprGapsIn: 0
  property int hyprBorderSize: 1
  property color activeBorderColor: Color.mPrimary
  property color inactiveBorderColor: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)
  property bool isActiveWorkspaceWindow: false
  property bool isFocusedWindow: false
  property bool showWindowIcons: true
  property bool colorizeWindowIcons: false
  property string windowIconPlacement: "center"
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
  property string titleStripPosition: "overlay-top"
  readonly property string stripPosition: titleStripPosition === "overlay-bottom" ? "overlay-bottom" : "overlay-top"
  property string titleStripMeta: "class"
  property string animationProfile: "hyprlike"
  property int animationDurationMs: 200
  // === DRAG STATE PROPERTIES ===
  property bool isDragging: false
  property bool suppressPositionAnimation: false
  property real dragVelocity: 0
  property real previousX: 0
  property real dragTilt: 0
  property real dragOriginX: width / 2
  property real dragOriginY: height / 2
  property real dragScale: isDragging ? 1.06 : (pressed ? 1.035 : 1)
  property real dragFeedbackOpacity: 1
  // === RETILING SHIFT PROPERTIES ===
  property real proximityShiftX: 0
  property real proximityShiftY: 0
  property string retilingDirection: ""
  property bool isRetileTarget: false
  // Shared monitor-space -> preview-space geometry model used by layout and drag inverse mapping.
  readonly property var geometryModel: WorkspaceGeometry.mapWindowToPreviewFrame({
                                                                                   "windowData": windowData,
                                                                                   "monitorData": monitorData,
                                                                                   "workspaceWidth": availableWorkspaceWidth,
                                                                                   "workspaceHeight": availableWorkspaceHeight,
                                                                                   "positionScaleX": positionScaleX,
                                                                                   "positionScaleY": positionScaleY,
                                                                                   "windowScale": windowScale,
                                                                                   "workAreaX": workAreaX,
                                                                                   "workAreaY": workAreaY,
                                                                                   "workAreaWidth": workAreaWidth,
                                                                                   "workAreaHeight": workAreaHeight,
                                                                                   "centeringX": centeringX,
                                                                                   "centeringY": centeringY,
                                                                                   "hyprGapsIn": hyprGapsIn,
                                                                                   "hyprBorderSize": hyprBorderSize,
                                                                                   "fallbackInset": workspaceExclusiveGap,
                                                                                   "useSimplifiedPreview": useSimplifiedPreview
                                                                                 })
  readonly property var displayGeometryModel: {
    var base = geometryModel;
    if (!base)
      return null;

    var frame = retileTransitionFrame;
    if (!root.isValidFrameRect(frame))
      return base;

    var next = {};
    for (var key in base)
      next[key] = base[key];

    next.x = Number(frame.x);
    next.y = Number(frame.y);
    next.w = Math.max(1, Number(frame.w));
    next.h = Math.max(1, Number(frame.h));
    return next;
  }
  readonly property real workspaceInset: (geometryModel && geometryModel.inset) || 0
  readonly property real safeWorkspaceWidth: (geometryModel && geometryModel.safeWorkspaceWidth) || Math.max(1, availableWorkspaceWidth)
  readonly property real safeWorkspaceHeight: (geometryModel && geometryModel.safeWorkspaceHeight) || Math.max(1, availableWorkspaceHeight)
  readonly property real effectivePositionScaleX: (geometryModel && geometryModel.effectivePositionScaleX) || Math.max(0.0001, positionScaleX)
  readonly property real effectivePositionScaleY: (geometryModel && geometryModel.effectivePositionScaleY) || Math.max(0.0001, positionScaleY)
  readonly property real effectiveWindowScale: (geometryModel && geometryModel.effectiveWindowScale) || Math.max(0.0001, windowScale)
  readonly property real outerBorderAlphaIdle: 0.34
  readonly property real contentWidth: (displayGeometryModel && displayGeometryModel.w) || 1
  readonly property real contentHeight: (displayGeometryModel && displayGeometryModel.h) || 1
  readonly property string displayedPreviewSizeKey: Math.round(contentWidth) + "x" + Math.round(contentHeight)
  property real initX: ((displayGeometryModel && displayGeometryModel.x) || workspaceInset) + xOffset
  property real initY: ((displayGeometryModel && displayGeometryModel.y) || workspaceInset) + yOffset
  property int widgetMonitorId: 0
  property var targetWindowWidth: width
  property var targetWindowHeight: contentHeight
  property bool hovered: false
  property bool pressed: false
  property real iconToWindowRatio: 0.25
  property real iconToWindowRatioCompact: 0.45
  property var retilingTarget: null
  property string ownAddress: ""
  readonly property real presetStrength: clamp(shaderPresetStrength, 0, 1)
  readonly property bool useMacPreset: shaderPreset === "mac"
  readonly property real effectivePixelDensity: useMacPreset ? clamp(simplifiedPixelDensity * (0.9 - presetStrength * 0.35), 0.1, 1) : simplifiedPixelDensity
  readonly property real effectiveColorDepth: useMacPreset ? clamp(simplifiedColorDepth - presetStrength * 2.5, 1, 8) : simplifiedColorDepth
  readonly property real effectiveSaturation: useMacPreset ? clamp(simplifiedSaturation + presetStrength * 0.25, 0.5, 2) : simplifiedSaturation
  readonly property real effectiveContrast: useMacPreset ? clamp(simplifiedContrast + presetStrength * 0.35, 0.5, 2) : simplifiedContrast
  readonly property real inactiveDimClamped: clamp(inactiveWorkspaceDimAmount, 0, 0.8)
  readonly property real workspaceOpacityFactor: isActiveWorkspaceWindow ? 1 : (1 - inactiveDimClamped)
  readonly property real monitorOpacityFactor: ((windowData && windowData.monitor) || -1) == widgetMonitorId ? 1 : 0.4
  readonly property real inactiveDesaturationAlpha: isActiveWorkspaceWindow ? 0 : clamp(1 - clamp(inactiveWorkspaceSaturation, 0.3, 1), 0, 0.65)
  readonly property real hoverEmphasisFactor: clamp(Math.max(0, hoverLiftAmount) / 12, 0, 1)
  readonly property real unfocusedIdleOpacityCut: (!root.isDragging && !root.isFocusedWindow && !root.hovered && !root.pressed) ? (0.05 + hoverEmphasisFactor * 0.08) : 0
  readonly property real hoverOpacityBoost: (!root.isDragging && (root.hovered || root.pressed)) ? (0.05 + hoverEmphasisFactor * 0.08) : 0
  readonly property real hoverSheenAlpha: (!root.isDragging && root.hovered) ? (0.03 + hoverEmphasisFactor * 0.06) : 0
  readonly property real materialSurfaceAlpha: root.isDragging ? 0.14 : (root.hovered ? Math.max(0.02, 0.05 - hoverEmphasisFactor * 0.02) : 0.07)
  readonly property real effectiveCornerRadius: {
    var sourceRadius = previewCornerMode === "fixed" ? previewFixedCornerRadius * windowScale : windowRounding * windowScale;
    var normalizedRadius = Math.max(0, sourceRadius);
    var snappedRadius = Math.floor(normalizedRadius);
    if (snappedRadius <= 1)
      return 0;

    return snappedRadius;
  }
  readonly property color baseBorderColor: isFocusedWindow ? activeBorderColor : inactiveBorderColor
  readonly property color workspaceAdjustedBorderColor: {
    if (!isFocusedWindow && isActiveWorkspaceWindow)
      return Qt.rgba(baseBorderColor.r, baseBorderColor.g, baseBorderColor.b, 1);

    if (!isFocusedWindow)
      return Qt.rgba(baseBorderColor.r, baseBorderColor.g, baseBorderColor.b, 1);

    return baseBorderColor;
  }
  readonly property color effectiveBorderColor: {
    if (root.isDragging)
      return Qt.rgba(workspaceAdjustedBorderColor.r, workspaceAdjustedBorderColor.g, workspaceAdjustedBorderColor.b, 1);

    if (root.hovered || root.pressed)
      return Qt.rgba(workspaceAdjustedBorderColor.r, workspaceAdjustedBorderColor.g, workspaceAdjustedBorderColor.b, 1);

    return workspaceAdjustedBorderColor;
  }
  readonly property color focusedBorderColor: Qt.rgba(root.activeBorderColor.r, root.activeBorderColor.g, root.activeBorderColor.b, 1)
  readonly property color hoverBorderColor: Qt.rgba(root.activeBorderColor.r, root.activeBorderColor.g, root.activeBorderColor.b, 0.66 + hoverEmphasisFactor * 0.22)
  readonly property real scaledBorderWidth: windowBorderSize <= 0 ? 0 : Math.max(1, windowBorderSize * windowScale)
  readonly property real drawnBorderWidth: root.scaledBorderWidth > 0 ? (root.isFocusedWindow ? Math.max(2, root.scaledBorderWidth + (root.showFocusedGlow ? 1 : 0)) : Math.max(1, root.scaledBorderWidth)) : 0
  readonly property real titleStripTargetHeight: Math.max(12, Math.min(28, titleStripHeight * windowScale * ((monitorData && monitorData.scale) || 1)))
  readonly property real titleStripDrawHeight: Math.max(0, Math.min(height, titleStripTargetHeight))
  readonly property bool titleStripEnabled: {
    if (titleStripMode === "off")
      return false;

    if (titleStripMode === "always")
      return true;

    return showTitleStrip;
  }
  readonly property bool canShowTitleStrip: titleStripEnabled && !isTreatedAsFullscreen && titleStripDrawHeight >= 8 && (titleStripMode === "always" || height >= (titleStripTargetHeight + 10))
  readonly property string displayTitle: {
    var value = (windowData && windowData.title) || "";
    if (value !== "")
      return value;

    return tr("overview.title.unknown");
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
  // Default icon source (icon theme based). Steam logos are discovered asynchronously.
  property var iconPath: {
    var fallback = "application-x-executable";

    // Steam windows start with the Steam icon, then the async logo lookup can replace it.
    if (steamAppId !== "")
      return ThemeIcons.iconFromName("steam", fallback);

    if (windowClass !== "")
      return ThemeIcons.iconForAppId(windowClass, fallback);

    return ThemeIcons.iconFromName(fallback, fallback);
  }
  property bool compactMode: 48 > targetWindowHeight || 48 > targetWindowWidth
  // ScreencopyView wrapper that fills the parent and clips
  // For fullscreen apps, we fill the entire workspace cell
  // For regular windows, we preserve aspect ratio
  readonly property bool isFullscreen: !!(windowData && windowData.fullscreen)
  readonly property bool isMaximized: !!(windowData && windowData.maximized)
  readonly property bool isEffectivelyFullscreen: !!(geometryModel && geometryModel.isEffectivelyFullscreen)
  readonly property bool isTreatedAsFullscreen: !!(geometryModel && geometryModel.isTreatedAsFullscreen)
  // Calculate shift when this window is the retiling target
  // The target shifts AWAY from where the dragged window will land
  // Shift is proportional to the size change (50% split = 25% shift to show movement)
  readonly property real calculatedShiftX: {
    if (!isRetileTarget || isDragging || isTreatedAsFullscreen)
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
    if (!isRetileTarget || isDragging || isTreatedAsFullscreen)
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
    return Utils.clamp(value, minValue, maxValue);
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

  function tr(key) {
    if (pluginMain && pluginMain.pluginApi && pluginMain.pluginApi.tr)
      return pluginMain.pluginApi.tr(key);

    return key;
  }

  function debugLog(message) {
    Logger.i("WorkspaceOverview", "[hypr-overview-debug:capture] " + message);
  }

  function isValidFrameRect(frame) {
    if (!frame)
      return false;

    return isFinite(Number(frame.x)) && isFinite(Number(frame.y)) && isFinite(Number(frame.w)) && isFinite(Number(frame.h)) && Number(frame.w) > 0 && Number(frame.h) > 0;
  }

  function queueCaptureRebind(reason) {
    if (!overviewOpen)
      return;

    if (retileTransitionActive) {
      pendingCaptureRebindReason = reason || "retile";
      debugLog("rebindDeferred address=" + ((windowData && windowData.address) || "") + " reason=" + pendingCaptureRebindReason + " visualMode=" + visualMode + " revision=" + captureRevision);
      return;
    }

    if (captureSourceEnabled) {
      captureSourceEnabled = false;
      debugLog("sourceDisabled address=" + ((windowData && windowData.address) || "") + " reason=" + (reason || "") + " visualMode=" + visualMode + " revision=" + captureRevision);
    }
    captureSourceRebind.restart();
  }

  x: initX + calculatedShiftX
  y: initY + calculatedShiftY
  opacity: clamp((monitorOpacityFactor * workspaceOpacityFactor * (1 - unfocusedIdleOpacityCut) + hoverOpacityBoost) * dragFeedbackOpacity, 0, 1)
  width: contentWidth
  height: contentHeight
  // Trigger Steam icon search when we have a steamAppId and the window is visible
  onOverviewOpenChanged: {
    debugLog("overviewOpenChanged address=" + ((windowData && windowData.address) || "") + " visualMode=" + visualMode + " revision=" + captureRevision + " sourceEnabled=" + captureSourceEnabled + " overviewOpen=" + overviewOpen);
    captureSourceEnabled = overviewOpen;
    if (overviewOpen && root.steamAppId !== "" && !steamIconFinder.hasRun) {
      steamIconFinder.hasRun = true;
      steamIconFinder.running = true;
    }
  }

  onCaptureRevisionChanged: {
    debugLog("revisionChanged address=" + ((windowData && windowData.address) || "") + " visualMode=" + visualMode + " revision=" + captureRevision + " sourceEnabled=" + captureSourceEnabled + " overviewOpen=" + overviewOpen);
    queueCaptureRebind("revision");
  }

  onDisplayedPreviewSizeKeyChanged: {
    debugLog("sizeChanged address=" + ((windowData && windowData.address) || "") + " size=" + displayedPreviewSizeKey + " visualMode=" + visualMode + " revision=" + captureRevision);
    queueCaptureRebind("size");
  }

  onRetileTransitionActiveChanged: {
    if (retileTransitionActive) {
      captureSourceRebind.stop();
      captureSourceEnabled = overviewOpen;
      debugLog("retileActive address=" + ((windowData && windowData.address) || "") + " sourceHeld=" + captureSourceEnabled + " visualMode=" + visualMode + " revision=" + captureRevision);
      return;
    }

    if (!retileTransitionActive && pendingCaptureRebindReason !== "") {
      var pendingReason = pendingCaptureRebindReason;
      pendingCaptureRebindReason = "";
      queueCaptureRebind(pendingReason);
    }
  }

  onPositionResyncRevisionChanged: {
    if (positionResyncRevision <= 0)
      return;

    x = Math.round(initX + calculatedShiftX);
    y = Math.round(initY + calculatedShiftY);
    debugLog("positionResync address=" + ((windowData && windowData.address) || "") + " revision=" + positionResyncRevision + " x=" + x + " y=" + y);
  }

  Timer {
    id: captureSourceRebind

    interval: 16
    repeat: false
    onTriggered: {
      if (root.overviewOpen) {
        root.captureSourceEnabled = true;
        root.debugLog("sourceEnabled address=" + ((root.windowData && root.windowData.address) || "") + " visualMode=" + root.visualMode + " revision=" + root.captureRevision);
      } else {
        root.debugLog("sourceEnableSkipped address=" + ((root.windowData && root.windowData.address) || "") + " visualMode=" + root.visualMode + " revision=" + root.captureRevision + " overviewOpen=false");
      }
    }
  }

  Item {
    id: visualShell

    anchors.fill: parent
    transform: [
      Scale {
        xScale: root.dragScale
        yScale: root.dragScale
        origin.x: root.dragOriginX
        origin.y: root.dragOriginY
      },
      Rotation {
        angle: root.dragTilt
        axis.x: 0
        axis.y: 1
        axis.z: 0
        origin.x: root.dragOriginX
        origin.y: root.dragOriginY
      }
    ]

    Rectangle {
      id: previewContentMask

      width: root.targetWindowWidth
      height: root.targetWindowHeight
      radius: root.effectiveCornerRadius
      visible: false
      layer.enabled: true
    }

    Rectangle {
      id: shadowCaster

      x: maskedPreviewContent.x
      y: maskedPreviewContent.y
      width: maskedPreviewContent.width
      height: maskedPreviewContent.height
      radius: root.effectiveCornerRadius
      color: Qt.rgba(1, 1, 1, 0.02)
      layer.enabled: true

      layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: Style.shadowBlurMax
        shadowBlur: Style.shadowBlur * (root.isFocusedWindow ? 1.55 : (root.hovered ? (1.36 + hoverEmphasisFactor * 0.24) : 1.32))
        shadowOpacity: Style.shadowOpacity * (root.isFocusedWindow ? 1.15 : (root.hovered ? (1 + hoverEmphasisFactor * 0.1) : 0.95))
        shadowColor: "#000000"
        shadowHorizontalOffset: 0
        shadowVerticalOffset: root.isDragging ? 8 : 4
      }
    }

    Item {
      id: maskedPreviewContent

      y: 0
      width: root.targetWindowWidth
      height: root.targetWindowHeight
      layer.enabled: true

      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: previewContentMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }

      ScreencopyView {
        id: windowPreview

        anchors.fill: parent
        captureSource: {
          if (!root.overviewOpen)
            return null;
          if (!root.captureSourceEnabled)
            return null;
          if (root.visualMode === "off")
            return null;
          return root.toplevel;
        }
        live: root.visualMode === "live" && !root.retileTransitionActive
        visible: root.visualMode !== "off" && root.overviewOpen
      }

      Rectangle {
        visible: root.visualMode === "off" && root.overviewOpen
        anchors.fill: parent
        color: Color.mSurfaceVariant
        border.color: Color.mOutline
        border.width: 1
        radius: root.effectiveCornerRadius
      }

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
        visible: root.visualMode === "simplified" && root.overviewOpen
        fragmentShader: root.shaderPreset === "mac" ? Qt.resolvedUrl("../shaders/qsb/window_mac_classic.frag.qsb") : Qt.resolvedUrl("../shaders/qsb/window_simplify.frag.qsb")

        source: ShaderEffectSource {
          sourceItem: windowPreview
          hideSource: root.visualMode === "simplified"
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
        border.width: 0

        Rectangle {
          id: interactionOverlay

          anchors.fill: parent
          radius: parent.radius
          color: {
            if (root.isDragging)
              return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.38);

            if (root.pressed)
              return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.34);

            if (root.hovered)
              return Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.12);

            return "transparent";
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          color: Qt.rgba(1, 1, 1, root.hoverSheenAlpha)
          visible: root.hoverSheenAlpha > 0.001
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, root.materialSurfaceAlpha)
        }
      }

      // App icon
      Item {
        visible: root.showWindowIcons
        anchors.fill: parent

        Item {
          // Dynamic positioning based on user setting (center vs corner).

          id: iconContainer

          x: root.windowIconPlacement === "center" ? (parent.width - width) / 2 : (parent.width - width - Math.max(8, parent.width * 0.05))
          y: root.windowIconPlacement === "center" ? ((parent.height - height) / 2 + (root.canShowTitleStrip ? root.titleStripDrawHeight * 0.35 : 0)) : (parent.height - height - Math.max(8, parent.height * 0.05))
          width: windowIcon.width
          height: windowIcon.height

          Image {
            id: windowIcon

            // Calculate max icon dimensions based on workspace size and placement mode.
            property real maxIconScale: root.windowIconPlacement === "corner" ? 0.35 : 1
            property real maxIconSize: {
              return Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) * maxIconScale / ((root.monitorData && root.monitorData.scale) || 1);
            }
            // Detect if this is a Steam logo (wide image) vs a normal icon (square)
            property bool isSteamLogo: root.steamAppId !== ""

            anchors.centerIn: parent
            // For Steam logos, use maximum available width; for icons, constrain to square
            width: isSteamLogo ? Math.min(root.targetWindowWidth * 0.9 * maxIconScale, implicitWidth) : maxIconSize
            height: maxIconSize
            source: root.iconPath
            fillMode: Image.PreserveAspectFit
            // Colorization (applies accent color over the icon, excluding Steam wide banners)
            layer.enabled: root.colorizeWindowIcons && !isSteamLogo

            layer.effect: MultiEffect {
              colorizationColor: root.activeBorderColor
              colorization: 1
            }

            Behavior on width {
              NumberAnimation {
                duration: root.isDragging ? Style.animationFast : Style.animationNormal
                easing.type: Easing.OutCubic
              }
            }

            Behavior on height {
              NumberAnimation {
                duration: root.isDragging ? Style.animationFast : Style.animationNormal
                easing.type: Easing.OutCubic
              }
            }
          }

          Behavior on x {
            NumberAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }

          Behavior on y {
            NumberAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }

    Row {
      id: stateBadges

      anchors.top: maskedPreviewContent.top
      anchors.right: maskedPreviewContent.right
      anchors.topMargin: Math.max(4, maskedPreviewContent.height * 0.05)
      anchors.rightMargin: Math.max(4, maskedPreviewContent.width * 0.04)
      spacing: 4
      visible: urgencyBadge.visible || floatingBadge.visible || fullscreenBadge.visible || monitorBadge.visible

      Rectangle {
        id: urgencyBadge

        visible: root.showUrgencyBadge && root.isUrgentWindow
        color: Qt.alpha(Color.mError, 0.92)
        radius: 6
        width: urgencyLabel.implicitWidth + 8
        height: urgencyLabel.implicitHeight + 4

        Text {
          id: urgencyLabel

          anchors.centerIn: parent
          text: root.tr("overview.badges.urgent")
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
          text: root.tr("overview.badges.floating")
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
          text: root.tr("overview.badges.fullscreen")
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

    // Single outer border for the combined window shape (titlebar + content)
    Rectangle {
      id: windowBorderOverlay

      z: 2
      x: 0
      y: 0
      width: root.width
      height: root.height
      radius: root.effectiveCornerRadius
      color: "transparent"
      border.width: root.drawnBorderWidth
      border.color: {
        if (root.isDragging)
          return root.focusedBorderColor;

        if (root.isFocusedWindow)
          return root.focusedBorderColor;

        if (root.hovered || root.pressed)
          return root.hoverBorderColor;

        return Qt.rgba(root.effectiveBorderColor.r, root.effectiveBorderColor.g, root.effectiveBorderColor.b, root.outerBorderAlphaIdle);
      }
      visible: root.scaledBorderWidth > 0
    }

    Rectangle {
      id: titleStrip

      // Cap strip corner radius so thin strips don't collapse into pill-like corners.
      property real effectiveRadius: Math.min(root.effectiveCornerRadius, height * 0.5)

      visible: root.canShowTitleStrip
      z: 1
      // Positioning logic based on user setting
      anchors.left: maskedPreviewContent.left
      anchors.right: maskedPreviewContent.right
      anchors.top: root.stripPosition === "overlay-bottom" ? undefined : maskedPreviewContent.top
      anchors.bottom: root.stripPosition === "overlay-bottom" ? maskedPreviewContent.bottom : undefined
      anchors.leftMargin: root.drawnBorderWidth
      anchors.rightMargin: root.drawnBorderWidth
      anchors.topMargin: root.stripPosition === "overlay-bottom" ? 0 : root.drawnBorderWidth
      anchors.bottomMargin: root.stripPosition === "overlay-bottom" ? root.drawnBorderWidth : 0
      height: root.titleStripDrawHeight
      radius: effectiveRadius
      border.width: 0
      color: "transparent"

      // Strong legibility gradient behind strip text without changing frame geometry.
      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: true

        gradient: Gradient {
          GradientStop {
            position: root.stripPosition === "overlay-top" ? 0 : 1
            color: root.isDragging ? Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.9) : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.84)
          }

          GradientStop {
            position: root.stripPosition === "overlay-top" ? 0.8 : 0.2
            color: root.isDragging ? Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.54) : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.4)
          }

          GradientStop {
            position: root.stripPosition === "overlay-top" ? 1 : 0
            color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.14)
          }
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(6, parent.height * 0.45)
        anchors.rightMargin: Math.max(6, parent.height * 0.45)
        anchors.topMargin: Math.max(1, parent.height * 0.12)
        anchors.bottomMargin: Math.max(1, parent.height * 0.12)
        spacing: Math.max(6, parent.height * 0.34)

        Text {
          Layout.fillWidth: true
          text: root.displayTitle
          color: Color.mOnSurface
          elide: Text.ElideRight
          font.family: Settings.data.ui.fontDefault
          font.pixelSize: Math.max(8, Math.min(14, titleStrip.height * 0.56))
          font.weight: Style.fontWeightSemiBold
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignLeft
          style: Text.Raised
          styleColor: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.94)
        }

        Text {
          visible: root.titleStripMetaText !== "" && root.width > 120
          text: root.titleStripMetaText
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
          font.family: Settings.data.ui.fontDefault
          font.pixelSize: Math.max(7, Math.min(11, titleStrip.height * 0.44))
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignRight
          Layout.maximumWidth: root.width * 0.34
          style: Text.Raised
          styleColor: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.86)
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
    enabled: !root.suppressPositionAnimation && !root.isDragging && root.animationDuration("normal") > 0

    NumberAnimation {
      duration: root.retileTransitionActive ? 140 : root.isDragging ? root.animationDuration("fast") : (root.isRetileTarget || root.retilingDirection !== "") ? root.animationDuration("fast") : root.animationDuration("normal")
      easing.type: root.retileTransitionActive ? Easing.BezierSpline : Easing.OutCubic
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
  }

  Behavior on y {
    enabled: !root.suppressPositionAnimation && !root.isDragging && root.animationDuration("normal") > 0

    NumberAnimation {
      duration: root.retileTransitionActive ? 140 : root.isDragging ? root.animationDuration("fast") : (root.isRetileTarget || root.retilingDirection !== "") ? root.animationDuration("fast") : root.animationDuration("normal")
      easing.type: root.retileTransitionActive ? Easing.BezierSpline : Easing.OutCubic
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
  }

  Behavior on width {
    enabled: root.animationDuration("normal") > 0

    NumberAnimation {
      duration: root.retileTransitionActive ? 140 : root.isDragging ? root.animationDuration("fast") : root.animationDuration("normal")
      easing.type: root.retileTransitionActive ? Easing.BezierSpline : Easing.OutCubic
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
  }

  Behavior on height {
    enabled: root.animationDuration("normal") > 0

    NumberAnimation {
      duration: root.retileTransitionActive ? 140 : root.isDragging ? root.animationDuration("fast") : root.animationDuration("normal")
      easing.type: root.retileTransitionActive ? Easing.BezierSpline : Easing.OutCubic
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
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
}
