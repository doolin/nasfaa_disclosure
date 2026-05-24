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
  const promptLine = document.getElementById('prompt-line');
  const promptText = document.getElementById('prompt-text');
  const touchControls = document.getElementById('touch-controls');

  // ── URL params ─────────────────────────────────────────────────
  const params = new URLSearchParams(window.location.search);
  const mode = (params.get('mode') || 'scenario').toLowerCase();
  const countParam = parseInt(params.get('count') || '', 10);

  // ── State ──────────────────────────────────────────────────────
  let state = null;
  let footer = '';

  // ── Helpers ────────────────────────────────────────────────────

  function progressBar(correct, total, width) {
    if (total <= 0) return '';
    const filled = Math.round((correct / total) * width);
    return '▓'.repeat(filled) + '░'.repeat(Math.max(width - filled, 0));
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  }

  // Citation linker. Citation strings chain semicolon-separated references
  // belonging to one of three legal bodies: HEA (U.S. Code Title 20), IRC
  // (U.S. Code Title 26), and FERPA (34 CFR Part 99). A body name "sticks"
  // to subsequent chunks until a new body is named, mirroring how the
  // citations are written in nasfaa_scenarios.yml ("HEA §1090(a); §1098h").
  const CITATION_BODIES = [
    { name: 'HEA',          url: 'https://www.law.cornell.edu/uscode/text/20/' },
    { name: 'IRC',          url: 'https://www.law.cornell.edu/uscode/text/26/' },
    { name: 'FERPA 34 CFR', url: 'https://www.ecfr.gov/current/title-34/section-' },
  ];
  const SECTION_RE = /§(\d+[a-z]*(?:\.\d+)?)((?:\([a-zA-Z0-9]+\))*)/g;

  function linkifyCitation(escapedText) {
    let currentBody = null;
    return escapedText.split(';').map((chunk) => {
      const trimmed = chunk.trimStart();
      for (const body of CITATION_BODIES) {
        if (trimmed.startsWith(body.name)) { currentBody = body; break; }
      }
      if (!currentBody) return chunk;
      return chunk.replace(SECTION_RE, (match, section) => {
        const href = currentBody.url + section;
        return `<a class="citation-link" href="${href}" target="_blank" rel="noopener">${match}</a>`;
      });
    }).join(';');
  }

  // Render a box line that needs HTML inside it (e.g. citation links).
  // Word-wraps using the plain text length so padding stays correct after
  // <a> tags are injected.
  function renderCitationBoxLine(text) {
    const lines = BD.wrapText(text, BD.INNER_WIDTH);
    return lines.map((line) => {
      const pad = ' '.repeat(Math.max(BD.INNER_WIDTH - line.length, 0));
      const html = linkifyCitation(escapeHtml(line));
      return '│ ' + html + pad + ' │';
    }).join('\n');
  }

  function formatInputs(inputs) {
    const keys = Object.keys(inputs);
    if (keys.length === 0) return [];
    return keys.map((k) => `  ${k}: ${inputs[k]}`);
  }

  function buildBanner() {
    let suffix;
    if (mode === 'random') {
      const n = (state && state.questionCount()) || 0;
      suffix = `${n} generated questions`;
    } else {
      suffix = `${state ? state.questionCount() : 24} real-world scenarios`;
    }
    return `Test your knowledge of FERPA/FAFSA/FTI disclosure rules with ${suffix}.`;
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

  // Returns HTML (not plain text) so the citation line can carry <a> tags.
  // render() does not re-escape this output.
  function renderReveal(q) {
    const out = [];
    out.push(escapeHtml(BD.boxTop(state.lastWasCorrect ? 'CORRECT!' : 'INCORRECT.')));
    out.push(escapeHtml(BD.boxLine(`Answer:   ${q.expectedResult}`)));
    out.push(escapeHtml(BD.boxLine(`Rule:     ${q.ruleId}`)));
    if (q.citation) {
      out.push(renderCitationBoxLine(`Citation: ${q.citation}`));
    }
    out.push(escapeHtml(BD.boxLine(`Score:    ${state.correct}/${state.total}`)));
    out.push(escapeHtml(BD.boxBottom()));
    return out.join('\n');
  }

  function renderFinal() {
    const out = [];
    out.push(BD.boxHeavyTop());
    out.push(BD.boxHeavyLine(`FINAL SCORE: ${state.correct}/${state.total}`));
    out.push(BD.boxHeavyLine(`${state.percent()}% correct`));
    out.push(BD.boxHeavyLine(''));
    out.push(BD.boxHeavyLine('Press [r] to play again.'));
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
    if (state.finished) return '[r] restart > ';
    if (state.revealing) return '[Space/Enter] continue · [r] restart · [q] quit > ';
    return '[p] permit · [d] deny · [r] restart · [q] quit > ';
  }

  function render() {
    // Parts that are already HTML (renderReveal) are not re-escaped; plain
    // text parts get escaped here.
    const htmlParts = [];
    htmlParts.push(escapeHtml(renderScoreBanner()));
    htmlParts.push('');

    if (state.finished) {
      htmlParts.push(escapeHtml(renderFinal()));
      footer = '';
    } else {
      const q = state.current();
      htmlParts.push(escapeHtml(renderQuestion(q)));
      if (state.revealing) {
        htmlParts.push('');
        htmlParts.push(renderReveal(q));
      }
    }
    if (promptText) promptText.textContent = renderPrompt();
    if (promptLine) promptLine.style.display = '';

    screen.innerHTML = htmlParts.join('\n')
      .replace('CORRECT!', '<span class="correct">CORRECT!</span>')
      .replace('INCORRECT.', '<span class="incorrect">INCORRECT.</span>');
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

  function handleRestart() {
    const data = window.NASFAA_QUIZ_DATA;
    if (!data || !data.rules || !data.scenarios) return;
    startQuiz(data);
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
    } else if (k === 'r' || k === 'R') {
      handleRestart();
      ev.preventDefault();
    } else if (k === ' ' || k === 'Enter' || k === 'Spacebar') {
      handleAdvance();
      ev.preventDefault();
    } else if (k === 'm' || k === 'M') {
      if (window.NasfaaTheme) {
        window.NasfaaTheme.cycle();
        const label = document.getElementById('theme-label');
        if (label) label.textContent = window.NasfaaTheme.current();
      }
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
    bind('btn-restart', handleRestart);
  }

  // ── Bootstrap ──────────────────────────────────────────────────
  // Reads data from window.NASFAA_QUIZ_DATA (populated by data.js, which
  // is generated by build.js from the canonical YAML). No fetch, no XHR —
  // works under file:// without a server.

  function startQuiz(data) {
    const engine = new RuleEngine(data.rules.rules);
    const questions = buildQuestions({
      mode,
      scenarios: data.scenarios.scenarios,
      engine,
      fields: DISCLOSURE_FIELDS,
      count: Number.isFinite(countParam) ? countParam : undefined,
    });
    state = new QuizState(questions);
    const subtitleEl = document.getElementById('subtitle');
    if (subtitleEl) subtitleEl.textContent = buildBanner();
    render();
  }

  function bootstrap() {
    const data = window.NASFAA_QUIZ_DATA;
    if (!data || !data.rules || !data.scenarios) {
      // data.js is a build artifact (gitignored). If it's missing, the
      // page was opened before `make build` ran. Show a terminal-styled
      // notice instead of a tech-y stack trace.
      screen.textContent = [
        '┌─ NOT BUILT ─────────────────────────────────────────────────┐',
        '│                                                             │',
        "│  This page hasn't been built yet.                           │",
        '│                                                             │',
        '│  The quiz loads its data from data.js, which is generated   │',
        '│  from the canonical YAML files at the repo root.            │',
        '│                                                             │',
        '│  From the project root, run:                                │',
        '│                                                             │',
        '│      make build                                             │',
        '│                                                             │',
        '│  Then refresh this page.                                    │',
        '│                                                             │',
        '└─────────────────────────────────────────────────────────────┘',
      ].join('\n');
      if (promptLine) promptLine.style.display = 'none';
      return;
    }
    startQuiz(data);

    const shaEl = document.getElementById('build-sha');
    if (shaEl && data.build && data.build.sha) {
      shaEl.textContent = data.build.sha.slice(0, 7);
    }

    const themeLabel = document.getElementById('theme-label');
    if (themeLabel && window.NasfaaTheme) {
      themeLabel.textContent = window.NasfaaTheme.current();
    }

    document.addEventListener('keydown', onKeyDown);
    wireTouchControls();
  }

  bootstrap();
})();
