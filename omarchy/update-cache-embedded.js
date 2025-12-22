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

// More specific regex to match the exact structure
const regex = /const THEME_CACHE = \{[\s\S]*?\n  \};/;
const replacement = 'const THEME_CACHE = ' + cacheStr + '\n  };';

// If regex doesn't match, try to find the start and manually replace
if (!regex.test(content)) {
  const startIndex = content.indexOf('const THEME_CACHE =');
  if (startIndex !== -1) {
    // Find the end of the object (look for the closing };
    const endPattern = /\n  \};/;
    const endMatch = content.slice(startIndex).match(endPattern);
    if (endMatch) {
      const endIndex = startIndex + endMatch.index + endMatch[0].length;
      content = content.slice(0, startIndex) + 'const THEME_CACHE = ' + cacheStr + '\n  };' + content.slice(endIndex);
    }
  }
} else {
  content = content.replace(regex, replacement);
}

// Write back
fs.writeFileSync(targetFile, content);

console.log('✓ Embedded cache updated in ColorsConvertCached.js');
console.log('  ' + Object.keys(cache).length + ' themes embedded');
