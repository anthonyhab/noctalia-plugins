# Omarchy Color Conversion

Fast color scheme conversion for QuickShell/Noctalia with CIELAB-optimized colors.

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Architecture

### Runtime (QuickShell)
- **SchemeCache.js** - Pre-computed Noctalia palettes (instant lookup)
- **ThemePipeline.js** - Fast fallback when cache is missing or stale
- **ColorsConvert.js** - Lightweight HSL utilities used by the pipeline

### Development (Node.js CLI)
- **ColorAnalysis.js** - Advanced CIELAB color science for perceptual analysis
- **generate-scheme-cache.js** - Generates the runtime scheme cache
- **update-scheme-cache-embedded.js** - Embeds the cache + pipeline version
- **color_analysis_report.js** - Analyzes color relationships between themes

## The Magic: CIELAB Color Science

All cached themes use **CIELAB color space** for:
- Perceptually uniform lightness adjustments
- Better color harmony
- More accurate contrast calculations
- Professional-grade color conversions

**Runtime** prefers pre-computed schemes and only falls back to live conversion if the cache is missing or stale.

## Workflow

### Using Themes at Runtime (QuickShell)
```javascript
.import "SchemeCache.js" as SchemeCache

const cached = SchemeCache.getScheme("catppuccin");
console.log(cached?.palette?.mSurface);
```

### Developing Color Algorithm

When you want to improve the color conversion:

1. **Analyze color relationships:**
   ```bash
   node color_analysis_report.js
   ```
   Shows how different themes handle color relationships

2. **Modify the algorithm:**
   - Edit `ThemePipeline.js` to improve runtime conversion
   - Uses fast HSL operations for instant response

3. **Regenerate cache:**
   ```bash
   node generate-scheme-cache.js --scope builtins
   node update-scheme-cache-embedded.js
   node check-cache-consistency.js
   ```
   First command generates JSON, second embeds it in the QML file
   and the third verifies version/key consistency.

4. **Test in QuickShell:**
   - The updated CIELAB-optimized colors are immediately available
   - No runtime performance impact - just better colors!

## Adding New Themes

Just add your theme to `~/.config/omarchy/themes/my-theme/` with a `colors.toml` file!

The script can automatically:
- Scan built-in themes only (default release mode):
  `node generate-scheme-cache.js --scope builtins`
- Scan built-in + user themes:
  `node generate-scheme-cache.js --scope all`
- Parses `colors.toml` for colors (simple TOML format: `key = "#hexvalue"`)
- Converts to CIELAB-optimized noctalia format

**Required colors.toml keys:**
- `background` - Main background color
- `foreground` - Main foreground color

**Optional keys (fallbacks provided):**
- `accent` or `color4` (blue) - Primary accent color
- `color1` (red), `color2` (green), `color3` (yellow), etc. - Terminal colors 0-15

Then regenerate:
```bash
node generate-scheme-cache.js --scope all
node update-scheme-cache-embedded.js
node check-cache-consistency.js
```

**Note: New omarchy versions include default themes bundled with omarchy, no need to install them separately!**

## Files

- **ColorAnalysis.js** - Node.js only, CIELAB color space conversions
- **SchemeCache.js** - QuickShell runtime, pre-computed Noctalia palettes
- **ThemePipeline.js** - Runtime conversion pipeline
- **ColorsConvert.js** - Runtime HSL utilities
- **generate-scheme-cache.js** - CLI tool to generate scheme cache
- **update-scheme-cache-embedded.js** - CLI tool to embed cache + version
- **check-cache-consistency.js** - Validates embedded cache keys/version against source files
- **scheme-cache.json** - Generated cache (auto-updated, don't edit)
- **color_analysis_report.js** - CLI tool for analyzing themes

## Why This Architecture?

✅ **Performance**: Color switching is instant (just array lookup)  
✅ **Quality**: Full CIELAB color science for professional results  
✅ **Development**: Iterate on algorithm without affecting runtime  
✅ **Best of Both**: Advanced science offline, instant results online  

You get **perceptually accurate, beautiful colors** with **zero runtime cost**!
