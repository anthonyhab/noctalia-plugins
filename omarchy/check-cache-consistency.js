#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

const schemeCacheJsPath = path.join(__dirname, "SchemeCache.js")
const schemeCacheJsonPath = path.join(__dirname, "scheme-cache.json")
const themePipelinePath = path.join(__dirname, "ThemePipeline.js")

function read(filePath) {
  return fs.readFileSync(filePath, "utf8")
}

function parseEmbeddedCache(content) {
  const versionMatch = content.match(/const SCHEME_CACHE_VERSION = "([^"]+)";/)
  if (!versionMatch) {
    throw new Error("SCHEME_CACHE_VERSION not found in SchemeCache.js")
  }

  const cacheMatch = content.match(/const SCHEME_CACHE = ([\s\S]*?);\n\nfunction getScheme/)
  if (!cacheMatch) {
    throw new Error("SCHEME_CACHE object not found in SchemeCache.js")
  }

  const embeddedCache = JSON.parse(cacheMatch[1])
  return {
    "version": versionMatch[1],
    "cache": embeddedCache
  }
}

function parsePipelineVersion(content) {
  const match = content.match(/const PIPELINE_VERSION = "([^"]+)";/)
  if (!match) {
    throw new Error("PIPELINE_VERSION not found in ThemePipeline.js")
  }
  return match[1]
}

function toKeySet(obj) {
  return new Set(Object.keys(obj || {}))
}

function diffSets(a, b) {
  const onlyA = []
  const onlyB = []

  for (const key of a) {
    if (!b.has(key))
      onlyA.push(key)
  }

  for (const key of b) {
    if (!a.has(key))
      onlyB.push(key)
  }

  return {
    "onlyA": onlyA.sort((x, y) => x.localeCompare(y)),
    "onlyB": onlyB.sort((x, y) => x.localeCompare(y))
  }
}

function main() {
  const embedded = parseEmbeddedCache(read(schemeCacheJsPath))
  const jsonCache = JSON.parse(read(schemeCacheJsonPath))
  const pipelineVersion = parsePipelineVersion(read(themePipelinePath))

  let hasError = false

  if (embedded.version !== pipelineVersion) {
    hasError = true
    console.error("Version mismatch:")
    console.error("  SchemeCache.js SCHEME_CACHE_VERSION:", embedded.version)
    console.error("  ThemePipeline.js PIPELINE_VERSION:", pipelineVersion)
  }

  const embeddedKeys = toKeySet(embedded.cache)
  const jsonKeys = toKeySet(jsonCache)
  const keyDiff = diffSets(embeddedKeys, jsonKeys)

  if (keyDiff.onlyA.length || keyDiff.onlyB.length) {
    hasError = true
    console.error("Cache key mismatch between SchemeCache.js and scheme-cache.json")
    if (keyDiff.onlyA.length)
      console.error("  Only in SchemeCache.js:", keyDiff.onlyA.join(", "))
    if (keyDiff.onlyB.length)
      console.error("  Only in scheme-cache.json:", keyDiff.onlyB.join(", "))
  }

  if (hasError) {
    process.exit(1)
  }

  console.log("Cache consistency check passed")
  console.log("Version:", embedded.version)
  console.log("Themes:", embeddedKeys.size)
}

main()
