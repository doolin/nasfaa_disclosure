// app.js — walkthrough driver. Plain script, no modules. Reads data
// from `window.NASFAA_DATA` populated by data.js (loaded earlier).

(function () {
  'use strict';

  const N = window.Nasfaa;
  const data = window.NASFAA_DATA;
  if (!N || !data) {
    document.body.textContent =
      'Walkthrough failed to load: missing Nasfaa or NASFAA_DATA. ' +
      'Make sure data.js, engine.js, dag.js, and box-draw.js are loaded before app.js.';
    return;
  }

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

  const engine = new N.RuleEngine(data.rules.rules);
  const walker = new N.DagWalker(data.questions);
  const PERMIT_RESULTS = ['permit', 'permit_with_scope', 'permit_with_caution'];

  // Build SHA in the footer (short form, dev fallback).
  const shaEl = $('build-sha');
  if (shaEl && data.build && data.build.sha) {
    shaEl.textContent = data.build.sha.slice(0, 7);
  }

  let mode = 'question';

  function showCurrentQuestion() {
    mode = 'question';
    const node = walker.currentNode();
    els.questionBox.textContent = N.BoxDraw.renderQuestionBox(node);
    els.promptText.textContent = '[y/n/q] > ';
    els.resultArea.hidden = true;
    els.questionArea.hidden = false;
    renderPath();
  }

  function renderPath() {
    const path = walker.path;
    els.pathList.textContent = path.length === 0 ? '(start)' : path.join(' -> ');
  }

  function showResult() {
    mode = 'result';
    const result = walker.result();
    const node = result.node;
    const engineTrace = engine.evaluate(result.inputs);
    const dagPermitted = PERMIT_RESULTS.includes(node.result);
    const enginePermitted = engineTrace && PERMIT_RESULTS.includes(engineTrace.result);

    let crossNote = '';
    if (!engineTrace) {
      crossNote = '\n(verify: engine returned no match — investigate)';
    } else if (dagPermitted !== enginePermitted) {
      crossNote =
        '\n(verify: DAG verdict (' + node.result + ') differs from engine ' +
        'verdict (' + engineTrace.result + ' via ' + engineTrace.ruleId + '))';
    } else if (engineTrace.ruleId === node.rule_id) {
      crossNote = '\n(verified: engine and DAG both -> ' + node.rule_id + ')';
    } else {
      crossNote =
        '\n(verified: same verdict (' + node.result + '); engine first-match ' +
        '-> ' + engineTrace.ruleId + ', DAG -> ' + node.rule_id + ')';
    }

    els.resultBox.textContent = N.BoxDraw.renderResultBox(node, result.path) + crossNote;
    els.resultBox.className = 'box result-box ' + node.result;
    els.resultArea.hidden = false;
    els.questionArea.hidden = true;
    renderPath();
  }

  function showQuit() {
    mode = 'quit';
    els.questionBox.textContent = 'Walkthrough ended. Press [r] to restart.';
    els.promptText.textContent = '[r] restart > ';
  }

  function restart() {
    walker.reset();
    els.resultBox.className = 'box result-box';
    showCurrentQuestion();
  }

  function handleKey(key) {
    const k = key.toLowerCase();
    if (mode === 'question') {
      if (k === 'y' || k === 'n') {
        walker.answer(k === 'y');
        if (walker.isResult()) showResult();
        else showCurrentQuestion();
      } else if (k === 'q') {
        showQuit();
      }
    } else if (mode === 'result' || mode === 'quit') {
      if (k === 'r') restart();
      else if (k === 't') window.location.href = 'test.html';
    }
  }

  document.addEventListener('keydown', (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key.length !== 1) return;
    handleKey(e.key);
  });

  const touchOnly = window.matchMedia('(hover: none) and (pointer: coarse)').matches;
  if (touchOnly) els.touchControls.hidden = false;
  els.touchControls.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-key]');
    if (!btn) return;
    handleKey(btn.dataset.key);
  });

  showCurrentQuestion();
})();
