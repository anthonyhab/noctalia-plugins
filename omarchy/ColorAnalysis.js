// ============================================
// Advanced Color Analysis and Conversion
// ============================================
// Node.js version for CLI development and cache generation
// ============================================

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
// CIELAB Color Space (Perceptually Uniform)
// ============================================

function rgbToXyz(r, g, b) {
  // Convert sRGB to XYZ
  const linearR = r <= 0.04045 ? r / 12.92 : Math.pow((r + 0.055) / 1.055, 2.4);
  const linearG = g <= 0.04045 ? g / 12.92 : Math.pow((g + 0.055) / 1.055, 2.4);
  const linearB = b <= 0.04045 ? b / 12.92 : Math.pow((b + 0.055) / 1.055, 2.4);
  
  return {
    x: linearR * 0.4124564 + linearG * 0.3575761 + linearB * 0.1804375,
    y: linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750,
    z: linearR * 0.0193339 + linearG * 0.1191920 + linearB * 0.9503041
  };
}

function xyzToLab(x, y, z) {
  // D65 illuminant reference
  const refX = 0.95047;
  const refY = 1.00000;
  const refZ = 1.08883;
  
  const epsilon = 0.008856;
  const kappa = 903.3;
  
  const fx = x > epsilon ? Math.cbrt(x / refX) : (kappa * x / refX + 16) / 116;
  const fy = y > epsilon ? Math.cbrt(y / refY) : (kappa * y / refY + 16) / 116;
  const fz = z > epsilon ? Math.cbrt(z / refZ) : (kappa * z / refZ + 16) / 116;
  
  return {
    l: 116 * fy - 16,
    a: 500 * (fx - fy),
    b: 200 * (fy - fz)
  };
}

function labToXyz(l, a, b) {
  const fy = (l + 16) / 116;
  const fx = a / 500 + fy;
  const fz = fy - b / 200;
  
  const refX = 0.95047;
  const refY = 1.00000;
  const refZ = 1.08883;
  
  const epsilon = 0.008856;
  const kappa = 903.3;
  
  const x = Math.pow(fx, 3) > epsilon ? refX * Math.pow(fx, 3) : refX * (116 * fx - 16) / kappa;
  const y = Math.pow(fy, 3) > epsilon ? refY * Math.pow(fy, 3) : refY * (116 * fy - 16) / kappa;
  const z = Math.pow(fz, 3) > epsilon ? refZ * Math.pow(fz, 3) : refZ * (116 * fz - 16) / kappa;
  
  return { x, y, z };
}

function xyzToRgb(x, y, z) {
  const r = x *  3.2404542 + y * -1.5371385 + z * -0.4985314;
  const g = x * -0.9692660 + y *  1.8760108 + z *  0.0415560;
  const b = x *  0.0556434 + y * -0.2040259 + z *  1.0572252;
  
  const linearR = r <= 0.0031308 ? r * 12.92 : 1.055 * Math.pow(r, 1/2.4) - 0.055;
  const linearG = g <= 0.0031308 ? g * 12.92 : 1.055 * Math.pow(g, 1/2.4) - 0.055;
  const linearB = b <= 0.0031308 ? b * 12.92 : 1.055 * Math.pow(b, 1/2.4) - 0.055;
  
  return {
    r: Math.max(0, Math.min(1, linearR)),
    g: Math.max(0, Math.min(1, linearG)),
    b: Math.max(0, Math.min(1, linearB))
  };
}

function hexToLab(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return null;
  
  const normalized = {
    r: rgb.r / 255,
    g: rgb.g / 255,
    b: rgb.b / 255
  };
  
  const xyz = rgbToXyz(normalized.r, normalized.g, normalized.b);
  return xyzToLab(xyz.x, xyz.y, xyz.z);
}

function labToHex(l, a, b) {
  const xyz = labToXyz(l, a, b);
  const rgb = xyzToRgb(xyz.x, xyz.y, xyz.z);
  
  return rgbToHex(
    Math.round(rgb.r * 255),
    Math.round(rgb.g * 255),
    Math.round(rgb.b * 255)
  );
}

// ============================================
// Advanced Color Analysis Functions
// ============================================

function calculateColorDifference(hex1, hex2) {
  // CIEDE2000 color difference formula
  const lab1 = hexToLab(hex1);
  const lab2 = hexToLab(hex2);
  
  if (!lab1 || !lab2) return 0;
  
  const L1 = lab1.l, a1 = lab1.a, b1 = lab1.b;
  const L2 = lab2.l, a2 = lab2.a, b2 = lab2.b;
  
  const avgL = (L1 + L2) / 2;
  const C1 = Math.sqrt(a1 * a1 + b1 * b1);
  const C2 = Math.sqrt(a2 * a2 + b2 * b2);
  const avgC = (C1 + C2) / 2;
  
  const G = 0.5 * (1 - Math.sqrt(Math.pow(avgC, 7) / (Math.pow(avgC, 7) + Math.pow(25, 7))));
  
  const a1p = (1 + G) * a1;
  const a2p = (1 + G) * a2;
  
  const C1p = Math.sqrt(a1p * a1p + b1 * b1);
  const C2p = Math.sqrt(a2p * a2p + b2 * b2);
  const avgCp = (C1p + C2p) / 2;
  
  const h1p = Math.atan2(b1, a1p) * 180 / Math.PI;
  const h2p = Math.atan2(b2, a2p) * 180 / Math.PI;
  
  const deltaLp = L2 - L1;
  const deltaCp = C2p - C1p;
  
  let deltahp;
  if (C1p * C2p === 0) {
    deltahp = 0;
  } else if (Math.abs(h1p - h2p) <= 180) {
    deltahp = h2p - h1p;
  } else if (h2p <= h1p) {
    deltahp = h2p - h1p + 360;
  } else {
    deltahp = h2p - h1p - 360;
  }
  
  const deltaHp = 2 * Math.sqrt(C1p * C2p) * Math.sin(deltahp * Math.PI / 360);
  
  const avgHp = Math.abs(h1p - h2p) > 180 ? (h1p + h2p + 360) / 2 : (h1p + h2p) / 2;
  const T = 1 - 0.17 * Math.cos((avgHp - 30) * Math.PI / 180) +
            0.24 * Math.cos(2 * avgHp * Math.PI / 180) +
            0.32 * Math.cos((3 * avgHp + 6) * Math.PI / 180) -
            0.20 * Math.cos((4 * avgHp - 63) * Math.PI / 180);
  
  const SL = 1 + (0.015 * Math.pow(avgL - 50, 2)) / Math.sqrt(20 + Math.pow(avgL - 50, 2));
  const SC = 1 + 0.045 * avgCp;
  const SH = 1 + 0.015 * avgCp * T;
  
  const deltaTheta = 30 * Math.exp(-Math.pow((avgHp - 275) / 25, 2));
  const RC = 2 * Math.sqrt(Math.pow(avgCp, 7) / (Math.pow(avgCp, 7) + Math.pow(25, 7)));
  const RT = -RC * Math.sin(2 * deltaTheta * Math.PI / 180);
  
  const deltaE = Math.sqrt(
    Math.pow(deltaLp / SL, 2) +
    Math.pow(deltaCp / SC, 2) +
    Math.pow(deltaHp / SH, 2) +
    RT * (deltaCp / SC) * (deltaHp / SH)
  );
  
  return deltaE;
}

function analyzeColorSaturation(hex) {
  const hsl = hexToHSL(hex);
  if (!hsl) return { saturation: 0, lightness: 0, hue: 0 };
  
  const lab = hexToLab(hex);
  if (!lab) return { saturation: hsl.s, lightness: hsl.l, hue: hsl.h, chroma: 0 };
  
  const chroma = Math.sqrt(lab.a * lab.a + lab.b * lab.b);
  
  return {
    saturation: hsl.s,
    lightness: hsl.l,
    hue: hsl.h,
    chroma: chroma,
    perceptualSaturation: chroma / lab.l * 100
  };
}

function optimizeSaturationForTheme(hex, targetSaturation) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;
  
  const lab = hexToLab(hex);
  if (!lab) return hex;
  
  // Calculate current chroma
  const currentChroma = Math.sqrt(lab.a * lab.a + lab.b * lab.b);
  
  // Adjust chroma while preserving hue
  const targetChroma = currentChroma * (targetSaturation / hsl.s);
  
  const hueRad = hsl.h * Math.PI / 180;
  const newA = targetChroma * Math.cos(hueRad);
  const newB = targetChroma * Math.sin(hueRad);
  
  const newLab = labToHex(lab.l, newA, newB);
  return newLab || hex;
}

// ============================================
// Color Harmony Analysis
// ============================================

function analyzeColorHarmony(colors) {
  const hslColors = colors
    .map(hexToHSL)
    .filter(c => c !== null);
  
  if (hslColors.length < 2) return { harmonyScore: 0, harmonyType: 'none' };
  
  // Calculate hue differences
  const hues = hslColors.map(c => c.h);
  const hueDifferences = [];
  
  for (let i = 0; i < hues.length; i++) {
    for (let j = i + 1; j < hues.length; j++) {
      const diff = Math.abs(hues[i] - hues[j]);
      hueDifferences.push(Math.min(diff, 360 - diff));
    }
  }
  
  const avgHueDiff = hueDifferences.reduce((a, b) => a + b, 0) / hueDifferences.length;
  
  // Analyze harmony patterns
  let harmonyType = 'none';
  let harmonyScore = 0;
  
  // Check for complementary harmony (180° ± 30°)
  const complementaryCount = hueDifferences.filter(d => Math.abs(d - 180) <= 30).length;
  if (complementaryCount >= 1) {
    harmonyType = 'complementary';
    harmonyScore = 0.8;
  }
  
  // Check for analogous harmony (30° ± 15°)
  const analogousCount = hueDifferences.filter(d => d <= 45).length;
  if (analogousCount >= hues.length - 1) {
    harmonyType = 'analogous';
    harmonyScore = 0.7;
  }
  
  // Check for triadic harmony (120° ± 20°)
  const triadicCount = hueDifferences.filter(d => Math.abs(d - 120) <= 20 || Math.abs(d - 240) <= 20).length;
  if (triadicCount >= 2 && hues.length >= 3) {
    harmonyType = 'triadic';
    harmonyScore = 0.9;
  }
  
  // Check for split-complementary harmony
  const splitCompCount = hueDifferences.filter(d => (Math.abs(d - 150) <= 20) || (Math.abs(d - 210) <= 20)).length;
  if (splitCompCount >= 2 && hues.length >= 3) {
    harmonyType = 'split-complementary';
    harmonyScore = 0.85;
  }
  
  // Saturation harmony analysis
  const saturations = hslColors.map(c => c.s);
  const avgSat = saturations.reduce((a, b) => a + b, 0) / saturations.length;
  const satStdDev = Math.sqrt(saturations.reduce((sq, n) => sq + Math.pow(n - avgSat, 2), 0) / saturations.length);
  
  // Better harmony if saturation is consistent
  harmonyScore *= Math.max(0, 1 - satStdDev / 50);
  
  return { harmonyScore, harmonyType };
}

// ============================================
// Theme Comparison and Optimization
// ============================================

function compareThemes(omarchyColors, noctaliaColors) {
  const comparisons = [];
  
  // Compare corresponding colors
  const omarchyKeys = Object.keys(omarchyColors);
  const noctaliaKeys = Object.keys(noctaliaColors);
  
  const commonKeys = omarchyKeys.filter(key => noctaliaKeys.includes(key));
  
  commonKeys.forEach(key => {
    const omarchyHex = omarchyColors[key];
    const noctaliaHex = noctaliaColors[key];
    
    const colorDiff = calculateColorDifference(omarchyHex, noctaliaHex);
    const omarchyAnalysis = analyzeColorSaturation(omarchyHex);
    const noctaliaAnalysis = analyzeColorSaturation(noctaliaHex);
    
    comparisons.push({
      colorType: key,
      colorDifference: colorDiff,
      omarchySaturation: omarchyAnalysis.saturation,
      noctaliaSaturation: noctaliaAnalysis.saturation,
      omarchyLightness: omarchyAnalysis.lightness,
      noctaliaLightness: noctaliaAnalysis.lightness,
      omarchyChroma: omarchyAnalysis.chroma,
      noctaliaChroma: noctaliaAnalysis.chroma
    });
  });
  
  return comparisons;
}

function optimizeThemeColors(sourceColors, targetColors) {
  const optimizedColors = {};
  
  const sourceKeys = Object.keys(sourceColors);
  const targetKeys = Object.keys(targetColors);
  
  const commonKeys = sourceKeys.filter(key => targetKeys.includes(key));
  
  commonKeys.forEach(key => {
    const sourceHex = sourceColors[key];
    const targetHex = targetColors[key];
    
    // Calculate color difference
    const colorDiff = calculateColorDifference(sourceHex, targetHex);
    
    if (colorDiff < 5) {
      // Colors are already similar, use target
      optimizedColors[key] = targetHex;
    } else {
      // Blend colors with preference for target saturation and hue
      const sourceHsl = hexToHSL(sourceHex);
      const targetHsl = hexToHSL(targetHex);
      
      if (sourceHsl && targetHsl) {
        // Use target hue and saturation, but adjust lightness to be closer to source
        const blendedHsl = {
          h: targetHsl.h,
          s: targetHsl.s * 0.9 + sourceHsl.s * 0.1, // 90% target saturation
          l: sourceHsl.l * 0.7 + targetHsl.l * 0.3  // 70% source lightness
        };
        
        optimizedColors[key] = hslToHex(blendedHsl.h, blendedHsl.s, blendedHsl.l);
      } else {
        optimizedColors[key] = targetHex;
      }
    }
  });
  
  return optimizedColors;
}

// ============================================
// Color Temperature Analysis
// ============================================

function calculateColorTemperature(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return { temperature: 0, isWarm: false };
  
  const r = rgb.r / 255;
  const g = rgb.g / 255;
  const b = rgb.b / 255;
  
  // Simple temperature calculation based on RGB ratios
  const temperature = (r * 1000 + g * 500 + b * 100) / (r + g + b);
  const isWarm = r > b && r > 0.4;
  
  return { temperature, isWarm };
}

function adjustColorTemperature(hex, temperatureChange) {
  const hsl = hexToHSL(hex);
  if (!hsl) return hex;
  
  // Adjust hue based on temperature change
  // Positive = warmer, negative = cooler
  const hueAdjustment = temperatureChange * 2;
  hsl.h = (hsl.h + hueAdjustment) % 360;
  
  // Slight saturation boost for warmth
  if (temperatureChange > 0) {
    hsl.s = Math.min(100, hsl.s + temperatureChange * 0.5);
  }
  
  return hslToHex(hsl.h, hsl.s, hsl.l);
}

// ============================================
// Export all functions (Node.js only)
// ============================================
module.exports = {
  hexToRgb,
  rgbToHex,
  clamp,
  hexToHSL,
  hslToHex,
  hexToLab,
  labToHex,
  calculateColorDifference,
  analyzeColorSaturation,
  optimizeSaturationForTheme,
  analyzeColorHarmony,
  compareThemes,
  optimizeThemeColors,
  calculateColorTemperature,
  adjustColorTemperature
};
