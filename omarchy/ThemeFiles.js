function normalizeBorderColor(hex) {
  if (!hex || typeof hex !== "string")
    return null;

  const normalized = hex.trim().toLowerCase();
  if (!/^[a-f0-9]{6,8}$/.test(normalized))
    return null;

  return "#" + normalized.slice(0, 6);
}

function extractLuaBorderColor(content) {
  if (!content || typeof content !== "string")
    return null;

  const activeBorderColorMatch = content.match(/(?:^|\n)\s*(?:local\s+)?active_border_color\s*=\s*["']rgba?\(([a-fA-F0-9]{6,8})\)["']/m);
  if (activeBorderColorMatch)
    return normalizeBorderColor(activeBorderColorMatch[1]);

  const directActiveBorderMatch = content.match(/(?:^|\n)\s*active_border\s*=\s*["']rgba?\(([a-fA-F0-9]{6,8})\)["']/m);
  if (directActiveBorderMatch)
    return normalizeBorderColor(directActiveBorderMatch[1]);

  return null;
}

function extractLegacyBorderColor(content) {
  if (!content || typeof content !== "string")
    return null;

  const lines = content.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line.startsWith("$activeBorderColor"))
      continue;

    const colorMatches = line.match(/rgba?\(([a-fA-F0-9]{6,8})\)/g);
    if (!colorMatches || colorMatches.length === 0)
      continue;

    const lastColor = colorMatches[colorMatches.length - 1];
    const hexMatch = lastColor.match(/rgba?\(([a-fA-F0-9]{6,8})\)/);
    if (hexMatch)
      return normalizeBorderColor(hexMatch[1]);
  }

  return null;
}

function parseHyprlandBorderColor(content) {
  if (!content || typeof content !== "string")
    return null;

  return extractLuaBorderColor(content) || extractLegacyBorderColor(content);
}

function parseColorsToml(content) {
  if (!content || typeof content !== "string")
    return null;

  const colors = {};
  const lines = content.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith("#") || line.startsWith("["))
      continue;

    const match = line.match(/^([a-zA-Z0-9_]+)\s*=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
    if (!match)
      continue;

    colors[match[1]] = "#" + match[2].toLowerCase().slice(-6);
  }

  if (!colors.background || !colors.foreground)
    return null;

  return colors;
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeBorderColor,
    extractLuaBorderColor,
    extractLegacyBorderColor,
    parseHyprlandBorderColor,
    parseColorsToml
  };
}
