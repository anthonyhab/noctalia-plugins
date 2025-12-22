.pragma library

// ============================================
// Cached Color Conversion for QuickShell
// ============================================
// This uses pre-computed CIELAB-optimized theme conversions
// To regenerate cache: node generate-theme-cache.js

// Theme cache embedded directly for maximum performance
// These colors were generated using advanced CIELAB color science
const THEME_CACHE =   {
    "catppuccin-mocha": {
      "surface": "#1e1e2e",
      "surfaceVariant": "#313244",
      "surface1": "#313244",
      "surface2": "#45475a",
      "onSurface": "#cdd6f4",
      "onSurfaceVariant": "#a6adc8",
      "outline": "#585b70",
      "outlineVariant": "#2f2f40",
      "primary": "#89b4fa",
      "primaryContainer": "#313244",
      "onPrimary": "#11111b",
      "secondary": "#cba6f7",
      "secondaryContainer": "#9f7cc9",
      "onSecondary": "#000000",
      "tertiary": "#f5c2e7",
      "tertiaryContainer": "#c797ba",
      "onTertiary": "#000000",
      "error": "#f38ba8",
      "errorContainer": "#b85674",
      "onError": "#000000",
      "warning": "#f9e2af",
      "success": "#a6e3a1",
      "info": "#89b4fa",
      "shadow": "#161625",
      "scrim": "#000000"
    },
    "catppuccin-latte": {
      "surface": "#eff1f5",
      "surfaceVariant": "#e6e9ef",
      "surface1": "#e6e9ef",
      "surface2": "#ccd0da",
      "onSurface": "#4c4f69",
      "onSurfaceVariant": "#6c6f85",
      "outline": "#9ca0b0",
      "outlineVariant": "#d8dade",
      "primary": "#1e66f5",
      "primaryContainer": "#e6e9ef",
      "onPrimary": "#dce0e8",
      "secondary": "#8839ef",
      "secondaryContainer": "#b865ff",
      "onSecondary": "#ffffff",
      "tertiary": "#ea76cb",
      "tertiaryContainer": "#ffa2f8",
      "onTertiary": "#ffffff",
      "error": "#d20f39",
      "errorContainer": "#ff5b68",
      "onError": "#ffffff",
      "warning": "#df8e1d",
      "success": "#40a02b",
      "info": "#1e66f5",
      "shadow": "#d8dade",
      "scrim": "#000000"
    },
    "tokyo-night": {
      "surface": "#1a1b26",
      "surfaceVariant": "#24283b",
      "surface1": "#24283b",
      "surface2": "#414868",
      "onSurface": "#c0caf5",
      "onSurfaceVariant": "#a9b1d6",
      "outline": "#565f89",
      "outlineVariant": "#2b2b37",
      "primary": "#7aa2f7",
      "primaryContainer": "#24283b",
      "onPrimary": "#16161e",
      "secondary": "#bb9af7",
      "secondaryContainer": "#8f70c9",
      "onSecondary": "#000000",
      "tertiary": "#ff7a93",
      "tertiaryContainer": "#ce4e6a",
      "onTertiary": "#000000",
      "error": "#f7768e",
      "errorContainer": "#bb3f5c",
      "onError": "#000000",
      "warning": "#e0af68",
      "success": "#9ece6a",
      "info": "#7aa2f7",
      "shadow": "#12131e",
      "scrim": "#000000"
    },
    "gruvbox-dark": {
      "surface": "#282828",
      "surfaceVariant": "#3c3836",
      "surface1": "#3c3836",
      "surface2": "#504945",
      "onSurface": "#ebdbb2",
      "onSurfaceVariant": "#d5c4a1",
      "outline": "#665c54",
      "outlineVariant": "#393939",
      "primary": "#83a598",
      "primaryContainer": "#3c3836",
      "onPrimary": "#1d2021",
      "secondary": "#d3869b",
      "secondaryContainer": "#a65d72",
      "onSecondary": "#000000",
      "tertiary": "#d3869b",
      "tertiaryContainer": "#a65d72",
      "onTertiary": "#000000",
      "error": "#fb4934",
      "errorContainer": "#ba0004",
      "onError": "#000000",
      "warning": "#fabd2f",
      "success": "#b8bb26",
      "info": "#83a598",
      "shadow": "#202020",
      "scrim": "#000000"
    },
    "nord": {
      "surface": "#2e3440",
      "surfaceVariant": "#3b4252",
      "surface1": "#3b4252",
      "surface2": "#434c5e",
      "onSurface": "#eceff4",
      "onSurfaceVariant": "#d8dee9",
      "outline": "#4c566a",
      "outlineVariant": "#404653",
      "primary": "#81a1c1",
      "primaryContainer": "#3b4252",
      "onPrimary": "#242933",
      "secondary": "#b48ead",
      "secondaryContainer": "#896583",
      "onSecondary": "#000000",
      "tertiary": "#b48ead",
      "tertiaryContainer": "#896583",
      "onTertiary": "#000000",
      "error": "#bf616a",
      "errorContainer": "#862e3b",
      "onError": "#000000",
      "warning": "#ebcb8b",
      "success": "#a3be8c",
      "info": "#81a1c1",
      "shadow": "#252b37",
      "scrim": "#000000"
    }
  };

// ============================================
// Fast theme lookup
// ============================================

function getConvertedTheme(themeName) {
  if (THEME_CACHE[themeName]) {
    return THEME_CACHE[themeName];
  }

  console.warn("Theme '" + themeName + "' not found in cache. Run: node generate-theme-cache.js");
  return null;
}

function getAvailableThemes() {
  return Object.keys(THEME_CACHE);
}

// ============================================
// QML Export (functions are accessible)
// ============================================
