// Fast runtime pipeline for generating Noctalia palettes from Omarchy colors.
const PIPELINE_VERSION = "e93a979d8999";

function ensureContrast(foreground, background, minRatio, step, convert) {
  let result = foreground;
  const direction = convert.getLuminance(background) < 0.5 ? 1 : -1;
  const stepSize = step || 4;
  for (let i = 0; i < 12; i++) {
    if (convert.getContrastRatio(result, background) >= minRatio)
      break;
    result = convert.adjustLightness(result, direction * stepSize);
  }
  return result;
}

function normalizeLightSurface(surface, convert) {
  const hsl = convert.hexToHSL(surface);
  if (!hsl)
    return surface;
  if (hsl.l < 85)
    return surface;
  const isWarmYellow = hsl.h >= 40 && hsl.h <= 70;
  // Only neutralize lightly saturated warm backgrounds (25-45% saturation)
  // High saturation (>45%) indicates an intentional warm theme like Flexoki
  if (!isWarmYellow || hsl.s < 25 || hsl.s > 45)
    return surface;
  const neutralLightness = convert.clamp(hsl.l, 88, 97);
  return convert.hslToHex(0, 0, neutralLightness);
}

function detectMode(colors, convert) {
  return convert.getLuminance(colors.background || "#000000") < 0.5;
}

function normalizeBase(colors, isDarkMode, convert) {
  let baseSurface = colors.background || (isDarkMode ? "#1a1b26" : "#ffffff");
  if (!isDarkMode) {
    baseSurface = normalizeLightSurface(baseSurface, convert);
  }
  const baseOnSurface = colors.foreground || (isDarkMode ? "#c0caf5" : "#1a1b26");
  return { "surface": baseSurface, "onSurface": baseOnSurface };
}

function pickAccents(colors) {
  const primary = colors.blue || colors.brightBlue || colors.cyan || "#4CAF50";
  const secondary = colors.magenta || colors.brightMagenta || colors.red || "#FFC107";
  const tertiary = colors.green || colors.brightGreen || colors.yellow || "#2196F3";

  return {
    "primary": primary,
    "secondary": secondary,
    "tertiary": tertiary
  };
}

function buildSurfaceTokens(base, isDarkMode, convert) {
  const mSurface = base.surface || (isDarkMode ? "#1a1b26" : "#ffffff");
  const textColor = isDarkMode
    ? (base.brightWhite || base.onSurface || "#c0caf5")
    : (base.onSurface || "#1a1b26");
  const mOnSurface = ensureContrast(textColor, mSurface, 4.5, 4, convert);

  return {
    "mSurface": mSurface,
    "mOnSurface": mOnSurface,
    "mBackground": mSurface,
    "mOnBackground": mOnSurface,
    "mSurfaceVariant": convert.generateSurfaceVariant(mSurface, isDarkMode),
    "mOnSurfaceVariant": convert.generateOnSurfaceVariant(mSurface, mOnSurface, isDarkMode),
    "mSurfaceContainerLowest": convert.generateSurfaceLevel(mSurface, 1, isDarkMode),
    "mSurfaceContainerLow": convert.generateSurfaceLevel(mSurface, 2, isDarkMode),
    "mSurfaceContainer": convert.generateSurfaceLevel(mSurface, 3, isDarkMode),
    "mSurfaceContainerHigh": convert.generateSurfaceLevel(mSurface, 4, isDarkMode),
    "mSurfaceContainerHighest": convert.generateSurfaceLevel(mSurface, 5, isDarkMode),
    "mSurfaceBright": convert.generateSurfaceLevel(mSurface, 4.5, isDarkMode),
    "mSurfaceDim": convert.adjustLightness(mSurface, isDarkMode ? -3 : 3),
    "mOutline": convert.generateOutline(mSurface, isDarkMode),
    "mOutlineVariant": convert.generateOutlineVariant(mSurface, isDarkMode),
    "mShadow": convert.generateShadow(mSurface, isDarkMode)
  };
}

function buildAccentTokens(accents, errorColor, surface, isDarkMode, convert) {
  const darkOnColor = convert.adjustLightness(surface, -2);
  const mOnPrimary = convert.getContrastRatio(darkOnColor, accents.primary) >= 4.5
    ? darkOnColor : convert.generateOnColor(accents.primary, isDarkMode);
  const mOnSecondary = convert.getContrastRatio(darkOnColor, accents.secondary) >= 4.5
    ? darkOnColor : convert.generateOnColor(accents.secondary, isDarkMode);
  const mOnTertiary = convert.getContrastRatio(darkOnColor, accents.tertiary) >= 4.5
    ? darkOnColor : convert.generateOnColor(accents.tertiary, isDarkMode);
  const mOnError = convert.getContrastRatio(darkOnColor, errorColor) >= 4.5
    ? darkOnColor : convert.generateOnColor(errorColor, isDarkMode);

  const mPrimaryContainer = convert.generateContainerColor(accents.primary, isDarkMode);
  const mSecondaryContainer = convert.generateContainerColor(accents.secondary, isDarkMode);
  const mTertiaryContainer = convert.generateContainerColor(accents.tertiary, isDarkMode);
  const mErrorContainer = convert.generateContainerColor(errorColor, isDarkMode);

  return {
    "mPrimary": accents.primary,
    "mOnPrimary": mOnPrimary,
    "mPrimaryContainer": mPrimaryContainer,
    "mOnPrimaryContainer": convert.generateOnColor(mPrimaryContainer, isDarkMode),
    "mSecondary": accents.secondary,
    "mOnSecondary": mOnSecondary,
    "mSecondaryContainer": mSecondaryContainer,
    "mOnSecondaryContainer": convert.generateOnColor(mSecondaryContainer, isDarkMode),
    "mTertiary": accents.tertiary,
    "mOnTertiary": mOnTertiary,
    "mTertiaryContainer": mTertiaryContainer,
    "mOnTertiaryContainer": convert.generateOnColor(mTertiaryContainer, isDarkMode),
    "mError": errorColor,
    "mOnError": mOnError,
    "mErrorContainer": mErrorContainer,
    "mOnErrorContainer": convert.generateOnColor(mErrorContainer, isDarkMode),
    "mHover": accents.tertiary,
    "mOnHover": convert.generateOnColor(accents.tertiary, isDarkMode)
  };
}

function generateScheme(colors, convert) {
  const isDarkMode = detectMode(colors, convert);
  const base = normalizeBase(colors, isDarkMode, convert);
  base.brightWhite = colors.brightWhite;

  const accents = pickAccents(colors);
  const errorColor = colors.red || "#f7768e";

  const surfaceTokens = buildSurfaceTokens(base, isDarkMode, convert);
  const accentTokens = buildAccentTokens(accents, errorColor, surfaceTokens.mSurface, isDarkMode, convert);

  return {
    "mode": isDarkMode ? "dark" : "light",
    "palette": Object.assign({}, accentTokens, surfaceTokens)
  };
}

// Node.js compatibility for test tooling.
if (typeof module !== "undefined") {
  module.exports = {
    PIPELINE_VERSION,
    generateScheme
  };
}
