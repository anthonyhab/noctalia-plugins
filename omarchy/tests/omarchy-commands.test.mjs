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

const commands = loadHelper("OmarchyCommands.js");
const mainQml = readPluginFile("Main.qml");
const asyncQml = readPluginFile("AsyncThemeSetter.qml");

const bootstrap = commands.omarchyBootstrapSnippet();
assert.match(bootstrap, /export OMARCHY_PATH/);
assert.match(bootstrap, /\$OMARCHY_PATH\/bin:\$PATH/);

const availability = commands.availabilityScript();
assert.match(availability, /custom_theme_set/);
assert.match(availability, /legacy_theme_set/);
assert.match(availability, /omarchy-theme-list/);
assert.match(availability, /command -v omarchy/);

const list = commands.themeListScript();
assert.match(list, /omarchy theme list/);
assert.match(list, /legacy_theme_list/);
assert.match(list, /printf '%s\|%s\|%s\\n'/);
assert.match(list, /light\.mode/);

const setScript = commands.themeSetFallbackScript();
assert.match(setScript, /omarchy theme set/);
assert.match(setScript, /legacy_command/);
sameJson(commands.themeSetFallbackCommand("gruvbox", "/omarchy", "/legacy"), [
  "sh",
  "-c",
  setScript,
  "--",
  "gruvbox",
  "/omarchy",
  "/legacy"
]);

assert.match(commands.feedbackDetectScript(), /fallback_path/);
assert.match(commands.feedbackCommandScript("omarchy toggle idle"), /omarchy toggle idle/);
assert.match(commands.feedbackCommandScript("omarchy toggle idle"), /legacy_name/);

assert.equal(mainQml.includes('import "OmarchyCommands.js" as OmarchyCommands'), true);
assert.equal(/OmarchyCommands\.availabilityScript\(\)/.test(mainQml), true);
assert.equal(/OmarchyCommands\.themeListScript\(\)/.test(mainQml), true);
assert.equal(asyncQml.includes('import "OmarchyCommands.js" as OmarchyCommands'), true);
assert.equal(/OmarchyCommands\.themeSetFallbackCommand/.test(asyncQml), true);
