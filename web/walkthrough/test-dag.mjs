// test-dag.mjs — Node tests for web/walkthrough/dag.js.
//
//   node --test web/walkthrough/test-dag.mjs
//
// dag.js attaches a DagWalker class to globalThis.Nasfaa.DagWalker via
// its IIFE (no module.exports). We require() it for side effects, then
// pull the class off the global. Tests use a small hand-built question
// graph that exercises every branch.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
require('./dag.js');
const DagWalker = globalThis.Nasfaa.DagWalker;
const DAG_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dag.js');

// Compact fixture: one question with single `field`, one with `fields`
// array, one with a falsy field (exercises the `if (!f) continue` arm),
// and a result node for each branch.
function buildFixture() {
  return {
    start: 'q1',
    nodes: {
      q1: { type: 'question', field: 'has_fti', on_yes: 'q2', on_no: 'r_no_fti' },
      q2: { type: 'question', fields: ['to_student', 'is_self'], on_yes: 'r_permit_student', on_no: 'q3' },
      q3: { type: 'question', field: null, on_yes: 'r_deny', on_no: 'r_caution' },
      r_no_fti:           { type: 'result', rule_id: 'FTI_R0', result: 'permit', message: 'No FTI present.', citation: 'IRC 6103' },
      r_permit_student:   { type: 'result', rule_id: 'FTI_R1', result: 'permit', message: 'Student may access.', citation: 'IRC 6103(l)(13)' },
      r_deny:             { type: 'result', rule_id: 'FTI_R2', result: 'deny', message: 'Not permitted.', citation: 'IRC 6103' },
      r_caution:          { type: 'result', rule_id: 'FTI_R3', result: 'permit_with_caution', message: 'Maybe with caution.', citation: 'IRC 6103' },
    },
  };
}

// ──────────────────────────────────────────────────────────────────────
// Construction + reset
// ──────────────────────────────────────────────────────────────────────

test('constructor: stores start + nodes and calls reset', () => {
  const walker = new DagWalker(buildFixture());
  assert.equal(walker.start, 'q1');
  assert.equal(walker.currentId, 'q1');
  assert.deepEqual(walker.inputs, {});
  assert.deepEqual(walker.path, []);
  assert.equal(walker.finished, false);
});

test('reset: walks back to start, clears inputs/path/finished', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(false); // → r_no_fti, finished
  assert.equal(walker.finished, true);
  walker.reset();
  assert.equal(walker.currentId, 'q1');
  assert.deepEqual(walker.inputs, {});
  assert.deepEqual(walker.path, []);
  assert.equal(walker.finished, false);
});

// ──────────────────────────────────────────────────────────────────────
// currentNode
// ──────────────────────────────────────────────────────────────────────

test('currentNode: returns the node at currentId', () => {
  const walker = new DagWalker(buildFixture());
  assert.equal(walker.currentNode().type, 'question');
});

test('currentNode: throws on unknown id', () => {
  const walker = new DagWalker(buildFixture());
  walker.currentId = 'nope';
  assert.throws(() => walker.currentNode(), /Unknown node: nope/);
});

// ──────────────────────────────────────────────────────────────────────
// isResult
// ──────────────────────────────────────────────────────────────────────

test('isResult: false at a question node', () => {
  const walker = new DagWalker(buildFixture());
  assert.equal(walker.isResult(), false);
});

test('isResult: true at a result node', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(false); // → r_no_fti
  assert.equal(walker.isResult(), true);
});

// ──────────────────────────────────────────────────────────────────────
// answer
// ──────────────────────────────────────────────────────────────────────

test('answer(true): pushes to path, records input, follows on_yes', () => {
  const walker = new DagWalker(buildFixture());
  const next = walker.answer(true);
  assert.deepEqual(walker.path, ['q1']);
  assert.equal(walker.inputs.has_fti, true);
  assert.equal(walker.currentId, 'q2');
  assert.equal(next, walker.currentNode());
});

test('answer(false): follows on_no instead', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(false);
  assert.equal(walker.currentId, 'r_no_fti');
  assert.equal(walker.inputs.has_fti, false);
});

test('answer: coerces truthy/falsy via Boolean()', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(1); // truthy non-bool
  assert.equal(walker.inputs.has_fti, true);
});

test('answer: sets finished when arriving at a result', () => {
  const walker = new DagWalker(buildFixture());
  assert.equal(walker.finished, false);
  walker.answer(false); // → r_no_fti (result)
  assert.equal(walker.finished, true);
});

test('answer: stays unfinished when arriving at another question', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(true); // q1 → q2 (still a question)
  assert.equal(walker.finished, false);
});

test('answer: throws if called on a result node', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(false); // → r_no_fti
  assert.throws(() => walker.answer(true), /Cannot answer at non-question node: r_no_fti/);
});

// ──────────────────────────────────────────────────────────────────────
// _recordAnswer branches via answer()
// ──────────────────────────────────────────────────────────────────────

test('_recordAnswer: multi-field node sets all fields to the same value', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(true); // q1 → q2
  walker.answer(true); // q2 (fields: ['to_student', 'is_self'])
  assert.equal(walker.inputs.to_student, true);
  assert.equal(walker.inputs.is_self, true);
});

test('_recordAnswer: node with null field skipped (no key added)', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(true);  // q1 → q2
  walker.answer(false); // q2 → q3
  // q3 has `field: null`; the `if (!f) continue` arm runs.
  const inputsBefore = { ...walker.inputs };
  walker.answer(true); // q3 → r_deny (no input recorded for q3)
  assert.deepEqual(walker.inputs, inputsBefore);
});

// ──────────────────────────────────────────────────────────────────────
// result
// ──────────────────────────────────────────────────────────────────────

test('result: returns null when not at a result node', () => {
  const walker = new DagWalker(buildFixture());
  assert.equal(walker.result(), null);
});

test('result: returns rule fields and copies inputs/path', () => {
  const walker = new DagWalker(buildFixture());
  walker.answer(true);  // q1 → q2
  walker.answer(true);  // q2 → r_permit_student
  const r = walker.result();
  assert.equal(r.ruleId, 'FTI_R1');
  assert.equal(r.result, 'permit');
  assert.equal(r.message, 'Student may access.');
  assert.equal(r.citation, 'IRC 6103(l)(13)');
  assert.deepEqual(r.path, ['q1', 'q2']);
  assert.deepEqual(r.inputs, { has_fti: true, to_student: true, is_self: true });
  // path and inputs should be copies (mutation-safe)
  r.path.push('mutated');
  r.inputs.injected = 'x';
  assert.deepEqual(walker.path, ['q1', 'q2']);
  assert.equal(walker.inputs.injected, undefined);
});

// ──────────────────────────────────────────────────────────────────────
// Environment-guard branch
// ──────────────────────────────────────────────────────────────────────

test('IIFE wrapper: re-loads under defined `window` so the browser arm runs', () => {
  const src = readFileSync(DAG_PATH, 'utf8');
  const savedWindow = globalThis.window;
  try {
    globalThis.window = {};
    vm.runInThisContext(src, { filename: DAG_PATH });
    assert.ok(globalThis.window.Nasfaa.DagWalker, 'expected attach to window');
  } finally {
    if (savedWindow === undefined) delete globalThis.window;
    else globalThis.window = savedWindow;
  }
});
