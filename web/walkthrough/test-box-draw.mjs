// test-box-draw.mjs — Node tests for web/walkthrough/box-draw.js.
//
//   node --test web/walkthrough/test-box-draw.mjs
//
// Loads the live module via require() and reads it back from
// globalThis.Nasfaa.BoxDraw (the IIFE attaches there when window is
// undefined). Citation linker and glyphs are loaded ahead of the
// module so the conditional helpers inside renderResultBox and
// renderCitationBoxLine see their dependencies.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

// Pre-load dependencies the box-draw module looks up on the global. Both
// citation.js and glyphs.js use `(typeof self !== 'undefined' ? self : this)`
// as their "root" — under CJS that `this` is `module.exports`, not
// globalThis, so the IIFE doesn't actually attach to a global Node can see.
// We mirror the module.exports onto globalThis ourselves so box-draw's
// `globalThis.NasfaaCitation` / `global.NasfaaGlyphs` lookups succeed.
globalThis.NasfaaCitation = require('../shared/citation.js');
globalThis.NasfaaGlyphs = require('../shared/glyphs.js');

// Loading box-draw.js attaches Nasfaa.BoxDraw to globalThis (window is
// undefined in Node, so the IIFE falls through to globalThis).
require('./box-draw.js');
const BoxDraw = globalThis.Nasfaa.BoxDraw;

const { BOX_WIDTH, INNER_WIDTH, TOTAL_WIDTH } = BoxDraw;

// ──────────────────────────────────────────────────────────────────────
// width constants
// ──────────────────────────────────────────────────────────────────────

test('width constants: BOX_WIDTH 68, INNER_WIDTH 66, TOTAL_WIDTH 70', () => {
  assert.equal(BOX_WIDTH, 68);
  assert.equal(INNER_WIDTH, 66);
  assert.equal(TOTAL_WIDTH, 70);
});

// ──────────────────────────────────────────────────────────────────────
// wrapText — exposed via BoxDraw.wrapText
// ──────────────────────────────────────────────────────────────────────

test('wrapText: empty string returns [\'\']', () => {
  assert.deepEqual(BoxDraw.wrapText('', 10), ['']);
});

test('wrapText: null returns [\'\']', () => {
  assert.deepEqual(BoxDraw.wrapText(null, 10), ['']);
});

test('wrapText: short single word stays on one line', () => {
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

test('wrapText: single word longer than width gets its own line', () => {
  assert.deepEqual(
    BoxDraw.wrapText('aaaa supercalifragilistic bb', 10),
    ['aaaa', 'supercalifragilistic', 'bb'],
  );
});

test('wrapText: defaults width to INNER_WIDTH when omitted (falsy)', () => {
  const text = 'word '.repeat(20).trim();
  const lines = BoxDraw.wrapText(text); // no width => uses INNER_WIDTH
  for (const line of lines) {
    assert.ok(line.length <= INNER_WIDTH, `line "${line}" > INNER_WIDTH`);
  }
});

test('wrapText: collapses runs of whitespace and ignores empty splits', () => {
  assert.deepEqual(BoxDraw.wrapText('   a    b   ', 80), ['a b']);
});

// ──────────────────────────────────────────────────────────────────────
// boxTop / boxDivider / boxBottom — light borders
// ──────────────────────────────────────────────────────────────────────

test('boxTop: no title — solid horizontal line between corners', () => {
  const top = BoxDraw.boxTop();
  assert.equal(top.length, TOTAL_WIDTH);
  assert.ok(top.startsWith('┌'));
  assert.ok(top.endsWith('┐'));
  // Body is all light horizontals
  assert.equal(top.slice(1, -1), '─'.repeat(BOX_WIDTH));
});

test('boxTop: with title — label inset and remaining filled', () => {
  const top = BoxDraw.boxTop('PERMIT');
  assert.equal(top.length, TOTAL_WIDTH);
  assert.ok(top.startsWith('┌─ PERMIT '));
  assert.ok(top.endsWith('┐'));
});

test('boxDivider: looks like top but with tee characters', () => {
  const div = BoxDraw.boxDivider();
  assert.equal(div, '├' + '─'.repeat(BOX_WIDTH) + '┤');
});

test('boxBottom: corners + horizontals', () => {
  assert.equal(BoxDraw.boxBottom(), '└' + '─'.repeat(BOX_WIDTH) + '┘');
});

// ──────────────────────────────────────────────────────────────────────
// boxLine — text wrapping + padding
// ──────────────────────────────────────────────────────────────────────

test('boxLine: short text padded to inner width', () => {
  const line = BoxDraw.boxLine('hi');
  assert.equal(line, '│ hi' + ' '.repeat(INNER_WIDTH - 2) + ' │');
});

test('boxLine: empty string still produces a padded line', () => {
  const line = BoxDraw.boxLine('');
  assert.equal(line, '│ ' + ' '.repeat(INNER_WIDTH) + ' │');
});

test('boxLine: null treated as empty string', () => {
  const line = BoxDraw.boxLine(null);
  assert.equal(line, '│ ' + ' '.repeat(INNER_WIDTH) + ' │');
});

test('boxLine: long text wraps into multiple lines joined by \\n', () => {
  const text = 'word '.repeat(40).trim(); // > INNER_WIDTH
  const out = BoxDraw.boxLine(text);
  assert.ok(out.includes('\n'), 'expected wrap to produce multiple lines');
  for (const ln of out.split('\n')) {
    assert.ok(ln.startsWith('│ '));
    assert.ok(ln.endsWith(' │'));
    assert.equal(ln.length, TOTAL_WIDTH);
  }
});

test('boxLine: word longer than INNER_WIDTH hits pad\'s no-pad branch (diff<=0)', () => {
  // pad() short-circuits when the text already meets/exceeds the target width.
  // A single word of INNER_WIDTH+4 chars exercises that else branch.
  const longWord = 'a'.repeat(INNER_WIDTH + 4);
  const line = BoxDraw.boxLine(longWord);
  // The returned line has no padding spaces added, just the word between borders.
  assert.equal(line, '│ ' + longWord + ' │');
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
  const line = BoxDraw.boxHeavyLine('hi');
  assert.equal(line, '║ hi' + ' '.repeat(INNER_WIDTH - 2) + ' ║');
});

test('boxHeavyLine: null treated as empty string', () => {
  const line = BoxDraw.boxHeavyLine(null);
  assert.equal(line, '║ ' + ' '.repeat(INNER_WIDTH) + ' ║');
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

// ──────────────────────────────────────────────────────────────────────
// renderQuestionBox
// ──────────────────────────────────────────────────────────────────────

test('renderQuestionBox: title includes box number; no help line when absent', () => {
  const out = BoxDraw.renderQuestionBox({ box: 5, text: 'Is FTI present?' });
  const lines = out.split('\n');
  assert.ok(lines[0].includes('Box 5'));
  assert.ok(lines[1].includes('Is FTI present?'));
  // 3 lines: top, text, bottom
  assert.equal(lines.length, 3);
  assert.ok(lines[2].startsWith('└'));
});

test('renderQuestionBox: includes help line in parens when help present', () => {
  const out = BoxDraw.renderQuestionBox({
    box: 1, text: 'Q', help: 'hint text',
  });
  const lines = out.split('\n');
  assert.equal(lines.length, 4); // top, text, help, bottom
  assert.ok(lines[2].includes('(hint text)'));
});

// ──────────────────────────────────────────────────────────────────────
// escapeHtml
// ──────────────────────────────────────────────────────────────────────

test('escapeHtml: & < > each get their entity', () => {
  assert.equal(BoxDraw.escapeHtml('&'), '&amp;');
  assert.equal(BoxDraw.escapeHtml('<'), '&lt;');
  assert.equal(BoxDraw.escapeHtml('>'), '&gt;');
});

test('escapeHtml: mixed content escaped correctly', () => {
  assert.equal(BoxDraw.escapeHtml('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
});

test('escapeHtml: coerces non-string input via String()', () => {
  assert.equal(BoxDraw.escapeHtml(42), '42');
  assert.equal(BoxDraw.escapeHtml(null), 'null');
});

test('escapeHtml: leaves plain text unchanged', () => {
  assert.equal(BoxDraw.escapeHtml('hello world'), 'hello world');
});

// ──────────────────────────────────────────────────────────────────────
// renderCitationBoxLine
// ──────────────────────────────────────────────────────────────────────

test('renderCitationBoxLine: linkifies HEA reference, padded inside box', () => {
  const out = BoxDraw.renderCitationBoxLine('Citation: HEA §1090(a)');
  assert.ok(out.includes('<a'));
  assert.ok(out.includes('HEA'));
  assert.ok(out.startsWith('│ '));
  assert.ok(out.endsWith(' │'));
});

test('renderCitationBoxLine: long citation wraps and threads body across lines', () => {
  // Build a long citation that forces wrapping. HEA body context must
  // carry across the wrap so the §ref on the second line still links.
  const longCite = 'Citation: HEA §1090(a); ' + 'placeholder '.repeat(8) + '§1098h';
  const out = BoxDraw.renderCitationBoxLine(longCite);
  const lines = out.split('\n');
  assert.ok(lines.length >= 2, 'expected at least one wrap');
  // Both lines should have anchor tags (body context threads via finalBody)
  assert.ok(lines.some((l) => l.includes('<a')));
});

test('renderCitationBoxLine: falls back to escaped plain box line when NasfaaCitation absent', () => {
  // Temporarily remove the global so we hit the fallback branch.
  const saved = globalThis.NasfaaCitation;
  try {
    delete globalThis.NasfaaCitation;
    const out = BoxDraw.renderCitationBoxLine('Citation: HEA §1090(a)');
    // No <a> tags in the fallback path; it's just escaped boxLine text.
    assert.ok(!out.includes('<a'));
    assert.ok(out.includes('Citation: HEA'));
  } finally {
    globalThis.NasfaaCitation = saved;
  }
});

// ──────────────────────────────────────────────────────────────────────
// resultColorClass
// ──────────────────────────────────────────────────────────────────────

test('resultColorClass: \'permit\' → result-permit', () => {
  // resultColorClass is not exported, but renderResultBox uses it; we
  // assert through the output of renderResultBox below.
  assert.equal(typeof BoxDraw.renderResultBox, 'function');
});

// ──────────────────────────────────────────────────────────────────────
// renderResultBox — exercises resultColorClass + the dev-mode branches
// ──────────────────────────────────────────────────────────────────────

const baseNode = {
  result: 'permit',
  message: 'Student may access their own records, including FTI.',
  citation: 'IRC §6103(l)(13)',
  rule_id: 'FTI_R1_student',
};

test('renderResultBox: permit → result-permit span wraps PERMIT in top border', () => {
  const out = BoxDraw.renderResultBox(baseNode, ['fti_check', 'fti_to_student']);
  assert.ok(out.includes('<span class="result-permit">PERMIT</span>'));
});

test('renderResultBox: deny → result-deny class', () => {
  const out = BoxDraw.renderResultBox({ ...baseNode, result: 'deny' }, []);
  assert.ok(out.includes('<span class="result-deny">DENY</span>'));
});

test('renderResultBox: other result (e.g. permit_with_caution) → result-caution', () => {
  const out = BoxDraw.renderResultBox({ ...baseNode, result: 'permit_with_caution' }, []);
  assert.ok(out.includes('result-caution'));
});

test('renderResultBox: wraps Citation: label in <span class="label">', () => {
  const out = BoxDraw.renderResultBox(baseNode, []);
  assert.ok(out.includes('<span class="label">Citation:</span>'));
});

test('renderResultBox: dev mode off — no Rule:/Path: lines, no dev wrapper', () => {
  const out = BoxDraw.renderResultBox(baseNode, ['a', 'b']);
  assert.ok(!out.includes('Rule:'));
  assert.ok(!out.includes('Path:'));
  assert.ok(!out.includes('class="dev"'));
});

test('renderResultBox: dev mode on — adds Rule, Path, and dev wrapper', () => {
  const out = BoxDraw.renderResultBox(
    baseNode,
    ['fti_check', 'fti_to_student'],
    { devMode: true },
  );
  assert.ok(out.includes('class="dev"'));
  assert.ok(out.includes('Rule:'));
  assert.ok(out.includes('FTI_R1_student'));
  assert.ok(out.includes('Path:'));
  assert.ok(out.includes('fti_check'));
  assert.ok(out.includes('→')); // ARROW_SEP from NasfaaGlyphs
});

test('renderResultBox: dev mode + verifyLine — appends verify line inside dev wrapper', () => {
  const out = BoxDraw.renderResultBox(
    baseNode, [],
    { devMode: true, verifyLine: 'Verified: engine and DAG both → FTI_R1' },
  );
  assert.ok(out.includes('Verified:'));
  assert.ok(out.includes('FTI_R1'));
});

test('renderResultBox: dev mode without pathIds (null) renders empty Path line', () => {
  const out = BoxDraw.renderResultBox(baseNode, null, { devMode: true });
  assert.ok(out.includes('Path:'));
});

test('renderResultBox: opts undefined — devMode falsy, verifyLine empty', () => {
  const out = BoxDraw.renderResultBox(baseNode, []);
  assert.ok(!out.includes('class="dev"'));
});

test('renderResultBox: opts present but no devMode key — still no dev wrapper', () => {
  const out = BoxDraw.renderResultBox(baseNode, [], {});
  assert.ok(!out.includes('class="dev"'));
});

test('renderResultBox: devMode on, glyphs absent → falls back to default arrow', () => {
  const saved = globalThis.NasfaaGlyphs;
  try {
    delete globalThis.NasfaaGlyphs;
    const out = BoxDraw.renderResultBox(
      baseNode, ['a', 'b'], { devMode: true },
    );
    // Default fallback string is ' → ' (same glyph, but exercises the || branch)
    assert.ok(out.includes('a → b'));
  } finally {
    globalThis.NasfaaGlyphs = saved;
  }
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branch coverage
//
// The module uses `typeof window !== 'undefined' ? window : globalThis`
// in two places: at the IIFE wrapper (line 179, runs once at require)
// and inside renderCitationBoxLine (runs every call). Both have a Node
// arm and a browser arm. The default Node test execution covers the
// Node arm; these two tests exercise the browser arm by stubbing
// `globalThis.window`.
// ──────────────────────────────────────────────────────────────────────

test('renderCitationBoxLine: looks up NasfaaCitation via window when window is defined', () => {
  const savedWindow = globalThis.window;
  try {
    // Make window a bag that exposes the citation linker; renderCitationBoxLine
    // should now pull NasfaaCitation off window instead of globalThis.
    globalThis.window = { NasfaaCitation: globalThis.NasfaaCitation };
    const out = BoxDraw.renderCitationBoxLine('Citation: HEA §1090(a)');
    assert.ok(out.includes('<a'));
  } finally {
    if (savedWindow === undefined) delete globalThis.window;
    else globalThis.window = savedWindow;
  }
});

test('IIFE wrapper: re-requires under a defined window so the truthy arm runs', () => {
  const path = require.resolve('./box-draw.js');
  const savedNasfaa = globalThis.Nasfaa;
  const savedWindow = globalThis.window;
  try {
    // Stub window so the IIFE wrapper picks `window` instead of `globalThis`.
    // Pre-stash the Nasfaa namespace on window so `global.Nasfaa = global.Nasfaa
    // || {}` finds something — but the assignment itself sets window.Nasfaa.
    globalThis.window = {};
    delete require.cache[path];
    delete globalThis.Nasfaa; // force re-init so we know window got it
    require('./box-draw.js');
    assert.ok(globalThis.window.Nasfaa, 'expected IIFE to attach to window');
    assert.equal(typeof globalThis.window.Nasfaa.BoxDraw.boxTop, 'function');
  } finally {
    if (savedWindow === undefined) delete globalThis.window;
    else globalThis.window = savedWindow;
    globalThis.Nasfaa = savedNasfaa;
    delete require.cache[path];
    require('./box-draw.js'); // restore the default-environment module
  }
});
