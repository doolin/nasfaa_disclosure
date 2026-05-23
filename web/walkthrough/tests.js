// tests.js — runs every scenario in scenarios.json through engine.js and
// renders pass/fail. This is the contract that links scenario inputs to
// rule outcomes — when rules change, scenarios are the canonical check.
//
// Loadable both in the browser (via test.html) and Node (for CI):
//   - In the browser, fetch() loads the JSON.
//   - In Node, set globalThis.NASFAA_TEST_DATA = { rules, scenarios } before
//     calling runScenarios(). See run-tests-node.mjs.

import { RuleEngine } from './engine.js';

export function runScenarios(rules, scenarios) {
  const engine = new RuleEngine(rules);
  const results = scenarios.map((s) => {
    const trace = engine.evaluate(s.inputs || {});
    const actualRuleId = trace ? trace.ruleId : null;
    const actualResult = trace ? trace.result : null;
    const expectedRuleId = s.expected.rule_id;
    const expectedResult = s.expected.result;
    const ok =
      actualRuleId === expectedRuleId && actualResult === expectedResult;
    return {
      id: s.id,
      name: s.name,
      inputs: s.inputs || {},
      expected: { ruleId: expectedRuleId, result: expectedResult },
      actual: { ruleId: actualRuleId, result: actualResult, path: trace ? trace.path : [] },
      pass: ok,
    };
  });
  const passed = results.filter((r) => r.pass).length;
  return { passed, total: results.length, results };
}

// Browser entry point
async function runInBrowser() {
  const out = document.getElementById('tests-out');
  const summary = document.getElementById('tests-summary');
  try {
    const [rules, scenarios] = await Promise.all([
      fetch('./rules.json').then((r) => r.json()),
      fetch('./scenarios.json').then((r) => r.json()),
    ]);
    const report = runScenarios(rules.rules, scenarios.scenarios);
    renderReport(report, summary, out);
  } catch (err) {
    summary.textContent = `Failed to load test data: ${err.message}`;
    summary.classList.add('any-fail');
  }
}

function renderReport(report, summaryEl, listEl) {
  const allPass = report.passed === report.total;
  summaryEl.classList.toggle('all-pass', allPass);
  summaryEl.classList.toggle('any-fail', !allPass);
  summaryEl.textContent = `${report.passed} / ${report.total} scenarios passed${allPass ? ' ✓' : ' (see failures below)'}`;

  listEl.innerHTML = '';
  for (const r of report.results) {
    const li = document.createElement('li');
    li.className = r.pass ? 'pass' : 'fail';

    const status = r.pass ? '[PASS]' : '[FAIL]';
    const head = document.createElement('div');
    head.innerHTML = `<span class="scenario-id">${status}</span><span>${r.id} — ${escapeHtml(r.name)}</span>`;
    li.appendChild(head);

    if (!r.pass) {
      const details = document.createElement('details');
      details.open = true;
      const summary = document.createElement('summary');
      summary.textContent = 'diff';
      details.appendChild(summary);
      const pre = document.createElement('pre');
      pre.textContent =
        `expected: ${r.expected.ruleId} (${r.expected.result})\n` +
        `actual:   ${r.actual.ruleId} (${r.actual.result})\n` +
        `inputs:   ${JSON.stringify(r.inputs)}\n` +
        `engine path: ${r.actual.path.join(' -> ')}`;
      details.appendChild(pre);
      li.appendChild(details);
    } else {
      const details = document.createElement('details');
      const summary = document.createElement('summary');
      summary.textContent = 'inputs / rule';
      details.appendChild(summary);
      const pre = document.createElement('pre');
      pre.textContent =
        `rule:   ${r.actual.ruleId} (${r.actual.result})\n` +
        `inputs: ${JSON.stringify(r.inputs)}`;
      details.appendChild(pre);
      li.appendChild(details);
    }
    listEl.appendChild(li);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[c]);
}

if (typeof window !== 'undefined' && document.getElementById('tests-out')) {
  runInBrowser();
}
