// test-glyphs.mjs — Node tests for web/shared/glyphs.js.
//
//   node --test web/shared/test-glyphs.mjs
//
// glyphs.js is a tiny constants module; tests mostly exist for branch
// coverage of the environment-guard wrappers (typeof self, typeof module).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const Glyphs = require('./glyphs.js');
const GLYPHS_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'glyphs.js');

test('ARROW_SEP is the spaced right arrow', () => {
  assert.equal(Glyphs.ARROW_SEP, ' → ');
});

test('CHECK and CROSS are the heavy outcome glyphs', () => {
  assert.equal(Glyphs.CHECK, '✔');
  assert.equal(Glyphs.CROSS, '✘');
});

test('module exports exactly three keys', () => {
  assert.deepEqual(Object.keys(Glyphs).sort(), ['ARROW_SEP', 'CHECK', 'CROSS']);
});

test('browser arm: IIFE wrapper picks `self` when defined; module gate falls to root', () => {
  // Same trick as quiz/test-box-draw.mjs: evaluate the source outside a
  // CJS wrapper so the IIFE sees `module` as undefined and falls into the
  // `root.NasfaaGlyphs = ...` else arm. Passing the original path as
  // filename merges V8 coverage into the same source file.
  const src = readFileSync(GLYPHS_PATH, 'utf8');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    vm.runInThisContext(src, { filename: GLYPHS_PATH });
    assert.ok(globalThis.self.NasfaaGlyphs, 'expected browser arm to attach to self');
    assert.equal(globalThis.self.NasfaaGlyphs.ARROW_SEP, ' → ');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
  }
});
