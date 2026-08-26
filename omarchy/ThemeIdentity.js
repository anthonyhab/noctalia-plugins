function normalizeThemeKey(name) {
  if (!name || typeof name !== "string")
    return "";

  return name.replace(/<[^>]+>/g, "").trim().toLowerCase().replace(/\s+/g, "-");
}

function formatThemeName(dirName) {
  if (!dirName || typeof dirName !== "string")
    return "";

  return dirName.replace(/-/g, " ").split(" ").map(function (word) {
    if (word.length === 0)
      return word;
    return word.charAt(0).toUpperCase() + word.slice(1);
  }).join(" ");
}

function themeEntryDisplayName(theme) {
  if (typeof theme === "string")
    return theme;
  if (theme && typeof theme === "object")
    return theme.name || theme.dirName || "";
  return "";
}

function themeEntryDirName(theme) {
  if (typeof theme === "string")
    return theme;
  if (theme && typeof theme === "object")
    return theme.dirName || theme.name || "";
  return "";
}

function themeEntryKey(theme) {
  return normalizeThemeKey(themeEntryDirName(theme));
}

function filterThemes(themes, mode, query) {
  if (!themes || themes.length === 0)
    return [];

  var filtered = themes;
  if (mode && mode !== "all") {
    filtered = filtered.filter(function (theme) {
      return theme && typeof theme === "object" && theme.mode === mode;
    });
  }

  const normalizedQuery = typeof query === "string" ? query.trim().toLowerCase() : "";
  if (normalizedQuery !== "") {
    filtered = filtered.filter(function (theme) {
      return themeEntryDisplayName(theme).toLowerCase().indexOf(normalizedQuery) !== -1;
    });
  }

  return filtered;
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeThemeKey,
    formatThemeName,
    themeEntryDisplayName,
    themeEntryDirName,
    themeEntryKey,
    filterThemes
  };
}
