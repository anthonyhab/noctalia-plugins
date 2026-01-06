#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

const ThemePipeline = require("./ThemePipeline.js");
const ColorsConvert = require("./ColorsConvert.js");

function parseColorsToml(content) {
  function extractColorFromLine(line) {
    // Match both formats: color = "#ffffff" and color = "0xffffff"
    const colorMatch = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
    if (colorMatch) {
      const hex = colorMatch[1].toLowerCase();
      return "#" + hex.slice(-6);
    }
    return null;
  }

  const colors = {};
  const lines = content.split("\n");

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith("#") || line.startsWith("["))
      continue;

    const color = extractColorFromLine(line);
    if (color) {
      const keyMatch = line.match(/^([a-zA-Z0-9_]+)\s*=/);
      if (keyMatch) {
        const key = keyMatch[1];
        colors[key] = color;
      }
    }
  }

  if (!colors.background || !colors.foreground)
    return null;
  return colors;
}

function scanThemesInDirectory(themesDir, label) {
  const themes = {};

  if (!fs.existsSync(themesDir)) {
    console.log(`  ${label} directory not found: ${themesDir}`);
    return themes;
  }

  console.log(`\nScanning ${label}: ${themesDir}`);

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

    const colorsTomlPath = path.join(realPath, "colors.toml");
    if (fs.existsSync(colorsTomlPath)) {
      try {
        const content = fs.readFileSync(colorsTomlPath, "utf8");
        const colors = parseColorsToml(content);
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
      console.log(`  - ${entry} (no colors.toml)`);
    }
  }

  return themes;
}

function scanOmarchyThemes() {
  const userThemesDir = path.join(os.homedir(), ".config", "omarchy", "themes");
  const defaultThemesDir = path.join(os.homedir(), ".local", "share", "omarchy", "themes");

  const userThemes = scanThemesInDirectory(userThemesDir, "User themes");
  const defaultThemes = scanThemesInDirectory(defaultThemesDir, "Default themes");

  // Merge themes, user themes take precedence
  const allThemes = { ...defaultThemes, ...userThemes };

  console.log(`\nTotal unique themes: ${Object.keys(allThemes).length}`);
  return allThemes;
}

console.log("Scanning omarchy themes...\n");

const omarchyThemes = scanOmarchyThemes();
if (!Object.keys(omarchyThemes).length) {
  console.error("\nNo themes found!");
  process.exit(1);
}

console.log(`\nFound ${Object.keys(omarchyThemes).length} unique themes. Generating scheme cache...\n`);

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
