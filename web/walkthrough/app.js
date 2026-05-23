// app.js — single-page walkthrough driver.
//
// Wires the DAG walker to the DOM. Single keystrokes advance the
// walkthrough; on a terminal node it cross-verifies with engine.js and
// renders a heavy result box. No framework.

import { DagWalker } from './dag.js';
import { RuleEngine } from './engine.js';
import { renderQuestionBox, renderResultBox } from './box-draw.js';

const QUESTIONS_URL = './questions.json';
const RULES_URL = './rules.json';

const $ = (id) => document.getElementById(id);

const els = {
  questionBox: $('question-box'),
  promptText: $('prompt-text'),
  pathList: $('path-list'),
  resultArea: $('result-area'),
  resultBox: $('result-box'),
  questionArea: document.querySelector('.question-area'),
  touchControls: $('touch-controls'),
};

const state = {
  walker: null,
  engine: null,
  questions: null,
  mode: 'question', // 'question' | 'result' | 'quit'
};

async function loadJson(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error(`failed to fetch ${url}: ${res.status}`);
  return res.json();
}

async function bootstrap() {
  try {
    const [questions, rules] = await Promise.all([
      loadJson(QUESTIONS_URL),
      loadJson(RULES_URL),
    ]);
    state.questions = questions;
    state.engine = new RuleEngine(rules.rules);
    state.walker = new DagWalker(questions);
    showCurrentQuestion();
    setupTouchControls();
  } catch (err) {
    els.questionBox.textContent =
      'Failed to load decision tree data.\n\n' +
      String(err && err.message ? err.message : err) +
      '\n\nIf you are opening this via file:// some browsers block fetch().\n' +
      'Try `python3 -m http.server` from web/walkthrough/ instead.';
  }
}

function showCurrentQuestion() {
  state.mode = 'question';
  const node = state.walker.currentNode();
  els.questionBox.textContent = renderQuestionBox(node);
  els.promptText.textContent = '[y/n/q] > ';
  els.resultArea.hidden = true;
  els.questionArea.hidden = false;
  renderPath();
}

function renderPath() {
  const path = state.walker.path;
  if (path.length === 0) {
    els.pathList.textContent = '(start)';
  } else {
    els.pathList.textContent = path.join(' -> ');
  }
}

function showResult() {
  state.mode = 'result';
  const result = state.walker.result();
  const node = result.node;

  // Cross-verify against the RuleEngine. We compare permit/deny verdicts
  // (not rule_id), matching the Ruby exhaustive verification spec — DAG
  // and engine can legitimately reach the same verdict via different rules
  // because the engine evaluates rules first-match-wins on the full input
  // bag while the DAG follows a specific path.
  const engineTrace = state.engine.evaluate(result.inputs);
  const permitResults = ['permit', 'permit_with_scope', 'permit_with_caution'];
  const dagPermitted = permitResults.includes(node.result);
  const enginePermitted =
    engineTrace && permitResults.includes(engineTrace.result);

  let crossNote = '';
  if (!engineTrace) {
    crossNote = '\n(verify: engine returned no match — investigate)';
  } else if (dagPermitted !== enginePermitted) {
    crossNote =
      `\n(verify: DAG verdict (${node.result}) differs from engine ` +
      `verdict (${engineTrace.result} via ${engineTrace.ruleId}))`;
  } else if (engineTrace.ruleId === node.rule_id) {
    crossNote = `\n(verified: engine and DAG both -> ${node.rule_id})`;
  } else {
    crossNote =
      `\n(verified: same verdict (${node.result}); engine first-match ` +
      `-> ${engineTrace.ruleId}, DAG -> ${node.rule_id})`;
  }

  els.resultBox.textContent = renderResultBox(node, result.path) + crossNote;
  els.resultBox.className = `box result-box ${node.result}`;
  els.resultArea.hidden = false;
  els.questionArea.hidden = true;
  renderPath();
}

function showQuit() {
  state.mode = 'quit';
  els.questionBox.textContent = 'Walkthrough ended. Press [r] to restart.';
  els.promptText.textContent = '[r] restart > ';
}

function restart() {
  state.walker.reset();
  els.resultBox.className = 'box result-box';
  showCurrentQuestion();
}

function handleKey(key) {
  const k = key.toLowerCase();
  if (state.mode === 'question') {
    if (k === 'y' || k === 'n') {
      state.walker.answer(k === 'y');
      if (state.walker.isResult()) {
        showResult();
      } else {
        showCurrentQuestion();
      }
    } else if (k === 'q') {
      showQuit();
    }
  } else if (state.mode === 'result' || state.mode === 'quit') {
    if (k === 'r') {
      restart();
    } else if (k === 't') {
      window.location.href = 'test.html';
    }
  }
}

document.addEventListener('keydown', (e) => {
  // Don't fight browser shortcuts (Cmd-R, Cmd-T, etc.)
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  if (e.key.length !== 1) return; // ignore Shift, Tab, arrows, etc.
  handleKey(e.key);
});

function setupTouchControls() {
  // Show on-screen buttons only when no physical keyboard is detected
  // (rough heuristic: touch-only device with no hover).
  const touchOnly =
    window.matchMedia('(hover: none) and (pointer: coarse)').matches;
  if (touchOnly) {
    els.touchControls.hidden = false;
  }
  els.touchControls.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-key]');
    if (!btn) return;
    handleKey(btn.dataset.key);
  });
}

bootstrap();
