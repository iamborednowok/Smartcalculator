#!/usr/bin/env node
/**
 * build.js — SmartCalc pre-compile step
 * 
 * Extracts JSX from index.html, compiles it with Babel,
 * injects the compiled JS back → www/index.html
 * 
 * Eliminates 400KB Babel standalone download + runtime compilation on device.
 * Run: node build.js
 */

const fs = require('fs');
const babel = require('@babel/core');

const src = fs.readFileSync('index.html', 'utf8');

// Extract JSX block
const BABEL_TAG = '<script type="text/babel">';
const END_TAG = '</script>';
const start = src.indexOf(BABEL_TAG);
const end = src.lastIndexOf(END_TAG) + END_TAG.length;

if (start === -1) {
  console.log('⚠️  No <script type="text/babel"> found — copying as-is');
  fs.mkdirSync('www', { recursive: true });
  fs.writeFileSync('www/index.html', src);
  process.exit(0);
}

const jsxCode = src.slice(start + BABEL_TAG.length, src.lastIndexOf(END_TAG));

console.log(`Compiling ${Math.round(jsxCode.length / 1024)}KB JSX...`);

// Compile
const result = babel.transformSync(jsxCode, {
  presets: [
    ['@babel/preset-react', { runtime: 'classic' }],
  ],
  compact: true,
  comments: false,
  sourceMaps: false,
});

if (!result || !result.code) {
  console.error('❌ Babel compilation failed');
  process.exit(1);
}

console.log(`Compiled → ${Math.round(result.code.length / 1024)}KB JS`);

// Rebuild HTML
let out = src;

// Remove Babel CDN script tag
out = out.replace(
  /\s*<script[^>]*babel-standalone[^>]*><\/script>/g, ''
);
// Remove from SW cache list
out = out.replace(
  /\s*'https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/babel-standalone[^']*',?\n?/g, ''
);
// Replace babel script block with compiled JS
const before = out.slice(0, out.indexOf(BABEL_TAG));
const after = out.slice(out.lastIndexOf(END_TAG) + END_TAG.length);
out = before + `<script>\n${result.code}\n</script>` + after;

fs.mkdirSync('www', { recursive: true });
fs.writeFileSync('www/index.html', out);

const origKB = Math.round(src.length / 1024);
const newKB  = Math.round(out.length / 1024);
console.log(`✅ www/index.html written (${origKB}KB → ${newKB}KB)`);
console.log('   Babel standalone (~400KB CDN) eliminated from user download');
