.pragma library

function toNumber(value, fallback) {
    var parsed = Number(value)
    if (!isFinite(parsed))
        return fallback

    return parsed
}

function isValidAddress(address) {
    return !!address && address.toString().length > 0
}

function isCrossMonitorTarget(args) {
    var sourceMonitorId = toNumber(args.sourceMonitorId, -1)
    var targetMonitorId = toNumber(args.targetMonitorId, sourceMonitorId)
    return !!args.crossMonitorDrag || (sourceMonitorId >= 0 && targetMonitorId >= 0 && sourceMonitorId !== targetMonitorId)
}

function baseIntent(type, args) {
    args = args || {}
    return {
        "type": type,
        "status": args.status || (type === "noop" ? "unsupported" : "ready"),
        "labelKey": args.labelKey || ("dropIntent." + type),
        "confidence": toNumber(args.confidence, type === "noop" ? 0 : 1),
        "preview": args.preview || null,
        "source": args.source || {},
        "target": args.target || {},
        "layout": args.layout || {}
    }
}

function invalidIntent(reason, args) {
    return baseIntent("noop", {
        "status": reason || "invalid",
        "labelKey": "dropIntent.noop",
        "confidence": 0,
        "source": args && args.source,
        "target": args && args.target,
        "layout": args && args.layout
    })
}

function resolve(args) {
    args = args || {}

    var source = {
        "address": args.windowAddress || "",
        "workspaceId": toNumber(args.currentWorkspaceId, -1),
        "specialName": args.currentSpecialName || "",
        "monitorId": toNumber(args.sourceMonitorId, -1),
        "floating": !!args.isFloating,
        "fullscreen": !!args.isFullscreen,
        "maximized": !!args.isMaximized
    }
    var targetWorkspace = args.targetWorkspace === undefined ? -1 : toNumber(args.targetWorkspace, -1)
    var targetSpecial = args.targetSpecial || null
    var target = {
        "workspaceId": targetWorkspace,
        "special": targetSpecial,
        "monitorId": toNumber(args.targetMonitorId, source.monitorId)
    }
    var layoutName = args.layoutName || "dwindle"
    var layout = {
        "name": layoutName,
        "scrollDirection": args.scrollDirection || "right"
    }
    var common = {
        "source": source,
        "target": target,
        "layout": layout
    }

    if (!isValidAddress(source.address))
        return invalidIntent("invalid-source", common)

    if (!!args.crossMonitorDrag && target.monitorId < 0)
        return invalidIntent("ambiguous-monitor", common)

    if (isCrossMonitorTarget(args) && args.enableCrossMonitorDrag === false)
        return invalidIntent("cross-monitor-disabled", common)

    if (source.fullscreen || source.maximized)
        return invalidIntent("unsupported-source-state", common)

    var floatingPosition = args.floatingDropPosition || null
    var isSameSpecialFloatingDrop = targetSpecial && source.workspaceId < 0 && source.specialName === targetSpecial.name
    if (source.floating && floatingPosition && (!targetSpecial || isSameSpecialFloatingDrop)) {
        var floatingType = targetWorkspace !== -1 && targetWorkspace !== source.workspaceId ? "floatingPlace" : "floatingPlace"
        return baseIntent(floatingType, {
            "labelKey": targetWorkspace !== -1 && targetWorkspace !== source.workspaceId ? "dropIntent.floatingMoveAndPlace" : "dropIntent.floatingPlace",
            "preview": {
                "mode": "floatingGhost",
                "x": floatingPosition.x,
                "y": floatingPosition.y
            },
            "source": source,
            "target": target,
            "layout": layout
        })
    }

    if (targetSpecial) {
        if (source.workspaceId >= 0 || source.specialName !== targetSpecial.name) {
            return baseIntent("specialMove", {
                "labelKey": "dropIntent.specialMove",
                "source": source,
                "target": target,
                "layout": layout
            })
        }
        return invalidIntent("same-special-workspace", common)
    }

    if (targetWorkspace !== -1 && targetWorkspace !== source.workspaceId) {
        return baseIntent("workspaceMove", {
            "labelKey": "dropIntent.workspaceMove",
            "source": source,
            "target": target,
            "layout": layout
        })
    }

    if (targetWorkspace !== -1 && targetWorkspace === source.workspaceId && !source.floating && (args.dragPreviewMode || "smart") !== "off") {
        var retilingInfo = args.retilingInfo || null
        if (layoutName === "dwindle") {
            if (!retilingInfo || !retilingInfo.targetAddress || retilingInfo.isNoop)
                return invalidIntent(retilingInfo && retilingInfo.noopReason ? retilingInfo.noopReason : "no-drop-target", common)

            if (retilingInfo.direction === "swap") {
                return baseIntent("tiledSwap", {
                    "labelKey": "dropIntent.tiledSwap",
                    "confidence": retilingInfo.confidence,
                    "preview": retilingInfo,
                    "source": source,
                    "target": target,
                    "layout": layout
                })
            }

            if (retilingInfo.direction !== "") {
                return baseIntent("tiledSplit", {
                    "labelKey": "dropIntent.tiledSplit",
                    "confidence": retilingInfo.confidence,
                    "preview": retilingInfo,
                    "source": source,
                    "target": target,
                    "layout": layout
                })
            }

            return invalidIntent("no-zone", common)
        }

        return baseIntent("layoutReorder", {
            "labelKey": layoutName === "monocle" ? "dropIntent.deckCycle" : "dropIntent.layoutReorder",
            "preview": {
                "mode": layoutName === "monocle" ? "deckCycle" : "insertionLine",
                "dragDeltaX": toNumber(args.dragDeltaX, 0),
                "dragDeltaY": toNumber(args.dragDeltaY, 0)
            },
            "source": source,
            "target": target,
            "layout": layout
        })
    }

    return invalidIntent("no-supported-drop", common)
}
