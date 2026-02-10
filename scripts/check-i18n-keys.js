#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

function collectQmlFiles(dirPath) {
  const files = []
  const entries = fs.readdirSync(dirPath, { "withFileTypes": true })
  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name)
    if (entry.isDirectory()) {
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
  const patterns = [
    /\btr\(\s*["']([^"']+)["']/g,
    /pluginApi\??\.tr\(\s*["']([^"']+)["']/g
  ]

  for (const regex of patterns) {
    let match = regex.exec(text)
    while (match) {
      keys.push(match[1])
      match = regex.exec(text)
    }
  }
  return keys
}

function main() {
  const repoRoot = process.cwd()
  const pluginDir = path.join(repoRoot, "omarchy")
  const localePath = path.join(pluginDir, "i18n", "en.json")

  if (!fs.existsSync(localePath)) {
    console.error("Missing locale file:", localePath)
    process.exit(1)
  }

  const locale = JSON.parse(fs.readFileSync(localePath, "utf8"))
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

  if (missing.length > 0) {
    console.error("Missing translation keys in omarchy/i18n/en.json:")
    for (const key of missing) {
      const refs = Array.from(new Set(locations[key] || []))
      console.error("  -", key, "(referenced in:", refs.join(", ") + ")")
    }
    process.exit(1)
  }

  console.log("Translation key check passed")
  console.log("Referenced keys:", referenced.size)
  console.log("Available keys:", availableKeys.size)
}

main()
