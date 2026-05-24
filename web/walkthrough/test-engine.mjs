// test-engine.mjs — Node tests for web/walkthrough/engine.js.
//
//   node --test web/walkthrough/test-engine.mjs
//
// engine.js attaches RuleEngine / permitted / denied to
// globalThis.Nasfaa. Same load pattern as dag.js.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
require('./engine.js');
const { RuleEngine, permitted, denied } = globalThis.Nasfaa;
const ENGINE_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'engine.js');

// ──────────────────────────────────────────────────────────────────────
// RuleEngine constructor
// ──────────────────────────────────────────────────────────────────────

test('constructor: stores the rules array', () => {
  const rules = [{ id: 'R1', when_all: ['x'], result: 'permit' }];
  const engine = new RuleEngine(rules);
  assert.equal(engine.rules, rules);
});

test('constructor: throws TypeError when rules is not an array', () => {
  assert.throws(() => new RuleEngine(null), TypeError);
  assert.throws(() => new RuleEngine({}), TypeError);
  assert.throws(() => new RuleEngine('rules'), TypeError);
});

// ──────────────────────────────────────────────────────────────────────
// evaluate: first-match-wins, path accumulation, return shape
// ──────────────────────────────────────────────────────────────────────

test('evaluate: first matching rule wins and stops the scan', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['nope'],   result: 'deny' },
    { id: 'R2', when_all: ['has_fti'], result: 'permit', scope_note: 'students only' },
    { id: 'R3', when_all: ['has_fti'], result: 'permit_with_scope' }, // never reached
  ]);
  const trace = engine.evaluate({ has_fti: true });
  assert.equal(trace.ruleId, 'R2');
  assert.equal(trace.result, 'permit');
  assert.equal(trace.scopeNote, 'students only');
  assert.equal(trace.cautionNote, undefined);
  // path contains every rule scanned, in order, ending with the matched one
  assert.deepEqual(trace.path, ['R1', 'R2']);
});

test('evaluate: returns null when no rule matches', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['has_fti'], result: 'permit' },
  ]);
  assert.equal(engine.evaluate({}), null);
});

test('evaluate: returns a *copy* of the path (mutation-safe)', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['x'], result: 'permit' },
  ]);
  const trace = engine.evaluate({ x: true });
  trace.path.push('mutated');
  // Re-evaluating should not see the mutation
  const trace2 = engine.evaluate({ x: true });
  assert.deepEqual(trace2.path, ['R1']);
});

test('evaluate: inputs omitted → treated as empty bag', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['needed'], result: 'permit' },
  ]);
  assert.equal(engine.evaluate(), null);          // inputs undefined
  assert.equal(engine.evaluate(null), null);      // inputs null
});

test('evaluate: cautionNote propagates when present on the matched rule', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['x'], result: 'permit_with_caution', caution_note: 'use scope' },
  ]);
  const trace = engine.evaluate({ x: true });
  assert.equal(trace.cautionNote, 'use scope');
});

// ──────────────────────────────────────────────────────────────────────
// _matches: positive + negated conditions
// ──────────────────────────────────────────────────────────────────────

test('_matches: positive condition requires bag[key] to be truthy', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['a', 'b'], result: 'permit' },
  ]);
  assert.ok(engine.evaluate({ a: true, b: true }));
  assert.equal(engine.evaluate({ a: true, b: false }), null);
  assert.equal(engine.evaluate({ a: true }), null);
});

test('_matches: leading "!" negates — requires bag[key] to be falsy', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: ['!has_fti'], result: 'permit' },
  ]);
  assert.ok(engine.evaluate({ has_fti: false }));
  assert.ok(engine.evaluate({}));                  // missing => falsy
  assert.equal(engine.evaluate({ has_fti: true }), null);
});

test('_matches: empty when_all matches everything (every() of empty)', () => {
  const engine = new RuleEngine([
    { id: 'R1', when_all: [], result: 'permit' },
  ]);
  const trace = engine.evaluate({});
  assert.equal(trace.ruleId, 'R1');
});

// ──────────────────────────────────────────────────────────────────────
// permitted / denied helpers
// ──────────────────────────────────────────────────────────────────────

test('permitted: false when trace is null/undefined', () => {
  assert.equal(permitted(null), false);
  assert.equal(permitted(undefined), false);
});

test('permitted: true for permit, permit_with_scope, permit_with_caution', () => {
  assert.equal(permitted({ result: 'permit' }), true);
  assert.equal(permitted({ result: 'permit_with_scope' }), true);
  assert.equal(permitted({ result: 'permit_with_caution' }), true);
});

test('permitted: false for deny or unknown result strings', () => {
  assert.equal(permitted({ result: 'deny' }), false);
  assert.equal(permitted({ result: 'unspecified' }), false);
});

test('denied: false when trace is null/undefined', () => {
  assert.equal(denied(null), false);
  assert.equal(denied(undefined), false);
});

test('denied: true only when result === "deny"', () => {
  assert.equal(denied({ result: 'deny' }), true);
  assert.equal(denied({ result: 'permit' }), false);
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branch
// ──────────────────────────────────────────────────────────────────────

test('IIFE wrapper: re-loads under defined `window` so the browser arm runs', () => {
  const src = readFileSync(ENGINE_PATH, 'utf8');
  const savedWindow = globalThis.window;
  try {
    globalThis.window = {};
    vm.runInThisContext(src, { filename: ENGINE_PATH });
    assert.ok(globalThis.window.Nasfaa.RuleEngine);
    assert.equal(typeof globalThis.window.Nasfaa.permitted, 'function');
    assert.equal(typeof globalThis.window.Nasfaa.denied, 'function');
  } finally {
    if (savedWindow === undefined) delete globalThis.window;
    else globalThis.window = savedWindow;
  }
});
