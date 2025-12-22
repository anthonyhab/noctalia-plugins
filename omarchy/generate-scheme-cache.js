#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

const ThemePipeline = require("./ThemePipeline.js");
const ColorsConvert = require("./ColorsConvert.js");

function parseAlacrittyToml(content) {
  function extractColorFromLine(line) {
    const colorMatch = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
    if (colorMatch) {
      const hex = colorMatch[1].toLowerCase();
      return "#" + hex.slice(-6);
    }
    return null;
  }

  const colors = {};
  const lines = content.split("\n");
  let currentSection = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line)
      continue;
    if (line.startsWith("[colors.primary]")) {
      currentSection = "primary";
      continue;
    } else if (line.startsWith("[colors.normal]")) {
      currentSection = "normal";
      continue;
    } else if (line.startsWith("[colors.bright]")) {
      currentSection = "bright";
      continue;
    } else if (line.startsWith("[colors.selection]")) {
      currentSection = "selection";
      continue;
    } else if (line.startsWith("[")) {
      currentSection = null;
      continue;
    }

    if (currentSection === "primary") {
      if (line.includes("background")) {
        const color = extractColorFromLine(line);
        if (color)
          colors.background = color;
      } else if (line.includes("foreground")) {
        const color = extractColorFromLine(line);
        if (color)
          colors.foreground = color;
      }
    } else if (currentSection === "normal") {
      const normalColors = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
      for (const colorName of normalColors) {
        const nameMatch = line.match(new RegExp("^\\s*(" + colorName + ")\\s*="));
        if (nameMatch) {
          const color = extractColorFromLine(line);
          if (color)
            colors[colorName] = color;
          break;
        }
      }
    } else if (currentSection === "bright") {
      const brightColors = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
      for (const brightName of brightColors) {
        const nameMatch = line.match(new RegExp("^\\s*(" + brightName + ")\\s*="));
        if (nameMatch) {
          const color = extractColorFromLine(line);
          if (color) {
            const key = "bright" + brightName.charAt(0).toUpperCase() + brightName.slice(1);
            colors[key] = color;
          }
          break;
        }
      }
    } else if (currentSection === "selection") {
      if (line.includes("background")) {
        const color = extractColorFromLine(line);
        if (color)
          colors.selectionBackground = color;
      }
    }
  }

  if (!colors.background || !colors.foreground)
    return null;
  return colors;
}

function scanOmarchyThemes() {
  const themesDir = path.join(os.homedir(), ".config", "omarchy", "themes");
  const themes = {};

  if (!fs.existsSync(themesDir)) {
    console.error(`Themes directory not found: ${themesDir}`);
    return themes;
  }

  const entries = fs.readdirSync(themesDir);

  for (const entry of entries) {
    const themePath = path.join(themesDir, entry);
    let realPath = themePath;

    try {
      const stat = fs.lstatSync(themePath);
      if (stat.isSymbolicLink()) {
        realPath = fs.realpathSync(themePath);
      }
    } catch (err) {
      console.warn(`  Skipping ${entry}: ${err.message}`);
      continue;
    }

    if (!fs.statSync(realPath).isDirectory()) {
      continue;
    }

    const alacrittyPath = path.join(realPath, "alacritty.toml");
    if (fs.existsSync(alacrittyPath)) {
      try {
        const content = fs.readFileSync(alacrittyPath, "utf8");
        const colors = parseAlacrittyToml(content);
        if (colors) {
          themes[entry] = colors;
          console.log(`  ✓ ${entry}`);
        } else {
          console.log(`  ⚠ ${entry} (incomplete colors)`);
        }
      } catch (err) {
        console.warn(`  ✗ ${entry}: ${err.message}`);
      }
    } else {
      console.log(`  - ${entry} (no alacritty.toml)`);
    }
  }

  return themes;
}

console.log("Scanning themes from ~/.config/omarchy/themes/*\n");

const omarchyThemes = scanOmarchyThemes();
if (!Object.keys(omarchyThemes).length) {
  console.error("\nNo themes found! Please check ~/.config/omarchy/themes/");
  process.exit(1);
}

console.log(`\nFound ${Object.keys(omarchyThemes).length} themes. Generating scheme cache...\n`);

const cache = {};
for (const [themeName, omarchyColors] of Object.entries(omarchyThemes)) {
  console.log(`  Converting ${themeName}...`);
  cache[themeName] = ThemePipeline.generateScheme(omarchyColors, ColorsConvert);
}

const cacheFile = path.join(__dirname, "scheme-cache.json");
fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 2));

console.log(`\n✓ Scheme cache generated: ${cacheFile}`);
console.log(`  ${Object.keys(cache).length} themes cached`);
console.log(`\nRun: node update-scheme-cache-embedded.js`);
