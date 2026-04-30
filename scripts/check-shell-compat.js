#!/usr/bin/env node

const fs = require("fs")
const path = require("path")

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8")
}

function getPluginDirs(repoRoot) {
  const entries = fs.readdirSync(repoRoot, { "withFileTypes": true })
  const dirs = []
  for (const entry of entries) {
    if (!entry.isDirectory())
      continue
    const manifestPath = path.join(repoRoot, entry.name, "manifest.json")
    if (fs.existsSync(manifestPath))
      dirs.push(path.join(repoRoot, entry.name))
  }
  return dirs.sort((a, b) => a.localeCompare(b))
}

function parseManifest(manifestPath) {
  return JSON.parse(readText(manifestPath))
}

function checkBarWidgetRequiredProps(pluginDir, manifest, errors) {
  const barWidgetEntry = manifest?.entryPoints?.barWidget
  if (!barWidgetEntry)
    return

  const barWidgetPath = path.join(pluginDir, barWidgetEntry)
  if (!fs.existsSync(barWidgetPath)) {
    errors.push(`${path.relative(process.cwd(), barWidgetPath)}: missing BarWidget entrypoint file`)
    return
  }

  const text = readText(barWidgetPath)
  const required = [
    {
      "name": "pluginApi",
      "regex": /property\s+var\s+pluginApi\b/
    },
    {
      "name": "screen",
      "regex": /property\s+ShellScreen\s+screen\b/
    },
    {
      "name": "widgetId",
      "regex": /property\s+string\s+widgetId\b/
    },
    {
      "name": "section",
      "regex": /property\s+string\s+section\b/
    },
    {
      "name": "sectionWidgetIndex",
      "regex": /property\s+int\s+sectionWidgetIndex\b/
    },
    {
      "name": "sectionWidgetsCount",
      "regex": /property\s+int\s+sectionWidgetsCount\b/
    }
  ]

  for (const rule of required) {
    if (!rule.regex.test(text)) {
      errors.push(`${path.relative(process.cwd(), barWidgetPath)}: missing required injected property '${rule.name}'`)
    }
  }
}

function collectBlock(lines, startLine) {
  let depth = 0
  const block = []
  for (let i = startLine; i < lines.length; i++) {
    const line = lines[i]
    block.push(line)
    for (const ch of line) {
      if (ch === "{")
        depth++
      else if (ch === "}")
        depth--
    }
    if (depth <= 0)
      return {
        "text": block.join("\n"),
        "endLine": i
      }
  }
  return {
    "text": block.join("\n"),
    "endLine": lines.length - 1
  }
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

function findNButtonIds(lines) {
  const ids = new Set()

  for (let i = 0; i < lines.length; i++) {
    if (!/\bNButton\s*\{/.test(lines[i]))
      continue

    const block = collectBlock(lines, i)
    const match = block.text.match(/\bid\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\b/)
    if (match)
      ids.add(match[1])

    i = block.endLine
  }

  return Array.from(ids)
}

function checkNButtonInternals(filePath, text, errors) {
  const lines = text.split("\n")
  const ids = findNButtonIds(lines)
  if (ids.length === 0)
    return

  for (const id of ids) {
    const escapedId = escapeRegex(id)

    const directBorderUse = new RegExp(`\\b${escapedId}\\.border\\.(width|color)\\b`)
    if (directBorderUse.test(text)) {
      errors.push(`${path.relative(process.cwd(), filePath)}: uses unsupported NButton internal border access via '${id}.border.*'`)
    }

    const directBackgroundUse = new RegExp(`\\b${escapedId}\\.background\\b`)
    if (directBackgroundUse.test(text)) {
      errors.push(`${path.relative(process.cwd(), filePath)}: uses unsupported NButton internal background access via '${id}.background'`)
    }

    for (let i = 0; i < lines.length; i++) {
      if (!/\bBinding\s*\{/.test(lines[i]))
        continue

      const block = collectBlock(lines, i)
      const blockText = block.text

      const targetRe = new RegExp(`target\\s*:\\s*${escapedId}\\b`)
      const borderPropRe = /property\s*:\s*"border\.(width|color)"/
      if (targetRe.test(blockText) && borderPropRe.test(blockText)) {
        errors.push(`${path.relative(process.cwd(), filePath)}:${i + 1}: Binding targets NButton '${id}' internal border property`)
      }

      const targetBgRe = new RegExp(`target\\s*:\\s*${escapedId}\\.background\\b`)
      if (targetBgRe.test(blockText)) {
        errors.push(`${path.relative(process.cwd(), filePath)}:${i + 1}: Binding targets NButton '${id}.background' (unsupported internal)`)
      }

      i = block.endLine
    }
  }
}

function checkPluginQmlInternals(pluginDir, errors) {
  const entries = fs.readdirSync(pluginDir)
  for (const entry of entries) {
    if (!entry.endsWith(".qml"))
      continue
    const filePath = path.join(pluginDir, entry)
    const text = readText(filePath)
    checkNButtonInternals(filePath, text, errors)
  }
}

function main() {
  const repoRoot = process.cwd()
  const pluginDirs = getPluginDirs(repoRoot)
  const errors = []

  for (const pluginDir of pluginDirs) {
    const manifestPath = path.join(pluginDir, "manifest.json")
    const manifest = parseManifest(manifestPath)
    checkBarWidgetRequiredProps(pluginDir, manifest, errors)
    checkPluginQmlInternals(pluginDir, errors)
  }

  if (errors.length > 0) {
    console.error("Shell compatibility check failed:")
    for (const error of errors)
      console.error("  -", error)
    process.exit(1)
  }

  console.log("Shell compatibility check passed")
}

main()
