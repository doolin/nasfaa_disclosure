// test-engine.mjs — Node tests for web/quiz/engine.js.
//
//   node --test web/quiz/test-engine.mjs
//
// Quiz's engine module exports via module.exports, so it loads directly
// through require. Same first-match-wins evaluator as the walkthrough's
// engine.js, but with a stricter cond-type guard and explicit nulls for
// missing scope/caution notes.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { RuleEngine, DISCLOSURE_FIELDS } = require('./engine.js');
const ENGINE_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'engine.js');

// ──────────────────────────────────────────────────────────────────────
// DISCLOSURE_FIELDS
// ──────────────────────────────────────────────────────────────────────

test('DISCLOSURE_FIELDS is a frozen list of 20 field names', () => {
  assert.equal(DISCLOSURE_FIELDS.length, 20);
  assert.ok(Object.isFrozen(DISCLOSURE_FIELDS));
  assert.ok(DISCLOSURE_FIELDS.includes('includes_fti'));
  assert.ok(DISCLOSURE_FIELDS.includes('contains_pii'));
});

// ──────────────────────────────────────────────────────────────────────
// Constructor
// ──────────────────────────────────────────────────────────────────────

test('constructor: stores the rules array', () => {
  const rules = [{ id: 'R1', when_all: ['x'], result: 'permit' }];
  assert.equal(new RuleEngine(rules).rules, rules);
});

test('constructor: throws TypeError when rules is not an array', () => {
  assert.throws(() => new RuleEngine(null), TypeError);
  assert.throws(() => new RuleEngine(undefined), TypeError);
  assert.throws(() => new RuleEngine({}), TypeError);
});

// ──────────────────────────────────────────────────────────────────────
// evaluate
// ──────────────────────────────────────────────────────────────────────

test('evaluate: first matching rule wins and returns trace shape', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['nope'],         result: 'deny' },
    { id: 'R2', when_all: ['includes_fti'], result: 'permit', scope_note: 'students' },
  ]);
  const trace = engine.evaluate({ includes_fti: true });
  assert.deepEqual(trace, {
    ruleId: 'R2',
    result: 'permit',
    path: ['R1', 'R2'],
    scopeNote: 'students',
    cautionNote: null,
  });
});

test('evaluate: no match → null', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['needed'], result: 'permit' },
  ]);
  assert.equal(engine.evaluate({}), null);
});

test('evaluate: inputs omitted → empty bag', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['needed'], result: 'permit' },
  ]);
  assert.equal(engine.evaluate(), null);
  assert.equal(engine.evaluate(null), null);
});

test('evaluate: cautionNote propagates when present, defaults to null otherwise', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['x'], result: 'permit_with_caution', caution_note: 'check scope' },
  ]);
  assert.equal(engine.evaluate({ x: true }).cautionNote, 'check scope');
});

test('evaluate: scopeNote falsy collapses to null (|| null branch)', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['x'], result: 'permit', scope_note: '' },
  ]);
  assert.equal(engine.evaluate({ x: true }).scopeNote, null);
});

test('evaluate: path is a copy (mutating it does not affect later evaluations)', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['x'], result: 'permit' },
  ]);
  const trace = engine.evaluate({ x: true });
  trace.path.push('mutated');
  assert.deepEqual(engine.evaluate({ x: true }).path, ['R1']);
});

// ──────────────────────────────────────────────────────────────────────
// _matches
// ──────────────────────────────────────────────────────────────────────

test('_matches: positive condition true', () => {
  const engine = new RuleEngine([{ id: 'R1', when_all: ['x'], result: 'permit' }]);
  assert.ok(engine.evaluate({ x: true }));
});

test('_matches: positive condition false (missing key counts as false)', () => {
  const engine = new RuleEngine([{ id: 'R1', when_all: ['x'], result: 'permit' }]);
  assert.equal(engine.evaluate({}), null);
});

test('_matches: leading "!" negates', () => {
  const engine = new RuleEngine([{ id: 'R1', when_all: ['!x'], result: 'permit' }]);
  assert.ok(engine.evaluate({ x: false }));
  assert.ok(engine.evaluate({}));
  assert.equal(engine.evaluate({ x: true }), null);
});

test('_matches: non-string condition short-circuits to false', () => {
  // Defensive guard for malformed rules data — neither arm of startsWith
  // would be safe to run on a non-string, so the rule simply doesn't match.
  const engine = new RuleEngine([{ id: 'R1', when_all: [42], result: 'permit' }]);
  assert.equal(engine.evaluate({ x: true }), null);
});

test('_matches: missing when_all key → empty conditions → always matches', () => {
  // The `rule.when_all || []` fallback turns missing/undefined into [];
  // every() on an empty array is vacuously true.
  const engine = new RuleEngine([{ id: 'R1', result: 'permit' }]);
  const trace = engine.evaluate({});
  assert.equal(trace.ruleId, 'R1');
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branches: same vm.runInThisContext trick as
// quiz/test-box-draw.mjs to cover the browser arm of the IIFE wrapper
// AND the else branch of the module-exports gate.
// ──────────────────────────────────────────────────────────────────────

test('browser arm: IIFE picks `self`; module gate falls through to root.NasfaaEngine', () => {
  const src = readFileSync(ENGINE_PATH, 'utf8');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    vm.runInThisContext(src, { filename: ENGINE_PATH });
    assert.ok(globalThis.self.NasfaaEngine, 'expected attach to self');
    assert.equal(typeof globalThis.self.NasfaaEngine.RuleEngine, 'function');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
  }
});
