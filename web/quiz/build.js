#!/usr/bin/env node
//
// build.js — Regenerate rules.json and scenarios.json from the canonical
// YAML sources at the project root.
//
// Strategy: shell out to Ruby (already a project dependency) so we use the
// exact same YAML parser that the canonical Ruby code uses.  No npm
// install step, no third-party JS YAML parser drift.
//
// Usage (from project root, OR from web/quiz/):
//   node web/quiz/build.js
//   # or
//   cd web/quiz && node build.js
//
// Re-run after editing nasfaa_rules.yml or nasfaa_scenarios.yml.

'use strict';

const { execFileSync } = require('node:child_process');
const { writeFileSync, existsSync } = require('node:fs');
const path = require('node:path');

const HERE = __dirname;
const PROJECT_ROOT = path.resolve(HERE, '..', '..');
const RULES_YAML = path.join(PROJECT_ROOT, 'nasfaa_rules.yml');
const SCENARIOS_YAML = path.join(PROJECT_ROOT, 'nasfaa_scenarios.yml');
const RULES_JSON = path.join(HERE, 'rules.json');
const SCENARIOS_JSON = path.join(HERE, 'scenarios.json');

function yamlToJson(yamlPath) {
  if (!existsSync(yamlPath)) {
    throw new Error(`YAML source not found: ${yamlPath}`);
  }
  const ruby = `require 'yaml'; require 'json'; ` +
               `puts JSON.pretty_generate(YAML.safe_load_file(ARGV[0]))`;
  const out = execFileSync('ruby', ['-e', ruby, yamlPath], {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
  });
  return out;
}

function build() {
  console.log('Reading', path.relative(PROJECT_ROOT, RULES_YAML));
  const rulesJson = yamlToJson(RULES_YAML);
  writeFileSync(RULES_JSON, rulesJson);
  console.log('  wrote', path.relative(PROJECT_ROOT, RULES_JSON));

  console.log('Reading', path.relative(PROJECT_ROOT, SCENARIOS_YAML));
  const scenariosJson = yamlToJson(SCENARIOS_YAML);
  writeFileSync(SCENARIOS_JSON, scenariosJson);
  console.log('  wrote', path.relative(PROJECT_ROOT, SCENARIOS_JSON));

  console.log('Done.');
}

try {
  build();
} catch (err) {
  console.error('build.js failed:', err.message);
  process.exit(1);
}
