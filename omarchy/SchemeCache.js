.pragma library

// ============================================
// Cached Scheme Output for QuickShell
// ============================================
// To regenerate cache:
//   node generate-scheme-cache.js
//   node update-scheme-cache-embedded.js

const SCHEME_CACHE_VERSION = "a0b9d7d54c47";
const SCHEME_CACHE = {};

function getScheme(themeName) {
  return SCHEME_CACHE[themeName] || null;
}

function getVersion() {
  return SCHEME_CACHE_VERSION;
}

function isCompatible(pipelineVersion) {
  return SCHEME_CACHE_VERSION === pipelineVersion;
}

function getAvailableThemes() {
  return Object.keys(SCHEME_CACHE);
}
