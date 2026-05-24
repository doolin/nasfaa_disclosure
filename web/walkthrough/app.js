// app.js — walkthrough driver. Plain script, no modules. Reads data
// from `window.NASFAA_DATA` populated by data.js (loaded earlier).

(function () {
  'use strict';

  const N = window.Nasfaa;
  const ARROW = (window.NasfaaGlyphs && window.NasfaaGlyphs.ARROW_SEP) || ' → ';
  const data = window.NASFAA_DATA;
  if (!N || !data) {
    renderUnbuiltNotice();
    return;
  }

  function renderUnbuiltNotice() {
    // data.js is a build artifact (gitignored). If it's missing, the page
    // was opened before `make build` ran. Show a clear, terminal-styled
    // notice instead of a tech-y stack trace.
    const box = document.getElementById('question-box');
    const lines = [
      '┌─ NOT BUILT ─────────────────────────────────────────────────┐',
      '│                                                             │',
      "│  This page hasn't been built yet.                           │",
      '│                                                             │',
      '│  The walkthrough loads its data from data.js, which is      │',
      '│  generated from the canonical YAML files at the repo root.  │',
      '│                                                             │',
      '│  From the project root, run:                                │',
      '│                                                             │',
      '│      make build                                             │',
      '│                                                             │',
      '│  Then refresh this page.                                    │',
      '│                                                             │',
      '└─────────────────────────────────────────────────────────────┘',
    ];
    if (box) {
      box.textContent = lines.join('\n');
      const prompt = document.getElementById('prompt-text');
      if (prompt) prompt.textContent = '(awaiting build) > ';
    } else {
      document.body.textContent = lines.join('\n');
    }
  }

  const $ = (id) => document.getElementById(id);

  const els = {
    questionBox: $('question-box'),
    promptText: $('prompt-text'),
    resultPromptText: $('result-prompt-text'),
    pathList: $('path-list'),
    resultArea: $('result-area'),
    resultBox: $('result-box'),
    questionArea: document.querySelector('.question-area'),
    devBadge: $('dev-badge'),
  };

  // Hidden dev mode: Shift+D toggles. While on, the [t] tests key is live
  // and advertised in the result/quit prompt; while off, [t] is a no-op
  // and the prompt doesn't mention it. Mirrors the quiz's dev mode.
  let devMode = false;

  const engine = new N.RuleEngine(data.rules.rules);
  const walker = new N.DagWalker(data.questions);
  const PERMIT_RESULTS = ['permit', 'permit_with_scope', 'permit_with_caution'];

  // Build SHA in the footer (short form, dev fallback).
  const shaEl = $('build-sha');
  if (shaEl && data.build && data.build.sha) {
    shaEl.textContent = data.build.sha.slice(0, 7);
  }

  let mode = 'question';

  function promptKey(key, label) {
    return `<span class="prompt-key" data-key="${key}">${label}</span>`;
  }

  function questionPromptHtml() {
    return 'Key: ' + [
      promptKey('y', '[y] yes'),
      promptKey('n', '[n] no'),
      promptKey('q', '[q] quit'),
    ].join(' · ') + ' > ';
  }

  // Result + quit prompts: append "[t] tests" only when dev mode is on.
  function restartPromptHtml() {
    const items = [promptKey('r', '[r] restart')];
    if (devMode) items.push(promptKey('t', '[t] tests'));
    return 'Key: ' + items.join(' · ') + ' > ';
  }

  function showCurrentQuestion() {
    mode = 'question';
    const node = walker.currentNode();
    els.questionBox.textContent = N.BoxDraw.renderQuestionBox(node);
    els.promptText.innerHTML = questionPromptHtml();
    els.resultArea.hidden = true;
    els.questionArea.hidden = false;
    renderPath();
  }

  function renderPath() {
    const path = walker.path;
    els.pathList.textContent = path.length === 0 ? '(start)' : path.join(ARROW);
  }

  function showResult() {
    mode = 'result';
    const result = walker.result();
    const node = result.node;
    const engineTrace = engine.evaluate(result.inputs);
    const dagPermitted = PERMIT_RESULTS.includes(node.result);
    const enginePermitted = engineTrace && PERMIT_RESULTS.includes(engineTrace.result);

    let verifyLine;
    if (!engineTrace) {
      verifyLine = 'Verify:   engine returned no match — investigate';
    } else if (dagPermitted !== enginePermitted) {
      verifyLine =
        'Verify:   DAG verdict (' + node.result + ') differs from engine (' +
        engineTrace.result + ' via ' + engineTrace.ruleId + ')';
    } else if (engineTrace.ruleId === node.rule_id) {
      verifyLine = 'Verified: engine and DAG both' + ARROW + node.rule_id;
    } else {
      verifyLine =
        'Verified: same verdict (' + node.result + '); engine first-match' +
        ARROW + engineTrace.ruleId + ', DAG' + ARROW + node.rule_id;
    }

    els.resultBox.innerHTML =
      N.BoxDraw.renderResultBox(node, result.path, { devMode, verifyLine });
    els.resultBox.className = 'box result-box ' + node.result;
    if (els.resultPromptText) els.resultPromptText.innerHTML = restartPromptHtml();
    els.resultArea.hidden = false;
    els.questionArea.hidden = true;
    renderPath();
  }

  function showQuit() {
    mode = 'quit';
    els.questionBox.textContent = 'Walkthrough ended. Press [r] to restart.';
    els.promptText.innerHTML = restartPromptHtml();
  }

  function toggleDevMode() {
    devMode = !devMode;
    if (els.devBadge) {
      if (devMode) els.devBadge.removeAttribute('hidden');
      else els.devBadge.setAttribute('hidden', '');
    }
    // Refresh whichever prompt is currently visible so [t] appears/disappears.
    if (mode === 'result' && els.resultPromptText) {
      els.resultPromptText.innerHTML = restartPromptHtml();
    } else if (mode === 'quit') {
      els.promptText.innerHTML = restartPromptHtml();
    }
    // Re-render the result box so Rule + Path lines show/hide with dev mode.
    if (mode === 'result') showResult();
  }

  function restart() {
    walker.reset();
    els.resultBox.className = 'box result-box';
    showCurrentQuestion();
  }

  function handleKey(key) {
    const k = key.toLowerCase();
    // Global: 'm' cycles theme (mode). 'm' instead of 't' (tests) or 'c' (copy).
    if (k === 'm' && window.NasfaaTheme) {
      window.NasfaaTheme.cycle();
      if (window.updateThemeLabel) window.updateThemeLabel();
      return;
    }
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
      else if (k === 't' && devMode) window.location.href = 'test.html';
    }
  }

  document.addEventListener('keydown', (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    // Hidden dev-mode toggle (Shift+D). Checked before handleKey lowercases.
    if (e.key === 'D' && e.shiftKey) {
      toggleDevMode();
      e.preventDefault();
      return;
    }
    if (e.key.length !== 1) return;
    handleKey(e.key);
  });

  // Inline-tappable prompt keys: click on a .prompt-key dispatches the
  // same handler as its keystroke. Touch-friendly without pill buttons.
  document.addEventListener('click', (ev) => {
    const target = ev.target.closest('.prompt-key');
    if (!target) return;
    handleKey(target.dataset.key);
    ev.preventDefault();
  });

  showCurrentQuestion();
})();
