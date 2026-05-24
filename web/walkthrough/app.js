// app.js — walkthrough driver. Plain script, no modules. Reads data
// from `window.NASFAA_DATA` populated by data.js (loaded earlier).

(function () {
  'use strict';

  const N = window.Nasfaa;
  const G = window.NasfaaGlyphs || {};
  const ARROW = G.ARROW_SEP || ' → ';
  const CHECK = G.CHECK || '✔';
  const CROSS = G.CROSS || '✘';

  // Human-readable labels for path display. The path encodes both the
  // question that was asked AND the answer that was given (since the path
  // *meaning* depends on the branch taken). Each entry has three forms:
  //
  //   question — shown for the current (unanswered) question, with "?"
  //              appended by renderPath (e.g. "Contains FTI?")
  //   yes      — shown for a prior question the user answered "yes"
  //   no       — shown for a prior question the user answered "no"
  //
  // Missing entries fall through to the raw question id, which is also
  // how the dev sees what's left to label (stepwise expansion).
  //
  // Lives here rather than in nasfaa_questions.yml for fast iteration;
  // a future commit can lift to YAML if labels stabilize.
  const PATH_LABELS = {
    // Entry
    fti_check:           { question: 'Contains FTI',                 yes: 'Contains FTI',                 no: 'No FTI' },

    // FTI branch (Page 2)
    fti_to_student:      { question: 'To student',                   yes: 'To student',                   no: 'Not to student' },
    fti_aid_admin:       { question: 'For aid admin',                yes: 'For aid admin',                no: 'Not for aid admin' },
    fti_school_official: { question: 'School official with LEI',     yes: 'School official with LEI',     no: 'Not a school official' },
    fti_scholarship:     { question: 'Scholarship org with consent', yes: 'Scholarship org with consent', no: 'Not scholarship / no consent' },

    // Non-FTI / FAFSA branch (Page 1, boxes 2-9)
    nonfti_to_student:   { question: 'To student',                   yes: 'To student',                   no: 'Not to student' },
    nonfti_fafsa_check:  { question: 'Is FAFSA data',                yes: 'FAFSA data',                   no: 'Non-FAFSA data' },
    fafsa_contributor:   { question: 'To FAFSA contributor',         yes: 'To FAFSA contributor',         no: 'Not a contributor' },
    fafsa_aid_admin:     { question: 'For aid admin',                yes: 'For aid admin',                no: 'Not for aid admin' },
    fafsa_scholarship:   { question: 'Scholarship org with consent', yes: 'Scholarship org with consent', no: 'Not scholarship / no consent' },
    fafsa_research:      { question: 'Institutional research',       yes: 'Institutional research',       no: 'Not research' },
    fafsa_hea_consent:   { question: 'HEA consent',                  yes: 'HEA consent',                  no: 'No HEA consent' },
    fafsa_pii:           { question: 'Contains PII',                 yes: 'Contains PII',                 no: 'No PII' },

    // FERPA chain (boxes 10-19)
    ferpa_consent:        { question: 'FERPA consent',                yes: 'FERPA consent',                no: 'No FERPA consent' },
    ferpa_directory:      { question: 'Directory info',               yes: 'Directory info',               no: 'Not directory info' },
    ferpa_school_official:{ question: 'School official with LEI',     yes: 'School official with LEI',     no: 'Not a school official' },
    ferpa_judicial:       { question: 'Judicial order / subpoena',    yes: 'Judicial order / subpoena',    no: 'Not judicial' },
    ferpa_transfer:       { question: 'School transfer',              yes: 'School transfer',              no: 'Not a transfer' },
    ferpa_authorized_rep: { question: 'Authorized rep',               yes: 'Authorized rep',               no: 'Not authorized rep' },
    ferpa_research_org:   { question: 'FERPA research org',           yes: 'FERPA research org',           no: 'Not research org' },
    ferpa_accreditor:     { question: 'Accrediting agency',           yes: 'Accrediting agency',           no: 'Not accreditor' },
    ferpa_parent:         { question: 'Parent of dependent',          yes: 'Parent of dependent',          no: 'Not parent of dependent' },
    ferpa_otherwise:      { question: 'Other §99.31 exception',       yes: 'Other §99.31 exception',       no: 'No §99.31 exception' },
  };

  function pathLabel(id, answered) {
    const entry = PATH_LABELS[id];
    if (!entry) return id;
    if (answered === undefined) return entry.question;
    return answered ? entry.yes : entry.no;
  }

  // Recovers the yes/no answer for an already-answered path entry by
  // peeking at the field the question set. Multi-field questions set all
  // their fields to the same value, so the first field is enough.
  function answerForPathEntry(id) {
    const node = walker.nodes[id];
    if (!node) return undefined;
    const field = node.field || (node.fields && node.fields[0]);
    if (!field) return undefined;
    return walker.inputs[field];
  }
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

  function promptKey(key, label, extraClass) {
    const cls = 'prompt-key' + (extraClass ? ' ' + extraClass : '');
    return `<span class="${cls}" data-key="${key}">${label}</span>`;
  }

  function questionPromptHtml() {
    return 'Key: ' + [
      promptKey('y', '[y] yes'),
      promptKey('n', '[n] no'),
      promptKey('q', '[q] quit'),
    ].join(' · ') + ' > ';
  }

  // Result + quit prompts: append "[t] tests" only when dev mode is on.
  // The [t] key is dev-only, so render it in the dev color to telegraph that.
  function restartPromptHtml() {
    const items = [promptKey('r', '[r] restart')];
    if (devMode) items.push(promptKey('t', '[t] tests', 'dev'));
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
    // walker.path only includes answered questions. In question mode the
    // current (unanswered) question gets appended with a trailing "?" so
    // the path display reads "answered → answered → current?". Once the
    // user answers, the "?" moves to the next current as the path grows.
    // In result mode an outcome mark (✔ or ✘) appends after the path.
    const answered = walker.path.map(function (id) {
      return pathLabel(id, answerForPathEntry(id));
    });
    let displayed = answered;
    if (mode === 'question' && !walker.finished) {
      displayed = answered.concat([pathLabel(walker.currentId) + '?']);
    }
    if (displayed.length === 0) {
      els.pathList.textContent = '(start)';
      return;
    }
    const text = displayed.join(ARROW);
    if (mode === 'result' && walker.finished) {
      const result = walker.currentNode().result;
      const isDeny = result === 'deny';
      const symbol = isDeny ? CROSS : CHECK;
      const cls = isDeny ? 'result-deny' : 'result-permit';
      els.pathList.innerHTML =
        N.BoxDraw.escapeHtml(text) +
        ' <span class="' + cls + '">' + symbol + '</span>';
    } else {
      els.pathList.textContent = text;
    }
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
