#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const cacheFile = path.join(__dirname, "scheme-cache.json");
const targetFile = path.join(__dirname, "SchemeCache.js");
const pipelineFile = path.join(__dirname, "ThemePipeline.js");
const convertFile = path.join(__dirname, "ColorsConvert.js");

function readFileSafe(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function stripPipelineVersion(content) {
  return content.replace(/const PIPELINE_VERSION = \"[^\"]*\";\n/, "");
}

function computePipelineVersion() {
  const pipeline = stripPipelineVersion(readFileSafe(pipelineFile));
  const convert = readFileSafe(convertFile);
  const hash = crypto.createHash("sha256");
  hash.update(pipeline);
  hash.update(convert);
  return hash.digest("hex").slice(0, 12);
}

function updatePipelineVersion(version) {
  const content = readFileSafe(pipelineFile);
  const next = content.replace(/const PIPELINE_VERSION = \"[^\"]*\";/, `const PIPELINE_VERSION = "${version}";`);
  fs.writeFileSync(pipelineFile, next);
}

function updateSchemeCache(version, cache) {
  const cacheStr = JSON.stringify(cache, null, 2);
  const content = readFileSafe(targetFile);
  const next = content
    .replace(/const SCHEME_CACHE_VERSION = \"[^\"]*\";/, `const SCHEME_CACHE_VERSION = "${version}";`)
    .replace(/const SCHEME_CACHE = [\\s\\S]*?;\\n/, `const SCHEME_CACHE = ${cacheStr};\n`);
  fs.writeFileSync(targetFile, next);
}

if (!fs.existsSync(cacheFile)) {
  console.error(`Missing cache file: ${cacheFile}`);
  console.error("Run: node generate-scheme-cache.js");
  process.exit(1);
}

const cache = JSON.parse(readFileSafe(cacheFile));
const version = computePipelineVersion();

updatePipelineVersion(version);
updateSchemeCache(version, cache);

console.log("✓ Embedded scheme cache updated in SchemeCache.js");
console.log(`  ${Object.keys(cache).length} themes embedded`);
console.log(`  version: ${version}`);
