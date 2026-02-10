import QtQuick
import Quickshell
import Quickshell.Io
import "SchemeCache.js" as SchemeCache
import qs.Commons
import qs.Services.Theming

// Instant color scheme application from cache
Item {
    id: root

    property string schemeDisplayName: "Omarchy"
    property var pluginApi: null
    readonly property string schemeKey: {
        const name = schemeDisplayName || "Omarchy";
        return name.replace(/[\\/]/g, "-").trim();
    }
    readonly property string schemeFolder: {
        const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
        const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
        return normalizedBase + "/" + schemeKey;
    }
    readonly property string schemeOutputPath: schemeFolder + "/" + schemeKey + ".json"
    readonly property string schemeOutputDir: schemeFolder
    // Preload cache at startup
    property var cachedSchemes: ({
    })
    property string pendingSchemeContent: ""

    function preloadCache() {
        // Load all schemes from SchemeCache into memory
        const schemes = SchemeCache.getAllSchemes ? SchemeCache.getAllSchemes() : null;
        if (schemes) {
            cachedSchemes = schemes;
            Logger.i("InstantSchemeApplier", "Preloaded", Object.keys(schemes).length, "schemes");
        }
    }

    function applyScheme(themeName) {
        const startTime = Date.now();
        if (!themeName)
            return {
            "success": false,
            "error": "No theme name",
            "duration": 0
        };

        // Normalize theme name to cache key
        const cacheKey = normalizeThemeKey(themeName);
        // Try memory cache first
        var cached = cachedSchemes[cacheKey];
        // Fallback to SchemeCache
        if (!cached && SchemeCache.getScheme)
            cached = SchemeCache.getScheme(cacheKey);

        if (!cached || !cached.palette || !cached.mode) {
            Logger.w("InstantSchemeApplier", "Cache miss for theme:", themeName, "key:", cacheKey);
            return {
                "success": false,
                "error": "Cache miss",
                "duration": Date.now() - startTime,
                "cacheHit": false
            };
        }
        // Apply the scheme
        try {
            applyCachedScheme(cached, themeName);
            const duration = Date.now() - startTime;
            Logger.i("InstantSchemeApplier", "Applied scheme in", duration, "ms:", themeName);
            return {
                "success": true,
                "duration": duration,
                "cacheHit": true
            };
        } catch (e) {
            Logger.e("InstantSchemeApplier", "Failed to apply scheme:", String(e));
            return {
                "success": false,
                "error": String(e),
                "duration": Date.now() - startTime,
                "cacheHit": true
            };
        }
    }

    function applyCachedScheme(cached, themeName) {
        const isDarkMode = cached.mode === "dark";
        // Update Noctalia dark mode if needed
        // Only when scheduling is disabled - respect user's scheduling preferences
        const schedulingMode = Settings.data.colorSchemes.schedulingMode || "off";
        if (schedulingMode === "off" && Settings.data.colorSchemes.darkMode !== isDarkMode) {
            Logger.i("InstantSchemeApplier", "Updating dark mode:", isDarkMode);
            const wasWallpaper = !!Settings.data.colorSchemes.useWallpaperColors;
            Settings.data.colorSchemes.useWallpaperColors = true;
            Settings.data.colorSchemes.darkMode = isDarkMode;
            Settings.data.colorSchemes.useWallpaperColors = wasWallpaper;
        }
        // Write scheme file
        const scheme = cached.palette;
        if (!scheme || !schemeOutputPath)
            throw new Error("Invalid scheme data or output path");

        const wrappedScheme = {
            "dark": scheme,
            "light": scheme
        };
        const jsonContent = JSON.stringify(wrappedScheme, null, 2);
        // Use FileView for async write
        writeSchemeFile(jsonContent, themeName);
    }

    function writeSchemeFile(jsonContent, themeName) {
        // Create directory if needed and write file
        const writeCmd = "mkdir -p \"" + schemeOutputDir + "\" && cat > \"" + schemeOutputPath + "\" << 'OMARCHY_SCHEME_EOF'\n" + jsonContent + "\nOMARCHY_SCHEME_EOF\n";
        schemeWriteProcess.command = ["sh", "-c", writeCmd];
        schemeWriteProcess.running = true;
    }

    function normalizeThemeKey(name) {
        if (!name || typeof name !== "string")
            return "";

        return name.replace(/<[^>]+>/g, "").trim().toLowerCase().replace(/\s+/g, "-");
    }

    // Update cache when themes are scanned
    function updateCache(themes) {
        if (!themes || themes.length === 0)
            return ;

        themes.forEach(function(theme) {
            const key = normalizeThemeKey(theme.name);
            if (key && !cachedSchemes[key]) {
                // Try to load from SchemeCache
                const cached = SchemeCache.getScheme ? SchemeCache.getScheme(key) : null;
                if (cached)
                    cachedSchemes[key] = cached;

            }
        });
        Logger.i("InstantSchemeApplier", "Cache updated, total schemes:", Object.keys(cachedSchemes).length);
    }

    // Add scheme to cache after live generation
    function addToCache(themeDirName, scheme) {
        if (!themeDirName || !scheme)
            return ;

        const key = normalizeThemeKey(themeDirName);
        if (!key)
            return ;

        // Add to memory cache
        cachedSchemes[key] = scheme;
        Logger.i("InstantSchemeApplier", "Added scheme to memory cache:", themeDirName);
        // Return the scheme for chaining
        return scheme;
    }

    Component.onCompleted: {
        preloadCache();
    }

    Process {
        id: schemeWriteProcess

        running: false
        onExited: function(code) {
            if (code === 0) {
                Logger.i("InstantSchemeApplier", "Scheme file written:", schemeOutputPath);
                ColorSchemeService.applyScheme(schemeOutputPath);
                // Update settings to use this scheme
                // Store scheme identity (key) not full path for better Noctalia integration
                if (Settings.data.colorSchemes.useWallpaperColors) {
                    Settings.data.colorSchemes.predefinedScheme = schemeKey;
                    Settings.data.colorSchemes.useWallpaperColors = false;
                }
            } else {
                Logger.e("InstantSchemeApplier", "Failed to write scheme file, exit code:", code);
            }
        }
    }

}
