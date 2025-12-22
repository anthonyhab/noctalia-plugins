# Omarchy Color Conversion

Fast color scheme conversion for QuickShell/Noctalia with CIELAB-optimized colors.

## Architecture

### Runtime (QuickShell)
- **ColorsConvertCached.js** - Pre-computed CIELAB-optimized themes (instant lookup)
- **ColorsConvert.js** - HSL utilities for dynamic adjustments (if needed)
- Themes use advanced CIELAB color science, loaded instantly from cache

### Development (Node.js CLI)
- **ColorAnalysis.js** - Advanced CIELAB color science for perceptually accurate conversions
- **generate-theme-cache.js** - Generates CIELAB-optimized theme conversions
- **color_analysis_report.js** - Analyzes color relationships between themes

## The Magic: CIELAB Color Science

All cached themes use **CIELAB color space** for:
- Perceptually uniform lightness adjustments
- Better color harmony
- More accurate contrast calculations
- Professional-grade color conversions

**Runtime** just loads these pre-computed perfect colors = instant + beautiful!

## Workflow

### Using Themes at Runtime (QuickShell)
```javascript
.import "ColorsConvertCached.js" as ThemeCache

// Get CIELAB-optimized theme (instant lookup)
const theme = ThemeCache.getConvertedTheme("catppuccin-mocha");

// All colors are pre-computed with advanced color science
console.log(theme.primary);  // "#89b4fa" - perfectly optimized
```

### Developing Color Algorithm

When you want to improve the color conversion:

1. **Analyze color relationships:**
   ```bash
   node color_analysis_report.js
   ```
   Shows how different themes handle color relationships

2. **Modify the algorithm:**
   - Edit `generate-theme-cache.js` to improve conversion logic
   - Uses CIELAB color space for perceptually accurate conversions
   - Optimizes saturation, lightness, and color harmony

3. **Regenerate cache:**
   ```bash
   node generate-theme-cache.js
   node update-cache-embedded.js
   ```
   First command generates JSON, second embeds it in the QML file

4. **Test in QuickShell:**
   - The updated CIELAB-optimized colors are immediately available
   - No runtime performance impact - just better colors!

## Adding New Themes

Just add your theme to `~/.config/omarchy/themes/my-theme/` with an `alacritty.toml` file!

The script automatically:
- Scans `~/.config/omarchy/themes/*`
- Follows symlinks (like the ones in `.local/share/omarchy/themes/`)
- Parses `alacritty.toml` for colors
- Converts to CIELAB-optimized noctalia format

Then regenerate:
```bash
node generate-theme-cache.js    # Scans all themes, generates with CIELAB
node update-cache-embedded.js   # Embeds into QML file
```

**18 themes cached automatically!**

## Files

- **ColorAnalysis.js** - Node.js only, CIELAB color space conversions
- **ColorsConvertCached.js** - QuickShell runtime, pre-computed CIELAB themes
- **ColorsConvert.js** - QuickShell runtime, HSL utilities for dynamic adjustments
- **generate-theme-cache.js** - CLI tool using CIELAB to generate theme cache
- **update-cache-embedded.js** - CLI tool to embed cache into QML file
- **theme-cache.json** - Generated cache (auto-updated, don't edit)
- **color_analysis_report.js** - CLI tool for analyzing themes

## Why This Architecture?

✅ **Performance**: Color switching is instant (just array lookup)  
✅ **Quality**: Full CIELAB color science for professional results  
✅ **Development**: Iterate on algorithm without affecting runtime  
✅ **Best of Both**: Advanced science offline, instant results online  

You get **perceptually accurate, beautiful colors** with **zero runtime cost**!
