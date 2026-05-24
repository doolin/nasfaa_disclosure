// test-quiz.mjs — Node tests for web/quiz/quiz.js.
//
//   node --test web/quiz/test-quiz.mjs
//
// quiz.js is a pure state machine (no DOM). Tests use a Math.random
// stub for deterministic shuffling.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const Quiz = require('./quiz.js');
const {
  RANDOM_QUESTION_COUNT_DEFAULT,
  shuffle,
  quizQuestionFromScenario,
  buildRandomQuestion,
  buildQuestions,
  isCorrect,
  QuizState,
} = Quiz;
const QUIZ_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), 'quiz.js');

// withStubbedRandom(fn, sequence): runs fn with Math.random producing
// the given values in order (then 0 for any extras), restores after.
function withStubbedRandom(seq, fn) {
  const saved = Math.random;
  let i = 0;
  Math.random = () => (i < seq.length ? seq[i++] : 0);
  try { fn(); } finally { Math.random = saved; }
}

// ──────────────────────────────────────────────────────────────────────
// shuffle
// ──────────────────────────────────────────────────────────────────────

test('shuffle: returns a new array (does not mutate input)', () => {
  const input = [1, 2, 3, 4];
  const output = shuffle(input);
  assert.notEqual(output, input);
  assert.deepEqual(input.slice().sort(), output.slice().sort());
});

test('shuffle: with stubbed Math.random=0 produces deterministic order', () => {
  // Fisher-Yates from high to low with j always = 0:
  //   i=2: swap a[2]/a[0] → ['c','b','a']
  //   i=1: swap a[1]/a[0] → ['b','c','a']
  withStubbedRandom([0, 0], () => {
    assert.deepEqual(shuffle(['a', 'b', 'c']), ['b', 'c', 'a']);
  });
});

test('shuffle: empty array returns empty array', () => {
  assert.deepEqual(shuffle([]), []);
});

test('shuffle: single-element array unchanged', () => {
  assert.deepEqual(shuffle([7]), [7]);
});

// ──────────────────────────────────────────────────────────────────────
// quizQuestionFromScenario
// ──────────────────────────────────────────────────────────────────────

test('quizQuestionFromScenario: full scenario projects all fields', () => {
  const rc = { flavor: 'why it matters', case_studies: [] };
  const q = quizQuestionFromScenario({
    description: 'A student requests records.',
    name: 'Self-service request',
    inputs: { includes_fti: true, disclosure_to_student: true },
    expected: { result: 'permit', rule_id: 'FTI_R1' },
    citation: 'IRC §6103(l)(13)',
    result_context: rc,
  });
  assert.deepEqual(q, {
    description: 'A student requests records.',
    name: 'Self-service request',
    inputs: { includes_fti: true, disclosure_to_student: true },
    expectedResult: 'permit',
    ruleId: 'FTI_R1',
    citation: 'IRC §6103(l)(13)',
    resultContext: rc,
  });
});

test('quizQuestionFromScenario: missing optional fields collapse to null/{}', () => {
  const q = quizQuestionFromScenario({
    expected: { result: 'deny', rule_id: 'R_X' },
  });
  assert.equal(q.description, null);
  assert.equal(q.name, null);
  assert.deepEqual(q.inputs, {});
  assert.equal(q.citation, null);
  assert.equal(q.resultContext, null);
});

// ──────────────────────────────────────────────────────────────────────
// buildRandomQuestion
// ──────────────────────────────────────────────────────────────────────

function fakeEngine(traceForInputs) {
  return {
    evaluate(inputs) {
      return typeof traceForInputs === 'function' ? traceForInputs(inputs) : traceForInputs;
    },
  };
}

test('buildRandomQuestion: produces a question with engine-matched expected result', () => {
  withStubbedRandom([0, 0, 0, 0, 0, 0], () => {
    const engine = fakeEngine({ result: 'permit', ruleId: 'R1' });
    const q = buildRandomQuestion(engine, ['a', 'b', 'c', 'd', 'e', 'f']);
    assert.equal(q.expectedResult, 'permit');
    assert.equal(q.ruleId, 'R1');
    assert.equal(q.description, null);
    assert.equal(q.name, null);
    assert.equal(q.citation, null);
    // inputs has at least one true field
    assert.ok(Object.values(q.inputs).every((v) => v === true));
  });
});

test('buildRandomQuestion: no rule match → expectedResult=deny, ruleId placeholder', () => {
  withStubbedRandom([0, 0, 0, 0, 0, 0], () => {
    const engine = fakeEngine(null);
    const q = buildRandomQuestion(engine, ['a', 'b', 'c']);
    assert.equal(q.expectedResult, 'deny');
    assert.equal(q.ruleId, '(no rule matched)');
  });
});

test('buildRandomQuestion: partial-shuffle loop clamps via `i < pool.length`', () => {
  // Math.random returning .99 makes `1 + floor(.99 * 5) = 5` requested,
  // but pool has only 3 — the partial-shuffle loop's second guard kicks
  // in. Note: the *assignment* loop below only checks `i < count`, so
  // it overruns the pool and writes inputs[undefined] = true for every
  // out-of-range iteration (all collapsed into one "undefined" key).
  // Documenting actual behavior here; the overrun is flagged in
  // docs/ROADMAP.md as a latent issue.
  withStubbedRandom([0.99], () => {
    const engine = fakeEngine({ result: 'deny', ruleId: 'R0' });
    const q = buildRandomQuestion(engine, ['x', 'y', 'z']);
    // 3 real field keys + 1 'undefined' key
    assert.equal(Object.keys(q.inputs).length, 4);
    assert.ok('undefined' in q.inputs, 'expected the overrun phantom key');
  });
});

// ──────────────────────────────────────────────────────────────────────
// buildQuestions
// ──────────────────────────────────────────────────────────────────────

test('buildQuestions: default scenario mode shuffles scenarios into question shape', () => {
  const scenarios = [
    { name: 'A', expected: { result: 'permit', rule_id: 'R1' } },
    { name: 'B', expected: { result: 'deny',   rule_id: 'R2' } },
  ];
  withStubbedRandom([0, 0], () => {
    const qs = buildQuestions({ mode: 'scenario', scenarios });
    assert.equal(qs.length, 2);
    assert.deepEqual(qs.map((q) => q.ruleId).sort(), ['R1', 'R2']);
  });
});

test('buildQuestions: mode=random with no count uses default of 10', () => {
  withStubbedRandom(new Array(60).fill(0), () => {
    const qs = buildQuestions({
      mode: 'random',
      engine: fakeEngine(null),
      fields: ['a', 'b'],
    });
    assert.equal(qs.length, RANDOM_QUESTION_COUNT_DEFAULT);
  });
});

test('buildQuestions: mode=random with count override produces that many', () => {
  withStubbedRandom(new Array(30).fill(0), () => {
    const qs = buildQuestions({
      mode: 'random',
      engine: fakeEngine(null),
      fields: ['a', 'b'],
      count: 3,
    });
    assert.equal(qs.length, 3);
  });
});

test('buildQuestions: mode=random with non-numeric / zero count → default', () => {
  withStubbedRandom(new Array(60).fill(0), () => {
    const qs = buildQuestions({
      mode: 'random', engine: fakeEngine(null), fields: ['a'], count: 0,
    });
    assert.equal(qs.length, RANDOM_QUESTION_COUNT_DEFAULT);
  });
});

// ──────────────────────────────────────────────────────────────────────
// isCorrect
// ──────────────────────────────────────────────────────────────────────

test('isCorrect: permit + permit/permit_with_scope/permit_with_caution → true', () => {
  assert.equal(isCorrect('permit', 'permit'), true);
  assert.equal(isCorrect('permit', 'permit_with_scope'), true);
  assert.equal(isCorrect('permit', 'permit_with_caution'), true);
});

test('isCorrect: deny + deny → true', () => {
  assert.equal(isCorrect('deny', 'deny'), true);
});

test('isCorrect: mismatches → false', () => {
  assert.equal(isCorrect('permit', 'deny'), false);
  assert.equal(isCorrect('deny', 'permit'), false);
  assert.equal(isCorrect('deny', 'permit_with_caution'), false);
});

// ──────────────────────────────────────────────────────────────────────
// QuizState
// ──────────────────────────────────────────────────────────────────────

function sampleQuestions() {
  return [
    { name: 'Q1', expectedResult: 'permit', ruleId: 'R1' },
    { name: 'Q2', expectedResult: 'deny',   ruleId: 'R2' },
  ];
}

test('QuizState: initial state with questions', () => {
  const s = new QuizState(sampleQuestions());
  assert.equal(s.questionNumber(), 1);
  assert.equal(s.questionCount(), 2);
  assert.equal(s.current().name, 'Q1');
  assert.equal(s.finished, false);
  assert.equal(s.correct, 0);
});

test('QuizState: empty questions → finished immediately', () => {
  const s = new QuizState([]);
  assert.equal(s.finished, true);
  assert.equal(s.current(), null);
});

test('QuizState: answer correct increments correct + total + sets reveal flags', () => {
  const s = new QuizState(sampleQuestions());
  const q = s.answer('permit');
  assert.equal(q.name, 'Q1');
  assert.equal(s.correct, 1);
  assert.equal(s.total, 1);
  assert.equal(s.lastAnswer, 'permit');
  assert.equal(s.lastWasCorrect, true);
  assert.equal(s.revealing, true);
});

test('QuizState: answer incorrect does not increment correct', () => {
  const s = new QuizState(sampleQuestions());
  s.answer('deny'); // Q1 expected permit
  assert.equal(s.correct, 0);
  assert.equal(s.lastWasCorrect, false);
});

test('QuizState: answer during reveal → returns null (no double-count)', () => {
  const s = new QuizState(sampleQuestions());
  s.answer('permit');
  assert.equal(s.answer('deny'), null);
  assert.equal(s.total, 1);
});

test('QuizState: answer on finished state → returns null', () => {
  const s = new QuizState([]);
  assert.equal(s.answer('permit'), null);
});

test('QuizState: advance leaves reveal, moves index, finishes at end', () => {
  const s = new QuizState(sampleQuestions());
  s.answer('permit'); // reveal Q1
  s.advance();
  assert.equal(s.revealing, false);
  assert.equal(s.questionNumber(), 2);
  assert.equal(s.current().name, 'Q2');
  s.answer('deny'); // reveal Q2 (correct)
  s.advance();
  assert.equal(s.finished, true);
});

test('QuizState: advance when not revealing → no-op', () => {
  const s = new QuizState(sampleQuestions());
  s.advance(); // not revealing yet
  assert.equal(s.questionNumber(), 1);
});

test('QuizState: quit ends the run without scoring', () => {
  const s = new QuizState(sampleQuestions());
  s.quit();
  assert.equal(s.finished, true);
  assert.equal(s.revealing, false);
  assert.equal(s.correct, 0);
});

test('QuizState: percent — 0 total → 0', () => {
  const s = new QuizState(sampleQuestions());
  assert.equal(s.percent(), 0);
});

test('QuizState: percent — 1 of 2 → 50', () => {
  const s = new QuizState(sampleQuestions());
  s.answer('permit'); s.advance(); // correct
  s.answer('permit'); s.advance(); // Q2 expected deny → incorrect
  assert.equal(s.percent(), 50);
});

// ──────────────────────────────────────────────────────────────────────
// Browser-arm env guard
// ──────────────────────────────────────────────────────────────────────

test('browser arm: IIFE picks `self`; module gate falls through to root.NasfaaQuiz', () => {
  const src = readFileSync(QUIZ_PATH, 'utf8');
  const savedSelf = globalThis.self;
  try {
    globalThis.self = {};
    vm.runInThisContext(src, { filename: QUIZ_PATH });
    assert.ok(globalThis.self.NasfaaQuiz);
    assert.equal(typeof globalThis.self.NasfaaQuiz.QuizState, 'function');
  } finally {
    if (savedSelf === undefined) delete globalThis.self;
    else globalThis.self = savedSelf;
  }
});
