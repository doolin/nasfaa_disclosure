// tests.js — runs every scenario in window.NASFAA_DATA.scenarios through
// engine.js and renders pass/fail. The scenarios file is the contract that
// links scenario inputs to rule outcomes — when rules change, scenarios are
// the canonical check.
//
// Plain script; expects window.Nasfaa.RuleEngine and window.NASFAA_DATA
// already loaded.

(function () {
  'use strict';

  const N = window.Nasfaa;
  const data = window.NASFAA_DATA;

  function runScenarios(rules, scenarios) {
    const engine = new N.RuleEngine(rules);
    const results = scenarios.map((s) => {
      const trace = engine.evaluate(s.inputs || {});
      const actualRuleId = trace ? trace.ruleId : null;
      const actualResult = trace ? trace.result : null;
      const expectedRuleId = s.expected.rule_id;
      const expectedResult = s.expected.result;
      const ok = actualRuleId === expectedRuleId && actualResult === expectedResult;
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
    return { passed: passed, total: results.length, results: results };
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  function renderReport(report, summaryEl, listEl) {
    const allPass = report.passed === report.total;
    summaryEl.classList.toggle('all-pass', allPass);
    summaryEl.classList.toggle('any-fail', !allPass);
    summaryEl.textContent =
      report.passed + ' / ' + report.total + ' scenarios passed' +
      (allPass ? ' ✓' : ' (see failures below)');

    listEl.innerHTML = '';
    for (const r of report.results) {
      const li = document.createElement('li');
      li.className = r.pass ? 'pass' : 'fail';

      const status = r.pass ? '[PASS]' : '[FAIL]';
      const head = document.createElement('div');
      head.innerHTML =
        '<span class="scenario-id">' + status + '</span>' +
        '<span>' + r.id + ' — ' + escapeHtml(r.name) + '</span>';
      li.appendChild(head);

      const details = document.createElement('details');
      details.open = !r.pass;
      const summary = document.createElement('summary');
      summary.textContent = r.pass ? 'inputs / rule' : 'diff';
      details.appendChild(summary);
      const pre = document.createElement('pre');
      if (r.pass) {
        pre.textContent =
          'rule:   ' + r.actual.ruleId + ' (' + r.actual.result + ')\n' +
          'inputs: ' + JSON.stringify(r.inputs);
      } else {
        pre.textContent =
          'expected: ' + r.expected.ruleId + ' (' + r.expected.result + ')\n' +
          'actual:   ' + r.actual.ruleId + ' (' + r.actual.result + ')\n' +
          'inputs:   ' + JSON.stringify(r.inputs) + '\n' +
          'engine path: ' + r.actual.path.join(' -> ');
      }
      details.appendChild(pre);
      li.appendChild(details);
      listEl.appendChild(li);
    }
  }

  const out = document.getElementById('tests-out');
  const summary = document.getElementById('tests-summary');
  const shaEl = document.getElementById('build-sha');
  if (!N || !data) {
    summary.textContent = 'Failed: data.js or engine.js did not load.';
    summary.classList.add('any-fail');
    return;
  }
  if (shaEl && data.build && data.build.sha) {
    shaEl.textContent = data.build.sha.slice(0, 7);
  }
  const report = runScenarios(data.rules.rules, data.scenarios.scenarios);
  renderReport(report, summary, out);
})();
