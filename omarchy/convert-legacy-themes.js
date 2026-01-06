#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

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
          if (color) {
            const colorIndex = normalColors.indexOf(colorName);
            colors[`color${colorIndex}`] = color;
          }
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
            const colorIndex = brightColors.indexOf(brightName) + 8;
            colors[`color${colorIndex}`] = color;
          }
          break;
        }
      }
    }
  }

  return colors;
}

function generateColorsToml(colors) {
  let output = "";

  // Base colors
  if (colors.background)
    output += `background = "${colors.background}"\n`;
  if (colors.foreground)
    output += `foreground = "${colors.foreground}"\n`;

  // Terminal colors 0-15
  for (let i = 0; i <= 15; i++) {
    const color = colors[`color${i}`];
    if (color) {
      output += `color${i} = "${color}"\n`;
    }
  }

  return output.trim() + "\n";
}

function convertTheme(themeDir) {
  const alacrittyPath = path.join(themeDir, "alacritty.toml");
  const colorsTomlPath = path.join(themeDir, "colors.toml");

  if (!fs.existsSync(alacrittyPath)) {
    console.log(`Skipping ${path.basename(themeDir)}: no alacritty.toml`);
    return;
  }

  if (fs.existsSync(colorsTomlPath)) {
    console.log(`Skipping ${path.basename(themeDir)}: colors.toml already exists`);
    return;
  }

  const content = fs.readFileSync(alacrittyPath, "utf8");
  const colors = parseAlacrittyToml(content);

  if (!colors.background || !colors.foreground) {
    console.error(`Error: ${path.basename(themeDir)} - missing required colors`);
    return;
  }

  const colorsToml = generateColorsToml(colors);
  fs.writeFileSync(colorsTomlPath, colorsToml);

  console.log(`✓ ${path.basename(themeDir)}`);
}

function main() {
  const themesDir = path.join(os.homedir(), ".config", "omarchy", "themes");

  if (!fs.existsSync(themesDir)) {
    console.error(`Themes directory not found: ${themesDir}`);
    process.exit(1);
  }

  const entries = fs.readdirSync(themesDir);
  let converted = 0;
  let skipped = 0;
  let errors = 0;

  console.log("Converting legacy themes to new colors.toml format...\n");

  for (const entry of entries) {
    const themePath = path.join(themesDir, entry);

    let realPath = themePath;
    try {
      const stat = fs.lstatSync(themePath);
      if (stat.isSymbolicLink()) {
        realPath = fs.realpathSync(themePath);
      }
    } catch (err) {
      console.warn(`Skipping ${entry}: ${err.message}`);
      skipped++;
      continue;
    }

    if (!fs.statSync(realPath).isDirectory()) {
      continue;
    }

    const alacrittyPath = path.join(realPath, "alacritty.toml");
    const colorsTomlPath = path.join(realPath, "colors.toml");

    if (!fs.existsSync(alacrittyPath)) {
      continue; // Already has colors.toml or no alacritty.toml
    }

    if (fs.existsSync(colorsTomlPath)) {
      skipped++;
      continue;
    }

    const content = fs.readFileSync(alacrittyPath, "utf8");
    const colors = parseAlacrittyToml(content);

    if (!colors.background || !colors.foreground) {
      console.error(`Error: ${entry} - missing required colors`);
      errors++;
      continue;
    }

    const colorsToml = generateColorsToml(colors);
    fs.writeFileSync(colorsTomlPath, colorsToml);

    converted++;
    console.log(`✓ ${entry}`);
  }

  console.log(`\nConversion complete:`);
  console.log(`  Converted: ${converted}`);
  console.log(`  Skipped: ${skipped}`);
  console.log(`  Errors: ${errors}`);
}

if (require.main === module) {
  main();
}

module.exports = {
  parseAlacrittyToml,
  generateColorsToml,
  convertTheme
};
