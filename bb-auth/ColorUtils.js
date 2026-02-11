.pragma library

/**
 * Generates a stable color from a string key.
 */
function getStableColor(key, palette) {
    if (!key) return palette[0];
    
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
        hash = key.charCodeAt(i) + ((hash << 5) - hash);
    }
    
    const index = Math.abs(hash) % palette.length;
    return palette[index];
}

/**
 * Returns a theme-safe palette of vibrant colors.
 */
function getVibrantPalette(isDark) {
    if (isDark) {
        return [
            "#ff5252", "#ff4081", "#e040fb", "#7c4dff", 
            "#536dfe", "#448aff", "#40c4ff", "#18ffff", 
            "#64ffda", "#69f0ae", "#b2ff59", "#eeff41", 
            "#ffff00", "#ffd740", "#ffab40", "#ff6e40"
        ];
    } else {
        return [
            "#d32f2f", "#c2185b", "#7b1fa2", "#512da8", 
            "#303f9f", "#1976d2", "#0288d1", "#0097a7", 
            "#00796b", "#388e3c", "#689f38", "#afb42b", 
            "#fbc02d", "#ffa000", "#f57c00", "#e64a19"
        ];
    }
}
