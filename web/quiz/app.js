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
  const devBadge = document.getElementById('dev-badge');

  // Dev mode: toggled by Shift+D. When on, the question card shows the raw
  // input bag and the reveal shows the rule_id, and `j` opens a scenario
  // jump prompt. Hidden by default — these are debugging tools that detract
  // from the normal quiz UX.
  let devMode = false;

  // Reveal-box case studies are collapsed by default so the box stays
  // above the fold; [c] (keystroke or click) toggles them in place. Reset
  // to collapsed on every new reveal — see handleAnswer/handleAdvance.
  let casesExpanded = false;

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

  // Citation linker now lives in web/shared/citation.js (loaded via
  // <script> tag before this file). See that file for the body table,
  // the section regex, and the cross-line `finalBody` threading.
  const { linkifyCitation } = window.NasfaaCitation;

  // Render a box line that needs HTML inside it (e.g. citation links).
  // Word-wraps using the plain text length so padding stays correct after
  // <a> tags are injected. Threads body context across wrapped lines.
  function renderCitationBoxLine(text) {
    const lines = BD.wrapText(text, BD.INNER_WIDTH);
    let body = null;
    return lines.map((line) => {
      const pad = ' '.repeat(Math.max(BD.INNER_WIDTH - line.length, 0));
      const { html, finalBody } = linkifyCitation(escapeHtml(line), body);
      body = finalBody;
      return '│ ' + html + pad + ' │';
    }).join('\n');
  }

  function formatInputs(inputs) {
    const keys = Object.keys(inputs);
    if (keys.length === 0) return [];
    return keys.map((k) => `  ▸ ${k}: ${inputs[k]}`);
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

  // Returns HTML (not plain text) so dev-only sections can be wrapped in a
  // <span class="dev">. render() does not re-escape this output.
  function renderQuestion(q) {
    const out = [];
    out.push(escapeHtml(BD.boxTop(`Question ${state.questionNumber()} of ${state.questionCount()}`)));
    out.push(escapeHtml(BD.boxLine()));
    if (q.description) {
      if (q.name) {
        out.push(`<span class="scenario-name">${escapeHtml(BD.boxCenterLine(q.name))}</span>`);
        out.push(escapeHtml(BD.boxDivider()));
      }
      out.push(escapeHtml(BD.boxLine(q.description.trim())));
      if (devMode) {
        const devLines = [];
        devLines.push(escapeHtml(BD.boxLine()));
        devLines.push(escapeHtml(BD.boxLine('Inputs:')));
        for (const line of formatInputs(q.inputs)) {
          devLines.push(escapeHtml(BD.boxLine(line)));
        }
        out.push('<span class="dev">' + devLines.join('\n') + '</span>');
      }
    } else {
      // Random mode has no description — the input bag IS the question.
      out.push(escapeHtml(BD.boxLine('Given the following disclosure parameters:')));
      out.push(escapeHtml(BD.boxLine()));
      for (const line of formatInputs(q.inputs)) {
        out.push(escapeHtml(BD.boxLine(line)));
      }
      out.push(escapeHtml(BD.boxLine()));
      out.push(escapeHtml(BD.boxLine('(All other fields are false.)')));
    }
    out.push(escapeHtml(BD.boxBottom()));
    return out.join('\n');
  }

  function urlDomain(url) {
    try {
      return new URL(url).hostname.replace(/^www\./, '');
    } catch (_e) {
      return url;
    }
  }

  // Renders the post-answer flavor paragraph + linked case studies inside
  // the existing reveal box. Returns an array of pre-rendered box lines
  // (mix of escaped plain text + HTML with anchors injected). The caller
  // splices these between the citation line and the score line.
  function renderResultContextLines(rc) {
    if (!rc) return [];
    const out = [];
    out.push(escapeHtml(BD.boxLine()));
    if (rc.flavor) {
      out.push(escapeHtml(BD.boxLine(rc.flavor.trim())));
    }
    const cases = Array.isArray(rc.case_studies) ? rc.case_studies : [];
    if (cases.length > 0) {
      out.push(escapeHtml(BD.boxLine()));
      // Clickable summary line. The whole line carries data-key="c" so a tap
      // toggles expansion (see the #screen click listener in bootstrap); the
      // [c] keystroke does the same. Collapsed-by-default keeps the box short.
      const marker = casesExpanded ? '▾' : '▸';
      const hint = casesExpanded ? '[c] hide' : '[c] show';
      const summaryText = `${marker} Cases (${cases.length})   ${hint}`;
      out.push(
        escapeHtml(BD.boxLine(summaryText)).replace(
          escapeHtml(summaryText),
          `<span class="prompt-key" data-key="c">${escapeHtml(summaryText)}</span>`,
        ),
      );
      if (casesExpanded) {
        for (const cs of cases) {
          const year = cs.year ? ` (${cs.year})` : '';
          out.push(escapeHtml(BD.boxLine(`  • ${cs.title}${year}`)));
          if (cs.summary) {
            // Indent summary lines 4 spaces so they read as a sub-bullet.
            const wrapped = BD.wrapText(cs.summary, BD.INNER_WIDTH - 4);
            for (const line of wrapped) {
              out.push(escapeHtml(BD.boxLine(`    ${line}`)));
            }
          }
          if (cs.url) {
            const domain = urlDomain(cs.url);
            const linkBody = `↗ ${domain}`;
            const lineText = `    ${linkBody}`;
            const base = escapeHtml(BD.boxLine(lineText));
            const anchor = `<a class="citation-link" href="${escapeHtml(cs.url)}" target="_blank" rel="noopener">${escapeHtml(linkBody)}</a>`;
            out.push(base.replace(escapeHtml(linkBody), anchor));
          }
        }
      }
    }
    return out;
  }

  // Returns HTML (not plain text) so the citation line can carry <a> tags.
  // render() does not re-escape this output.
  function renderReveal(q) {
    const out = [];
    out.push(escapeHtml(BD.boxTop(state.lastWasCorrect ? 'CORRECT!' : 'INCORRECT.')));
    out.push(escapeHtml(BD.boxLine(`Answer:   ${q.expectedResult}`)));
    if (q.citation) {
      out.push(renderCitationBoxLine(`Citation: ${q.citation}`));
    }
    // Flavor + case studies (only present on scenario-mode questions).
    for (const line of renderResultContextLines(q.resultContext)) {
      out.push(line);
    }
    const scoreLine = escapeHtml(BD.boxLine(`Score:    ${state.correct}/${state.total}`));
    if (state.total > 0) {
      const pct = Math.round((state.correct / state.total) * 100);
      out.push(`<span class="${scoreColorClass(pct)}">${scoreLine}</span>`);
    } else {
      out.push(scoreLine);
    }
    if (devMode) {
      // Inline single-rule value below the user-viewable lines, separated
      // by a blank line. (Inputs in renderQuestion use header+items because
      // they're a list; Rule is always one value, so it stays inline.)
      const devLines = [];
      devLines.push(escapeHtml(BD.boxLine()));
      devLines.push(escapeHtml(BD.boxLine(`Rule:     ${q.ruleId}`)));
      out.push('<span class="dev">' + devLines.join('\n') + '</span>');
    }
    out.push(escapeHtml(BD.boxBottom()));
    return out.join('\n');
  }

  function scoreColorClass(pct) {
    if (pct >= 75) return 'score-high';
    if (pct >= 50) return 'score-mid';
    return 'score-low';
  }

  // Returns HTML; render() does not re-escape it.
  function renderFinal() {
    const pct = state.percent();
    const cls = scoreColorClass(pct);
    const out = [];
    out.push(escapeHtml(BD.boxHeavyTop()));
    out.push(`<span class="${cls}">${escapeHtml(BD.boxHeavyLine(`FINAL SCORE: ${state.correct}/${state.total}`))}</span>`);
    out.push(`<span class="${cls}">${escapeHtml(BD.boxHeavyLine(`${pct}% correct`))}</span>`);
    out.push(escapeHtml(BD.boxHeavyLine('')));
    out.push(escapeHtml(BD.boxHeavyLine('Press [r] to play again.')));
    out.push(escapeHtml(BD.boxHeavyBottom()));
    return out.join('\n');
  }

  // Returns HTML; render() does not re-escape it.
  function renderScoreBanner() {
    const total = state.questionCount();
    const answered = state.total;
    const bar = progressBar(state.correct, total, 16);
    const tail = escapeHtml(`${state.correct}/${answered} of ${total}  ${bar}`);
    if (answered === 0) return `Score: ${tail}`;
    const pct = Math.round((state.correct / answered) * 100);
    return `Score: <span class="${scoreColorClass(pct)}">${tail}</span>`;
  }

  function promptKey(key, label) {
    return `<span class="prompt-key" data-key="${key}">${label}</span>`;
  }

  // Returns HTML with each [k] label wrapped in a clickable .prompt-key span.
  // The click listener (wired in bootstrap) dispatches to the same handlers
  // as the keystroke for that key.
  function renderPrompt() {
    let keys;
    if (state.finished) {
      keys = [promptKey('r', '[r] restart')];
    } else if (state.revealing) {
      // ↵ is the Return-key glyph; kept short so the reveal prompt + [c] cases
      // chip fits one line inside the frame (Return advances — see onKeyDown).
      keys = [promptKey('advance', '[Space/↵] continue')];
      if (currentHasCases()) {
        // Constant label — the in-box ▾/▸ marker conveys expanded/collapsed
        // state, so this stays short to keep the prompt within the frame.
        keys.push(promptKey('c', '[c] cases'));
      }
      keys.push(promptKey('r', '[r] restart'));
      keys.push(promptKey('q', '[q] quit'));
    } else {
      keys = [
        promptKey('p', '[p] permit'),
        promptKey('d', '[d] deny'),
        promptKey('r', '[r] restart'),
        promptKey('q', '[q] quit'),
      ];
    }
    // Trailing no-break space ( ) glues the cursor to the ">" so the
    // blinking block never wraps onto its own line when the prompt wraps.
    return 'Key: ' + keys.join(' · ') + ' > ';
  }

  // scrollMode controls where the viewport lands after a re-render:
  //   undefined → bottom (default: a fresh reveal/question appears at the
  //               foot of the page, so we follow it down)
  //   'cases'   → the "Cases" summary line tops the viewport, so toggling
  //               expansion reveals the cases below it instead of scrolling
  //               past them to the score line at the bottom.
  function render(scrollMode) {
    // Parts that are already HTML (renderQuestion, renderReveal) are not
    // re-escaped; plain text parts get escaped here.
    const htmlParts = [];
    htmlParts.push(renderScoreBanner());
    htmlParts.push('');

    if (state.finished) {
      htmlParts.push(renderFinal());
      footer = '';
    } else {
      const q = state.current();
      htmlParts.push(renderQuestion(q));
      if (state.revealing) {
        htmlParts.push('');
        htmlParts.push(renderReveal(q));
      }
    }
    if (promptText) promptText.innerHTML = renderPrompt();
    if (promptLine) promptLine.style.display = '';

    screen.innerHTML = htmlParts.join('\n')
      .replace('CORRECT!', '<span class="correct">CORRECT!</span>')
      .replace('INCORRECT.', '<span class="incorrect">INCORRECT.</span>')
      .replace(/\bAnswer:/g,   '<span class="label">Answer:</span>')
      .replace(/\bCitation:/g, '<span class="label">Citation:</span>')
      .replace(/\bScore:/g,    '<span class="label">Score:</span>');
    if (scrollMode === 'cases') {
      // Keep the freshly-toggled cases in view: top-align the summary line
      // rather than scrolling to the bottom (which would push the cases off
      // the top of the viewport — see handleCases).
      const summary = screen.querySelector('.prompt-key[data-key="c"]');
      if (summary && summary.scrollIntoView) {
        summary.scrollIntoView({ block: 'start' });
        return;
      }
    }
    // Scroll to bottom so the cursor + prompt stay in view on small screens.
    window.scrollTo(0, document.body.scrollHeight);
  }

  // ── Input handling ─────────────────────────────────────────────

  // True when the reveal for the current question carries case studies, i.e.
  // when the [c] toggle is meaningful. Used by both renderPrompt and handleCases.
  function currentHasCases() {
    if (!state || !state.revealing) return false;
    const q = state.current();
    const rc = q && q.resultContext;
    return !!(rc && Array.isArray(rc.case_studies) && rc.case_studies.length > 0);
  }

  function handleAnswer(choice) {
    if (state.finished) return;
    if (state.revealing) return;       // Space/Enter handles advance separately
    casesExpanded = false;             // new reveal starts collapsed
    state.answer(choice);
    render();
  }

  function handleAdvance() {
    if (state.finished) return;
    if (!state.revealing) return;
    casesExpanded = false;             // next reveal starts collapsed
    state.advance();
    render();
  }

  function handleCases() {
    if (!currentHasCases()) return;
    casesExpanded = !casesExpanded;
    render('cases');
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

  function toggleDevMode() {
    devMode = !devMode;
    if (devBadge) {
      if (devMode) devBadge.removeAttribute('hidden');
      else devBadge.setAttribute('hidden', '');
    }
    if (state) render();
  }

  // Jump to a scenario by 1-based index in the canonical scenarios.json order
  // (not the current shuffled order). Rebuilds state so the chosen scenario
  // is question 1, with the remaining scenarios in canonical order after it.
  function handleJump() {
    if (!devMode) return;
    const data = window.NASFAA_QUIZ_DATA;
    if (!data || !data.scenarios) return;
    const scenarios = data.scenarios.scenarios;
    const input = window.prompt(`Jump to scenario (1-${scenarios.length}):`);
    if (input === null) return;
    const n = parseInt(input, 10);
    if (!Number.isFinite(n) || n < 1 || n > scenarios.length) return;
    const reordered = scenarios.slice(n - 1).concat(scenarios.slice(0, n - 1));
    const Quiz = window.NasfaaQuiz;
    const newQuestions = reordered.map(Quiz.quizQuestionFromScenario);
    state = new Quiz.QuizState(newQuestions);
    casesExpanded = false;
    render();
  }

  function onKeyDown(ev) {
    // Don't fight browser shortcuts.
    if (ev.metaKey || ev.ctrlKey || ev.altKey) return;

    const k = ev.key;

    // Hidden dev-mode toggle (Shift+D). Checked before the plain 'D' = deny
    // branch so Shift+D doesn't double-fire as a deny answer.
    if (k === 'D' && ev.shiftKey) {
      toggleDevMode();
      ev.preventDefault();
      return;
    }
    if ((k === 'j' || k === 'J') && devMode) {
      handleJump();
      ev.preventDefault();
      return;
    }

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
    } else if (k === 'c' || k === 'C') {
      handleCases();
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
    casesExpanded = false;
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

    // Inline-tappable prompt keys: clicking a .prompt-key dispatches the
    // same handler as the corresponding keystroke (touch-friendly without
    // pill buttons taking up screen real estate).
    if (promptLine) {
      promptLine.addEventListener('click', (ev) => {
        const target = ev.target.closest('.prompt-key');
        if (!target) return;
        const key = target.dataset.key;
        if (key === 'p') handleAnswer('permit');
        else if (key === 'd') handleAnswer('deny');
        else if (key === 'r') handleRestart();
        else if (key === 'q') handleQuit();
        else if (key === 'c') handleCases();
        else if (key === 'advance') handleAdvance();
        ev.preventDefault();
      });
    }

    // The in-box "▸ Cases (N)" summary is also a .prompt-key (data-key="c"),
    // so a tap on it toggles expansion just like the prompt-line chip.
    if (screen) {
      screen.addEventListener('click', (ev) => {
        const target = ev.target.closest('.prompt-key');
        if (!target || target.dataset.key !== 'c') return;
        handleCases();
        ev.preventDefault();
      });
    }
  }

  bootstrap();
})();
