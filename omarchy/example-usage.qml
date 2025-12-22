import QtQuick 2.15
import "ColorsConvertCached.js" as ThemeCache

Item {
    // Example: Load CIELAB-optimized theme
    Component.onCompleted: {
        // Get the pre-computed, CIELAB-optimized theme
        var theme = ThemeCache.getConvertedTheme("catppuccin-mocha");

        if (theme) {
            console.log("Theme loaded! Surface color:", theme.surface);
            console.log("Primary color:", theme.primary);
            console.log("All colors are CIELAB-optimized for perceptual accuracy!");

            // Use the colors directly - they're already perfect!
            // No conversions, no calculations, just beautiful colors
        }

        // List available themes
        var availableThemes = ThemeCache.getAvailableThemes();
        console.log("Available themes:", availableThemes.join(", "));
    }

    Rectangle {
        // Example usage
        property var currentTheme: ThemeCache.getConvertedTheme("tokyo-night")

        anchors.fill: parent
        color: currentTheme ? currentTheme.surface : "#000000"

        Rectangle {
            width: 200
            height: 100
            anchors.centerIn: parent
            color: currentTheme ? currentTheme.primary : "#0000ff"

            Text {
                anchors.centerIn: parent
                text: "CIELAB-Optimized Colors!"
                color: currentTheme ? currentTheme.onPrimary : "#ffffff"
            }
        }
    }
}
