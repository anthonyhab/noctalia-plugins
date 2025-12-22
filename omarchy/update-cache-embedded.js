#!/usr/bin/env node

// ============================================
// Update Embedded Cache in ColorsConvertCached.js
// ============================================
// This script updates the embedded theme cache after running generate-theme-cache.js

const fs = require('fs');
const path = require('path');

const cacheFile = path.join(__dirname, 'theme-cache.json');
const targetFile = path.join(__dirname, 'ColorsConvertCached.js');

// Read the cache
const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));

// Read the target file
let content = fs.readFileSync(targetFile, 'utf8');

// Find the THEME_CACHE object and replace it
const cacheStr = JSON.stringify(cache, null, 2)
  .split('\n')
  .map(line => '  ' + line)
  .join('\n');

const regex = /const THEME_CACHE = \{[\s\S]*?\n\};/;
const replacement = 'const THEME_CACHE = ' + cacheStr + ';';

content = content.replace(regex, replacement);

// Write back
fs.writeFileSync(targetFile, content);

console.log('✓ Embedded cache updated in ColorsConvertCached.js');
console.log('  ' + Object.keys(cache).length + ' themes embedded');
