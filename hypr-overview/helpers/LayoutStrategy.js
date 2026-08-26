.pragma library

// LayoutStrategy — per-layout behavior via strategy pattern.
// Each strategy defines: rendering transforms, window ordering, drag semantics, badge label.

// Local copies of helpers (QML .pragma library cannot share state across files).
function toNumber(v, fb) {
    var parsed = Number(v)
    return isFinite(parsed) ? parsed : fb
}

function clamp(v, min, max) {
    if (v < min) return min
    if (v > max) return max
    return v
}

function isIntent(ctx, typeName) {
    return !!ctx && ctx.source && ctx.target && ctx.layout && (!typeName || ctx.type === typeName)
}

function sourceAddressFrom(ctx) {
    if (isIntent(ctx))
        return ctx.source.address || ""

    return (ctx && ctx.sourceAddress) || ""
}

function workspaceIdFrom(ctx) {
    if (isIntent(ctx))
        return ctx.source.workspaceId

    return (ctx && ctx.wsId) || -1
}

function previewFrom(ctx) {
    if (isIntent(ctx))
        return ctx.preview || null

    return (ctx && ctx.retilingInfo) || null
}

function noopAction() {
    return { type: "noop", commands: [], refresh: false }
}

// All known layout names in display order.
var allLayouts = ["dwindle", "master", "scroll", "monocle"]

var allBadgeLabels = { "dwindle": "D", "master": "M", "scroll": "S", "monocle": "\u2261" }

var allDisplayNames = { "dwindle": "Dwindle", "master": "Master", "scroll": "Scroll", "monocle": "Monocle" }

// Returns a strategy object for the given layout name.
function get(layoutName) {
    switch (layoutName) {
    case "master":  return masterStrategy
    case "scroll":  return scrollStrategy
    case "monocle": return monocleStrategy
    default:        return dwindleStrategy
    }
}

// ---------------------------------------------------------------------------
// Dwindle strategy
// ---------------------------------------------------------------------------
var dwindleStrategy = {
    name: "dwindle",
    badgeLabel: "D",

    // Hyprland geometry is accurate — no transform needed.
    transformWindowData: function(/* rawData, ctx */) { return null },

    // No custom ordering needed.
    computeWindowOrder: function(/* windowByAddress, workspaceLayouts, scrollDirs */) { return null },

    // Intra-workspace retile: directional preselect + move-to-9999-and-back, or swapwindow.
    getDropAction: function(ctx) {
        if (isIntent(ctx) && ctx.type !== "tiledSplit" && ctx.type !== "tiledSwap")
            return noopAction()

        var info = previewFrom(ctx)
        if (!ctx || !info || !info.targetAddress)
            return noopAction()

        var sourceAddress = sourceAddressFrom(ctx)
        var wsId = workspaceIdFrom(ctx)
        if (info.isNoop)
            return noopAction()

        if (info.direction === "swap" || (isIntent(ctx) && ctx.type === "tiledSwap")) {
            return {
                type: "tiledSwap",
                commands: [
                    "focuswindow address:" + sourceAddress,
                    "swapwindow address:" + info.targetAddress
                ],
                refresh: true
            }
        }

        // Directional split
        return {
            type: "tiledSplit",
            commands: [
                "movetoworkspacesilent 9999, address:" + sourceAddress,
                "focuswindow address:" + info.targetAddress,
                "layoutmsg preselect " + info.direction,
                "movetoworkspacesilent " + wsId + ", address:" + sourceAddress,
                "layoutmsg preselect 0"
            ],
            refresh: true
        }
    },

    supportsRetilePreview: true
}

// ---------------------------------------------------------------------------
// Master strategy
// ---------------------------------------------------------------------------
var masterStrategy = {
    name: "master",
    badgeLabel: "M",

    transformWindowData: function() { return null },
    computeWindowOrder: function() { return null },

    // Master layout: swap with any window. Drop onto master → swapwithmaster.
    getDropAction: function(ctx) {
        if (isIntent(ctx) && ctx.type !== "layoutReorder")
            return noopAction()

        var sourceAddress = sourceAddressFrom(ctx)
        var info = previewFrom(ctx)
        if (!sourceAddress)
            return noopAction()

        if (isIntent(ctx) && (!info || !info.targetAddress)) {
            var dx = toNumber(ctx.preview && ctx.preview.dragDeltaX, 0)
            var dy = toNumber(ctx.preview && ctx.preview.dragDeltaY, 0)
            if (Math.max(Math.abs(dx), Math.abs(dy)) < 5)
                return noopAction()

            return {
                type: "layoutReorder",
                commands: [
                    "focuswindow address:" + sourceAddress,
                    "layoutmsg swapwithmaster"
                ],
                refresh: true
            }
        }

        if (!ctx || !info || !info.targetAddress)
            return noopAction()

        if (info.isNoop)
            return noopAction()

        // For any drop, swap the two windows.
        return {
            type: "layoutReorder",
            commands: [
                "focuswindow address:" + sourceAddress,
                "swapwindow address:" + info.targetAddress
            ],
            refresh: true
        }
    },

    supportsRetilePreview: false
}

// ---------------------------------------------------------------------------
// Scroll strategy
// ---------------------------------------------------------------------------
var scrollStrategy = {
    name: "scroll",
    badgeLabel: "S",

    // Synthesize tape-strip coordinates from normalized proportions.
    // ctx: { scrollInfo, sourceMonitorWidth, sourceMonitorHeight, monX, monY, rawWindowData }
    transformWindowData: function(rawData, ctx) {
        if (!rawData || !ctx || !ctx.scrollInfo)
            return null

        var info = ctx.scrollInfo
        var isVert = info.isVertical
        var mW = toNumber(ctx.sourceMonitorWidth, 1920)
        var mH = toNumber(ctx.sourceMonitorHeight, 1080)
        var monX = toNumber(ctx.monX, 0)
        var monY = toNumber(ctx.monY, 0)
        var nPos = info.normalizedPos
        var nSz = info.normalizedSize

        var synthAt = isVert ? [monX, monY + nPos * mH] : [monX + nPos * mW, monY]
        var synthSize = isVert ? [mW, nSz * mH] : [nSz * mW, mH]

        return {
            "at": synthAt,
            "size": synthSize,
            "address": rawData.address,
            "floating": false,
            "fullscreen": false,
            "workspace": rawData.workspace,
            "focusHistoryID": rawData.focusHistoryID,
            "class": rawData["class"],
            "title": rawData.title,
            "monitor": rawData.monitor,
            "initialClass": rawData.initialClass,
            "urgent": rawData.urgent,
            "pinned": rawData.pinned
        }
    },

    // Compute scroll window order: address → { index, total, isVertical, normalizedPos, normalizedSize }
    // Pure function operating on the full windowByAddress map.
    computeWindowOrder: function(windowByAddress, workspaceLayouts, scrollDirs) {
        var result = {}
        if (!windowByAddress) return result

        var byWs = {}
        for (var addr in windowByAddress) {
            var win = windowByAddress[addr]
            if (!win || win.floating || !win.workspace) continue

            var wsId = win.workspace.id
            if (!wsId || wsId < 0) continue
            if ((workspaceLayouts[wsId] || "dwindle") !== "scroll") continue

            if (!byWs[wsId]) byWs[wsId] = []
            byWs[wsId].push(win)
        }

        for (var sid in byWs) {
            var wins = byWs[sid]
            var dir = (scrollDirs && scrollDirs[sid]) || "right"
            var isVertical = (dir === "up" || dir === "down")
            var axis = isVertical ? 1 : 0

            wins.sort(function(a, b) {
                return ((a.at && a.at[axis]) || 0) - ((b.at && b.at[axis]) || 0)
            })

            // Compute full tape extent from actual Hyprland positions/sizes.
            var minPos = (wins[0].at && wins[0].at[axis]) || 0
            var maxEnd = minPos + ((wins[0].size && wins[0].size[axis]) || 0)
            for (var i = 1; i < wins.length; i++) {
                var p = (wins[i].at && wins[i].at[axis]) || 0
                var e = p + ((wins[i].size && wins[i].size[axis]) || 0)
                if (p < minPos) minPos = p
                if (e > maxEnd) maxEnd = e
            }

            var totalTape = Math.max(1, maxEnd - minPos)
            for (var j = 0; j < wins.length; j++) {
                var wpos = (wins[j].at && wins[j].at[axis]) || 0
                var wsz = (wins[j].size && wins[j].size[axis]) || 0
                result[wins[j].address] = {
                    "index": j,
                    "total": wins.length,
                    "isVertical": isVertical,
                    "normalizedPos": (wpos - minPos) / totalTape,
                    "normalizedSize": Math.max(0.01, wsz / totalTape)
                }
            }
        }
        return result
    },

    // Scroll layout: reorder columns via layoutmsg movewindow.
    getDropAction: function(ctx) {
        if (isIntent(ctx) && ctx.type !== "layoutReorder")
            return noopAction()

        var sourceAddress = sourceAddressFrom(ctx)
        if (!ctx || !sourceAddress)
            return noopAction()

        var dx = isIntent(ctx) ? toNumber(ctx.preview && ctx.preview.dragDeltaX, 0) : toNumber(ctx.dragDeltaX, 0)
        var dy = isIntent(ctx) ? toNumber(ctx.preview && ctx.preview.dragDeltaY, 0) : toNumber(ctx.dragDeltaY, 0)

        // Determine scroll direction for this workspace
        var scrollDir = isIntent(ctx) ? (ctx.layout.scrollDirection || "right") : (ctx.scrollDirection || "right")
        var isVertical = (scrollDir === "up" || scrollDir === "down")

        var moveDir
        if (isVertical) {
            moveDir = dy < 0 ? "u" : "d"
        } else {
            moveDir = dx < 0 ? "l" : "r"
        }

        // Require minimum drag distance to avoid accidental reorders
        var delta = isVertical ? Math.abs(dy) : Math.abs(dx)
        if (delta < 5)
            return noopAction()

        return {
            type: "layoutReorder",
            commands: [
                "focuswindow address:" + sourceAddress,
                "layoutmsg movewindow " + moveDir
            ],
            refresh: true
        }
    },

    supportsRetilePreview: false
}

// ---------------------------------------------------------------------------
// Monocle strategy
// ---------------------------------------------------------------------------
var monocleStrategy = {
    name: "monocle",
    badgeLabel: "\u2261",

    // No coordinate transform — monocle uses deck offsets applied externally.
    transformWindowData: function() { return null },

    // Compute monocle deck order: address → { deckPos, total }
    // Sorted by focusHistoryID (0 = most recent = top of deck).
    computeWindowOrder: function(windowByAddress, workspaceLayouts) {
        var result = {}
        if (!windowByAddress) return result

        var byWs = {}
        for (var addr in windowByAddress) {
            var win = windowByAddress[addr]
            if (!win || win.floating || !win.workspace) continue

            var wsId = win.workspace.id
            if (!wsId || wsId < 0) continue
            if ((workspaceLayouts[wsId] || "dwindle") !== "monocle") continue

            if (!byWs[wsId]) byWs[wsId] = []
            byWs[wsId].push(win)
        }

        for (var mid in byWs) {
            var mwins = byWs[mid]
            mwins.sort(function(a, b) {
                var rankA = (a.focusHistoryID !== undefined && a.focusHistoryID !== null) ? a.focusHistoryID : 9999
                var rankB = (b.focusHistoryID !== undefined && b.focusHistoryID !== null) ? b.focusHistoryID : 9999
                return rankA - rankB
            })
            for (var j = 0; j < mwins.length; j++) {
                result[mwins[j].address] = {
                    "deckPos": j,
                    "total": mwins.length
                }
            }
        }
        return result
    },

    // Monocle: cycle through stack. Primary use is cross-workspace moves (handled by OverviewGrid).
    getDropAction: function(ctx) {
        if (isIntent(ctx) && ctx.type !== "layoutReorder")
            return noopAction()

        var sourceAddress = sourceAddressFrom(ctx)
        if (!ctx || !sourceAddress)
            return noopAction()

        var dy = isIntent(ctx) ? toNumber(ctx.preview && ctx.preview.dragDeltaY, 0) : toNumber(ctx.dragDeltaY, 0)
        if (Math.abs(dy) < 5)
            return noopAction()

        return {
            type: "layoutReorder",
            commands: [
                "focuswindow address:" + sourceAddress,
                dy < 0 ? "cyclenext" : "cycleprev"
            ],
            refresh: true
        }
    },

    supportsRetilePreview: false
}
