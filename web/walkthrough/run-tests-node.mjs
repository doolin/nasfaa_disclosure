// run-tests-node.mjs — Node-side runner for the same scenario tests
// that test.html executes in the browser. Useful for CI and pre-commit
// without needing a headless browser.
//
//   node web/walkthrough/run-tests-node.mjs
//
// Exits 0 on all-pass, 1 on any failure.

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runScenarios } from './tests.js';

const here = dirname(fileURLToPath(import.meta.url));
const rules = JSON.parse(readFileSync(resolve(here, 'rules.json'), 'utf8'));
const scenarios = JSON.parse(
  readFileSync(resolve(here, 'scenarios.json'), 'utf8')
);

const report = runScenarios(rules.rules, scenarios.scenarios);

for (const r of report.results) {
  const tag = r.pass ? 'PASS' : 'FAIL';
  process.stdout.write(`[${tag}] ${r.id} — ${r.name}\n`);
  if (!r.pass) {
    process.stdout.write(
      `       expected: ${r.expected.ruleId} (${r.expected.result})\n` +
        `       actual:   ${r.actual.ruleId} (${r.actual.result})\n` +
        `       inputs:   ${JSON.stringify(r.inputs)}\n` +
        `       engine path: ${r.actual.path.join(' -> ')}\n`
    );
  }
}

process.stdout.write(`\n${report.passed} / ${report.total} scenarios passed\n`);
process.exit(report.passed === report.total ? 0 : 1);
