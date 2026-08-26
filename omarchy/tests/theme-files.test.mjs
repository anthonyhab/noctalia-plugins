import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const pluginRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function readPluginFile(relativePath) {
  return fs.readFileSync(path.join(pluginRoot, relativePath), "utf8");
}

function loadHelper(relativePath) {
  const source = readPluginFile(relativePath).replace(/^\.pragma library\s*$/m, "");
  const context = vm.createContext({ console, Math, Number, String, Object, Array, RegExp });
  vm.runInContext(source, context, { filename: relativePath });
  return context;
}

function sameJson(actual, expected) {
  assert.deepEqual(JSON.parse(JSON.stringify(actual)), expected);
}

const themeFiles = loadHelper("ThemeFiles.js");
const mainQml = readPluginFile("Main.qml");
const asyncThemeSetterQml = readPluginFile("AsyncThemeSetter.qml");

assert.equal(themeFiles.normalizeBorderColor("abcdef"), "#abcdef");
assert.equal(themeFiles.normalizeBorderColor("ABCDEF99"), "#abcdef");
assert.equal(themeFiles.normalizeBorderColor("bad"), null);

assert.equal(
  themeFiles.parseHyprlandBorderColor('local active_border_color = "rgb(abcdef)"\nactive_border = active_border_color'),
  "#abcdef"
);
assert.equal(
  themeFiles.parseHyprlandBorderColor('active_border_color = "rgba(123456aa)"'),
  "#123456"
);
assert.equal(
  themeFiles.parseHyprlandBorderColor('hl.config({\n  active_border = "rgb(654321)",\n})'),
  "#654321"
);
assert.equal(
  themeFiles.parseHyprlandBorderColor('$activeBorderColor = rgba(111111aa) rgba(a1b2c3ff) 45deg'),
  "#a1b2c3"
);
assert.equal(themeFiles.parseHyprlandBorderColor('active_border = active_border_color'), null);
assert.equal(themeFiles.parseHyprlandBorderColor(''), null);

sameJson(
  themeFiles.parseColorsToml(`
# comment
[colors]
background = "#101010"
foreground = '0xffffff'
accent = "0xff00ff"
ignored = "not-a-color"
`),
  {
    background: "#101010",
    foreground: "#ffffff",
    accent: "#ff00ff"
  }
);
sameJson(
  themeFiles.parseColorsToml('background = "0xff1122"\nforeground = "#aabbccdd"'),
  {
    background: "#ff1122",
    foreground: "#bbccdd"
  }
);
assert.equal(themeFiles.parseColorsToml('background = "#101010"'), null);
assert.equal(themeFiles.parseColorsToml('foreground = "#ffffff"'), null);
assert.equal(themeFiles.parseColorsToml(''), null);

assert.equal(mainQml.includes('import "ThemeFiles.js" as ThemeFiles'), true);
assert.equal(mainQml.includes('import "ThemeIdentity.js" as ThemeIdentity'), true);
assert.equal(/readonly property string omarchyHyprlandLuaPath:\s*omarchyConfigDir \+ "current\/theme\/hyprland\.lua"/.test(mainQml), true);
assert.equal(/readonly property string omarchyHyprlandConfPath:\s*omarchyConfigDir \+ "current\/theme\/hyprland\.conf"/.test(mainQml), true);
assert.equal(/pendingHyprlandThemePaths\s*=\s*\[omarchyHyprlandLuaPath, omarchyHyprlandConfPath\]/.test(mainQml), true);
assert.equal(/ThemeFiles\.parseHyprlandBorderColor\(content\)/.test(mainQml), true);
assert.equal(/ThemeFiles\.parseColorsToml\(content\)/.test(mainQml), true);
assert.equal(mainQml.includes("function parseColorsToml"), false);
assert.equal(mainQml.includes("instantSchemeApplier.writeAndApplyScheme(result, handleSchemeApplyFinished)"), true);
assert.equal(mainQml.includes("id: schemeWriteProcess"), false);
assert.equal(mainQml.includes("omarchyHyprlandPath"), false);

assert.equal(/const envPath = Quickshell\.env\("OMARCHY_PATH"\)/.test(mainQml), true);
assert.equal(/readonly property string legacyThemeSetCommand:\s*omarchyPath \+ "\/bin\/omarchy-theme-set"/.test(mainQml), true);
assert.equal(/readonly property string legacyThemeListCommand:\s*omarchyPath \+ "\/bin\/omarchy-theme-list"/.test(mainQml), true);
assert.equal(mainQml.includes('import "OmarchyCommands.js" as OmarchyCommands'), true);
assert.equal(asyncThemeSetterQml.includes('import "OmarchyCommands.js" as OmarchyCommands'), true);
assert.equal(/OmarchyCommands\.themeSetFallbackCommand/.test(asyncThemeSetterQml), true);
assert.equal(asyncThemeSetterQml.includes("useFastScript"), false);
