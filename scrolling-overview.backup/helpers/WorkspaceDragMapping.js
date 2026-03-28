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
    var rawX = ((clampedFrameX - inset) / scaleX) - centeringX
    var rawY = ((clampedFrameY - inset) / scaleY) - centeringY

    var monitorX = toNumber(args.monitorX, 0)
    var monitorY = toNumber(args.monitorY, 0)
    var monitorLogicalWidth = Math.max(1, toNumber(args.monitorLogicalWidth, 1920))
    var monitorLogicalHeight = Math.max(1, toNumber(args.monitorLogicalHeight, 1080))
    var windowWidthRaw = Math.max(1, toNumber(args.windowWidthRaw, 1))
    var windowHeightRaw = Math.max(1, toNumber(args.windowHeightRaw, 1))

    var minX = monitorX
    var minY = monitorY
    var maxX = Math.max(minX, monitorX + monitorLogicalWidth - windowWidthRaw)
    var maxY = Math.max(minY, monitorY + monitorLogicalHeight - windowHeightRaw)

    return {
        "x": Math.round(clamp(rawX + monitorX, minX, maxX)),
        "y": Math.round(clamp(rawY + monitorY, minY, maxY)),
        "minX": minX,
        "minY": minY,
        "maxX": maxX,
        "maxY": maxY
    }
}

function snapToCandidates(value, candidates, minValue, maxValue, thresholdPx) {
    if (!candidates || candidates.length === 0)
        return value

    var bestValue = value
    var bestDistance = thresholdPx + 1

    for (var i = 0; i < candidates.length; i++) {
        var candidate = Math.round(clamp(candidates[i], minValue, maxValue))
        var distance = Math.abs(value - candidate)
        if (distance < bestDistance) {
            bestDistance = distance
            bestValue = candidate
        }
    }

    if (bestDistance <= thresholdPx)
        return bestValue

    return value
}

function hasFloatingOverlapAt(windowByAddress, draggedAddress, workspaceId, monitorId, xPos, yPos, widthPx, heightPx, overlapThresholdRatio) {
    var minOverlapX = Math.max(16, Math.min(widthPx, 200) * Math.max(0, toNumber(overlapThresholdRatio, 0.32)))
    var minOverlapY = Math.max(16, Math.min(heightPx, 200) * Math.max(0, toNumber(overlapThresholdRatio, 0.32)))

    for (var addr in windowByAddress) {
        if (addr === draggedAddress)
            continue

        var win = windowByAddress[addr]
        if (!win || !win.workspace || win.workspace.id !== workspaceId || !win.floating)
            continue

        if (toNumber(win.monitor, -1) !== monitorId)
            continue

        var winX = toNumber(win.at && win.at[0], 0)
        var winY = toNumber(win.at && win.at[1], 0)
        var winW = Math.max(1, toNumber(win.size && win.size[0], 1))
        var winH = Math.max(1, toNumber(win.size && win.size[1], 1))
        var overlapX = Math.min(xPos + widthPx, winX + winW) - Math.max(xPos, winX)
        var overlapY = Math.min(yPos + heightPx, winY + winH) - Math.max(yPos, winY)

        if (overlapX >= minOverlapX && overlapY >= minOverlapY)
            return true
    }

    return false
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
        "windowWidthRaw": args.windowWidthRaw,
        "windowHeightRaw": args.windowHeightRaw
    })

    if (!mapped)
        return null

    var nextX = mapped.x
    var nextY = mapped.y
    var minX = mapped.minX
    var minY = mapped.minY
    var maxX = mapped.maxX
    var maxY = mapped.maxY

    var windowWidthRaw = Math.max(1, toNumber(args.windowWidthRaw, 1))
    var windowHeightRaw = Math.max(1, toNumber(args.windowHeightRaw, 1))
    var snapBasePx = Math.max(0, toNumber(args.snapBasePx, 42))
    var snapRatio = Math.max(0, toNumber(args.snapRatio, 0.1))
    var snapThreshold = Math.max(snapBasePx, Math.round(Math.min(windowWidthRaw, windowHeightRaw) * snapRatio))

    var xCandidates = [minX, maxX]
    var yCandidates = [minY, maxY]

    var workspaceId = toNumber(args.workspaceId, -1)
    var monitorId = toNumber(args.monitorId, -1)
    var draggedAddress = args.draggedAddress || ""
    var windowByAddress = args.windowByAddress || {}

    for (var addr in windowByAddress) {
        if (addr === draggedAddress)
            continue

        var otherWin = windowByAddress[addr]
        if (!otherWin || !otherWin.workspace || !otherWin.floating || otherWin.workspace.id !== workspaceId)
            continue

        if (toNumber(otherWin.monitor, -1) !== monitorId)
            continue

        var otherX = toNumber(otherWin.at && otherWin.at[0], 0)
        var otherY = toNumber(otherWin.at && otherWin.at[1], 0)
        var otherW = Math.max(1, toNumber(otherWin.size && otherWin.size[0], 1))
        var otherH = Math.max(1, toNumber(otherWin.size && otherWin.size[1], 1))

        xCandidates.push(otherX)
        xCandidates.push(otherX + otherW - windowWidthRaw)
        xCandidates.push(otherX - windowWidthRaw)
        xCandidates.push(otherX + otherW)

        yCandidates.push(otherY)
        yCandidates.push(otherY + otherH - windowHeightRaw)
        yCandidates.push(otherY - windowHeightRaw)
        yCandidates.push(otherY + otherH)
    }

    nextX = snapToCandidates(nextX, xCandidates, minX, maxX, snapThreshold)
    nextY = snapToCandidates(nextY, yCandidates, minY, maxY, snapThreshold)

    var minStepPx = Math.max(1, toNumber(args.minStepPx, 28))
    var maxOffsetSteps = Math.max(0, Math.floor(toNumber(args.maxOffsetSteps, 6)))
    var overlapThresholdRatio = Math.max(0, toNumber(args.overlapThresholdRatio, 0.32))
    var step = Math.max(minStepPx, Math.round(Math.min(windowWidthRaw, windowHeightRaw) * 0.12))

    for (var i = 0; i < maxOffsetSteps; i++) {
        if (!hasFloatingOverlapAt(windowByAddress, draggedAddress, workspaceId, monitorId, nextX, nextY, windowWidthRaw, windowHeightRaw, overlapThresholdRatio))
            break

        nextX = Math.round(clamp(nextX + step, minX, maxX))
        nextY = Math.round(clamp(nextY + step, minY, maxY))
    }

    return {
        "x": nextX,
        "y": nextY
    }
}
