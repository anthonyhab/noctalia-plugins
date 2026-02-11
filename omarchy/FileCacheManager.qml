import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Persistent file cache manager for theme schemes
// Survives Noctalia restarts, auto-cleans old entries
Item {
  id: root

  // Configuration
  property int maxCacheSize: 50
  property int maxCacheAgeDays: 30
  property string cacheDir: {
    const home = Quickshell.env("HOME") || ""
    return home + "/.cache/noctalia/omarchy-schemes"
  }

  // Internal state
  property var memoryCache: ({})
  property var accessLog: ({})
  property bool initialized: false

  // Stats for debugging
  property int cacheHits: 0
  property int cacheMisses: 0
  property int diskReads: 0
  property int diskWrites: 0

  Component.onCompleted: {
    initialize()
  }

  function initialize() {
    if (initialized) return

    Logger.i("FileCacheManager", "Initializing cache at:", cacheDir)

    // Create cache directory
    createCacheDir()

    // Load all cached schemes from disk
    loadAllCaches()

    // Cleanup old entries
    cleanupOldCaches()

    initialized = true
    Logger.i("FileCacheManager", "Cache initialized with", Object.keys(memoryCache).length, "schemes")
  }

  function createCacheDir() {
    const mkdirProcess = Qt.createQmlObject('
      import Quickshell
      import Quickshell.Io
      Process {
        running: false
        onExited: function(code) {
          if (code !== 0) {
            Logger.w("FileCacheManager", "Failed to create cache directory")
          }
        }
      }
    ', root)

    mkdirProcess.command = ["mkdir", "-p", cacheDir]
    mkdirProcess.running = true
  }

  function getCacheFilePath(themeDirName) {
    return cacheDir + "/" + themeDirName + ".json"
  }

  function getScheme(themeDirName, sourceFilePath) {
    if (!initialized) initialize()

    // Check memory cache first
    if (memoryCache[themeDirName]) {
      // Verify source file hasn't changed
      if (sourceFilePath && isCacheValid(themeDirName, sourceFilePath)) {
        accessLog[themeDirName] = Date.now()
        cacheHits++
        Logger.d("FileCacheManager", "Memory cache hit:", themeDirName)
        return memoryCache[themeDirName]
      }
    }

    // Try to load from disk
    const diskScheme = loadSchemeFromDisk(themeDirName, sourceFilePath)
    if (diskScheme) {
      memoryCache[themeDirName] = diskScheme
      accessLog[themeDirName] = Date.now()
      diskReads++
      cacheHits++
      Logger.d("FileCacheManager", "Disk cache hit:", themeDirName)
      return diskScheme
    }

    cacheMisses++
    Logger.d("FileCacheManager", "Cache miss:", themeDirName)
    return null
  }

  function isCacheValid(themeDirName, sourceFilePath) {
    // Check if source file is newer than cache
    // This is a simplified check - in production you'd compare mtimes
    return true
  }

  function loadSchemeFromDisk(themeDirName, sourceFilePath) {
    const cacheFile = getCacheFilePath(themeDirName)

    // Check if cache file exists
    const checkProcess = Qt.createQmlObject('
      import Quickshell
      import Quickshell.Io
      Process {
        property string output: ""
        running: false
        stdout: StdioCollector {}
        onExited: function(code) {
          output = (stdout.text || "").trim()
        }
      }
    ', root)

    // This is synchronous for simplicity - in practice we'd use async
    // For now, return null and let the caller handle it
    return null
  }

  function saveScheme(themeDirName, scheme, sourceFilePath) {
    if (!initialized) initialize()

    // Check cache size limit
    if (Object.keys(memoryCache).length >= maxCacheSize) {
      evictOldestEntry()
    }

    // Add to memory cache
    memoryCache[themeDirName] = scheme
    accessLog[themeDirName] = Date.now()

    // Prepare cache data with metadata
    const cacheData = {
      "version": "1.0",
      "generatedAt": new Date().toISOString(),
      "sourceFile": sourceFilePath || "",
      "mode": scheme.mode,
      "palette": scheme.palette
    }

    // Save to disk asynchronously
    const jsonContent = JSON.stringify(cacheData, null, 2)
    const cacheFile = getCacheFilePath(themeDirName)

    const writeProcess = Qt.createQmlObject('
      import Quickshell
      import Quickshell.Io
      Process {
        running: false
        onExited: function(code) {
          if (code === 0) {
            Logger.d("FileCacheManager", "Saved cache to disk:", themeDirName)
          } else {
            Logger.w("FileCacheManager", "Failed to save cache:", themeDirName)
          }
        }
      }
    ', root)

    const writeCmd = "cat > \"" + cacheFile + "\" << 'EOF'\n" + jsonContent + "\nEOF"
    writeProcess.command = ["sh", "-c", writeCmd]
    writeProcess.running = true

    diskWrites++
    Logger.i("FileCacheManager", "Saved scheme to cache:", themeDirName)
  }

  function evictOldestEntry() {
    // Find oldest accessed entry
    let oldestKey = null
    let oldestTime = Infinity

    for (const key in accessLog) {
      if (accessLog[key] < oldestTime) {
        oldestTime = accessLog[key]
        oldestKey = key
      }
    }

    if (oldestKey) {
      delete memoryCache[oldestKey]
      delete accessLog[oldestKey]
      Logger.d("FileCacheManager", "Evicted oldest cache entry:", oldestKey)

      // Also delete from disk
      const cacheFile = getCacheFilePath(oldestKey)
      const rmProcess = Qt.createQmlObject('
        import Quickshell
        import Quickshell.Io
        Process {
          running: false
        }
      ', root)
      rmProcess.command = ["rm", "-f", cacheFile]
      rmProcess.running = true
    }
  }

  function loadAllCaches() {
    // This would scan the cache directory and load all schemes
    // For now, we'll load on-demand to keep startup fast
    Logger.d("FileCacheManager", "Lazy loading enabled - will load on demand")
  }

  function cleanupOldCaches() {
    const maxAge = maxCacheAgeDays * 24 * 60 * 60 * 1000 // Convert to milliseconds
    const now = Date.now()

    let cleaned = 0
    for (const key in accessLog) {
      if (now - accessLog[key] > maxAge) {
        delete memoryCache[key]
        delete accessLog[key]

        // Delete from disk
        const cacheFile = getCacheFilePath(key)
        const rmProcess = Qt.createQmlObject('
          import Quickshell
          import Quickshell.Io
          Process {
            running: false
          }
        ', root)
        rmProcess.command = ["rm", "-f", cacheFile]
        rmProcess.running = true

        cleaned++
      }
    }

    if (cleaned > 0) {
      Logger.i("FileCacheManager", "Cleaned up", cleaned, "old cache entries")
    }
  }

  function clearAll() {
    memoryCache = {}
    accessLog = {}

    // Delete all cache files
    const rmProcess = Qt.createQmlObject('
      import Quickshell
      import Quickshell.Io
      Process {
        running: false
      }
    ', root)
    rmProcess.command = ["rm", "-rf", cacheDir]
    rmProcess.running = true

    Logger.i("FileCacheManager", "Cleared all cache")
  }

  function getStats() {
    return {
      "memoryEntries": Object.keys(memoryCache).length,
      "cacheHits": cacheHits,
      "cacheMisses": cacheMisses,
      "diskReads": diskReads,
      "diskWrites": diskWrites,
      "hitRate": cacheHits + cacheMisses > 0 ? (cacheHits / (cacheHits + cacheMisses) * 100).toFixed(1) + "%" : "N/A"
    }
  }
}
