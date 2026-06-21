// test-citation.mjs — Node tests for the shared citation linkifier.
//
//   node --test web/quiz/test-citation.mjs
//
// Exits 0 on all-pass, 1 on any failure. No npm dependency — uses
// node:test and node:assert. Imports the live implementation from
// web/shared/citation.js so the tests cover the real module, not a
// drift-prone copy.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// citation.js is a plain IIFE script that attaches NasfaaCitation to a
// root object — works under both browser (window) and Node (module.exports).
// Loading it via createRequire keeps the test file ESM while the module
// stays CJS-compatible.
const require = createRequire(import.meta.url);
const { CITATION_BODIES, linkifyCitation } = require('../shared/citation.js');

function escapeHtml(s) {
  return String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
}

// Convenience for tests: just return the html.
const linkify = (text, init) => linkifyCitation(escapeHtml(text), init).html;

// ──────────────────────────────────────────────────────────────────────
// escapeHtml
// ──────────────────────────────────────────────────────────────────────

test('escapeHtml escapes ampersand, less-than, greater-than', () => {
  assert.equal(escapeHtml('a & b'), 'a &amp; b');
  assert.equal(escapeHtml('<script>'), '&lt;script&gt;');
  assert.equal(escapeHtml('Tom & <Jerry>'), 'Tom &amp; &lt;Jerry&gt;');
});

test('escapeHtml leaves and other safe unicode alone', () => {
  assert.equal(escapeHtml('1090(a)'), '1090(a)');
  assert.equal(escapeHtml('café — em-dash'), 'café — em-dash');
});

test('escapeHtml is idempotent only on already-escaped HTML in the sense that & re-escapes', () => {
  // Documented quirk: running twice double-escapes ampersand entities.
  // This is fine for our use case — render() runs escape exactly once.
  assert.equal(escapeHtml('&amp;'), '&amp;amp;');
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — single-body, single-section
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: HEA single section with subsection', () => {
  const out = linkify('HEA 1090(a)');
  assert.match(out, /<a class="citation-link" href="https:\/\/www\.law\.cornell\.edu\/uscode\/text\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
});

test('linkifyCitation: IRC section uses Title 26', () => {
  const out = linkify('IRC 6103(l)(13)');
  assert.match(out, /href="https:\/\/www\.law\.cornell\.edu\/uscode\/text\/26\/6103"/);
  assert.match(out, />IRC 6103\(l\)\(13\)<\/a>/);
});

test('linkifyCitation: FERPA section uses ecfr', () => {
  const out = linkify('FERPA 34 CFR 99.31(a)(1)');
  assert.match(out, /href="https:\/\/www\.ecfr\.gov\/current\/title-34\/section-99\.31"/);
  assert.match(out, />FERPA 34 CFR 99\.31\(a\)\(1\)<\/a>/);
});

test('linkifyCitation: section with letter suffix (1098h)', () => {
  const out = linkify('HEA 1098h');
  assert.match(out, /href=".*\/20\/1098h"/);
  assert.match(out, />HEA 1098h<\/a>/);
});

test('linkifyCitation: deeply nested subsections still link to base section', () => {
  const out = linkify('HEA 1090(a)(3)(C)');
  assert.match(out, /href=".*\/20\/1090"/);
  assert.match(out, />HEA 1090\(a\)\(3\)\(C\)<\/a>/);
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — body context across chunks (no body name in chunk)
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: refs after a HEA chunk inherit HEA url', () => {
  const out = linkify('HEA 1090(a); 1098h');
  // 1090(a) links with body in anchor text
  assert.match(out, /href=".*\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
  // 1098h links via inherited HEA context, anchor text is just the section
  assert.match(out, /href=".*\/20\/1098h"[^>]*>1098h<\/a>/);
});

test('linkifyCitation: new body name in a later chunk switches context', () => {
  const out = linkify('HEA 1090(a); FERPA 34 CFR 99.31(a)(1)');
  assert.match(out, /href=".*\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
  assert.match(out, /href=".*\/section-99\.31"[^>]*>FERPA 34 CFR 99\.31\(a\)\(1\)<\/a>/);
});

test('linkifyCitation: three-body chain (HEA, then HEA-inherited, then FERPA)', () => {
  const out = linkify('HEA 1090(a); 1098h; FERPA 34 CFR 99.31(a)(1) — aid admin');
  assert.match(out, /href=".*\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
  assert.match(out, /href=".*\/20\/1098h"[^>]*>1098h<\/a>/);
  assert.match(out, /href=".*\/section-99\.31"[^>]*>FERPA 34 CFR 99\.31\(a\)\(1\)<\/a>/);
  // Em-dash and trailing text survive unchanged
  assert.match(out, / — aid admin$/);
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — cross-line body inheritance
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: initialBody seeds context (simulates wrapped line)', () => {
  // Second line of a wrapped citation starts with refs whose body was named
  // on the previous line. Caller threads the finalBody through.
  const heaBody = CITATION_BODIES.find((b) => b.name === 'HEA');
  const out = linkifyCitation(escapeHtml('1098h'), heaBody).html;
  assert.match(out, /href=".*\/20\/1098h"[^>]*>1098h<\/a>/);
});

test('linkifyCitation: finalBody returned matches last body seen', () => {
  const result = linkifyCitation(escapeHtml('HEA 1090; FERPA 34 CFR 99.31'), null);
  assert.equal(result.finalBody.name, 'FERPA');
});

test('linkifyCitation: finalBody persists when only one body is named', () => {
  const result = linkifyCitation(escapeHtml('IRC 6103(l)'), null);
  assert.equal(result.finalBody.name, 'IRC');
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — body-only chunks (no ref)
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: body-only chunk updates context for later chunks', () => {
  // "FERPA does not apply" is a real pattern in scenarios.yml. No ref in the
  // first chunk, but later chunks should pick up FERPA as the body.
  const out = linkify('FERPA does not apply to de-identified data; 99.31 still cited');
  assert.match(out, /href=".*\/section-99\.31"/);
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — prefix text doesn't suppress linking
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: "Citation:" prefix doesn\'t suppress body detection', () => {
  // Regression: an earlier impl used startsWith() which failed when the body
  // name wasn't literally at chunk start (e.g. prefixed with "Citation: ").
  const out = linkify('Citation: HEA 1090(a)');
  assert.match(out, /href=".*\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
});

// ──────────────────────────────────────────────────────────────────────
// linkifyCitation — degenerate / edge inputs
// ──────────────────────────────────────────────────────────────────────

test('linkifyCitation: empty string returns empty', () => {
  assert.equal(linkify(''), '');
});

test('linkifyCitation: text with no ref and no body is returned as-is', () => {
  assert.equal(linkify('plain text with no citation'), 'plain text with no citation');
});

test('linkifyCitation: ref with no body context is left alone (not linked)', () => {
  // No prior body anywhere — can't know which URL to use.
  assert.equal(linkify('99.31 with no body'), '99.31 with no body');
});

test('linkifyCitation: HTML-special chars in citation are pre-escaped', () => {
  // Caller always escapes first. The linkifier should not double-escape.
  // (We feed already-escaped input via the `linkify` helper.)
  const out = linkify('HEA 1090 & 1098h');
  // The & became &amp; in the escape pass; linkifier doesn't touch it.
  assert.match(out, /&amp;/);
});

test('linkifyCitation: multiple refs in one chunk all get linked', () => {
  // Rare in the scenarios but the regex should handle it.
  const out = linkify('HEA 1090(a) and 1098h together');
  assert.match(out, /href=".*\/20\/1090"[^>]*>HEA 1090\(a\)<\/a>/);
  assert.match(out, /href=".*\/20\/1098h"[^>]*>1098h<\/a>/);
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branch coverage
//
// citation.js's IIFE wrapper picks `self` when defined and falls back
// to `this` (= module.exports under CJS), and its module-exports gate
// only attaches to root.NasfaaCitation as a side effect under browser
// scripts. Default Node load covers the CJS arms; this test covers
// the browser arms by evaluating the source in the current context
// with the original filename so V8 merges coverage into the same file.
// ──────────────────────────────────────────────────────────────────────

test('browser arm: IIFE picks `self` and falls through to root.NasfaaCitation', () => {
  const CITATION_PATH = path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    '..', 'shared', 'citation.js',
  );
  const src = readFileSync(CITATION_PATH, 'utf8');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    vm.runInThisContext(src, { filename: CITATION_PATH });
    assert.ok(globalThis.self.NasfaaCitation, 'expected attach to self');
    assert.equal(typeof globalThis.self.NasfaaCitation.linkifyCitation, 'function');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
  }
});
