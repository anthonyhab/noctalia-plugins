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

const identity = loadHelper("ThemeIdentity.js");
const ui = loadHelper("PluginUi.js");

assert.equal(identity.normalizeThemeKey("Catppuccin Latte"), "catppuccin-latte");
assert.equal(identity.normalizeThemeKey("  Catppuccin   Latte  "), "catppuccin-latte");
assert.equal(identity.normalizeThemeKey("<span>Gruvbox Dark</span>"), "gruvbox-dark");
assert.equal(identity.normalizeThemeKey("gruvbox-dark"), "gruvbox-dark");
assert.equal(identity.normalizeThemeKey(""), "");
assert.equal(identity.normalizeThemeKey(null), "");

assert.equal(identity.formatThemeName("catppuccin-latte"), "Catppuccin Latte");
assert.equal(identity.formatThemeName("gruvbox"), "Gruvbox");
assert.equal(identity.themeEntryDisplayName({ name: "Display", dirName: "dir" }), "Display");
assert.equal(identity.themeEntryDirName({ name: "Display", dirName: "dir" }), "dir");
assert.equal(identity.themeEntryDirName("plain-theme"), "plain-theme");
assert.equal(identity.themeEntryKey({ name: "Display", dirName: "plain-theme" }), "plain-theme");

const themes = [
  { name: "Catppuccin Latte", dirName: "catppuccin-latte", mode: "light" },
  { name: "Gruvbox Dark", dirName: "gruvbox-dark", mode: "dark" },
  { name: "Rose Pine", dirName: "rose-pine", mode: "dark" }
];
sameJson(identity.filterThemes(themes, "light", ""), [themes[0]]);
sameJson(identity.filterThemes(themes, "dark", "rose"), [themes[2]]);
sameJson(identity.filterThemes(themes, "all", "CAT"), [themes[0]]);
sameJson(identity.filterThemes(null, "all", ""), []);

const translations = {
  "known": "Known value",
  "placeholderHash": "##missing##",
  "placeholderBang": "!!missing!!",
  "tooltips.active": "Theme: {theme}",
  "status.applying": "Applying...",
  "tooltips.inactive": "Inactive",
  "tooltips.not-available": "Unavailable",
  "actions.activate": "Activate",
  "tooltips.widget-settings": "Settings",
  "tooltips.random-theme": "Random"
};
const pluginApi = { tr: key => translations[key] };
assert.equal(ui.tr(pluginApi, "known", "Fallback"), "Known value");
assert.equal(ui.tr(pluginApi, "placeholderHash", "Fallback"), "Fallback");
assert.equal(ui.tr(pluginApi, "placeholderBang", "Fallback"), "Fallback");
assert.equal(ui.tr(pluginApi, "missing", "Fallback"), "Fallback");
assert.equal(ui.omarchyTooltip(pluginApi, false, true, true, "Gruvbox"), "Theme: Gruvbox");
assert.equal(ui.omarchyTooltip(pluginApi, true, true, true, "Gruvbox"), "Applying...");
assert.equal(ui.primaryAction(false, true), "activate");
assert.equal(ui.primaryAction(false, false), "panel");
assert.equal(ui.primaryAction(true, true), "panel");
sameJson(ui.contextMenuModel(pluginApi, false).map(item => item.action), ["activate", "settings"]);
sameJson(ui.contextMenuModel(pluginApi, true).map(item => item.action), ["random", "settings"]);
