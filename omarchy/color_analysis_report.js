const colorAnalysis = require('./ColorAnalysis.js');
const colorConvert = require('./ColorsConvert.js');

// Define the themes we want to analyze
const themes = {
  'Tokyo Night': {
    surface: '#1a1b26',
    surfaceVariant: '#24283b', 
    outline: '#353D57',
    shadow: '#15161e',
    primary: '#7aa2f7',
    secondary: '#bb9af7',
    onSurface: '#c0caf5',
    onSurfaceVariant: '#9aa5ce'
  },
  'Catppuccin Mocha': {
    surface: '#1e1e2e',
    surfaceVariant: '#313244',
    outline: '#45475a',
    shadow: '#11111b',
    primary: '#89b4fa',
    secondary: '#f5c2e7',
    onSurface: '#cdd6f4',
    onSurfaceVariant: '#bac2de'
  },
  'Gruvbox': {
    surface: '#282828',
    surfaceVariant: '#3c3836',
    outline: '#504945',
    shadow: '#1d2021',
    primary: '#ea6962',
    secondary: '#d3869b',
    onSurface: '#d4be98',
    onSurfaceVariant: '#a89984'
  },
  'Nord': {
    surface: '#2e3440',
    surfaceVariant: '#3b4252',
    outline: '#4c566a',
    shadow: '#242933',
    primary: '#81a1c1',
    secondary: '#b48ead',
    onSurface: '#d8dee9',
    onSurfaceVariant: '#e5e9f0'
  },
  'Rosepine': {
    surface: '#faf4ed',
    surfaceVariant: '#f2e9e1',
    outline: '#e8e2d8',
    shadow: '#f0e8e0',
    primary: '#d7827e',
    secondary: '#907aa9',
    onSurface: '#575279',
    onSurfaceVariant: '#797593'
  }
};

console.log('=== COMPREHENSIVE COLOR RELATIONSHIP ANALYSIS ===\n');

// Analyze each theme
for (const [themeName, colors] of Object.entries(themes)) {
  console.log(`${themeName}:`);
  
  // Convert all colors to CIELAB for analysis
  const surfaceLab = colorAnalysis.hexToLab(colors.surface);
  const surfaceVariantLab = colorAnalysis.hexToLab(colors.surfaceVariant);
  const outlineLab = colorAnalysis.hexToLab(colors.outline);
  const shadowLab = colorAnalysis.hexToLab(colors.shadow);
  const primaryLab = colorAnalysis.hexToLab(colors.primary);
  const secondaryLab = colorAnalysis.hexToLab(colors.secondary);
  
  console.log('  Surface Relationships:');
  
  // Surface to SurfaceVariant
  if (surfaceLab && surfaceVariantLab) {
    const surfaceToVariantDiff = colorAnalysis.calculateColorDifference(colors.surface, colors.surfaceVariant);
    const lightnessRatio = surfaceVariantLab.l / surfaceLab.l;
    const chromaRatio = Math.sqrt(surfaceVariantLab.a * surfaceVariantLab.a + surfaceVariantLab.b * surfaceVariantLab.b) / 
                       Math.sqrt(surfaceLab.a * surfaceLab.a + surfaceLab.b * surfaceLab.b);
    console.log(`    Surface -> SurfaceVariant: DeltaE=${surfaceToVariantDiff.toFixed(1)}, Lightness Ratio: ${lightnessRatio.toFixed(2)}, Chroma Ratio: ${chromaRatio.toFixed(2)}`);
  }
  
  // Surface to Outline
  if (surfaceLab && outlineLab) {
    const surfaceToOutlineDiff = colorAnalysis.calculateColorDifference(colors.surface, colors.outline);
    const lightnessDiff = outlineLab.l - surfaceLab.l;
    const hueShift = Math.atan2(outlineLab.b, outlineLab.a) - Math.atan2(surfaceLab.b, surfaceLab.a);
    console.log(`    Surface -> Outline: DeltaE=${surfaceToOutlineDiff.toFixed(1)}, Lightness Delta: ${lightnessDiff.toFixed(1)}, Hue Shift: ${(hueShift * 180 / Math.PI).toFixed(1)} degrees`);
  }
  
  // Surface to Shadow
  if (surfaceLab && shadowLab) {
    const surfaceToShadowDiff = colorAnalysis.calculateColorDifference(colors.surface, colors.shadow);
    const lightnessDiff = shadowLab.l - surfaceLab.l;
    console.log(`    Surface -> Shadow: DeltaE=${surfaceToShadowDiff.toFixed(1)}, Lightness Delta: ${lightnessDiff.toFixed(1)}`);
  }
  
  console.log('  Primary/Secondary Saturation Patterns:');
  
  // Primary/Secondary analysis
  if (primaryLab && secondaryLab) {
    const primarySat = colorAnalysis.analyzeColorSaturation(colors.primary);
    const secondarySat = colorAnalysis.analyzeColorSaturation(colors.secondary);
    const saturationRatio = secondarySat.saturation / primarySat.saturation;
    const chromaRatio = secondarySat.chroma / primarySat.chroma;
    console.log(`    Primary Sat: ${primarySat.saturation.toFixed(1)}%, Chroma: ${primarySat.chroma.toFixed(1)}`);
    console.log(`    Secondary Sat: ${secondarySat.saturation.toFixed(1)}%, Chroma: ${secondarySat.chroma.toFixed(1)}`);
    console.log(`    Saturation Ratio (Sec/Prim): ${saturationRatio.toFixed(2)}, Chroma Ratio: ${chromaRatio.toFixed(2)}`);
  }
  
  console.log('  Lightness Progression:');
  
  // Lightness progression analysis
  const colorNames = ['shadow', 'surface', 'surfaceVariant', 'outline', 'onSurfaceVariant', 'onSurface'];
  const lightnessValues = [];
  
  for (const name of colorNames) {
    if (colors[name]) {
      const lab = colorAnalysis.hexToLab(colors[name]);
      if (lab) {
        lightnessValues.push({ name, lightness: lab.l });
      }
    }
  }
  
  // Sort by lightness
  lightnessValues.sort((a, b) => a.lightness - b.lightness);
  
  let progressionString = '    ';
  for (let i = 0; i < lightnessValues.length; i++) {
    progressionString += `${lightnessValues[i].name}(${lightnessValues[i].lightness.toFixed(1)})`;
    if (i < lightnessValues.length - 1) {
      const diff = lightnessValues[i+1].lightness - lightnessValues[i].lightness;
      progressionString += ` ->(+${diff.toFixed(1)}) `;
    }
  }
  console.log(progressionString);
  
  console.log('');
}

console.log('=== SYSTEMATIC DIFFERENCES ANALYSIS ===\n');

// Compare systematic differences between themes
const referenceTheme = themes['Tokyo Night'];

for (const [themeName, colors] of Object.entries(themes)) {
  if (themeName === 'Tokyo Night') continue;
  
  console.log(`${themeName} vs Tokyo Night:`);
  
  // Surface to SurfaceVariant lightness ratio comparison
  const refSurfaceLab = colorAnalysis.hexToLab(referenceTheme.surface);
  const refVariantLab = colorAnalysis.hexToLab(referenceTheme.surfaceVariant);
  const themeSurfaceLab = colorAnalysis.hexToLab(colors.surface);
  const themeVariantLab = colorAnalysis.hexToLab(colors.surfaceVariant);
  
  if (refSurfaceLab && refVariantLab && themeSurfaceLab && themeVariantLab) {
    const refRatio = refVariantLab.l / refSurfaceLab.l;
    const themeRatio = themeVariantLab.l / themeSurfaceLab.l;
    const ratioDiff = themeRatio - refRatio;
    console.log(`  Surface->Variant Lightness Ratio: ${refRatio.toFixed(2)} -> ${themeRatio.toFixed(2)} (Delta: ${ratioDiff.toFixed(2)})`);
  }
  
  // Surface to Outline lightness difference comparison
  const refOutlineLab = colorAnalysis.hexToLab(referenceTheme.outline);
  const themeOutlineLab = colorAnalysis.hexToLab(colors.outline);
  
  if (refSurfaceLab && refOutlineLab && themeSurfaceLab && themeOutlineLab) {
    const refDiff = refOutlineLab.l - refSurfaceLab.l;
    const themeDiff = themeOutlineLab.l - themeSurfaceLab.l;
    const diffChange = themeDiff - refDiff;
    console.log(`  Surface->Outline Lightness Delta: ${refDiff.toFixed(1)} -> ${themeDiff.toFixed(1)} (Delta: ${diffChange.toFixed(1)})`);
  }
  
  // Primary saturation comparison
  const refPrimarySat = colorAnalysis.analyzeColorSaturation(referenceTheme.primary);
  const themePrimarySat = colorAnalysis.analyzeColorSaturation(colors.primary);
  
  if (refPrimarySat && themePrimarySat) {
    const satDiff = themePrimarySat.saturation - refPrimarySat.saturation;
    const chromaDiff = themePrimarySat.chroma - refPrimarySat.chroma;
    console.log(`  Primary Saturation: ${refPrimarySat.saturation.toFixed(1)}% -> ${themePrimarySat.saturation.toFixed(1)}% (Delta: ${satDiff.toFixed(1)}%)`);
    console.log(`  Primary Chroma: ${refPrimarySat.chroma.toFixed(1)} -> ${themePrimarySat.chroma.toFixed(1)} (Delta: ${chromaDiff.toFixed(1)})`);
  }
  
  console.log('');
}
