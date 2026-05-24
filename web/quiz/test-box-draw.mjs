// test-box-draw.mjs — Node tests for web/quiz/box-draw.js.
//
//   node --test web/quiz/test-box-draw.mjs
//
// The quiz's box-draw module exports via `module.exports`, so we can
// require it directly. (The walkthrough's variant attaches to a
// global; see web/walkthrough/test-box-draw.mjs for that pattern.)

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const BoxDraw = require('./box-draw.js');
const BOX_DRAW_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'box-draw.js');

const { BOX_WIDTH, INNER_WIDTH } = BoxDraw;
const TOTAL_WIDTH = BOX_WIDTH + 2;

// ──────────────────────────────────────────────────────────────────────
// width constants
// ──────────────────────────────────────────────────────────────────────

test('width constants: BOX_WIDTH 60, INNER_WIDTH 58', () => {
  assert.equal(BOX_WIDTH, 60);
  assert.equal(INNER_WIDTH, 58);
});

// ──────────────────────────────────────────────────────────────────────
// wrapText
// ──────────────────────────────────────────────────────────────────────

test('wrapText: empty string returns [\'\']', () => {
  assert.deepEqual(BoxDraw.wrapText('', 10), ['']);
});

test('wrapText: null returns [\'\']', () => {
  assert.deepEqual(BoxDraw.wrapText(null, 10), ['']);
});

test('wrapText: whitespace-only string returns [\'\']', () => {
  // After split+filter, words.length === 0; exercises that early return.
  assert.deepEqual(BoxDraw.wrapText('   \t  ', 10), ['']);
});

test('wrapText: single short word stays on one line', () => {
  assert.deepEqual(BoxDraw.wrapText('hello', 10), ['hello']);
});

test('wrapText: two words that fit stay on one line', () => {
  assert.deepEqual(BoxDraw.wrapText('hi there', 10), ['hi there']);
});

test('wrapText: wraps when next word would exceed width', () => {
  assert.deepEqual(
    BoxDraw.wrapText('one two three', 7),
    ['one two', 'three'],
  );
});

test('wrapText: word longer than width gets its own line', () => {
  assert.deepEqual(
    BoxDraw.wrapText('aa supercalifragilistic bb', 10),
    ['aa', 'supercalifragilistic', 'bb'],
  );
});

// ──────────────────────────────────────────────────────────────────────
// Thin borders
// ──────────────────────────────────────────────────────────────────────

test('boxTop: no title — corners + horizontal fill', () => {
  const top = BoxDraw.boxTop();
  assert.equal(top, '┌' + '─'.repeat(BOX_WIDTH) + '┐');
  assert.equal(top.length, TOTAL_WIDTH);
});

test('boxTop: with title — label inset and right-padded with horizontals', () => {
  const top = BoxDraw.boxTop('Box 5');
  assert.ok(top.startsWith('┌─ Box 5 '));
  assert.ok(top.endsWith('┐'));
  assert.equal(top.length, TOTAL_WIDTH);
});

test('boxTop: title that exactly equals BOX_WIDTH still produces valid top', () => {
  // Pushes Math.max(BOX_WIDTH - label.length, 0) into the 0-arm — fill is empty.
  // Label is '─ ' + title + ' ' so to make label.length === BOX_WIDTH (60),
  // title length must be 57.
  const title = 'X'.repeat(57);
  const top = BoxDraw.boxTop(title);
  assert.ok(top.startsWith('┌─ ' + title + ' ┐'));
});

test('boxDivider: tee corners + horizontal fill', () => {
  assert.equal(BoxDraw.boxDivider(), '├' + '─'.repeat(BOX_WIDTH) + '┤');
});

test('boxBottom: bottom corners + horizontal fill', () => {
  assert.equal(BoxDraw.boxBottom(), '└' + '─'.repeat(BOX_WIDTH) + '┘');
});

// ──────────────────────────────────────────────────────────────────────
// boxLine
// ──────────────────────────────────────────────────────────────────────

test('boxLine: short text padded to inner width', () => {
  const line = BoxDraw.boxLine('hi');
  assert.equal(line, '│ hi' + ' '.repeat(INNER_WIDTH - 2) + ' │');
});

test('boxLine: empty string still produces a padded line', () => {
  const line = BoxDraw.boxLine('');
  assert.equal(line, '│ ' + ' '.repeat(INNER_WIDTH) + ' │');
});

test('boxLine: null coerced to empty', () => {
  assert.equal(
    BoxDraw.boxLine(null),
    '│ ' + ' '.repeat(INNER_WIDTH) + ' │',
  );
});

test('boxLine: long text wraps into multiple lines joined by \\n', () => {
  const text = 'word '.repeat(40).trim();
  const out = BoxDraw.boxLine(text);
  assert.ok(out.includes('\n'));
  for (const ln of out.split('\n')) {
    assert.ok(ln.startsWith('│ '));
    assert.ok(ln.endsWith(' │'));
    assert.equal(ln.length, TOTAL_WIDTH);
  }
});

test('boxLine: word wider than INNER_WIDTH overflows (no pad)', () => {
  // When a single word exceeds INNER_WIDTH, pad becomes empty (Math.max ... 0).
  const longWord = 'a'.repeat(INNER_WIDTH + 4);
  const line = BoxDraw.boxLine(longWord);
  assert.equal(line, '│ ' + longWord + ' │');
});

// ──────────────────────────────────────────────────────────────────────
// boxCenterLine
// ──────────────────────────────────────────────────────────────────────

test('boxCenterLine: short text centered with equal-ish padding', () => {
  const line = BoxDraw.boxCenterLine('hi');
  // INNER_WIDTH 58, text 'hi' (2). total=56, left=28, right=28.
  assert.equal(line, '│ ' + ' '.repeat(28) + 'hi' + ' '.repeat(28) + ' │');
});

test('boxCenterLine: odd-leftover padding lands the extra space on the right', () => {
  // text length 3 -> total = 55, left=27, right=28
  const line = BoxDraw.boxCenterLine('foo');
  assert.ok(line.startsWith('│ ' + ' '.repeat(27) + 'foo'));
  assert.equal(line.length, TOTAL_WIDTH);
});

test('boxCenterLine: empty string fills the whole inner width with spaces', () => {
  assert.equal(BoxDraw.boxCenterLine(''), '│ ' + ' '.repeat(INNER_WIDTH) + ' │');
});

test('boxCenterLine: null treated as empty string', () => {
  assert.equal(BoxDraw.boxCenterLine(null), '│ ' + ' '.repeat(INNER_WIDTH) + ' │');
});

test('boxCenterLine: text wider than INNER_WIDTH falls back to boxLine wrapping', () => {
  const text = 'word '.repeat(40).trim();
  const out = BoxDraw.boxCenterLine(text);
  // Falls back to boxLine — output should contain \n from wrapping.
  assert.ok(out.includes('\n'));
});

// ──────────────────────────────────────────────────────────────────────
// Heavy variants
// ──────────────────────────────────────────────────────────────────────

test('boxHeavyTop / Divider / Bottom use double-line glyphs', () => {
  assert.equal(BoxDraw.boxHeavyTop(),     '╔' + '═'.repeat(BOX_WIDTH) + '╗');
  assert.equal(BoxDraw.boxHeavyDivider(), '╠' + '═'.repeat(BOX_WIDTH) + '╣');
  assert.equal(BoxDraw.boxHeavyBottom(),  '╚' + '═'.repeat(BOX_WIDTH) + '╝');
});

test('boxHeavyLine: short text padded with heavy borders', () => {
  assert.equal(
    BoxDraw.boxHeavyLine('hi'),
    '║ hi' + ' '.repeat(INNER_WIDTH - 2) + ' ║',
  );
});

test('boxHeavyLine: null coerced to empty', () => {
  assert.equal(
    BoxDraw.boxHeavyLine(null),
    '║ ' + ' '.repeat(INNER_WIDTH) + ' ║',
  );
});

test('boxHeavyLine: wraps long text', () => {
  const text = 'x '.repeat(50).trim();
  const out = BoxDraw.boxHeavyLine(text);
  assert.ok(out.includes('\n'));
  for (const ln of out.split('\n')) {
    assert.ok(ln.startsWith('║ '));
    assert.ok(ln.endsWith(' ║'));
  }
});

test('boxHeavyLine: word wider than INNER_WIDTH overflows (no pad)', () => {
  const longWord = 'a'.repeat(INNER_WIDTH + 4);
  assert.equal(BoxDraw.boxHeavyLine(longWord), '║ ' + longWord + ' ║');
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branches: the IIFE wrapper checks `typeof self` and
// the module-exports gate checks `typeof module`. In a default Node CJS
// load, `self` is undefined and `module` is defined — covers one arm of
// each. To cover the other arms we'd need to load the file under a
// shimmed environment, which is more brittle than the small coverage
// uplift warrants here. (The module.exports arm is the production path
// for Node tests; the `self` arm runs only in browsers.)
// ──────────────────────────────────────────────────────────────────────

test('IIFE wrapper: re-loads under defined `self` so the browser arm runs', () => {
  // Branch coverage for the IIFE wrapper's `typeof self !== 'undefined'
  // ? self : this` ternary. The inner `module.exports` gate still runs
  // the CJS-export arm under require(), so this test alone doesn't cover
  // lines 129-130 (the `root.NasfaaBoxDraw = BoxDraw` arm) — that needs
  // the vm.runInThisContext test below, which evaluates the source
  // outside a CJS module wrapper.
  const resolved = require.resolve('./box-draw.js');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    delete require.cache[resolved];
    const reloaded = require('./box-draw.js');
    assert.equal(typeof reloaded.boxTop, 'function');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
    delete require.cache[resolved];
    require('./box-draw.js');
  }
});

test('browser-arm: module-export gate falls through to root.NasfaaBoxDraw', () => {
  // V8 instruments per Script. By passing `filename` to runInThisContext,
  // the eval'd source registers under the same path as the require'd
  // module, so its coverage merges. Inside the eval, `module` is
  // undefined (we're outside the CJS wrapper), so the export gate's
  // else arm runs and `root.NasfaaBoxDraw = BoxDraw` executes.
  const src = readFileSync(BOX_DRAW_PATH, 'utf8');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    vm.runInThisContext(src, { filename: BOX_DRAW_PATH });
    assert.ok(globalThis.self.NasfaaBoxDraw, 'expected browser arm to attach to self');
    assert.equal(typeof globalThis.self.NasfaaBoxDraw.boxTop, 'function');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
  }
});
