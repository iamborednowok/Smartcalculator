#!/usr/bin/env node
/**
 * build.js — SmartCalc pre-compile step
 * If index.html still has <script type="text/babel">, compiles it.
 * If already compiled (no babel tag), copies as-is.
 */
const fs = require('fs');
let babel;
try { babel = require('@babel/core'); } catch(e) { babel = null; }

const src = fs.readFileSync('index.html', 'utf8');
const BABEL_TAG = '<script type="text/babel">';
const END_TAG = '</script>';

fs.mkdirSync('www', { recursive: true });

if (!src.includes(BABEL_TAG)) {
  // Already compiled — just copy
  fs.writeFileSync('www/index.html', src);
  console.log('✅ index.html already compiled — copied to www/');
  process.exit(0);
}

if (!babel) {
  console.error('❌ @babel/core not found. Run: npm install');
  process.exit(1);
}

const jsxCode = src.slice(src.indexOf(BABEL_TAG) + BABEL_TAG.length, src.lastIndexOf(END_TAG));
console.log(`Compiling ${Math.round(jsxCode.length/1024)}KB JSX...`);

const result = babel.transformSync(jsxCode, {
  presets: [['@babel/preset-react', { runtime: 'classic' }]],
  compact: true, comments: false,
});
if (!result?.code) { console.error('❌ Babel failed'); process.exit(1); }

let out = src;
out = out.replace(/<script[^>]*babel-standalone[^>]*><\/script>\s*/g, '');
out = out.replace(/\s*'https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/babel-standalone[^']*',?\n?/g, '');
const before = out.slice(0, out.indexOf(BABEL_TAG));
const after  = out.slice(out.lastIndexOf(END_TAG) + END_TAG.length);
out = before + `<script>\n${result.code}\n</script>` + after;

fs.writeFileSync('www/index.html', out);
console.log(`✅ Compiled → www/index.html (${Math.round(out.length/1024)}KB, Babel removed)`);
