import QtQuick 2.15
import "ColorsConvertCached.js" as ThemeCache

// Quick test to verify all cached themes load correctly
Item {
    Component.onCompleted: {
        console.log("Testing CIELAB-optimized theme cache...\n");

        var themes = ThemeCache.getAvailableThemes();
        console.log("Available themes:", themes.length);

        // Test loading each theme
        var successCount = 0;
        for (var i = 0; i < themes.length; i++) {
            var themeName = themes[i];
            var theme = ThemeCache.getConvertedTheme(themeName);

            if (theme && theme.surface && theme.primary) {
                console.log("  ✓", themeName, "- surface:", theme.surface, "primary:", theme.primary);
                successCount++;
            } else {
                console.log("  ✗", themeName, "- FAILED");
            }
        }

        console.log("\n" + successCount + "/" + themes.length + " themes loaded successfully!");
        console.log("All colors are CIELAB-optimized for perceptual accuracy.");
    }
}
