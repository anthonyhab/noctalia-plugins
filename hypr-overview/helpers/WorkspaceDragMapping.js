.pragma library

var MIN_SCALE = 0.0001

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

function mapPreviewFrameToLogical(args) {
    args = args || {}

    var workspaceWidth = Math.max(1, toNumber(args.workspaceWidth, 100))
    var workspaceHeight = Math.max(1, toNumber(args.workspaceHeight, 100))
    var inset = Math.max(0, toNumber(args.inset, 0))
    var frameWidth = Math.max(1, toNumber(args.frameWidth, 1))
    var frameHeight = Math.max(1, toNumber(args.frameHeight, 1))

    var frameMaxX = Math.max(inset, workspaceWidth - frameWidth - inset)
    var frameMaxY = Math.max(inset, workspaceHeight - frameHeight - inset)
    var clampedFrameX = clamp(toNumber(args.frameX, inset), inset, frameMaxX)
    var clampedFrameY = clamp(toNumber(args.frameY, inset), inset, frameMaxY)

    var fallbackScaleX = Math.max(MIN_SCALE, toNumber(args.positionScaleX, 1))
    var fallbackScaleY = Math.max(MIN_SCALE, toNumber(args.positionScaleY, 1))
    var scaleX = Math.max(MIN_SCALE, toNumber(args.effectivePositionScaleX, fallbackScaleX))
    var scaleY = Math.max(MIN_SCALE, toNumber(args.effectivePositionScaleY, fallbackScaleY))

    var centeringX = toNumber(args.centeringX, 0)
    var centeringY = toNumber(args.centeringY, 0)
    var workAreaX = Math.max(0, toNumber(args.workAreaX, 0))
    var workAreaY = Math.max(0, toNumber(args.workAreaY, 0))
    var rawX = ((clampedFrameX - inset) / scaleX) - centeringX
    var rawY = ((clampedFrameY - inset) / scaleY) - centeringY

    var monitorX = toNumber(args.monitorX, 0)
    var monitorY = toNumber(args.monitorY, 0)
    var monitorLogicalWidth = Math.max(1, toNumber(args.workAreaWidth, toNumber(args.monitorLogicalWidth, 1920)))
    var monitorLogicalHeight = Math.max(1, toNumber(args.workAreaHeight, toNumber(args.monitorLogicalHeight, 1080)))
    var windowWidthRaw = Math.max(1, toNumber(args.windowWidthRaw, 1))
    var windowHeightRaw = Math.max(1, toNumber(args.windowHeightRaw, 1))

    var minX = monitorX + workAreaX
    var minY = monitorY + workAreaY
    var maxX = Math.max(minX, minX + monitorLogicalWidth - windowWidthRaw)
    var maxY = Math.max(minY, minY + monitorLogicalHeight - windowHeightRaw)

    return {
        "x": Math.round(clamp(rawX + minX, minX, maxX)),
        "y": Math.round(clamp(rawY + minY, minY, maxY)),
        "minX": minX,
        "minY": minY,
        "maxX": maxX,
        "maxY": maxY
    }
}

function resolveFloatingDropPosition(args) {
    args = args || {}

    var mapped = mapPreviewFrameToLogical({
        "workspaceWidth": args.workspaceWidth,
        "workspaceHeight": args.workspaceHeight,
        "inset": args.inset,
        "frameWidth": args.frameWidth,
        "frameHeight": args.frameHeight,
        "frameX": args.frameX,
        "frameY": args.frameY,
        "effectivePositionScaleX": args.effectivePositionScaleX,
        "effectivePositionScaleY": args.effectivePositionScaleY,
        "positionScaleX": args.positionScaleX,
        "positionScaleY": args.positionScaleY,
        "centeringX": args.centeringX,
        "centeringY": args.centeringY,
        "monitorX": args.monitorX,
        "monitorY": args.monitorY,
        "monitorLogicalWidth": args.monitorLogicalWidth,
        "monitorLogicalHeight": args.monitorLogicalHeight,
        "workAreaX": args.workAreaX,
        "workAreaY": args.workAreaY,
        "workAreaWidth": args.workAreaWidth,
        "workAreaHeight": args.workAreaHeight,
        "windowWidthRaw": args.windowWidthRaw,
        "windowHeightRaw": args.windowHeightRaw
    })

    if (!mapped)
        return null

    return {
        "x": mapped.x,
        "y": mapped.y
    }
}
