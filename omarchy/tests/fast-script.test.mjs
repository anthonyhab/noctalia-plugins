import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const scriptPath = path.join(os.homedir(), ".local/bin/omarchy-theme-set-fast");
assert.equal(fs.existsSync(scriptPath), true, `${scriptPath} must exist`);

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-fast-"));
const home = path.join(tmp, "home");
const omarchyRoot = path.join(tmp, "omarchy");
const binDir = path.join(tmp, "bin");
const cacheDir = path.join(tmp, "render-cache");
const currentDir = path.join(tmp, "current");
const stateDir = path.join(tmp, "state");
const orderLog = path.join(tmp, "order.log");
const scriptLog = path.join(tmp, "script.log");
const configPath = path.join(tmp, "config.sh");

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function writeExecutable(file, content) {
  fs.writeFileSync(file, content);
  fs.chmodSync(file, 0o755);
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function readLines(file) {
  if (!fs.existsSync(file))
    return [];
  return fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean);
}

function countLinesContaining(needle) {
  return readLines(orderLog).filter(line => line.includes(needle)).length;
}

function waitForLine(needle) {
  for (let i = 0; i < 50; i++) {
    if (readLines(orderLog).some(line => line.includes(needle)))
      return;
    sleep(50);
  }
  assert.fail(`Timed out waiting for ${needle}`);
}

function killPidFile(file) {
  if (!fs.existsSync(file))
    return;
  const raw = fs.readFileSync(file, "utf8").trim();
  if (!/^\d+$/.test(raw))
    return;
  const pid = Number(raw);
  try {
    process.kill(-pid, "SIGTERM");
  } catch {
    try {
      process.kill(pid, "SIGTERM");
    } catch {}
  }
}

mkdirp(home);
mkdirp(binDir);
mkdirp(path.join(omarchyRoot, "themes", "test-theme"));
mkdirp(path.join(omarchyRoot, "default", "themed"));
mkdirp(path.join(home, ".config/omarchy/themes/test-theme"));
mkdirp(path.join(home, ".config/omarchy/themed"));

fs.writeFileSync(path.join(omarchyRoot, "themes/test-theme/alacritty.toml"), "[colors]\n");
fs.writeFileSync(path.join(omarchyRoot, "themes/test-theme/marker.txt"), "stock\n");
fs.writeFileSync(path.join(home, ".config/omarchy/themes/test-theme/marker.txt"), "user\n");

writeExecutable(path.join(binDir, "omarchy-theme-colors-from-alacritty"), `#!/usr/bin/env bash
set -euo pipefail
printf 'fallback %s\n' "$1" >> "$ORDER_LOG"
printf 'background = "#101010"\nforeground = "#ffffff"\n' > "$1/colors.toml"
`);
writeExecutable(path.join(binDir, "theme-bg-next"), `#!/usr/bin/env bash
set -euo pipefail
printf 'wallpaper start %s\n' "$$" >> "$ORDER_LOG"
trap 'printf "wallpaper term %s\\n" "$$" >> "$ORDER_LOG"; exit 143' TERM
sleep "\${WALLPAPER_SLEEP:-0}"
printf 'wallpaper done %s\n' "$$" >> "$ORDER_LOG"
`);
writeExecutable(path.join(binDir, "early-theme"), `#!/usr/bin/env bash
set -euo pipefail
printf 'early-theme\n' >> "$ORDER_LOG"
sleep "\${EARLY_SLEEP:-0}"
`);
writeExecutable(path.join(binDir, "early-restart"), `#!/usr/bin/env bash
set -euo pipefail
printf 'early-restart\n' >> "$ORDER_LOG"
sleep "\${EARLY_RESTART_SLEEP:-0}"
`);
writeExecutable(path.join(binDir, "slow-followup"), `#!/usr/bin/env bash
set -euo pipefail
printf 'slow-followup start %s\n' "$$" >> "$ORDER_LOG"
trap 'printf "slow-followup term %s\\n" "$$" >> "$ORDER_LOG"; exit 143' TERM
sleep "\${FOLLOWUP_SLEEP:-0}"
printf 'slow-followup done %s\n' "$$" >> "$ORDER_LOG"
`);

fs.writeFileSync(configPath, `EARLY_THEME_COMMANDS=("early-theme")
EARLY_RESTART_COMMANDS=("early-restart")
SYNC_THEME_COMMANDS=("slow-followup")
SYNC_RESTART_COMMANDS=()
ASYNC_THEME_COMMANDS=()
NOCTALIA_SHELL_PATH=""
`);

function runTheme(extraEnv = {}) {
  const result = spawnSync(scriptPath, ["Test Theme"], {
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: home,
      OMARCHY_PATH: omarchyRoot,
      PATH: `${binDir}:${process.env.PATH}`,
      ORDER_LOG: orderLog,
      OMARCHY_THEME_LOG_FILE: scriptLog,
      OMARCHY_THEME_CONFIG: configPath,
      OMARCHY_THEME_RENDER_CACHE: cacheDir,
      OMARCHY_THEME_CURRENT_DIR: currentDir,
      OMARCHY_THEME_STATE_DIR: stateDir,
      ...extraEnv
    }
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result;
}

try {
  runTheme({ EARLY_SLEEP: "0.2" });
  waitForLine("slow-followup done");

  const themeLink = path.join(currentDir, "theme");
  assert.equal(fs.lstatSync(themeLink).isSymbolicLink(), true);
  const renderPath = fs.readlinkSync(themeLink);
  assert.equal(fs.readFileSync(path.join(currentDir, "theme.name"), "utf8").trim(), "test-theme");
  assert.match(fs.readFileSync(path.join(currentDir, "theme.hash"), "utf8").trim(), /^[a-f0-9]{64}$/);
  assert.equal(fs.readFileSync(path.join(renderPath, "marker.txt"), "utf8").trim(), "user");
  assert.equal(fs.readFileSync(path.join(renderPath, "colors.toml"), "utf8").includes("background"), true);

  const firstLines = readLines(orderLog);
  assert.ok(firstLines.findIndex(line => line.startsWith("wallpaper start")) < firstLines.indexOf("early-theme"));
  assert.ok(firstLines.indexOf("early-theme") < firstLines.indexOf("early-restart"));
  assert.ok(firstLines.indexOf("early-restart") < firstLines.findIndex(line => line.startsWith("slow-followup start")));

  const fallbackCount = countLinesContaining("fallback ");
  runTheme();
  waitForLine("slow-followup done");
  assert.equal(countLinesContaining("fallback "), fallbackCount);
  assert.equal(fs.readlinkSync(themeLink), renderPath);

  fs.writeFileSync(orderLog, "");
  runTheme({ WALLPAPER_SLEEP: "2", FOLLOWUP_SLEEP: "2" });
  waitForLine("slow-followup start");
  runTheme({ WALLPAPER_SLEEP: "2", FOLLOWUP_SLEEP: "2" });
  for (let i = 0; i < 50; i++) {
    const lines = readLines(orderLog).join("\n");
    if (lines.includes("wallpaper term") || lines.includes("slow-followup term"))
      break;
    sleep(50);
  }
  const finalLines = readLines(orderLog).join("\n");
  assert.match(finalLines, /(wallpaper term|slow-followup term)/);
} finally {
  killPidFile(path.join(stateDir, "wallpaper-pgid"));
  killPidFile(path.join(stateDir, "followup-pgid"));
  sleep(100);
  fs.rmSync(tmp, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
}
