.pragma library

function toNumber(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
}

function clamp(value, min, max) {
    if (value < min) return min
    if (value > max) return max
    return value
}

function isSplitDirection(direction) {
    return direction === "l" || direction === "r" || direction === "u" || direction === "d"
}

function resolveZone(args) {
    args = args || {}
    var x = toNumber(args.x, 0)
    var y = toNumber(args.y, 0)
    var width = Math.max(1, toNumber(args.width, 1))
    var height = Math.max(1, toNumber(args.height, 1))
    var edgeRatio = clamp(Math.max(toNumber(args.edgeRatio, 0.33), toNumber(args.minSplitRatio, 0)), 0.15, 0.49)
    var minEdgePx = Math.max(0, toNumber(args.minEdgePx, 32))
    var deadzonePx = Math.max(1, toNumber(args.deadzonePx, 6))
    var edgeX = clamp(Math.max(edgeRatio, minEdgePx / width), 0.15, 0.49)
    var edgeY = clamp(Math.max(edgeRatio, minEdgePx / height), 0.15, 0.49)
    var relX = clamp(x / width, 0, 1)
    var relY = clamp(y / height, 0, 1)
    var edgeXPx = edgeX * width
    var edgeYPx = edgeY * height
    var candidates = []
    var previousDirection = args.previousDirection || ""

    if (relX < edgeX)
        candidates.push({ direction: "l", distance: x, edgeLimit: edgeXPx })

    if (relX > 1 - edgeX)
        candidates.push({ direction: "r", distance: width - x, edgeLimit: edgeXPx })

    if (relY < edgeY)
        candidates.push({ direction: "u", distance: y, edgeLimit: edgeYPx })

    if (relY > 1 - edgeY)
        candidates.push({ direction: "d", distance: height - y, edgeLimit: edgeYPx })

    if (candidates.length === 0)
        return { direction: "swap", confidence: 1 }

    candidates.sort(function(a, b) {
        return a.distance - b.distance
    })

    var nearest = candidates[0]
    if (candidates.length > 1 && isSplitDirection(previousDirection)) {
        var separationForTie = Math.abs(candidates[1].distance - nearest.distance)
        if (separationForTie <= 0.0001) {
            for (var i = 0; i < candidates.length; i++) {
                if (candidates[i].direction === previousDirection) {
                    nearest = candidates[i]
                    break
                }
            }
        }
    }

    var edgeDepth = nearest.edgeLimit - nearest.distance
    var confidence = clamp(edgeDepth / deadzonePx, 0, 1)
    if (candidates.length > 1) {
        var separation = candidates[1].distance - nearest.distance
        confidence = Math.min(confidence, clamp(separation / deadzonePx, 0, 1))
    }

    return { direction: nearest.direction, confidence: confidence }
}

function zoneForPoint(args) {
    return resolveZone(args).direction
}

function splitRects(targetRect, direction) {
    if (!targetRect || !isSplitDirection(direction))
        return { draggedResultRect: null, targetResultRect: null }

    var targetX = toNumber(targetRect.x, 0)
    var targetY = toNumber(targetRect.y, 0)
    var targetW = toNumber(targetRect.w, targetRect.width || 0)
    var targetH = toNumber(targetRect.h, targetRect.height || 0)
    var dragged = { x: targetX, y: targetY, w: targetW, h: targetH }
    var target = { x: targetX, y: targetY, w: targetW, h: targetH }

    if (direction === "l") {
        dragged.w = targetW / 2
        target.x = targetX + targetW / 2
        target.w = targetW / 2
    } else if (direction === "r") {
        dragged.x = targetX + targetW / 2
        dragged.w = targetW / 2
        target.w = targetW / 2
    } else if (direction === "u") {
        dragged.h = targetH / 2
        target.y = targetY + targetH / 2
        target.h = targetH / 2
    } else if (direction === "d") {
        dragged.y = targetY + targetH / 2
        dragged.h = targetH / 2
        target.h = targetH / 2
    }

    return { draggedResultRect: dragged, targetResultRect: target }
}

function rectNearlyEqual(a, b, epsilonPx) {
    if (!a || !b)
        return false

    return Math.abs(a.x - b.x) <= epsilonPx && Math.abs(a.y - b.y) <= epsilonPx && Math.abs(a.w - b.w) <= epsilonPx && Math.abs(a.h - b.h) <= epsilonPx
}

function isSplitNoop(direction, draggedRect, targetRect, epsilonPx) {
    if (!draggedRect || !targetRect)
        return false

    if (direction === "l")
        return Math.abs((draggedRect.x + draggedRect.w) - targetRect.x) <= epsilonPx && Math.abs(draggedRect.y - targetRect.y) <= epsilonPx && Math.abs(draggedRect.h - targetRect.h) <= epsilonPx

    if (direction === "r")
        return Math.abs(draggedRect.x - (targetRect.x + targetRect.w)) <= epsilonPx && Math.abs(draggedRect.y - targetRect.y) <= epsilonPx && Math.abs(draggedRect.h - targetRect.h) <= epsilonPx

    if (direction === "u")
        return Math.abs((draggedRect.y + draggedRect.h) - targetRect.y) <= epsilonPx && Math.abs(draggedRect.x - targetRect.x) <= epsilonPx && Math.abs(draggedRect.w - targetRect.w) <= epsilonPx

    if (direction === "d")
        return Math.abs(draggedRect.y - (targetRect.y + targetRect.h)) <= epsilonPx && Math.abs(draggedRect.x - targetRect.x) <= epsilonPx && Math.abs(draggedRect.w - targetRect.w) <= epsilonPx

    return false
}

function recordWorkspaceId(record) {
    if (!record)
        return -1

    if (record.workspaceId !== undefined)
        return toNumber(record.workspaceId, -1)

    if (record.workspace && record.workspace.id !== undefined)
        return toNumber(record.workspace.id, -1)

    return -1
}

function recordRect(record) {
    if (!record)
        return null

    var source = record.rect || record.scaledRect || record.currentRect || null
    if (!source)
        return null

    var width = source.w !== undefined ? source.w : source.width
    var height = source.h !== undefined ? source.h : source.height
    var rect = {
        x: toNumber(source.x, NaN),
        y: toNumber(source.y, NaN),
        w: toNumber(width, NaN),
        h: toNumber(height, NaN)
    }
    if (!isFinite(rect.x) || !isFinite(rect.y) || !isFinite(rect.w) || !isFinite(rect.h) || rect.w <= 0 || rect.h <= 0)
        return null

    return rect
}

function targetSortKey(candidate, localAimX, localAimY) {
    var rect = candidate.rect
    var centerX = rect.x + rect.w / 2
    var centerY = rect.y + rect.h / 2
    var dx = localAimX - centerX
    var dy = localAimY - centerY
    return {
        area: rect.w * rect.h,
        centerDistanceSq: dx * dx + dy * dy,
        address: candidate.address || ""
    }
}

function compareTargets(a, b, localAimX, localAimY) {
    var ak = targetSortKey(a, localAimX, localAimY)
    var bk = targetSortKey(b, localAimX, localAimY)
    if (ak.area !== bk.area)
        return ak.area - bk.area

    if (ak.centerDistanceSq !== bk.centerDistanceSq)
        return ak.centerDistanceSq - bk.centerDistanceSq

    if (ak.address < bk.address)
        return -1

    if (ak.address > bk.address)
        return 1

    return 0
}

function resolveTarget(args) {
    args = args || {}
    var workspaceId = toNumber(args.workspaceId, -1)
    var offset = args.workspaceOffset || {}
    var wsOffsetX = toNumber(args.workspaceOffsetX, toNumber(offset.x, 0))
    var wsOffsetY = toNumber(args.workspaceOffsetY, toNumber(offset.y, 0))
    var hotspotX = toNumber(args.hotspotX, NaN)
    var hotspotY = toNumber(args.hotspotY, NaN)
    var draggedAddress = args.draggedAddress || ""
    var windows = args.windows || []
    var draggedWindow = args.draggedWindow || null

    if (workspaceId === -1 || !draggedAddress || !isFinite(hotspotX) || !isFinite(hotspotY) || !windows || windows.length === 0)
        return null

    if (draggedWindow && (draggedWindow.floating || draggedWindow.fullscreen || draggedWindow.maximized))
        return null

    var localAimX = hotspotX - wsOffsetX
    var localAimY = hotspotY - wsOffsetY
    var draggedRectLocal = null
    var candidates = []

    for (var i = 0; i < windows.length; i++) {
        var record = windows[i]
        if (!record)
            continue

        var address = record.address || ""
        if (!address)
            continue

        if (address === draggedAddress) {
            draggedRectLocal = recordRect(record)
            if (record.floating || record.fullscreen || record.maximized)
                return null
            continue
        }

        if (recordWorkspaceId(record) !== workspaceId)
            continue

        if (record.floating || record.fullscreen || record.maximized)
            continue

        var rect = recordRect(record)
        if (!rect)
            continue

        if (localAimX >= rect.x && localAimX <= rect.x + rect.w && localAimY >= rect.y && localAimY <= rect.y + rect.h)
            candidates.push({ address: address, rect: rect })
    }

    if (!draggedRectLocal && draggedWindow)
        draggedRectLocal = recordRect(draggedWindow)

    if (candidates.length === 0)
        return null

    candidates.sort(function(a, b) {
        return compareTargets(a, b, localAimX, localAimY)
    })

    var target = candidates[0]
    var targetRectLocal = {
        x: target.rect.x,
        y: target.rect.y,
        w: target.rect.w,
        h: target.rect.h
    }
    var targetInfo = {
        targetAddress: target.address,
        targetX: targetRectLocal.x + wsOffsetX,
        targetY: targetRectLocal.y + wsOffsetY,
        targetW: targetRectLocal.w,
        targetH: targetRectLocal.h
    }
    var zone = resolveZone({
        x: localAimX - targetRectLocal.x,
        y: localAimY - targetRectLocal.y,
        width: targetRectLocal.w,
        height: targetRectLocal.h,
        edgeRatio: args.edgeRatio,
        minSplitRatio: args.minSplitRatio,
        minEdgePx: args.minEdgePx,
        deadzonePx: args.deadzonePx,
        previousDirection: args.previousDirection || ""
    })
    var direction = zone.direction
    var split = splitRects({
        x: targetInfo.targetX,
        y: targetInfo.targetY,
        w: targetInfo.targetW,
        h: targetInfo.targetH
    }, direction)
    var previewX = targetInfo.targetX
    var previewY = targetInfo.targetY
    var previewW = targetInfo.targetW
    var previewH = targetInfo.targetH
    var targetNewX = targetInfo.targetX
    var targetNewY = targetInfo.targetY
    var targetNewW = targetInfo.targetW
    var targetNewH = targetInfo.targetH
    if (split.draggedResultRect) {
        previewX = split.draggedResultRect.x
        previewY = split.draggedResultRect.y
        previewW = split.draggedResultRect.w
        previewH = split.draggedResultRect.h
    }
    if (split.targetResultRect) {
        targetNewX = split.targetResultRect.x
        targetNewY = split.targetResultRect.y
        targetNewW = split.targetResultRect.w
        targetNewH = split.targetResultRect.h
    }

    var draggedCurrentRect = draggedRectLocal ? {
        x: draggedRectLocal.x + wsOffsetX,
        y: draggedRectLocal.y + wsOffsetY,
        w: draggedRectLocal.w,
        h: draggedRectLocal.h
    } : null
    var predictedDraggedRect = split.draggedResultRect ? {
        x: split.draggedResultRect.x,
        y: split.draggedResultRect.y,
        w: split.draggedResultRect.w,
        h: split.draggedResultRect.h
    } : null
    var noopEpsilon = Math.max(0, toNumber(args.noopGeometryEpsilonPx, 2))
    var isNoop = false
    var noopReason = ""
    if (isSplitDirection(direction) && draggedRectLocal) {
        isNoop = isSplitNoop(direction, draggedRectLocal, targetRectLocal, noopEpsilon)
        if (isNoop)
            noopReason = "split-already-matches"
        else if (predictedDraggedRect && rectNearlyEqual(draggedCurrentRect, predictedDraggedRect, noopEpsilon)) {
            isNoop = true
            noopReason = "predicted-geometry-matches"
        }
    }

    var result = {
        targetAddress: target.address,
        direction: direction,
        confidence: zone.confidence,
        operationType: direction === "swap" ? "swap" : "split",
        isNoop: isNoop,
        noopReason: noopReason,
        targetX: targetInfo.targetX,
        targetY: targetInfo.targetY,
        targetW: targetInfo.targetW,
        targetH: targetInfo.targetH,
        previewX: previewX,
        previewY: previewY,
        previewW: previewW,
        previewH: previewH,
        targetNewX: targetNewX,
        targetNewY: targetNewY,
        targetNewW: targetNewW,
        targetNewH: targetNewH,
        draggedCurrentRect: draggedCurrentRect,
        predictedDraggedRect: predictedDraggedRect,
        previewModel: null
    }
    result.previewModel = buildPreviewModel(result, direction, args.labels || {})
    return result
}

function buildPreviewModel(targetInfo, direction, labels) {
    if (!targetInfo || !direction)
        return { mode: "none", activeDirection: "", label: "", draggedSlotLabel: "", targetSlotLabel: "" }

    labels = labels || {}
    var targetRect = {
        x: toNumber(targetInfo.targetX, 0),
        y: toNumber(targetInfo.targetY, 0),
        w: toNumber(targetInfo.targetW, 0),
        h: toNumber(targetInfo.targetH, 0)
    }
    var mode = direction === "swap" ? "swap" : "split"
    var rects = splitRects(targetRect, direction)

    return {
        mode: mode,
        activeDirection: direction,
        targetAddress: targetInfo.targetAddress || "",
        targetRect: targetRect,
        draggedResultRect: rects.draggedResultRect,
        targetResultRect: rects.targetResultRect,
        label: labels[direction] || "",
        draggedSlotLabel: labels.draggedSlot || "",
        targetSlotLabel: labels.targetSlot || ""
    }
}

function sameCandidate(a, b) {
    if (!a || !b)
        return false

    return a.targetAddress === b.targetAddress && a.direction === b.direction
}

function cloneFrameRect(rect) {
    if (!rect)
        return null

    var width = rect.w !== undefined ? rect.w : rect.width
    var height = rect.h !== undefined ? rect.h : rect.height
    var frame = {
        x: toNumber(rect.x, NaN),
        y: toNumber(rect.y, NaN),
        w: toNumber(width, NaN),
        h: toNumber(height, NaN)
    }
    if (!isFinite(frame.x) || !isFinite(frame.y) || !isFinite(frame.w) || !isFinite(frame.h) || frame.w <= 0 || frame.h <= 0)
        return null

    return frame
}

function transitionRecord(role, fromFrame, toFrame, durationMs, nowMs, settleTimeoutMs) {
    var from = cloneFrameRect(fromFrame)
    var to = cloneFrameRect(toFrame)
    if (!from || !to)
        return null

    var startedAt = toNumber(nowMs, (typeof Date !== "undefined" && Date.now) ? Date.now() : 0)
    var duration = Math.max(1, toNumber(durationMs, 140))
    return {
        role: role || "",
        fromFrame: from,
        toFrame: to,
        previousFrame: cloneFrameRect(from),
        startedAt: startedAt,
        durationMs: duration,
        settleDeadlineMs: startedAt + Math.max(duration, toNumber(settleTimeoutMs, 450)),
        settledAgainstActual: false
    }
}

function buildTransitionRecords(args) {
    args = args || {}
    var releaseType = args.releaseType || ""
    var sourceAddress = args.sourceAddress || ""
    var info = args.retilingInfo || null
    var preview = info && info.previewModel
    var targetAddress = (info && info.targetAddress) || (preview && preview.targetAddress) || ""

    if ((releaseType !== "tiledSplit" && releaseType !== "tiledSwap") || !sourceAddress || !targetAddress || !info || !preview)
        return null

    var durationMs = Math.max(1, toNumber(args.durationMs, 140))
    var settleTimeoutMs = Math.max(durationMs, toNumber(args.settleTimeoutMs, 450))
    var nowMs = toNumber(args.nowMs, (typeof Date !== "undefined" && Date.now) ? Date.now() : 0)
    var records = {}

    if (releaseType === "tiledSplit") {
        var draggedSplit = transitionRecord("dragged", info.draggedCurrentRect, preview.draggedResultRect, durationMs, nowMs, settleTimeoutMs)
        var targetSplit = transitionRecord("target", preview.targetRect, preview.targetResultRect, durationMs, nowMs, settleTimeoutMs)
        if (draggedSplit)
            records[sourceAddress] = draggedSplit
        if (targetSplit)
            records[targetAddress] = targetSplit
    } else if (releaseType === "tiledSwap") {
        var sourceSwap = transitionRecord("dragged", info.draggedCurrentRect, preview.targetRect, durationMs, nowMs, settleTimeoutMs)
        var targetSwap = transitionRecord("target", preview.targetRect, info.draggedCurrentRect, durationMs, nowMs, settleTimeoutMs)
        if (sourceSwap)
            records[sourceAddress] = sourceSwap
        if (targetSwap)
            records[targetAddress] = targetSwap
    }

    return Object.keys(records).length > 0 ? records : null
}

function reconcileTransitionRecords(args) {
    args = args || {}
    var records = args.records || {}
    var actualFrames = args.actualFrames || {}
    var epsilonPx = Math.max(0, toNumber(args.epsilonPx, 2))
    var nowMs = toNumber(args.nowMs, (typeof Date !== "undefined" && Date.now) ? Date.now() : 0)
    var next = {}
    var retargeted = false
    var statuses = {}
    var nextWakeAt = 0
    var finalizedAddresses = []

    function keep(address, record, status) {
        next[address] = record
        statuses[address] = status
        var visualDeadline = toNumber(record.startedAt, nowMs) + Math.max(1, toNumber(record.durationMs, 140))
        var settleDeadline = toNumber(record.settleDeadlineMs, visualDeadline)
        var wakeAt = Math.min(visualDeadline, settleDeadline)
        if (wakeAt <= nowMs)
            wakeAt = settleDeadline
        if (wakeAt > nowMs && (nextWakeAt === 0 || wakeAt < nextWakeAt))
            nextWakeAt = wakeAt
    }

    for (var address in records) {
        var record = records[address]
        if (!record)
            continue

        var actual = cloneFrameRect(actualFrames[address])
        var visualReady = nowMs >= toNumber(record.startedAt, nowMs) + Math.max(1, toNumber(record.durationMs, 140))
        var settleExpired = nowMs >= toNumber(record.settleDeadlineMs, nowMs + 1)
        if (!actual) {
            if (settleExpired) {
                statuses[address] = "capExpiredMissing"
                finalizedAddresses.push(address)
            } else {
                keep(address, record, "pendingMissing")
            }
            continue
        }

        if (rectNearlyEqual(actual, record.toFrame, epsilonPx)) {
            if (visualReady) {
                statuses[address] = record.settledAgainstActual ? "matchedActual" : "matchedPrediction"
                finalizedAddresses.push(address)
            } else {
                keep(address, record, record.settledAgainstActual ? "pendingActual" : "pendingPrediction")
            }
            continue
        }

        if (record.previousFrame && rectNearlyEqual(actual, record.previousFrame, epsilonPx)) {
            if (settleExpired) {
                statuses[address] = "capExpiredUnchanged"
                finalizedAddresses.push(address)
            } else {
                keep(address, record, "pendingPrevious")
            }
            continue
        }

        var retarget = {}
        for (var key in record)
            retarget[key] = record[key]
        retarget.fromFrame = cloneFrameRect(record.toFrame)
        retarget.toFrame = actual
        retarget.startedAt = nowMs
        retarget.settledAgainstActual = true
        next[address] = retarget
        statuses[address] = "retargeted"
        nextWakeAt = nowMs + Math.max(1, toNumber(retarget.durationMs, 140))
        retargeted = true
    }

    var count = Object.keys(next).length
    return {
        records: next,
        cleared: count === 0,
        retargeted: retargeted,
        statuses: statuses,
        finalizedAddresses: finalizedAddresses,
        nextWakeAt: nextWakeAt
    }
}
