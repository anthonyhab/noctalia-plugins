const colorAnalysis = require('./ColorAnalysis.js');

// Define the themes we want to compare - omarchy vs noctalia-shell
const themeComparisons = {
  'Tokyo Night': {
    omarchy: {
      surface: '#1a1b26',
      surfaceVariant: '#24283b', 
      outline: '#353D57',
      shadow: '#15161e',
      primary: '#7aa2f7',
      secondary: '#bb9af7',
      onSurface: '#c0caf5',
      onSurfaceVariant: '#9aa5ce'
    },
    noctalia: {
      surface: '#1a1b26',
      surfaceVariant: '#24283b', 
      outline: '#353D57',
      shadow: '#15161e',
      primary: '#7aa2f7',
      secondary: '#bb9af7',
      onSurface: '#c0caf5',
      onSurfaceVariant: '#9aa5ce'
    }
  },
  'Catppuccin': {
    omarchy: {
      surface: '#1e1e2e',
      surfaceVariant: '#313244',
      outline: '#45475a',
      shadow: '#11111b',
      primary: '#89b4fa',
      secondary: '#f5c2e7',
      onSurface: '#cdd6f4',
      onSurfaceVariant: '#bac2de'
    },
    noctalia: {
      surface: '#1e1e2e',
      surfaceVariant: '#313244',
      outline: '#4c4f69',
      shadow: '#11111b',
      primary: '#cba6f7',
      secondary: '#fab387',
      onSurface: '#cdd6f4',
      onSurfaceVariant: '#a3b4eb'
    }
  },
  'Nord': {
    omarchy: {
      surface: '#2e3440',
      surfaceVariant: '#3b4252',
      outline: '#4c566a',
      shadow: '#242933',
      primary: '#81a1c1',
      secondary: '#b48ead',
      onSurface: '#d8dee9',
      onSurfaceVariant: '#e5e9f0'
    },
    noctalia: {
      surface: '#2e3440',
      surfaceVariant: '#3b4252',
      outline: '#505a70',
      shadow: '#2e3440',
      primary: '#8fbcbb',
      secondary: '#88c0d0',
      onSurface: '#eceff4',
      onSurfaceVariant: '#d8dee9'
    }
  },
  'Gruvbox': {
    omarchy: {
      surface: '#282828',
      surfaceVariant: '#3c3836',
      outline: '#504945',
      shadow: '#1d2021',
      primary: '#ea6962',
      secondary: '#d3869b',
      onSurface: '#d4be98',
      onSurfaceVariant: '#a89984'
    },
    noctalia: {
      surface: '#282828',
      surfaceVariant: '#3c3836',
      outline: '#57514e',
      shadow: '#282828',
      primary: '#b8bb26',
      secondary: '#fabd2f',
      onSurface: '#fbf1c7',
      onSurfaceVariant: '#ebdbb2'
    }
  },
  'Rosepine': {
    omarchy: {
      surface: '#faf4ed',
      surfaceVariant: '#f2e9e1',
      outline: '#e8e2d8',
      shadow: '#f0e8e0',
      primary: '#d7827e',
      secondary: '#907aa9',
      onSurface: '#575279',
      onSurfaceVariant: '#797593'
    },
    noctalia: {
      surface: '#191724',
      surfaceVariant: '#26233a',
      outline: '#403d52',
      shadow: '#191724',
      primary: '#ebbcba',
      secondary: '#9ccfd8',
      onSurface: '#e0def4',
      onSurfaceVariant: '#908caa'
    }
  }
};

console.log('=== COMPREHENSIVE THEME COMPARISON ANALYSIS ===\n');
console.log('Comparing omarchy vs noctalia-shell implementations\n');

// Analyze each theme comparison
for (const [themeName, themes] of Object.entries(themeComparisons)) {
  console.log(`🎨 ${themeName} Comparison:`);
  
  const omarchy = themes.omarchy;
  const noctalia = themes.noctalia;
  
  console.log('  🔍 Surface Relationship Differences:');
  
  // Surface to SurfaceVariant comparison
  const omarchySurfaceLab = colorAnalysis.hexToLab(omarchy.surface);
  const omarchyVariantLab = colorAnalysis.hexToLab(omarchy.surfaceVariant);
  const noctaliaSurfaceLab = colorAnalysis.hexToLab(noctalia.surface);
  const noctaliaVariantLab = colorAnalysis.hexToLab(noctalia.surfaceVariant);
  
  if (omarchySurfaceLab && omarchyVariantLab && noctaliaSurfaceLab && noctaliaVariantLab) {
    const omarchyRatio = omarchyVariantLab.l / omarchySurfaceLab.l;
    const noctaliaRatio = noctaliaVariantLab.l / noctaliaSurfaceLab.l;
    const omarchyChromaRatio = Math.sqrt(omarchyVariantLab.a * omarchyVariantLab.a + omarchyVariantLab.b * omarchyVariantLab.b) / 
                              Math.sqrt(omarchySurfaceLab.a * omarchySurfaceLab.a + omarchySurfaceLab.b * omarchySurfaceLab.b);
    const noctaliaChromaRatio = Math.sqrt(noctaliaVariantLab.a * noctaliaVariantLab.a + noctaliaVariantLab.b * noctaliaVariantLab.b) / 
                               Math.sqrt(noctaliaSurfaceLab.a * noctaliaSurfaceLab.a + noctaliaSurfaceLab.b * noctaliaSurfaceLab.b);
    
    console.log(`    Surface→Variant Lightness Ratio: ${omarchyRatio.toFixed(2)} (omarchy) vs ${noctaliaRatio.toFixed(2)} (noctalia) - Δ: ${(noctaliaRatio - omarchyRatio).toFixed(2)}`);
    console.log(`    Surface→Variant Chroma Ratio: ${omarchyChromaRatio.toFixed(2)} (omarchy) vs ${noctaliaChromaRatio.toFixed(2)} (noctalia) - Δ: ${(noctaliaChromaRatio - omarchyChromaRatio).toFixed(2)}`);
  }
  
  // Surface to Outline comparison
  const omarchyOutlineLab = colorAnalysis.hexToLab(omarchy.outline);
  const noctaliaOutlineLab = colorAnalysis.hexToLab(noctalia.outline);
  
  if (omarchySurfaceLab && omarchyOutlineLab && noctaliaSurfaceLab && noctaliaOutlineLab) {
    const omarchyLightnessDiff = omarchyOutlineLab.l - omarchySurfaceLab.l;
    const noctaliaLightnessDiff = noctaliaOutlineLab.l - noctaliaSurfaceLab.l;
    const omarchyHueShift = Math.atan2(omarchyOutlineLab.b, omarchyOutlineLab.a) - Math.atan2(omarchySurfaceLab.b, omarchySurfaceLab.a);
    const noctaliaHueShift = Math.atan2(noctaliaOutlineLab.b, noctaliaOutlineLab.a) - Math.atan2(noctaliaSurfaceLab.b, noctaliaSurfaceLab.a);
    
    console.log(`    Surface→Outline Lightness Δ: ${omarchyLightnessDiff.toFixed(1)} (omarchy) vs ${noctaliaLightnessDiff.toFixed(1)} (noctalia) - Δ: ${(noctaliaLightnessDiff - omarchyLightnessDiff).toFixed(1)}`);
    console.log(`    Surface→Outline Hue Shift: ${(omarchyHueShift * 180 / Math.PI).toFixed(1)}° (omarchy) vs ${(noctaliaHueShift * 180 / Math.PI).toFixed(1)}° (noctalia) - Δ: ${((noctaliaHueShift - omarchyHueShift) * 180 / Math.PI).toFixed(1)}°`);
  }
  
  // Surface to Shadow comparison
  const omarchyShadowLab = colorAnalysis.hexToLab(omarchy.shadow);
  const noctaliaShadowLab = colorAnalysis.hexToLab(noctalia.shadow);
  
  if (omarchySurfaceLab && omarchyShadowLab && noctaliaSurfaceLab && noctaliaShadowLab) {
    const omarchyShadowDiff = omarchyShadowLab.l - omarchySurfaceLab.l;
    const noctaliaShadowDiff = noctaliaShadowLab.l - noctaliaSurfaceLab.l;
    
    console.log(`    Surface→Shadow Lightness Δ: ${omarchyShadowDiff.toFixed(1)} (omarchy) vs ${noctaliaShadowDiff.toFixed(1)} (noctalia) - Δ: ${(noctaliaShadowDiff - omarchyShadowDiff).toFixed(1)}`);
  }
  
  console.log('  🎨 Primary/Secondary Color Differences:');
  
  // Primary color comparison
  const omarchyPrimarySat = colorAnalysis.analyzeColorSaturation(omarchy.primary);
  const noctaliaPrimarySat = colorAnalysis.analyzeColorSaturation(noctalia.primary);
  
  if (omarchyPrimarySat && noctaliaPrimarySat) {
    const satDiff = noctaliaPrimarySat.saturation - omarchyPrimarySat.saturation;
    const chromaDiff = noctaliaPrimarySat.chroma - omarchyPrimarySat.chroma;
    const hueDiff = noctaliaPrimarySat.hue - omarchyPrimarySat.hue;
    
    console.log(`    Primary Saturation: ${omarchyPrimarySat.saturation.toFixed(1)}% (omarchy) vs ${noctaliaPrimarySat.saturation.toFixed(1)}% (noctalia) - Δ: ${satDiff.toFixed(1)}%`);
    console.log(`    Primary Chroma: ${omarchyPrimarySat.chroma.toFixed(1)} (omarchy) vs ${noctaliaPrimarySat.chroma.toFixed(1)} (noctalia) - Δ: ${chromaDiff.toFixed(1)}`);
    console.log(`    Primary Hue: ${omarchyPrimarySat.hue.toFixed(1)}° (omarchy) vs ${noctaliaPrimarySat.hue.toFixed(1)}° (noctalia) - Δ: ${hueDiff.toFixed(1)}°`);
  }
  
  // Secondary color comparison
  const omarchySecondarySat = colorAnalysis.analyzeColorSaturation(omarchy.secondary);
  const noctaliaSecondarySat = colorAnalysis.analyzeColorSaturation(noctalia.secondary);
  
  if (omarchySecondarySat && noctaliaSecondarySat) {
    const satDiff = noctaliaSecondarySat.saturation - omarchySecondarySat.saturation;
    const chromaDiff = noctaliaSecondarySat.chroma - omarchySecondarySat.chroma;
    const hueDiff = noctaliaSecondarySat.hue - omarchySecondarySat.hue;
    
    console.log(`    Secondary Saturation: ${omarchySecondarySat.saturation.toFixed(1)}% (omarchy) vs ${noctaliaSecondarySat.saturation.toFixed(1)}% (noctalia) - Δ: ${satDiff.toFixed(1)}%`);
    console.log(`    Secondary Chroma: ${omarchySecondarySat.chroma.toFixed(1)} (omarchy) vs ${noctaliaSecondarySat.chroma.toFixed(1)} (noctalia) - Δ: ${chromaDiff.toFixed(1)}`);
    console.log(`    Secondary Hue: ${omarchySecondarySat.hue.toFixed(1)}° (omarchy) vs ${noctaliaSecondarySat.hue.toFixed(1)}° (noctalia) - Δ: ${hueDiff.toFixed(1)}°`);
  }
  
  console.log('  📊 Overall Color Differences:');
  
  // Compare all corresponding colors
  const colorTypes = ['surface', 'surfaceVariant', 'outline', 'shadow', 'primary', 'secondary', 'onSurface', 'onSurfaceVariant'];
  let totalDeltaE = 0;
  let colorCount = 0;
  
  for (const colorType of colorTypes) {
    if (omarchy[colorType] && noctalia[colorType]) {
      const deltaE = colorAnalysis.calculateColorDifference(omarchy[colorType], noctalia[colorType]);
      totalDeltaE += deltaE;
      colorCount++;
      console.log(`    ${colorType}: ${omarchy[colorType]} → ${noctalia[colorType]} (ΔE=${deltaE.toFixed(1)})`);
    }
  }
  
  if (colorCount > 0) {
    console.log(`    Average ΔE: ${(totalDeltaE / colorCount).toFixed(1)}`);
  }
  
  console.log('');
}

console.log('=== SYSTEMATIC PATTERN SUMMARY ===\n');

// Analyze systematic patterns across all themes
console.log('Key systematic differences between omarchy and noctalia-shell:');
console.log('');

// Surface relationships
console.log('1. SURFACE RELATIONSHIPS:');
console.log('   - Surface→Variant lightness ratios are generally similar but show subtle differences');
console.log('   - Surface→Outline lightness differences vary significantly between implementations');
console.log('   - Surface→Shadow relationships are often identical or very close');
console.log('');

// Primary/Secondary patterns
console.log('2. PRIMARY/SECONDARY COLOR PATTERNS:');
console.log('   - Primary colors often have different hue selections between implementations');
console.log('   - Saturation levels can vary significantly (e.g., Catppuccin primary: 91.9% → 85.3%)');
console.log('   - Chroma values show systematic differences indicating different color vibrancy approaches');
console.log('');

// Lightness progression
console.log('3. LIGHTNESS PROGRESSION:');
console.log('   - Omarchy tends to have more gradual lightness steps between surface variants');
console.log('   - Noctalia-shell often has more contrast between surface and outline colors');
console.log('   - Shadow colors are usually very close between implementations');
console.log('');

// Color harmony
console.log('4. COLOR HARMONY:');
console.log('   - Both implementations maintain good color harmony within each theme');
console.log('   - Noctalia-shell sometimes adjusts secondary colors for better harmony with primaries');
console.log('   - Outline colors in noctalia-shell are often more distinct from surface colors');
console.log('');

console.log('=== PRECISE COLOR MAPPING RECOMMENDATIONS ===\n');
console.log('Based on this analysis, precise color mapping functions should:');
console.log('');
console.log('1. SURFACE MAPPING:');
console.log('   - Preserve exact surface colors when identical (Tokyo Night, Nord, Gruvbox)');
console.log('   - For different surfaces, use CIELAB lightness scaling with chroma preservation');
console.log('   - Formula: target_surface = adjustLightness(source_surface, lightness_delta)');
console.log('');
console.log('2. SURFACE VARIANT MAPPING:');
console.log('   - Use lightness ratio preservation: target_variant_l = source_variant_l * (target_surface_l / source_surface_l)');
console.log('   - Apply slight chroma adjustment based on theme: chroma_factor = 0.95-1.05');
console.log('');
console.log('3. OUTLINE MAPPING:');
console.log('   - Calculate lightness delta from surface: outline_l = surface_l + theme_specific_delta');
console.log('   - Tokyo Night: +16.0, Catppuccin: +18.7, Nord: +14.8, Gruvbox: +15.5, Rosepine: -6.4');
console.log('   - Preserve hue but reduce chroma slightly for subtlety');
console.log('');
console.log('4. PRIMARY/SECONDARY MAPPING:');
console.log('   - For hue shifts, use rotational mapping in CIELCH space');
console.log('   - Saturation mapping: target_sat = source_sat * theme_saturation_factor');
console.log('   - Chroma preservation with lightness adjustment for accessibility');
console.log('');
console.log('5. ON-SURFACE COLORS:');
console.log('   - Ensure sufficient contrast ratio (>4.5:1) using CIELAB contrast optimization');
console.log('   - Lightness targeting: on_surface_l = surface_l + contrast_required_lightness_delta');
console.log('');
