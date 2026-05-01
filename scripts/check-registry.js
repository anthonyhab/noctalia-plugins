#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"))
}

function listPluginDirs(repoRoot) {
  const dirs = fs.readdirSync(repoRoot, { "withFileTypes": true })
  const plugins = []

  for (const entry of dirs) {
    if (!entry.isDirectory())
      continue

    const manifestPath = path.join(repoRoot, entry.name, "manifest.json")
    if (fs.existsSync(manifestPath)) {
      plugins.push({
        "id": entry.name,
        "manifestPath": manifestPath
      })
    }
  }

  return plugins.sort((a, b) => a.id.localeCompare(b.id))
}

function main() {
  const repoRoot = process.cwd()
  const registryPath = path.join(repoRoot, "registry.json")

  if (!fs.existsSync(registryPath)) {
    console.error("registry.json is missing")
    process.exit(1)
  }

  const registry = readJson(registryPath)
  const registryPlugins = Array.isArray(registry.plugins) ? registry.plugins : []
  const manifestDirs = listPluginDirs(repoRoot)

  const errors = []
  const warnings = []

  const seenRegistryIds = new Set()
  const registryById = new Map()

  for (const plugin of registryPlugins) {
    if (!plugin || typeof plugin.id !== "string" || plugin.id.trim() === "") {
      errors.push("registry.json has plugin entry with missing/invalid id")
      continue
    }

    if (seenRegistryIds.has(plugin.id)) {
      errors.push("registry.json has duplicate plugin id: " + plugin.id)
      continue
    }

    seenRegistryIds.add(plugin.id)
    registryById.set(plugin.id, plugin)
  }

  for (const pluginDir of manifestDirs) {
    const manifest = readJson(pluginDir.manifestPath)
    const entry = registryById.get(manifest.id)

    if (!entry) {
      errors.push("manifest is not listed in registry: " + pluginDir.id)
      continue
    }

    if (entry.id !== manifest.id) {
      errors.push("id mismatch for " + pluginDir.id + ": registry='" + entry.id + "' manifest='" + manifest.id + "'")
    }

    if (entry.name !== manifest.name) {
      errors.push("name mismatch for " + pluginDir.id + ": registry='" + entry.name + "' manifest='" + manifest.name + "'")
    }

    if (entry.version !== manifest.version) {
      errors.push("version mismatch for " + pluginDir.id + ": registry='" + entry.version + "' manifest='" + manifest.version + "'")
    }

    if (entry.description !== manifest.description) {
      errors.push("description mismatch for " + pluginDir.id)
    }

    if (!entry.lastUpdated) {
      warnings.push("registry entry missing lastUpdated: " + pluginDir.id)
    }
  }

  for (const plugin of registryPlugins) {
    if (!plugin || !plugin.id)
      continue

    const manifestPath = path.join(repoRoot, plugin.id, "manifest.json")
    if (!fs.existsSync(manifestPath)) {
      errors.push("registry plugin has no manifest directory: " + plugin.id)
    }
  }

  if (warnings.length > 0) {
    console.log("Registry warnings:")
    for (const warning of warnings) {
      console.log("  - " + warning)
    }
  }

  if (errors.length > 0) {
    console.error("Registry consistency check failed:")
    for (const error of errors) {
      console.error("  - " + error)
    }
    process.exit(1)
  }

  console.log("Registry consistency check passed")
  console.log("Stable plugins:", manifestDirs.length)
}

main()
