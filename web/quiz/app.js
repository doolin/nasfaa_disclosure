// app.js — DOM driver for the NASFAA disclosure quiz.
//
// Loads rules.json + scenarios.json, builds the question list, listens
// for p/d/q/space/enter keystrokes, and re-renders the terminal frame
// after every state change.

(function () {
  'use strict';

  const { RuleEngine, DISCLOSURE_FIELDS } = window.NasfaaEngine;
  const BD = window.NasfaaBoxDraw;
  const { buildQuestions, QuizState } = window.NasfaaQuiz;

  const screen = document.getElementById('screen');
  const cursor = document.getElementById('cursor');
  const touchControls = document.getElementById('touch-controls');

  // ── URL params ─────────────────────────────────────────────────
  const params = new URLSearchParams(window.location.search);
  const mode = (params.get('mode') || 'scenario').toLowerCase();
  const countParam = parseInt(params.get('count') || '', 10);

  // ── State ──────────────────────────────────────────────────────
  let state = null;
  let banner = '';
  let footer = '';

  // ── Helpers ────────────────────────────────────────────────────

  function progressBar(correct, total, width) {
    if (total <= 0) return '';
    const filled = Math.round((correct / total) * width);
    return '▓'.repeat(filled) + '░'.repeat(Math.max(width - filled, 0));
  }

  function formatInputs(inputs) {
    const keys = Object.keys(inputs);
    if (keys.length === 0) return [];
    return keys.map((k) => `  ${k}: ${inputs[k]}`);
  }

  function buildBanner() {
    const lines = [];
    const title = 'NASFAA DISCLOSURE QUIZ';
    lines.push(title);
    let modeLine;
    if (mode === 'random') {
      const n = (state && state.questionCount()) || 0;
      modeLine = `Mode: random — ${n} generated questions`;
    } else {
      modeLine = `Mode: scenario — ${state ? state.questionCount() : 24} real-world scenarios`;
    }
    lines.push(modeLine);
    lines.push('Test your knowledge of FERPA/FAFSA/FTI disclosure rules.');
    lines.push('Press [p] permit, [d] deny, [q] quit. Space/Enter to advance.');
    lines.push('For Entertainment Purposes Only.');
    return lines.join('\n');
  }

  // ── Rendering ──────────────────────────────────────────────────

  function renderQuestion(q) {
    const out = [];
    out.push(BD.boxTop(`Question ${state.questionNumber()} of ${state.questionCount()}`));
    out.push(BD.boxLine());
    if (q.description) {
      if (q.name) {
        out.push(BD.boxLine(q.name));
        out.push(BD.boxDivider());
      }
      out.push(BD.boxLine(q.description.trim()));
      out.push(BD.boxLine());
      out.push(BD.boxLine('Inputs:'));
    } else {
      out.push(BD.boxLine('Given the following disclosure parameters:'));
      out.push(BD.boxLine());
    }
    for (const line of formatInputs(q.inputs)) {
      out.push(BD.boxLine(line));
    }
    if (!q.description) {
      out.push(BD.boxLine());
      out.push(BD.boxLine('(All other fields are false.)'));
    }
    out.push(BD.boxBottom());
    return out.join('\n');
  }

  function renderReveal(q) {
    const out = [];
    out.push(BD.boxTop());
    out.push(state.lastWasCorrect
      ? BD.boxLine('CORRECT!')
      : BD.boxLine('INCORRECT.'));
    out.push(BD.boxLine(`Answer:   ${q.expectedResult}`));
    out.push(BD.boxLine(`Rule:     ${q.ruleId}`));
    if (q.citation) {
      out.push(BD.boxLine(`Citation: ${q.citation}`));
    }
    out.push(BD.boxLine(`Score:    ${state.correct}/${state.total}`));
    out.push(BD.boxBottom());
    return out.join('\n');
  }

  function renderFinal() {
    const out = [];
    out.push(BD.boxHeavyTop());
    out.push(BD.boxHeavyLine(`FINAL SCORE: ${state.correct}/${state.total}`));
    out.push(BD.boxHeavyLine(`${state.percent()}% correct`));
    out.push(BD.boxHeavyLine(''));
    out.push(BD.boxHeavyLine('Reload the page to play again.'));
    out.push(BD.boxHeavyBottom());
    return out.join('\n');
  }

  function renderScoreBanner() {
    const total = state.questionCount();
    const answered = state.total;
    const bar = progressBar(state.correct, total, 16);
    return `Score: ${state.correct}/${answered} of ${total}  ${bar}`;
  }

  function renderPrompt() {
    if (state.finished) return '';
    if (state.revealing) return '[Space/Enter] continue · [q] quit';
    return '[p] permit · [d] deny · [q] quit';
  }

  function render() {
    const parts = [];
    parts.push(banner);
    parts.push('');
    parts.push(renderScoreBanner());
    parts.push('');

    if (state.finished) {
      parts.push(renderFinal());
      cursor.style.display = 'none';
      if (touchControls) touchControls.style.display = 'none';
      footer = '';
    } else {
      const q = state.current();
      parts.push(renderQuestion(q));
      if (state.revealing) {
        parts.push('');
        parts.push(renderReveal(q));
      }
      parts.push('');
      parts.push(renderPrompt());
      cursor.style.display = '';
    }

    screen.textContent = parts.join('\n');
    // Scroll to bottom so the cursor + prompt stay in view on small screens.
    window.scrollTo(0, document.body.scrollHeight);
  }

  // ── Input handling ─────────────────────────────────────────────

  function handleAnswer(choice) {
    if (state.finished) return;
    if (state.revealing) return;       // Space/Enter handles advance separately
    state.answer(choice);
    render();
  }

  function handleAdvance() {
    if (state.finished) return;
    if (!state.revealing) return;
    state.advance();
    render();
  }

  function handleQuit() {
    state.quit();
    render();
  }

  function onKeyDown(ev) {
    // Don't fight browser shortcuts.
    if (ev.metaKey || ev.ctrlKey || ev.altKey) return;

    const k = ev.key;
    if (k === 'p' || k === 'P') {
      handleAnswer('permit');
      ev.preventDefault();
    } else if (k === 'd' || k === 'D') {
      handleAnswer('deny');
      ev.preventDefault();
    } else if (k === 'q' || k === 'Q') {
      handleQuit();
      ev.preventDefault();
    } else if (k === ' ' || k === 'Enter' || k === 'Spacebar') {
      handleAdvance();
      ev.preventDefault();
    }
  }

  function wireTouchControls() {
    if (!touchControls) return;
    // Heuristic: show touch buttons on coarse pointer devices (phones/tablets).
    const isTouch = (window.matchMedia && window.matchMedia('(pointer: coarse)').matches);
    if (isTouch) {
      touchControls.style.display = '';
    }
    const bind = (id, fn) => {
      const el = document.getElementById(id);
      if (el) el.addEventListener('click', (ev) => { fn(); ev.preventDefault(); });
    };
    bind('btn-permit', () => handleAnswer('permit'));
    bind('btn-deny', () => handleAnswer('deny'));
    bind('btn-quit', handleQuit);
    bind('btn-advance', handleAdvance);
  }

  // ── Bootstrap ──────────────────────────────────────────────────

  async function fetchJson(path) {
    // When served over file://, fetch() may fail in some browsers; fall back
    // to XHR which has wider local-file support.
    if (window.location.protocol === 'file:') {
      return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open('GET', path, true);
        xhr.onload = () => {
          if (xhr.status === 200 || xhr.status === 0) {
            try { resolve(JSON.parse(xhr.responseText)); }
            catch (e) { reject(e); }
          } else { reject(new Error('HTTP ' + xhr.status + ' for ' + path)); }
        };
        xhr.onerror = () => reject(new Error('XHR failed for ' + path));
        xhr.send();
      });
    }
    const res = await fetch(path);
    if (!res.ok) throw new Error('HTTP ' + res.status + ' for ' + path);
    return res.json();
  }

  async function bootstrap() {
    try {
      const [rulesData, scenariosData] = await Promise.all([
        fetchJson('rules.json'),
        fetchJson('scenarios.json'),
      ]);
      const engine = new RuleEngine(rulesData.rules);
      const questions = buildQuestions({
        mode,
        scenarios: scenariosData.scenarios,
        engine,
        fields: DISCLOSURE_FIELDS,
        count: Number.isFinite(countParam) ? countParam : undefined,
      });
      state = new QuizState(questions);
      banner = buildBanner();
      render();
      document.addEventListener('keydown', onKeyDown);
      wireTouchControls();
    } catch (err) {
      screen.textContent =
        'Failed to load quiz data.\n\n' +
        String(err) +
        '\n\nIf you are opening this via file://, try:\n' +
        '  python3 -m http.server\n' +
        'then visit http://localhost:8000/web/quiz/';
    }
  }

  bootstrap();
})();
