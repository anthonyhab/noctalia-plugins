#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

const REQUIRED_FIELDS = [
  "id",
  "name",
  "version",
  "minNoctaliaVersion",
  "author",
  "license",
  "repository",
  "description",
  "tags",
  "entryPoints",
  "dependencies",
  "metadata"
]

const ALLOWED_TAGS = new Set([
  "Bar",
  "Desktop",
  "Panel",
  "Launcher",
  "Productivity",
  "System",
  "Audio",
  "Network",
  "Privacy",
  "Development",
  "Fun",
  "Gaming",
  "Indicator"
])

function isObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function getManifestPaths(repoRoot) {
  const entries = fs.readdirSync(repoRoot, { "withFileTypes": true })
  const paths = []
  for (const entry of entries) {
    if (!entry.isDirectory())
      continue
    const manifestPath = path.join(repoRoot, entry.name, "manifest.json")
    if (fs.existsSync(manifestPath))
      paths.push(manifestPath)
  }
  return paths.sort((a, b) => a.localeCompare(b))
}

function validateManifest(filePath, data) {
  const errors = []
  const warnings = []
  const rel = path.relative(process.cwd(), filePath)
  const pluginDir = path.dirname(filePath)

  for (const field of REQUIRED_FIELDS) {
    if (!(field in data)) {
      errors.push(rel + ": missing required field '" + field + "'")
    }
  }

  if (typeof data.id !== "string" || !/^[a-z0-9-]+$/.test(data.id)) {
    errors.push(rel + ": id must be lowercase letters/numbers/hyphens")
  }

  if (!Array.isArray(data.tags) || data.tags.length === 0) {
    errors.push(rel + ": tags must be a non-empty array")
  } else {
    for (const tag of data.tags) {
      if (!ALLOWED_TAGS.has(tag)) {
        errors.push(rel + ": invalid tag '" + tag + "'")
      }
    }
  }

  if (!isObject(data.entryPoints) || Object.keys(data.entryPoints).length === 0) {
    errors.push(rel + ": entryPoints must be a non-empty object")
  } else {
    for (const key of Object.keys(data.entryPoints)) {
      const entryPath = data.entryPoints[key]
      if (typeof entryPath !== "string" || entryPath.trim() === "") {
        errors.push(rel + ": entryPoints." + key + " must be a non-empty string")
        continue
      }
      const absoluteEntryPath = path.join(pluginDir, entryPath)
      if (!fs.existsSync(absoluteEntryPath)) {
        errors.push(rel + ": entryPoints." + key + " points to missing file '" + entryPath + "'")
      }
    }
  }

  if (!isObject(data.dependencies) || !Array.isArray(data.dependencies.plugins)) {
    errors.push(rel + ": dependencies.plugins must be an array")
  }

  if (!isObject(data.metadata) || !isObject(data.metadata.defaultSettings)) {
    errors.push(rel + ": metadata.defaultSettings must be an object")
  }

  if (typeof data.repository !== "string" || !data.repository.startsWith("https://")) {
    errors.push(rel + ": repository must be an https URL")
  }

  if (typeof data.version !== "string" || !/^\d+\.\d+\.\d+$/.test(data.version)) {
    errors.push(rel + ": version must follow semver x.y.z")
  }

  if (typeof data.minNoctaliaVersion !== "string" || !/^\d+\.\d+\.\d+$/.test(data.minNoctaliaVersion)) {
    errors.push(rel + ": minNoctaliaVersion must follow semver x.y.z")
  }

  const readmePath = path.join(pluginDir, "README.md")
  if (!fs.existsSync(readmePath)) {
    errors.push(rel + ": missing README.md")
  }

  const previewCandidates = ["preview.png", "preview.jpg", "preview.jpeg", "preview.webp"]
  const hasPreview = previewCandidates.some(name => fs.existsSync(path.join(pluginDir, name)))
  if (!hasPreview) {
    warnings.push(rel + ": preview image missing (recommended for official directory)")
  }

  return {
    "errors": errors,
    "warnings": warnings
  }
}

function main() {
  const repoRoot = process.cwd()
  const manifestPaths = getManifestPaths(repoRoot)

  if (manifestPaths.length === 0) {
    console.error("No manifest.json files found")
    process.exit(1)
  }

  const allErrors = []
  const allWarnings = []
  for (const manifestPath of manifestPaths) {
    const raw = fs.readFileSync(manifestPath, "utf8")
    const parsed = JSON.parse(raw)
    const result = validateManifest(manifestPath, parsed)
    allErrors.push(...result.errors)
    allWarnings.push(...result.warnings)
  }

  if (allErrors.length > 0) {
    console.error("Manifest validation failed:")
    for (const error of allErrors) {
      console.error("  -", error)
    }
    process.exit(1)
  }

  if (allWarnings.length > 0) {
    console.log("Manifest recommendations:")
    for (const warning of allWarnings) {
      console.log("  -", warning)
    }
  }

  console.log("Manifest compliance check passed")
  console.log("Manifests:", manifestPaths.length)
}

main()
