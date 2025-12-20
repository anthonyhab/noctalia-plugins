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
// Lightness adjustments
// ============================================

function adjustLightness(hex, amount) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;
  hsl.l = clamp(hsl.l + amount, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

function adjustLightnessAndSaturation(hex, lightnessAmount, saturationAmount) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;
  hsl.l = clamp(hsl.l + lightnessAmount, 0, 100);
  hsl.s = clamp(hsl.s + saturationAmount, 0, 100);
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Surface level generation with proper steps
// ============================================

// Generate a surface at a specific "elevation" level
// level: 0 = base surface, higher = more elevated (lighter in dark mode)
function generateSurfaceLevel(baseSurface, level, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Lightness step: ~3.5% per level (dark) or -2.5% (light)
  const lightnessStep = isDarkMode ? 3.5 : -2.5;
  hsl.l = clamp(hsl.l + (level * lightnessStep), 0, 100);

  // Very subtle saturation boost (+0.5% per level) - don't overdo it
  hsl.s = clamp(hsl.s + (level * 0.5), 0, 100);

  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// Generate surface variant with clear distinction from base
// Matches native: +6% lightness, minimal saturation change
function generateSurfaceVariant(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // ~6% lightness shift (matches Tokyo-Night: 12.55% → 18.63%)
  const shift = isDarkMode ? 6 : -5;
  hsl.l = clamp(hsl.l + shift, 0, 100);

  // Minimal saturation change - native schemes barely adjust this
  hsl.s = clamp(hsl.s + (isDarkMode ? 2 : -1), 0, 100);

  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Accent tinting for color harmony
// ============================================

// Tint a surface color with an accent for cohesive color family
// Native schemes subtly tint surfaces with primary accent (3-5%)
function tintSurfaceWithAccent(surface, accent, strength) {
  if (!surface || !accent) return surface;
  const weight = clamp(strength || 0.04, 0, 0.15);
  return mixColors(surface, accent, weight);
}

// ============================================
// Text color generation with contrast enforcement
// ============================================

// Generate "on" color that meets minimum contrast ratio
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

  // If preferred doesn't work, adjust until we get contrast
  const hsl = hexToHSL(preferred);
  if (!hsl) return isBaseLight ? "#000000" : "#ffffff";

  // Binary search for minimum adjustment needed
  for (let i = 0; i < 20; i++) {
    const candidate = hslToHex(hsl.h, hsl.s, hsl.l);
    if (getContrastRatio(baseColor, candidate) >= targetContrast) {
      return candidate;
    }
    // Move toward extreme
    hsl.l = isBaseLight ? Math.max(0, hsl.l - 5) : Math.min(100, hsl.l + 5);
  }

  return isBaseLight ? "#000000" : "#ffffff";
}

// Generate onSurfaceVariant with lower contrast for secondary text
// Native Tokyo-Night: #c0caf5 → #9aa5ce (about -15% lightness, -38% saturation)
// But we were over-desaturating - use -15% to preserve some color
function generateOnSurfaceVariant(baseSurface, onSurface, isDarkMode) {
  const minContrast = 3.0;
  const hsl = hexToHSL(onSurface);
  if (!hsl) return onSurface;

  // Reduce lightness by ~12% (matches native: -6 to -15%)
  const lightnessShift = isDarkMode ? -12 : 12;
  hsl.l = clamp(hsl.l + lightnessShift, 0, 100);

  // Moderate desaturation - preserve some color character
  // -15% is enough to create hierarchy without making it gray
  hsl.s = clamp(hsl.s - 15, 0, 100);

  const candidate = hslToHex(hsl.h, hsl.s, hsl.l);

  // Ensure minimum contrast is met
  if (getContrastRatio(baseSurface, candidate) >= minContrast) {
    return candidate;
  }
  return onSurface;
}

// ============================================
// Outline generation
// ============================================

function generateOutline(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Native Tokyo-Night: surface #1a1b26 (L:12.5%) → outline #353D57 (L:27.5%) = +15%
  // But also slightly increases saturation
  const shift = isDarkMode ? 13 : -10;
  hsl.l = clamp(hsl.l + shift, 0, 100);
  // Keep saturation or slightly increase for dark mode
  hsl.s = clamp(hsl.s + (isDarkMode ? 2 : -3), 0, 100);

  return hslToHex(hsl.h, hsl.s, hsl.l);
}

function generateOutlineVariant(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return baseSurface;

  // Outline variant is subtler than outline
  const shift = isDarkMode ? 10 : -8;
  hsl.l = clamp(hsl.l + shift, 0, 100);
  hsl.s = clamp(hsl.s - 8, 0, 100);

  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Container color generation
// ============================================

function generateContainerColor(baseColor, isDarkMode) {
  const rgb = hexToRgb(baseColor);
  if (!rgb) return baseColor;

  const hsl = rgbToHsl(rgb.r, rgb.g, rgb.b);

  if (isDarkMode) {
    // Darker, desaturated version for dark mode containers
    const depth = 16 + (hsl.l * 0.18);
    hsl.l = clamp(hsl.l - depth, 6, 26);
    hsl.s = clamp(hsl.s - 10, 0, 100);
  } else {
    // Lighter, desaturated version for light mode containers
    const lift = 22 + ((100 - hsl.l) * 0.12);
    hsl.l = clamp(hsl.l + lift, 74, 94);
    hsl.s = clamp(hsl.s - 12, 0, 100);
  }

  const newRgb = hslToRgb(hsl.h, hsl.s, hsl.l);
  return rgbToHex(newRgb.r, newRgb.g, newRgb.b);
}

// ============================================
// Shadow generation
// ============================================

function generateShadow(baseSurface, isDarkMode) {
  const hsl = hexToHSL(baseSurface);
  if (!hsl) return isDarkMode ? "#000000" : "#000000";

  // Native Tokyo-Night: surface #1a1b26 → shadow #15161e (just ~3% darker)
  // Keep it close to surface, not too dark
  hsl.l = clamp(hsl.l - (isDarkMode ? 3 : 8), 0, 100);
  hsl.s = clamp(hsl.s - 5, 0, 100);

  return hslToHex(hsl.h, hsl.s, hsl.l);
}
