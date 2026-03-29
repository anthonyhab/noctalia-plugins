.pragma library

var FULLSCREEN_THRESHOLD_RATIO = 0.95
var FULLSCREEN_GAP_PX = 8
var FULLSCREEN_GAP_SIMPLIFIED_PX = 4
var MIN_INSET_PX = 1

function toNumber(value, fallback) {
    var parsed = Number(value)
    if (!isFinite(parsed))
        return fallback

    return parsed
}

function clamp(value, minValue, maxValue) {
    if (value < minValue)
        return minValue

    if (value > maxValue)
        return maxValue

    return value
}

function getMonitorLogicalSize(monitorObj) {
    if (!monitorObj) {
        return {
            "width": 1920,
            "height": 1080
        }
    }

    var scale = Math.max(0.0001, toNumber(monitorObj.scale, 1))
    var rawWidth = toNumber(monitorObj.width, 1920) / scale
    var rawHeight = toNumber(monitorObj.height, 1080) / scale
    var transform = Math.floor(toNumber(monitorObj.transform, 0))

    if (transform % 2 === 1) {
        return {
            "width": rawHeight,
            "height": rawWidth
        }
    }

    return {
        "width": rawWidth,
        "height": rawHeight
    }
}

function getHyprlandPreviewInset(args) {
    args = args || {}

    var hyprGapsIn = Math.max(0, toNumber(args.hyprGapsIn, 0))
    var hyprBorderSize = Math.max(0, toNumber(args.hyprBorderSize, 0))
    var fallbackInset = Math.max(0, toNumber(args.fallbackInset, 0))
    var scaleX = Math.abs(toNumber(args.positionScaleX, 1))
    var scaleY = Math.abs(toNumber(args.positionScaleY, 1))
    var axisScale = Math.min(Math.max(0.0001, scaleX), Math.max(0.0001, scaleY))

    // Mirror Hyprland spacing: inner gaps plus border thickness converted into preview pixels.
    var scaledGap = hyprGapsIn * axisScale
    var scaledBorder = hyprBorderSize * axisScale
    var hyprInset = Math.round(scaledGap + scaledBorder)

    return Math.max(MIN_INSET_PX, Math.max(hyprInset, Math.round(fallbackInset)))
}

function buildWorkspaceContext(args) {
    args = args || {}

    var workspaceWidth = Math.max(1, toNumber(args.workspaceWidth, 100))
    var workspaceHeight = Math.max(1, toNumber(args.workspaceHeight, 100))
    var logicalSize = getMonitorLogicalSize(args.monitorData)
    var positionScaleX = toNumber(args.positionScaleX, workspaceWidth / Math.max(1, logicalSize.width))
    var positionScaleY = toNumber(args.positionScaleY, workspaceHeight / Math.max(1, logicalSize.height))
    var windowScale = toNumber(args.windowScale, Math.min(positionScaleX, positionScaleY))
    var centeringX = toNumber(args.centeringX, 0)
    var centeringY = toNumber(args.centeringY, 0)
    var previewInset = getHyprlandPreviewInset({
        "hyprGapsIn": args.hyprGapsIn,
        "hyprBorderSize": args.hyprBorderSize,
        "positionScaleX": positionScaleX,
        "positionScaleY": positionScaleY,
        "fallbackInset": args.fallbackInset
    })
    var fullscreenGap = Math.max(0, Math.round(toNumber(args.fullscreenGap, args.useSimplifiedPreview ? FULLSCREEN_GAP_SIMPLIFIED_PX : FULLSCREEN_GAP_PX)))

    return {
        "workspaceWidth": workspaceWidth,
        "workspaceHeight": workspaceHeight,
        "logicalMonitorWidth": logicalSize.width,
        "logicalMonitorHeight": logicalSize.height,
        "positionScaleX": positionScaleX,
        "positionScaleY": positionScaleY,
        "windowScale": windowScale,
        "centeringX": centeringX,
        "centeringY": centeringY,
        "previewInset": previewInset,
        "fullscreenGap": Math.max(MIN_INSET_PX, fullscreenGap)
    }
}

function mapWindowToPreviewFrame(args) {
    args = args || {}

    var windowData = args.windowData
    if (!windowData)
        return null

    var context = buildWorkspaceContext(args)
    var monitorData = args.monitorData || {}
    var monitorX = toNumber(monitorData.x, 0)
    var monitorY = toNumber(monitorData.y, 0)

    var rawPosX = toNumber(windowData.at && windowData.at[0], 0) - monitorX
    var rawPosY = toNumber(windowData.at && windowData.at[1], 0) - monitorY
    var windowWidthRaw = Math.max(1, toNumber(windowData.size && windowData.size[0], 1))
    var windowHeightRaw = Math.max(1, toNumber(windowData.size && windowData.size[1], 1))

    var scaledClientWidth = windowWidthRaw * context.windowScale
    var scaledClientHeight = windowHeightRaw * context.windowScale
    var isFullscreen = !!windowData.fullscreen
    var isMaximized = !!windowData.maximized
    var isEffectivelyFullscreen = scaledClientWidth >= context.workspaceWidth * FULLSCREEN_THRESHOLD_RATIO && scaledClientHeight >= context.workspaceHeight * FULLSCREEN_THRESHOLD_RATIO

    var forcedFullscreen = args.forceTreatedAsFullscreen
    var isTreatedAsFullscreen = forcedFullscreen === undefined ? (isFullscreen || isMaximized || isEffectivelyFullscreen) : !!forcedFullscreen
    var frameInset = isTreatedAsFullscreen ? context.fullscreenGap : context.previewInset

    var safeWorkspaceWidth = Math.max(1, context.workspaceWidth - (frameInset * 2))
    var safeWorkspaceHeight = Math.max(1, context.workspaceHeight - (frameInset * 2))
    var insetScaleX = safeWorkspaceWidth / Math.max(1, context.workspaceWidth)
    var insetScaleY = safeWorkspaceHeight / Math.max(1, context.workspaceHeight)
    var effectivePositionScaleX = context.positionScaleX * insetScaleX
    var effectivePositionScaleY = context.positionScaleY * insetScaleY
    var effectiveWindowScale = context.windowScale * Math.min(insetScaleX, insetScaleY)

    var scaledPosX = (rawPosX + context.centeringX) * effectivePositionScaleX
    var scaledPosY = (rawPosY + context.centeringY) * effectivePositionScaleY

    var maxFrameWidth = Math.max(1, Math.round(context.workspaceWidth - (frameInset * 2)))
    var maxFrameHeight = Math.max(1, Math.round(context.workspaceHeight - (frameInset * 2)))
    var frameWidth = isTreatedAsFullscreen ? maxFrameWidth : Math.max(1, Math.round(Math.min(windowWidthRaw * effectiveWindowScale, maxFrameWidth)))
    var frameHeight = isTreatedAsFullscreen ? maxFrameHeight : Math.max(1, Math.round(Math.min(windowHeightRaw * effectiveWindowScale, maxFrameHeight)))

    var frameTargetX = scaledPosX + frameInset
    var frameTargetY = scaledPosY + frameInset
    var frameMaxX = Math.max(frameInset, context.workspaceWidth - frameWidth - frameInset)
    var frameMaxY = Math.max(frameInset, context.workspaceHeight - frameHeight - frameInset)
    var frameX = clamp(frameTargetX, frameInset, frameMaxX)
    var frameY = clamp(frameTargetY, frameInset, frameMaxY)

    return {
        "x": frameX,
        "y": frameY,
        "w": frameWidth,
        "h": frameHeight,
        "inset": frameInset,
        "frameTargetX": frameTargetX,
        "frameTargetY": frameTargetY,
        "frameMaxX": frameMaxX,
        "frameMaxY": frameMaxY,
        "workspaceWidth": context.workspaceWidth,
        "workspaceHeight": context.workspaceHeight,
        "safeWorkspaceWidth": safeWorkspaceWidth,
        "safeWorkspaceHeight": safeWorkspaceHeight,
        "logicalMonitorWidth": context.logicalMonitorWidth,
        "logicalMonitorHeight": context.logicalMonitorHeight,
        "positionScaleX": context.positionScaleX,
        "positionScaleY": context.positionScaleY,
        "windowScale": context.windowScale,
        "effectivePositionScaleX": effectivePositionScaleX,
        "effectivePositionScaleY": effectivePositionScaleY,
        "effectiveWindowScale": effectiveWindowScale,
        "centeringX": context.centeringX,
        "centeringY": context.centeringY,
        "monitorX": monitorX,
        "monitorY": monitorY,
        "windowWidthRaw": windowWidthRaw,
        "windowHeightRaw": windowHeightRaw,
        "isFullscreen": isFullscreen,
        "isMaximized": isMaximized,
        "isEffectivelyFullscreen": isEffectivelyFullscreen,
        "isTreatedAsFullscreen": isTreatedAsFullscreen
    }
}
