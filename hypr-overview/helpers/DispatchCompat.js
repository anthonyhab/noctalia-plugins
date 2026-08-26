.pragma library

function trimCommand(command) {
    return (command === undefined || command === null) ? "" : command.toString().trim()
}

function luaStringLiteral(value) {
    return "\"" + (value === undefined || value === null ? "" : value.toString())
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n")
        .replace(/\r/g, "\\r") + "\""
}

function normalizeNumberLiteral(value) {
    var n = Number(value)
    if (!isFinite(n))
        return value.toString()
    return Math.round(n) === n ? Math.round(n).toString() : n.toString()
}

function toKeywordSegment(command) {
    var text = trimCommand(command)
    var luaConfig = keywordToLuaConfig(text)
    return luaConfig === "" ? "" : "eval " + luaConfig
}

function keywordToLuaConfig(command) {
    var text = trimCommand(command)
    var match = text.match(/^keyword\s+(\S+)(?:\s+(.+))?$/)
    if (!match)
        return ""

    return keywordPathToLuaConfig(match[1], match[2] === undefined ? "" : match[2].trim())
}

function keywordPathToLuaConfig(name, value) {
    var text = trimCommand(name)
    var parts = text.split(":")
    if (parts.length !== 2 || parts[0] === "" || parts[1] === "")
        return ""

    return "hl.config({ " + parts[0] + " = { " + parts[1] + " = " + luaKeywordValue(parts[0], parts[1], value) + " } })"
}

function luaKeywordValue(section, key, value) {
    var text = trimCommand(value)
    if (key === "no_warps" || key === "warp_on_change_workspace" || key === "warp_on_toggle_special" || key === "always_follow_on_dnd")
        return text === "1" || text === "true" ? "true" : "false"

    if (/^-?\d+(?:\.\d+)?$/.test(text))
        return normalizeNumberLiteral(text)

    return luaStringLiteral(text)
}

function cursorRestoreCommand(x, y) {
    return "movecursor " + normalizeNumberLiteral(x) + " " + normalizeNumberLiteral(y)
}

function cursorMoveDispatch(x, y) {
    return "hl.dsp.cursor.move({ x = " + normalizeNumberLiteral(x) + ", y = " + normalizeNumberLiteral(y) + " })"
}

function isCursorRestoreCommand(command) {
    return /^movecursor\s+-?\d+(?:\.\d+)?\s+-?\d+(?:\.\d+)?$/.test(trimCommand(command))
}

function shouldRestoreCursorAfter(command) {
    var text = trimCommand(command)
    return text !== ""
        && text.indexOf("keyword ") !== 0
        && !isCursorRestoreCommand(text)
        && text.indexOf("hl.dsp.cursor.move(") !== 0
}

function toLuaDispatch(command) {
    var text = trimCommand(command)
    if (text === "")
        return ""

    if (text.indexOf("dispatch ") === 0)
        text = trimCommand(text.slice(9))

    if (text.indexOf("hl.dsp.") === 0)
        return text

    var match = text.match(/^movecursor\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)$/)
    if (match)
        return cursorMoveDispatch(match[1], match[2])

    match = text.match(/^workspace\s+(.+)$/)
    if (match)
        return "hl.dsp.focus({ workspace = " + luaStringLiteral(match[1].trim()) + " })"

    match = text.match(/^togglespecialworkspace\s+(.+)$/)
    if (match)
        return "hl.dsp.workspace.toggle_special(" + luaStringLiteral(match[1].trim()) + ")"

    match = text.match(/^movetoworkspacesilent\s+(.+?)\s*,\s*(.+)$/)
    if (match)
        return "hl.dsp.window.move({ workspace = " + luaStringLiteral(match[1].trim()) + ", window = " + luaStringLiteral(match[2].trim()) + ", follow = false })"

    match = text.match(/^movewindowpixel\s+exact\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*,\s*(.+)$/)
    if (match)
        return "hl.dsp.window.move({ x = " + normalizeNumberLiteral(match[1]) + ", y = " + normalizeNumberLiteral(match[2]) + ", relative = false, window = " + luaStringLiteral(match[3].trim()) + " })"

    match = text.match(/^focuswindow\s+(.+)$/)
    if (match)
        return "hl.dsp.focus({ window = " + luaStringLiteral(match[1].trim()) + " })"

    match = text.match(/^closewindow\s+(.+)$/)
    if (match)
        return "hl.dsp.window.close(" + luaStringLiteral(match[1].trim()) + ")"

    match = text.match(/^swapwindow\s+(.+)$/)
    if (match)
        return "hl.dsp.window.swap({ target = " + luaStringLiteral(match[1].trim()) + " })"

    match = text.match(/^layoutmsg\s+(.+)$/)
    if (match)
        return "hl.dsp.layout(" + luaStringLiteral(match[1].trim()) + ")"

    if (text === "cyclenext")
        return "hl.dsp.window.cycle_next({ next = true })"

    if (text === "cycleprev")
        return "hl.dsp.window.cycle_next({ next = false })"

    return ""
}

function toBatchSegment(command) {
    var text = trimCommand(command)
    if (text === "")
        return ""

    if (text.indexOf("keyword ") === 0)
        return toKeywordSegment(text)

    var dispatch = toLuaDispatch(text)
    return dispatch === "" ? "" : "dispatch " + dispatch
}

function rejectedCommands(commands) {
    if (!commands || commands.length === 0)
        return []

    var rejected = []
    for (var i = 0; i < commands.length; i++) {
        var text = trimCommand(commands[i])
        if (text !== "" && toBatchSegment(text) === "")
            rejected.push(text)
    }
    return rejected
}

function commandsToBatchPayload(commands) {
    if (!commands || commands.length === 0)
        return ""

    var parts = []
    for (var i = 0; i < commands.length; i++) {
        var segment = toBatchSegment(commands[i])
        if (segment !== "")
            parts.push(segment)
    }
    return parts.join("; ")
}
