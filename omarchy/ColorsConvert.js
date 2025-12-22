// ============================================
// Enhanced Color Conversion with Advanced Color Science
// ============================================
// Runtime version - uses basic conversions only
// For advanced analysis, use ColorAnalysis.js with Node.js

// ============================================
// Core color conversion utilities
// ============================================

function hexToRgb(hex) {
  if (!hex || typeof hex !== "string") return null;
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}

function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map(x => {
    const hex = Math.round(Math.max(0, Math.min(255, x))).toString(16);
    return hex.length === 1 ? "0" + hex : hex;
  }).join("");
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;

  if (max === min) {
    h = s = 0;
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
      case g: h = ((b - r) / d + 2) / 6; break;
      case b: h = ((r - g) / d + 4) / 6; break;
    }
  }
  return { h: h * 360, s: s * 100, l: l * 100 };
}

function hslToRgb(h, s, l) {
  h /= 360; s /= 100; l /= 100;
  let r, g, b;
  if (s === 0) {
    r = g = b = l;
  } else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }
  return { r: Math.round(r * 255), g: Math.round(g * 255), b: Math.round(b * 255) };
}

function hexToHSL(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return null;
  return rgbToHsl(rgb.r, rgb.g, rgb.b);
}

function hslToHex(h, s, l) {
  const rgb = hslToRgb(h, s, l);
  return rgbToHex(rgb.r, rgb.g, rgb.b);
}

// ============================================
// Luminance and contrast
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

function getContrastRatio(hex1, hex2) {
  const lum1 = getLuminance(hex1);
  const lum2 = getLuminance(hex2);
  const brightest = Math.max(lum1, lum2);
  const darkest = Math.min(lum1, lum2);
  return (brightest + 0.05) / (darkest + 0.05);
}

function isLightColor(hex) {
  return getLuminance(hex) > 0.4;
}

// ============================================
// Color mixing (perceptually linear)
// ============================================

function srgbToLinear(channel) {
  const c = channel / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function linearToSrgb(channel) {
  const c = channel <= 0.0031308 ? channel * 12.92 : 1.055 * Math.pow(channel, 1/2.4) - 0.055;
  return Math.round(clamp(c, 0, 1) * 255);
}

function mixColors(hexA, hexB, weightB) {
  const a = hexToRgb(hexA);
  const b = hexToRgb(hexB);
  if (!a && !b) return hexA || hexB || "#000000";
  if (!a) return hexB;
  if (!b) return hexA;
  const w = clamp(weightB, 0, 1);
  const r = srgbToLinear(a.r) * (1 - w) + srgbToLinear(b.r) * w;
  const g = srgbToLinear(a.g) * (1 - w) + srgbToLinear(b.g) * w;
  const bch = srgbToLinear(a.b) * (1 - w) + srgbToLinear(b.b) * w;
  return rgbToHex(linearToSrgb(r), linearToSrgb(g), linearToSrgb(bch));
}

// ============================================
// Enhanced Lightness adjustments with CIELAB
// ============================================

function adjustLightness(hex, amount) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;

  // Simple HSL lightness adjustment (fast runtime version)
  hsl.l = clamp(hsl.l + amount, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

function adjustLightnessAndSaturation(hex, lightnessAmount, saturationAmount) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;

  // Simple HSL adjustment (fast runtime version)
  hsl.l = clamp(hsl.l + lightnessAmount, 0, 100);
  hsl.s = clamp(hsl.s + saturationAmount, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Enhanced Surface level generation
// ============================================

function generateSurfaceLevel(baseSurface, level, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Simple HSL surface level generation (fast runtime version)
  const lightnessStep = isDarkMode ? 3.5 : -2.5;
  hsl.l = clamp(hsl.l + (level * lightnessStep), 0, 100);
  hsl.s = clamp(hsl.s + (level * 0.5), 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Enhanced Surface variant generation
// ============================================

function generateSurfaceVariant(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Simple HSL surface variant (fast runtime version)
  const shift = isDarkMode ? 6 : -5;
  hsl.l = clamp(hsl.l + shift, 0, 100);
  hsl.s = clamp(hsl.s + (isDarkMode ? 2 : -1), 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Enhanced Accent tinting with color harmony
// ============================================

function tintSurfaceWithAccent(surface, accent, strength) {
  if (!surface || !accent) return surface;
  const weight = clamp(strength || 0.04, 0, 0.15);

  // Simple perceptually linear mixing (fast runtime version)
  return mixColors(surface, accent, weight);
}

// ============================================
// Enhanced Text color generation
// ============================================

function generateOnColor(baseColor, isDarkMode) {
  const targetContrast = 4.5;
  const isBaseLight = isLightColor(baseColor);

  // Start with theme-appropriate text color
  const lightText = "#f0f0f5";
  const darkText = "#101015";
  const preferred = isBaseLight ? darkText : lightText;

  if (getContrastRatio(baseColor, preferred) >= targetContrast) {
    return preferred;
  }

  // Simple HSL contrast adjustment (fast runtime version)
  const hsl = hexToHSL(preferred);
  if (!hsl) return isBaseLight ? "#000000" : "#ffffff";

  for (let i = 0; i < 20; i++) {
    const candidate = hslToHex(hsl.h, hsl.s, hsl.l);
    if (getContrastRatio(baseColor, candidate) >= targetContrast) {
      return candidate;
    }
    hsl.l = isBaseLight ? Math.max(0, hsl.l - 5) : Math.min(100, hsl.l + 5);
  }

  return isBaseLight ? "#000000" : "#ffffff";
}

// ============================================
// Enhanced onSurfaceVariant generation
// ============================================

function generateOnSurfaceVariant(baseSurface, onSurface, isDarkMode) {
  const minContrast = 3.0;
  const hsl = hexToHSL(onSurface);
  if (!hsl) return onSurface;

  // Simple HSL adjustment (fast runtime version)
  const lightnessShift = isDarkMode ? -12 : 12;
  hsl.l = clamp(hsl.l + lightnessShift, 0, 100);
  hsl.s = clamp(hsl.s - 15, 0, 100);

  const candidate = hslToHex(hsl.h, hsl.s, hsl.l);

  if (getContrastRatio(baseSurface, candidate) >= minContrast) {
    return candidate;
  }
  return onSurface;
}

// ============================================
// Enhanced Outline generation
// ============================================

function generateOutline(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Simple HSL outline generation (fast runtime version)
  const shift = isDarkMode ? 13 : -10;
  hsl.l = clamp(hsl.l + shift, 0, 100);
  hsl.s = clamp(hsl.s + (isDarkMode ? 2 : -3), 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Enhanced Outline variant generation
// ============================================

function generateOutlineVariant(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Simple HSL outline variant (fast runtime version)
  const shift = isDarkMode ? 10 : -8;
  hsl.l = clamp(hsl.l + shift, 0, 100);
  hsl.s = clamp(hsl.s - 8, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Enhanced Container color generation
// ============================================

function generateContainerColor(baseColor, isDarkMode) {
  const rgb = hexToRgb(baseColor);
  if (!rgb) return baseColor;

  const hsl = rgbToHsl(rgb.r, rgb.g, rgb.b);

  // Simple HSL container generation (fast runtime version)
  if (isDarkMode) {
    const depth = 16 + (hsl.l * 0.18);
    hsl.l = clamp(hsl.l - depth, 6, 26);
    hsl.s = clamp(hsl.s - 10, 0, 100);
  } else {
    const lift = 22 + ((100 - hsl.l) * 0.12);
    hsl.l = clamp(hsl.l + lift, 74, 94);
    hsl.s = clamp(hsl.s - 12, 0, 100);
  }

  const newRgb = hslToRgb(hsl.h, hsl.s, hsl.l);
  return rgbToHex(newRgb.r, newRgb.g, newRgb.b);
}

// ============================================
// Enhanced Shadow generation
// ============================================

function generateShadow(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return isDarkMode ? "#000000" : "#000000";

  // Simple HSL shadow generation (fast runtime version)
  hsl.l = clamp(hsl.l - (isDarkMode ? 3 : 8), 0, 100);
  hsl.s = clamp(hsl.s - 5, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Theme Conversion with Advanced Color Science
// ============================================

function convertThemeToNoctalia(omarchyTheme, noctaliaReference) {
  // This function is deprecated - use the pre-generated cache instead
  // For development/regeneration, use: node generate-theme-cache.js
  console.warn("convertThemeToNoctalia is deprecated - use cached themes");
  return omarchyTheme;
}

// ============================================
// Export all functions (QML-style - functions are already accessible)
// ============================================
