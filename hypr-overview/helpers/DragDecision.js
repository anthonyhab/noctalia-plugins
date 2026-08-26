.pragma library

function isValidAddress(address) {
    return !!address && address.toString().length > 0
}

function decideRelease(args) {
    args = args || {}
    var intent = args.intent || null
    var windowAddress = args.windowAddress || ""
    var currentWsId = args.currentWorkspaceId === undefined ? -1 : args.currentWorkspaceId
    var targetWorkspace = args.targetWorkspace === undefined ? -1 : args.targetWorkspace
    var targetSpecial = args.targetSpecial || null
    var currentSpecialName = args.currentSpecialName || ""
    var isFloating = !!args.isFloating
    var dragPreviewMode = args.dragPreviewMode || "smart"
    var layoutAction = args.layoutAction || { "type": "noop", "commands": [] }
    var floatingDropPosition = args.floatingDropPosition || null
    var sourceMonitorId = args.sourceMonitorId === undefined ? -1 : args.sourceMonitorId
    var targetMonitorId = args.targetMonitorId === undefined ? sourceMonitorId : args.targetMonitorId
    var enableCrossMonitorDrag = args.enableCrossMonitorDrag !== undefined ? !!args.enableCrossMonitorDrag : true
    var crossMonitorRequested = !!args.crossMonitorDrag
    var isCrossMonitorTarget = crossMonitorRequested || (sourceMonitorId >= 0 && targetMonitorId >= 0 && sourceMonitorId !== targetMonitorId)

    if (intent) {
        windowAddress = (intent.source && intent.source.address) || windowAddress
        currentWsId = (intent.source && intent.source.workspaceId !== undefined) ? intent.source.workspaceId : currentWsId
        targetWorkspace = (intent.target && intent.target.workspaceId !== undefined) ? intent.target.workspaceId : targetWorkspace
        targetSpecial = (intent.target && intent.target.special) || targetSpecial
        isFloating = !!(intent.source && intent.source.floating)
        sourceMonitorId = (intent.source && intent.source.monitorId !== undefined) ? intent.source.monitorId : sourceMonitorId
        targetMonitorId = (intent.target && intent.target.monitorId !== undefined) ? intent.target.monitorId : targetMonitorId
        isCrossMonitorTarget = sourceMonitorId >= 0 && targetMonitorId >= 0 && sourceMonitorId !== targetMonitorId
    }

    if (!isValidAddress(windowAddress))
        return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }

    if (crossMonitorRequested && targetMonitorId < 0)
        return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }

    if (isCrossMonitorTarget && !enableCrossMonitorDrag)
        return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }

    if (intent && intent.type === "noop")
        return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }

    if (intent && intent.type === "floatingPlace" && floatingDropPosition) {
        var commands = []
        if (targetWorkspace !== -1 && targetWorkspace !== currentWsId)
            commands.push("movetoworkspacesilent " + targetWorkspace + ", address:" + windowAddress)
        commands.push("movewindowpixel exact " + floatingDropPosition.x + " " + floatingDropPosition.y + ",address:" + windowAddress)
        return {
            "type": "floatingMove",
            "commands": commands,
            "refresh": true,
            "optimisticMove": {
                "x": floatingDropPosition.x,
                "y": floatingDropPosition.y,
                "workspaceId": targetWorkspace !== -1 ? targetWorkspace : currentWsId
            }
        }
    }

    if (targetSpecial) {
        if (currentWsId >= 0 || currentSpecialName !== targetSpecial.name) {
            return {
                "type": "specialMove",
                "commands": ["movetoworkspacesilent special:" + targetSpecial.name + ", address:" + windowAddress],
                "refresh": true,
                "optimisticMove": null
            }
        }
        return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }
    }

    if (intent && (intent.type === "tiledSplit" || intent.type === "tiledSwap" || intent.type === "layoutReorder")) {
        if (layoutAction && layoutAction.type !== "noop" && layoutAction.commands && layoutAction.commands.length > 0)
            return { "type": layoutAction.type, "commands": layoutAction.commands, "refresh": true, "optimisticMove": null }

        return { "type": "reset", "commands": [], "refresh": true, "optimisticMove": null }
    }

    if (targetWorkspace !== -1 && targetWorkspace !== currentWsId) {
        return {
            "type": "workspaceMove",
            "commands": ["movetoworkspacesilent " + targetWorkspace + ", address:" + windowAddress],
            "refresh": true,
            "optimisticMove": null
        }
    }

    if (targetWorkspace !== -1 && targetWorkspace === currentWsId && !isFloating && dragPreviewMode !== "off") {
        if (layoutAction && layoutAction.type !== "noop" && layoutAction.commands && layoutAction.commands.length > 0)
            return { "type": layoutAction.type, "commands": layoutAction.commands, "refresh": true, "optimisticMove": null }

        return { "type": "reset", "commands": [], "refresh": true, "optimisticMove": null }
    }

    if (isFloating && floatingDropPosition) {
        return {
            "type": "floatingMove",
            "commands": ["movewindowpixel exact " + floatingDropPosition.x + " " + floatingDropPosition.y + ",address:" + windowAddress],
            "refresh": true,
            "optimisticMove": {
                "x": floatingDropPosition.x,
                "y": floatingDropPosition.y,
                "workspaceId": currentWsId
            }
        }
    }

    return { "type": "reset", "commands": [], "refresh": false, "optimisticMove": null }
}
