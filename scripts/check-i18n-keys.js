#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

const SKIP_DIRS = new Set([".git", ".worktrees", "node_modules"])

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"))
}

function collectQmlFiles(dirPath) {
  const files = []
  const entries = fs.readdirSync(dirPath, { "withFileTypes": true })
  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name)
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name) || entry.name.startsWith("."))
        continue
      files.push(...collectQmlFiles(fullPath))
    } else if (entry.isFile() && entry.name.endsWith(".qml")) {
      files.push(fullPath)
    }
  }
  return files
}

function flattenKeys(obj, prefix, out) {
  if (!obj || typeof obj !== "object")
    return
  const keys = Object.keys(obj)
  for (const key of keys) {
    const nextPrefix = prefix ? (prefix + "." + key) : key
    const value = obj[key]
    if (value && typeof value === "object" && !Array.isArray(value)) {
      flattenKeys(value, nextPrefix, out)
    } else {
      out.add(nextPrefix)
    }
  }
}

function collectReferencedKeys(filePath) {
  const text = fs.readFileSync(filePath, "utf8")
  const keys = []

  const pluginApiTrRe = /pluginApi\??\.tr\(\s*["']([^"']+)["']/g
  let pluginApiTrMatch = pluginApiTrRe.exec(text)
  while (pluginApiTrMatch) {
    keys.push(pluginApiTrMatch[1])
    pluginApiTrMatch = pluginApiTrRe.exec(text)
  }

  const pluginApiTrpRe = /pluginApi\??\.trp\(\s*["']([^"']+)["']/g
  let pluginApiTrpMatch = pluginApiTrpRe.exec(text)
  while (pluginApiTrpMatch) {
    keys.push(pluginApiTrpMatch[1])
    pluginApiTrpMatch = pluginApiTrpRe.exec(text)
  }

  const trOrDefaultRe = /trOrDefault\(\s*["']([^"']+)["']/g
  let trOrDefaultMatch = trOrDefaultRe.exec(text)
  while (trOrDefaultMatch) {
    keys.push(trOrDefaultMatch[1])
    trOrDefaultMatch = trOrDefaultRe.exec(text)
  }

  const localTrRe = /(^|[^A-Za-z0-9_.])tr\(\s*["']([^"']+)["']/g
  let localTrMatch = localTrRe.exec(text)
  while (localTrMatch) {
    keys.push(localTrMatch[2])
    localTrMatch = localTrRe.exec(text)
  }

  const localTrpRe = /(^|[^A-Za-z0-9_.])trp\(\s*["']([^"']+)["']/g
  let localTrpMatch = localTrpRe.exec(text)
  while (localTrpMatch) {
    keys.push(localTrpMatch[2])
    localTrpMatch = localTrpRe.exec(text)
  }

  return keys
}

function getStablePluginIds(repoRoot) {
  const registryPath = path.join(repoRoot, "registry.json")
  if (!fs.existsSync(registryPath)) {
    console.error("Missing registry file:", registryPath)
    process.exit(1)
  }

  const registry = readJson(registryPath)
  const plugins = Array.isArray(registry.plugins) ? registry.plugins : []
  return plugins
    .map(plugin => plugin && plugin.id)
    .filter(id => typeof id === "string" && id.trim().length > 0)
}

function validatePlugin(repoRoot, pluginId) {
  const pluginDir = path.join(repoRoot, pluginId)
  const manifestPath = path.join(pluginDir, "manifest.json")
  const localePath = path.join(pluginDir, "i18n", "en.json")

  if (!fs.existsSync(manifestPath)) {
    return {
      "pluginId": pluginId,
      "errors": [`${pluginId}: missing manifest.json`],
      "referencedCount": 0,
      "availableCount": 0
    }
  }

  if (!fs.existsSync(localePath)) {
    return {
      "pluginId": pluginId,
      "errors": [`${pluginId}: missing i18n/en.json`],
      "referencedCount": 0,
      "availableCount": 0
    }
  }

  const locale = readJson(localePath)
  const availableKeys = new Set()
  flattenKeys(locale, "", availableKeys)

  const qmlFiles = collectQmlFiles(pluginDir)
  const referenced = new Set()
  const locations = {}

  for (const filePath of qmlFiles) {
    const keys = collectReferencedKeys(filePath)
    for (const key of keys) {
      referenced.add(key)
      if (!locations[key])
        locations[key] = []
      locations[key].push(path.relative(repoRoot, filePath))
    }
  }

  const missing = Array.from(referenced)
    .filter(key => !availableKeys.has(key))
    .sort((a, b) => a.localeCompare(b))

  const errors = []
  if (missing.length > 0) {
    errors.push(`${pluginId}: missing translation keys in i18n/en.json`)
    for (const key of missing) {
      const refs = Array.from(new Set(locations[key] || []))
      errors.push(`  - ${key} (referenced in: ${refs.join(", ")})`)
    }
  }

  return {
    "pluginId": pluginId,
    "errors": errors,
    "referencedCount": referenced.size,
    "availableCount": availableKeys.size
  }
}

function main() {
  const repoRoot = process.cwd()
  const stablePluginIds = getStablePluginIds(repoRoot)

  if (stablePluginIds.length === 0) {
    console.error("No stable plugins found in registry.json")
    process.exit(1)
  }

  const allErrors = []
  let totalReferenced = 0
  let totalAvailable = 0

  for (const pluginId of stablePluginIds) {
    const result = validatePlugin(repoRoot, pluginId)
    totalReferenced += result.referencedCount
    totalAvailable += result.availableCount

    if (result.errors.length > 0) {
      allErrors.push(...result.errors)
      continue
    }

    console.log(`[i18n] ${pluginId}: referenced=${result.referencedCount} available=${result.availableCount}`)
  }

  if (allErrors.length > 0) {
    console.error("Translation key check failed:")
    for (const error of allErrors)
      console.error(error)
    process.exit(1)
  }

  console.log("Translation key check passed")
  console.log("Stable plugins:", stablePluginIds.length)
  console.log("Total referenced keys:", totalReferenced)
  console.log("Total available keys:", totalAvailable)
}

main()
