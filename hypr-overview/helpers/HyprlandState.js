.pragma library

function normalizeSpecialName(wsName) {
    var name = (wsName || "").toString().trim()
    if (name.indexOf("special:") === 0)
        name = name.slice("special:".length)

    name = name.trim()
    return name.length > 0 ? name : "special"
}

function normalizeLayoutName(layoutName) {
    var value = (layoutName || "dwindle").toString()
    return value === "scrolling" ? "scroll" : value
}

function buildWorkspaceMonitorBindings(windowList, workspaceList) {
    var bindings = {}
    var workspaces = workspaceList || []
    for (var i = 0; i < workspaces.length; i++) {
        var ws = workspaces[i]
        if (!ws || ws.id === undefined || ws.id === null)
            continue

        var wsMonitor = ws.monitorID
        if (wsMonitor === undefined || wsMonitor === null)
            wsMonitor = ws.monitor
        if (wsMonitor === undefined || wsMonitor === null)
            continue

        if (!bindings[ws.id])
            bindings[ws.id] = []
        if (bindings[ws.id].indexOf(wsMonitor) === -1)
            bindings[ws.id].push(wsMonitor)
    }

    var wins = windowList || []
    for (var j = 0; j < wins.length; j++) {
        var win = wins[j]
        if (!win || !win.workspace)
            continue

        var wsId = win.workspace.id
        var monId = win.monitor
        if (wsId === undefined || wsId === null || monId === undefined || monId === null)
            continue

        if (!bindings[wsId])
            bindings[wsId] = []
        if (bindings[wsId].indexOf(monId) === -1)
            bindings[wsId].push(monId)
    }
    return bindings
}

function collectSpecialWorkspaces(workspaceList, windowByAddress, showScratchpadWorkspaces) {
    if (!showScratchpadWorkspaces)
        return []

    var byName = {}
    var workspaces = workspaceList || []
    for (var i = 0; i < workspaces.length; i++) {
        var ws = workspaces[i]
        if (!ws)
            continue

        var rawName = ws.name || ""
        var isSpecial = (ws.id < 0) || (rawName && rawName.toString().indexOf("special:") === 0) || rawName === "special"
        if (!isSpecial)
            continue

        var normalizedName = normalizeSpecialName(rawName)
        if (!byName[normalizedName]) {
            byName[normalizedName] = {
                "id": ws.id,
                "rawName": rawName,
                "name": normalizedName,
                "windows": []
            }
        }
    }

    var windows = windowByAddress || {}
    for (var addr in windows) {
        var win = windows[addr]
        if (!win || !win.workspace || win.workspace.id >= 0)
            continue

        var rawWinName = win.workspace.name || ""
        var normalizedWinName = normalizeSpecialName(rawWinName)
        if (!byName[normalizedWinName]) {
            byName[normalizedWinName] = {
                "id": win.workspace.id,
                "rawName": rawWinName,
                "name": normalizedWinName,
                "windows": []
            }
        }
        byName[normalizedWinName].windows.push(win)
    }

    var result = []
    for (var key in byName)
        result.push(byName[key])
    result.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return result
}

function buildVisibleWorkspaces(args) {
    args = args || {}
    var gridRows = Math.max(1, args.gridRows || 2)
    var gridColumns = Math.max(1, args.gridColumns || 5)
    var workspacesPerGroup = gridRows * gridColumns
    var monitors = args.monitors || []
    var monitorId = args.monitorId
    var targetMonitor = null
    for (var i = 0; i < monitors.length; i++) {
        if (String(monitors[i] && monitors[i].id) === String(monitorId)) {
            targetMonitor = monitors[i]
            break
        }
    }
    if (!targetMonitor)
        return []

    var currentId = 1
    if (targetMonitor.activeWorkspace)
        currentId = targetMonitor.activeWorkspace.id || 1
    if (currentId < 0)
        currentId = 1

    var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup)
    var minWorkspaceId = currentGroup * workspacesPerGroup + 1
    var visible = []
    for (var j = 0; j < workspacesPerGroup; j++)
        visible.push({ "id": minWorkspaceId + j, "type": "normal" })

    if (args.showScratchpadWorkspaces) {
        var specialWorkspaces = args.specialWorkspaces || []
        var reservedSlots = Math.min(specialWorkspaces.length, workspacesPerGroup)
        reservedSlots = Math.min(reservedSlots, Math.max(0, workspacesPerGroup - 1))
        for (var k = 0; k < reservedSlots; k++) {
            var special = specialWorkspaces[k]
            var targetIndex = visible.length - reservedSlots + k
            if (targetIndex >= 0 && targetIndex < visible.length) {
                visible[targetIndex] = {
                    "id": special.id,
                    "type": "special",
                    "name": special.name,
                    "rawName": special.rawName
                }
            }
        }
    }
    return visible
}

function buildWorkspaceLayouts(workspaceList, pendingLayouts) {
    var map = {}
    var workspaces = workspaceList || []
    for (var i = 0; i < workspaces.length; i++) {
        var ws = workspaces[i]
        if (ws && ws.id !== undefined)
            map[ws.id] = normalizeLayoutName(ws.tiledLayout || "dwindle")
    }

    var pending = pendingLayouts || {}
    var remaining = {}
    for (var key in pending) {
        if (map[key] === pending[key])
            continue

        if (map[key] !== undefined)
            map[key] = pending[key]
        remaining[key] = pending[key]
    }

    return {
        "layouts": map,
        "pending": remaining
    }
}

function focusHistoryRank(win) {
    if (win && win.focusHistoryID !== undefined && win.focusHistoryID !== null)
        return win.focusHistoryID

    return 9999
}

function sortWindowRecords(records) {
    var list = (records || []).slice()
    list.sort(compareWindowRecords)
    return list
}

function compareWindowRecords(a, b) {
    var winA = a && (a.win || a.window || a)
    var winB = b && (b.win || b.window || b)
    var pinnedA = !!(winA && winA.pinned)
    var pinnedB = !!(winB && winB.pinned)
    if (pinnedA !== pinnedB)
        return pinnedA ? 1 : -1

    var floatingA = !!(winA && winA.floating)
    var floatingB = !!(winB && winB.floating)
    if (floatingA !== floatingB)
        return floatingA ? 1 : -1

    return focusHistoryRank(winB) - focusHistoryRank(winA)
}
