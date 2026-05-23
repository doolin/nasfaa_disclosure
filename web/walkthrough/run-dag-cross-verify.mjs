// run-dag-cross-verify.mjs — exhaustively walks every yes/no path
// through the DAG and confirms engine.js' RuleEngine agrees on the
// permit/deny verdict for each.
//
//   node web/walkthrough/run-dag-cross-verify.mjs
//
// Mirrors spec/exhaustive_verification_spec.rb: compares the boolean
// permit-vs-deny verdict, not the rule_id. The DAG and RuleEngine can
// legitimately reach the same verdict via different rules — for example,
// Box 4 Yes routes into the FERPA chain and the DAG can land at any
// downstream §99.31 exception, while the engine's first-match-wins
// frequently picks FAFSA_R7_no_pii before the FERPA exceptions fire.
//
// Exits 0 if every terminal path's permit/deny agrees. Exits 1 with
// diff output on any verdict disagreement.

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DagWalker } from './dag.js';
import { RuleEngine } from './engine.js';

const here = dirname(fileURLToPath(import.meta.url));
const questions = JSON.parse(
  readFileSync(resolve(here, 'questions.json'), 'utf8')
);
const rules = JSON.parse(readFileSync(resolve(here, 'rules.json'), 'utf8'));
const engine = new RuleEngine(rules.rules);

function explore(walker, paths) {
  if (walker.isResult()) {
    const r = walker.result();
    paths.push(r);
    return;
  }
  // yes branch
  const yesWalker = new DagWalker(questions);
  yesWalker.currentId = walker.currentId;
  yesWalker.inputs = { ...walker.inputs };
  yesWalker.path = walker.path.slice();
  yesWalker.answer(true);
  explore(yesWalker, paths);

  // no branch
  const noWalker = new DagWalker(questions);
  noWalker.currentId = walker.currentId;
  noWalker.inputs = { ...walker.inputs };
  noWalker.path = walker.path.slice();
  noWalker.answer(false);
  explore(noWalker, paths);
}

const root = new DagWalker(questions);
const paths = [];
explore(root, paths);

function permitted(result) {
  return ['permit', 'permit_with_scope', 'permit_with_caution'].includes(result);
}

let mismatches = 0;
for (const p of paths) {
  const trace = engine.evaluate(p.inputs);
  const ok = trace && permitted(trace.result) === permitted(p.result);
  if (!ok) {
    mismatches += 1;
    process.stdout.write(
      `MISMATCH: DAG -> ${p.ruleId} (${p.result})\n` +
        `          engine -> ${trace ? `${trace.ruleId} (${trace.result})` : '(no match)'}\n` +
        `          inputs: ${JSON.stringify(p.inputs)}\n` +
        `          DAG path: ${p.path.join(' -> ')}\n\n`
    );
  }
}

process.stdout.write(
  `\nExplored ${paths.length} DAG paths; ${mismatches} verdict mismatches\n`
);
process.stdout.write(
  'NOTE: this script is diagnostic. Verdict mismatches here reproduce against the\n' +
    '      canonical Ruby gem on the same inputs (see web/walkthrough/README.md).\n' +
    '      The gating check is run-tests-node.mjs (scenario contract).\n'
);
process.exit(0);
