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
  
  // First, validate and correct the source colors
  const correctedColors = correctThemeColors(omarchyColors, isDarkMode);
  
  // Map corrected colors to noctalia structure
  const noctaliaTheme = {
    // Surface colors
    surface: correctedColors.background || correctedColors.surface,
    surfaceVariant: correctedColors.surface1 || adjustLightness(correctedColors.background, isDarkMode ? 5 : -5),
    surface1: correctedColors.surface1,
    surface2: correctedColors.surface2,
  
  // Text colors
  onSurface: correctedColors.foreground || correctedColors.onSurface,
  onSurfaceVariant: correctedColors.subtext0 || adjustLightness(correctedColors.foreground, isDarkMode ? -15 : 15),
  
  // Outline colors
  outline: correctedColors.outline || adjustLightness(correctedColors.background, isDarkMode ? 15 : -15),
  outlineVariant: correctedColors.outlineVariant || adjustLightness(correctedColors.background, isDarkMode ? 10 : -10),
  
  // Accent colors
  primary: correctedColors.blue || correctedColors.primary,
  primaryContainer: correctedColors.surface1 || adjustLightness(correctedColors.blue, isDarkMode ? -20 : 20),
  onPrimary: correctedColors.crust || (isDarkMode ? '#000000' : '#ffffff'),
  
  secondary: correctedColors.mauve || correctedColors.secondary,
  secondaryContainer: adjustLightness(correctedColors.mauve, isDarkMode ? -20 : 20),
  onSecondary: isDarkMode ? '#000000' : '#ffffff',
  
  tertiary: correctedColors.pink || correctedColors.tertiary,
  tertiaryContainer: adjustLightness(correctedColors.pink, isDarkMode ? -20 : 20),
  onTertiary: isDarkMode ? '#000000' : '#ffffff',
  
  // Semantic colors
  error: correctedColors.red,
  errorContainer: adjustLightness(correctedColors.red, isDarkMode ? -25 : 25),
  onError: isDarkMode ? '#000000' : '#ffffff',
  
  warning: correctedColors.yellow || correctedColors.peach,
  success: correctedColors.green,
  info: correctedColors.blue || correctedColors.sky,
  
  // Shadow (ensure it's different from surface)
  shadow: adjustLightness(correctedColors.background, isDarkMode ? -5 : -10),
  
  // Scrim
  scrim: isDarkMode ? '#000000' : '#000000'
  };
  
  // Final validation of the converted theme
  const validationIssues = validateThemeColors(noctaliaTheme, isDarkMode);
  if (validationIssues.length > 0) {
    console.warn(`  Theme validation issues for ${omarchyColors.themeName || 'unknown'}:`);
    validationIssues.forEach(issue => console.warn(`    - ${issue}`));
  }
  
  return noctaliaTheme;
}

// Add the validation and correction functions
function validateThemeColors(themeColors, isDarkMode) {
  const issues = [];
  
  // Convert all colors to analysis formats
  const surfaceLab = colorAnalysis.hexToLab(themeColors.surface || themeColors.background);
  const onSurfaceLab = colorAnalysis.hexToLab(themeColors.onSurface || themeColors.foreground);
  const primaryLab = colorAnalysis.hexToLab(themeColors.primary);
  const shadowLab = colorAnalysis.hexToLab(themeColors.shadow);
  
  const surfaceHsl = colorAnalysis.hexToHSL(themeColors.surface || themeColors.background);
  const primaryHsl = colorAnalysis.hexToHSL(themeColors.primary);
  
  if (!surfaceLab || !onSurfaceLab || !primaryLab) {
    issues.push('Invalid color format in theme');
    return issues;
  }
  
  // Mode-specific validation
  if (isDarkMode) {
    // Dark theme validation
    if (surfaceLab.l > 60) {
      issues.push('Dark theme surface too light (L:' + surfaceLab.l.toFixed(1) + ', should be <60)');
    }
    if (onSurfaceLab.l < 70) {
      issues.push('Dark theme text too dark (L:' + onSurfaceLab.l.toFixed(1) + ', should be >70)');
    }
  } else {
    // Light theme validation
    if (surfaceLab.l < 85) {
      issues.push('Light theme surface too dark (L:' + surfaceLab.l.toFixed(1) + ', should be >85)');
    }
    if (surfaceHsl.h > 60 || surfaceHsl.h < 0) {
      issues.push('Light theme surface too warm (H:' + surfaceHsl.h.toFixed(0) + '°, should be 0-60°)');
    }
    if (surfaceHsl.s > 15) {
      issues.push('Light theme surface too saturated (S:' + surfaceHsl.s.toFixed(1) + '%, should be <15%)');
    }
    if (onSurfaceLab.l > 30 || onSurfaceLab.l < 15) {
      issues.push('Light theme text improper lightness (L:' + onSurfaceLab.l.toFixed(1) + ', should be 15-30)');
    }
  }
  
  // Common validation for both modes
  const surfaceTextContrast = colorAnalysis.calculateColorDifference(
    themeColors.surface || themeColors.background, 
    themeColors.onSurface || themeColors.foreground
  );
  if (surfaceTextContrast < 40) {
    issues.push('Poor surface/text contrast (ΔE:' + surfaceTextContrast.toFixed(1) + ', should be >40)');
  } else if (surfaceTextContrast > 80) {
    issues.push('Excessive surface/text contrast (ΔE:' + surfaceTextContrast.toFixed(1) + ', should be <80)');
  }
  
  const surfacePrimaryContrast = colorAnalysis.calculateColorDifference(
    themeColors.surface || themeColors.background, 
    themeColors.primary
  );
  if (surfacePrimaryContrast < 20) {
    issues.push('Poor primary visibility (ΔE:' + surfacePrimaryContrast.toFixed(1) + ', should be >20)');
  }
  
  const surfaceShadowDiff = colorAnalysis.calculateColorDifference(
    themeColors.surface || themeColors.background, 
    themeColors.shadow
  );
  if (surfaceShadowDiff < 2) {
    issues.push('Surface and shadow too similar (ΔE:' + surfaceShadowDiff.toFixed(1) + ', should be >2)');
  }
  
  return issues;
}

function correctThemeColors(themeColors, isDarkMode) {
  const corrected = {...themeColors};
  const issues = validateThemeColors(themeColors, isDarkMode);
  
  if (issues.length === 0) {
    return corrected; // No issues to fix
  }
  
  // Apply corrections based on validation issues
  const surfaceLab = colorAnalysis.hexToLab(themeColors.surface || themeColors.background);
  const onSurfaceLab = colorAnalysis.hexToLab(themeColors.onSurface || themeColors.foreground);
  
  if (!isDarkMode) {
    // Light theme specific corrections
    
    // Fix surface color if too warm or saturated
    const surfaceHsl = colorAnalysis.hexToHSL(themeColors.surface || themeColors.background);
    if ((surfaceHsl.h > 60 || surfaceHsl.s > 15) && surfaceLab) {
      // Make surface more neutral and refresh derived surfaces.
      const neutralLightness = clamp(surfaceLab.l, 85, 95);
      const neutralSurface = colorAnalysis.labToHex(neutralLightness, 0, 0) || corrected.background;
      corrected.background = neutralSurface;
      corrected.surface = neutralSurface;
      corrected.surface1 = adjustLightness(neutralSurface, 5);
      corrected.surface2 = adjustLightness(neutralSurface, 10);
      corrected.outline = adjustLightness(neutralSurface, 15);
      corrected.outlineVariant = adjustLightness(neutralSurface, 10);
    }
    
    // Fix text color if improper lightness
    if (onSurfaceLab && (onSurfaceLab.l > 30 || onSurfaceLab.l < 15)) {
      const targetLightness = clamp(onSurfaceLab.l, 15, 30);
      corrected.foreground = colorAnalysis.labToHex(targetLightness, onSurfaceLab.a, onSurfaceLab.b) || corrected.foreground;
      corrected.onSurface = corrected.foreground;
    }
    
    // Ensure proper contrast
    const contrast = colorAnalysis.calculateColorDifference(corrected.surface || corrected.background, corrected.onSurface || corrected.foreground);
    if (contrast > 80) {
      // Reduce contrast by lightening text slightly
      const onSurfaceLab = colorAnalysis.hexToLab(corrected.onSurface || corrected.foreground);
      if (onSurfaceLab) {
        const adjustedLightness = onSurfaceLab.l + 5;
        corrected.foreground = colorAnalysis.labToHex(adjustedLightness, onSurfaceLab.a, onSurfaceLab.b) || corrected.foreground;
        corrected.onSurface = corrected.foreground;
      }
    }
  }
  
  // Fix shadow color if identical to surface
  const surfaceShadowDiff = colorAnalysis.calculateColorDifference(
    corrected.surface || corrected.background, 
    corrected.shadow
  );
  if (surfaceShadowDiff < 2) {
    const surfaceLab = colorAnalysis.hexToLab(corrected.surface || corrected.background);
    if (surfaceLab) {
      const shadowLightness = isDarkMode ? surfaceLab.l - 3 : surfaceLab.l - 2;
      corrected.shadow = colorAnalysis.labToHex(shadowLightness, surfaceLab.a * 0.9, surfaceLab.b * 0.9) || corrected.shadow;
    }
  }
  
  // Fix primary visibility if poor
  const primaryContrast = colorAnalysis.calculateColorDifference(
    corrected.surface || corrected.background, 
    corrected.primary || corrected.blue
  );
  if (primaryContrast < 20) {
    // Try to adjust primary color for better visibility
    const primaryHsl = colorAnalysis.hexToHSL(corrected.primary || corrected.blue);
    const surfaceHsl = colorAnalysis.hexToHSL(corrected.surface || corrected.background);
    
    if (primaryHsl && surfaceHsl) {
      // Adjust hue to be more different from surface
      const hueDiff = Math.abs(primaryHsl.h - surfaceHsl.h);
      if (hueDiff < 60 || hueDiff > 300) {
        // Move hue away from surface hue
        const newHue = (surfaceHsl.h + 180) % 360;
        corrected.blue = colorAnalysis.hslToHex(newHue, primaryHsl.s, primaryHsl.l);
        corrected.primary = corrected.blue;
      }
    }
  }
  
  return corrected;
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
