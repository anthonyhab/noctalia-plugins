#!/usr/bin/env node

const fs = require("fs")
const path = require("path")
const os = require("os")

const ThemePipeline = require("./ThemePipeline.js")
const ColorsConvert = require("./ColorsConvert.js")

function parseColorsToml(content) {
  function extractColorFromLine(line) {
    const colorMatch = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/)
    if (!colorMatch)
      return null
    const hex = colorMatch[1].toLowerCase()
    return "#" + hex.slice(-6)
  }

  const colors = {}
  const lines = content.split("\n")

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line || line.startsWith("#") || line.startsWith("["))
      continue

    const color = extractColorFromLine(line)
    if (!color)
      continue

    const keyMatch = line.match(/^([a-zA-Z0-9_]+)\s*=/)
    if (!keyMatch)
      continue

    colors[keyMatch[1]] = color
  }

  if (!colors.background || !colors.foreground)
    return null
  return colors
}

function usage() {
  console.log("Usage: node generate-scheme-cache.js [options]")
  console.log("")
  console.log("Options:")
  console.log("  --scope <builtins|all>   Theme source scope (default: builtins)")
  console.log("  --builtins-dir <path>    Built-in Omarchy themes directory")
  console.log("  --user-dir <path>        User themes directory")
  console.log("  --output <path>          Output JSON path")
  console.log("  --quiet                  Reduce log output")
  console.log("  --help                   Show this help")
}

function parseArgs(argv) {
  const defaults = {
    "scope": "builtins",
    "builtinsDir": path.join(os.homedir(), ".local", "share", "omarchy", "themes"),
    "userDir": path.join(os.homedir(), ".config", "omarchy", "themes"),
    "output": path.join(__dirname, "scheme-cache.json"),
    "quiet": false
  }

  if (process.env.OMARCHY_PATH) {
    defaults.builtinsDir = path.join(process.env.OMARCHY_PATH, "themes")
  }

  const args = {
    ...defaults
  }

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    if (arg === "--help") {
      usage()
      process.exit(0)
    }
    if (arg === "--quiet") {
      args.quiet = true
      continue
    }
    if (arg === "--scope") {
      args.scope = argv[++i]
      continue
    }
    if (arg === "--builtins-dir") {
      args.builtinsDir = argv[++i]
      continue
    }
    if (arg === "--user-dir") {
      args.userDir = argv[++i]
      continue
    }
    if (arg === "--output") {
      args.output = argv[++i]
      continue
    }

    console.error("Unknown argument:", arg)
    usage()
    process.exit(1)
  }

  if (args.scope !== "builtins" && args.scope !== "all") {
    console.error("Invalid --scope value:", args.scope)
    console.error("Expected: builtins or all")
    process.exit(1)
  }

  return args
}

function scanThemesInDirectory(themesDir, label, quiet) {
  const themes = {}

  if (!fs.existsSync(themesDir)) {
    if (!quiet)
      console.log(label + " directory not found: " + themesDir)
    return themes
  }

  if (!quiet)
    console.log("Scanning " + label + ": " + themesDir)

  const entries = fs.readdirSync(themesDir).sort((a, b) => a.localeCompare(b))

  for (const entry of entries) {
    const themePath = path.join(themesDir, entry)
    let realPath = themePath

    try {
      const stat = fs.lstatSync(themePath)
      if (stat.isSymbolicLink()) {
        realPath = fs.realpathSync(themePath)
      }
      if (!fs.statSync(realPath).isDirectory()) {
        continue
      }
    } catch (error) {
      if (!quiet)
        console.log("  skip " + entry + ": " + error.message)
      continue
    }

    const colorsTomlPath = path.join(realPath, "colors.toml")
    if (!fs.existsSync(colorsTomlPath))
      continue

    try {
      const content = fs.readFileSync(colorsTomlPath, "utf8")
      const colors = parseColorsToml(content)
      if (!colors) {
        if (!quiet)
          console.log("  skip " + entry + ": missing required colors")
        continue
      }
      themes[entry] = colors
      if (!quiet)
        console.log("  ok " + entry)
    } catch (error) {
      if (!quiet)
        console.log("  skip " + entry + ": " + error.message)
    }
  }

  return themes
}

function buildThemeSource(config) {
  const builtins = scanThemesInDirectory(config.builtinsDir, "built-in themes", config.quiet)
  if (config.scope === "builtins") {
    return builtins
  }

  const userThemes = scanThemesInDirectory(config.userDir, "user themes", config.quiet)
  return {
    ...builtins,
    ...userThemes
  }
}

function generateCache(themeSource, quiet) {
  const cache = {}
  const names = Object.keys(themeSource).sort((a, b) => a.localeCompare(b))

  if (!quiet)
    console.log("Generating cache for " + names.length + " themes")

  for (const themeName of names) {
    const omarchyColors = themeSource[themeName]
    if (!quiet)
      console.log("  convert " + themeName)
    cache[themeName] = ThemePipeline.generateScheme(omarchyColors, ColorsConvert)
  }

  return cache
}

function main() {
  const config = parseArgs(process.argv.slice(2))
  const themeSource = buildThemeSource(config)

  if (!Object.keys(themeSource).length) {
    console.error("No themes found for scope:", config.scope)
    process.exit(1)
  }

  const cache = generateCache(themeSource, config.quiet)
  fs.writeFileSync(config.output, JSON.stringify(cache, null, 2) + "\n")

  console.log("Generated scheme cache:", config.output)
  console.log("Themes:", Object.keys(cache).length)
  console.log("Scope:", config.scope)
}

main()
