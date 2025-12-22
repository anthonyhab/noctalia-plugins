#!/usr/bin/env node

// ============================================
// Theme Cache Generator
// ============================================
// Automatically scans ~/.config/omarchy/themes/* and caches all themes
// Usage: node generate-theme-cache.js

const fs = require('fs');
const path = require('path');
const os = require('os');
const colorAnalysis = require('./ColorAnalysis.js');

// Import the color conversion utilities we need
const { hexToHSL, hslToHex, clamp, hexToRgb, rgbToHex } = colorAnalysis;

// ============================================
// Core conversion functions (from ColorsConvert.js)
// ============================================

function getLuminance(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  const [r, g, b] = [rgb.r, rgb.g, rgb.b].map(val => {
    val /= 255;
    return val <= 0.03928 ? val / 12.92 : Math.pow((val + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function isLightColor(hex) {
  return getLuminance(hex) > 0.4;
}

// ============================================
// Theme conversion logic
// ============================================

function convertOmarchyToNoctalia(omarchyColors) {
  const isDarkMode = !isLightColor(omarchyColors.background || '#000000');

  // Map omarchy colors to noctalia structure
  const noctaliaTheme = {
    // Surface colors
    surface: omarchyColors.background || omarchyColors.surface,
    surfaceVariant: omarchyColors.surface1 || adjustLightness(omarchyColors.background, isDarkMode ? 5 : -5),
    surface1: omarchyColors.surface1,
    surface2: omarchyColors.surface2,

    // Text colors
    onSurface: omarchyColors.foreground || omarchyColors.onSurface,
    onSurfaceVariant: omarchyColors.subtext0 || adjustLightness(omarchyColors.foreground, isDarkMode ? -15 : 15),

    // Outline colors
    outline: omarchyColors.outline || adjustLightness(omarchyColors.background, isDarkMode ? 15 : -15),
    outlineVariant: omarchyColors.outlineVariant || adjustLightness(omarchyColors.background, isDarkMode ? 10 : -10),

    // Accent colors
    primary: omarchyColors.blue || omarchyColors.primary,
    primaryContainer: omarchyColors.surface1 || adjustLightness(omarchyColors.blue, isDarkMode ? -20 : 20),
    onPrimary: omarchyColors.crust || (isDarkMode ? '#000000' : '#ffffff'),

    secondary: omarchyColors.mauve || omarchyColors.secondary,
    secondaryContainer: adjustLightness(omarchyColors.mauve, isDarkMode ? -20 : 20),
    onSecondary: isDarkMode ? '#000000' : '#ffffff',

    tertiary: omarchyColors.pink || omarchyColors.tertiary,
    tertiaryContainer: adjustLightness(omarchyColors.pink, isDarkMode ? -20 : 20),
    onTertiary: isDarkMode ? '#000000' : '#ffffff',

    // Semantic colors
    error: omarchyColors.red,
    errorContainer: adjustLightness(omarchyColors.red, isDarkMode ? -25 : 25),
    onError: isDarkMode ? '#000000' : '#ffffff',

    warning: omarchyColors.yellow || omarchyColors.peach,
    success: omarchyColors.green,
    info: omarchyColors.blue || omarchyColors.sky,

    // Shadow
    shadow: adjustLightness(omarchyColors.background, isDarkMode ? -5 : -10),

    // Scrim
    scrim: isDarkMode ? '#000000' : '#000000'
  };

  return noctaliaTheme;
}

function adjustLightness(hex, amount) {
  if (!hex) return hex;

  // Use CIELAB for perceptually accurate lightness adjustment
  const lab = colorAnalysis.hexToLab(hex);
  if (lab) {
    lab.l = clamp(lab.l + amount * 0.8, 0, 100);
    const newHex = colorAnalysis.labToHex(lab.l, lab.a, lab.b);
    if (newHex) return newHex;
  }

  // Fallback to HSL if CIELAB fails
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;
  hsl.l = clamp(hsl.l + amount, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Parse TOML (simple parser for alacritty.toml color format)
// ============================================

function parseAlacrittyToml(content) {
  const colors = {};
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    // Parse primary colors
    if (line.includes('background =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.background = match[1];
    }
    if (line.includes('foreground =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.foreground = match[1];
    }

    // Parse normal colors (ANSI)
    if (line.includes('red     =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.red = match[1];
    }
    if (line.includes('green   =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.green = match[1];
    }
    if (line.includes('yellow  =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.yellow = match[1];
    }
    if (line.includes('blue    =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.blue = match[1];
    }
    if (line.includes('magenta =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.mauve = match[1];
    }
    if (line.includes('cyan    =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.sky = match[1];
    }
    if (line.includes('white   =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.subtext0 = match[1];
    }
    if (line.includes('black   =')) {
      const match = line.match(/["']([#\w]+)["']/);
      if (match) colors.crust = match[1];
    }
  }

  // Generate surface colors if not present
  if (colors.background && !colors.surface1) {
    colors.surface1 = adjustLightness(colors.background, 5);
  }
  if (colors.background && !colors.surface2) {
    colors.surface2 = adjustLightness(colors.background, 10);
  }
  if (!colors.outline && colors.background) {
    colors.outline = adjustLightness(colors.background, 15);
  }

  // Add default fallbacks
  if (!colors.pink) colors.pink = colors.mauve || colors.red;
  if (!colors.peach) colors.peach = colors.yellow || colors.red;

  return colors;
}

// ============================================
// Scan themes from ~/.config/omarchy/themes/*
// ============================================

function scanOmarchyThemes() {
  const themesDir = path.join(os.homedir(), '.config', 'omarchy', 'themes');
  const themes = {};

  if (!fs.existsSync(themesDir)) {
    console.error(`Themes directory not found: ${themesDir}`);
    console.log('Using fallback themes...');
    return getFallbackThemes();
  }

  const entries = fs.readdirSync(themesDir);

  for (const entry of entries) {
    const themePath = path.join(themesDir, entry);

    // Follow symlinks
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

    // Check if it's a directory
    if (!fs.statSync(realPath).isDirectory()) {
      continue;
    }

    // Look for alacritty.toml
    const alacrittyPath = path.join(realPath, 'alacritty.toml');
    if (fs.existsSync(alacrittyPath)) {
      try {
        const content = fs.readFileSync(alacrittyPath, 'utf8');
        const colors = parseAlacrittyToml(content);

        if (colors.background && colors.foreground) {
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

function getFallbackThemes() {
  // Fallback themes if directory scan fails
  return {
    'catppuccin-mocha': {
      background: '#1e1e2e',
      surface1: '#313244',
      surface2: '#45475a',
      foreground: '#cdd6f4',
      subtext0: '#a6adc8',
      outline: '#585b70',
      blue: '#89b4fa',
      mauve: '#cba6f7',
      pink: '#f5c2e7',
      red: '#f38ba8',
      peach: '#fab387',
      yellow: '#f9e2af',
      green: '#a6e3a1',
      sky: '#89dceb',
      crust: '#11111b'
    }
  };
}

// ============================================
// Generate cache
// ============================================

console.log('Scanning themes from ~/.config/omarchy/themes/*\n');

const omarchyThemes = scanOmarchyThemes();

if (Object.keys(omarchyThemes).length === 0) {
  console.error('\nNo themes found! Please check ~/.config/omarchy/themes/');
  process.exit(1);
}

console.log(`\nFound ${Object.keys(omarchyThemes).length} themes. Converting with CIELAB...\n`);

const cache = {};

for (const [themeName, omarchyColors] of Object.entries(omarchyThemes)) {
  console.log(`  Converting ${themeName}...`);
  cache[themeName] = convertOmarchyToNoctalia(omarchyColors);
}

// Write cache to file
const cacheFile = path.join(__dirname, 'theme-cache.json');
fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 2));

console.log(`\n✓ Theme cache generated: ${cacheFile}`);
console.log(`  ${Object.keys(cache).length} themes cached`);
console.log(`\nRun: node update-cache-embedded.js`);
console.log('To update the embedded cache in ColorsConvertCached.js');
