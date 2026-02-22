# NASFAA Decision Tree — Development Roadmap

## Context

The project is a well-tested Ruby implementation of the NASFAA FERPA/FAFSA disclosure decision tree (109 specs, 95%+ coverage, rubocop clean). The code and YAML rules have just been corrected against the canonical PDF. Next steps: package as a gem, build interactive tools, and port to the web.

Key insight from this session: the YAML rules are a language-neutral specification that, once verified exhaustively, becomes the portable target for other platforms. This reframes the work — rather than hand-translating Ruby `if/elsif` logic to JavaScript, we build a YAML evaluator in each language and share the same rule file.

---

## Phase 1: Ruby Gem Packaging

Restructure the flat project into a proper gem. Mechanical refactoring, no behavior changes.

**Files to create:**
- `nasfaa.gemspec` — gem metadata, no runtime deps, dev deps moved from Gemfile
- `Rakefile` — `rake spec`, `rake rubocop`, `rake build`
- `lib/nasfaa.rb` — gem entry point, requires subfiles
- `lib/nasfaa/version.rb` — `Nasfaa::VERSION = "0.1.0"`
- `lib/nasfaa/disclosure_data.rb` — moved from `lib/disclosure_data.rb`, wrapped in `Nasfaa` module
- `lib/nasfaa/decision_tree.rb` — moved from `lib/nasfaa_data_sharing_decision_tree.rb`, renamed class to `Nasfaa::DecisionTree`
- `bin/console` — IRB preloaded with gem
- `bin/nasfaa` — CLI executable (stub for Phase 2)

**Files to update:**
- `Gemfile` — `gemspec` reference instead of inline deps
- `spec/spec_helper.rb` — `require "nasfaa"` instead of relative paths
- All specs — `Nasfaa::DisclosureData`, `Nasfaa::DecisionTree`
- `.rubocop.yml` — exclude `bin/`

**Note:** The `is_fafsa_data` / `fafsa_data?` naming mismatch should be resolved here (add `is_fafsa_data?` alias) since the rule engine in Phase 1.5 needs predicate names to match YAML input names.

**Verification:** `gem build`, `gem install`, `require "nasfaa"`, all specs pass, rubocop clean.

---

## Phase 1.5: YAML Rule Engine + Audit Trail + Exhaustive Verification

This phase creates the infrastructure that makes every subsequent phase dramatically better. The YAML becomes executable, not just documentation.

### 1.5a — Rule Engine (`lib/nasfaa/rule_engine.rb`)
Loads `nasfaa_rules.yml`, evaluates a `DisclosureData` instance against rules in order, returns first match. ~50 lines of core logic. The `when_all` conditions map to predicate methods; negated conditions (prefixed `!`) call the predicate and invert.

### 1.5b — Audit Trail (`lib/nasfaa/trace.rb`)
`Nasfaa::Trace` struct returned by the rule engine: `rule_id`, `result`, `path` (boxes evaluated), `citation`, `scope_note`, `caution_note`. Add `DecisionTree#evaluate` returning a Trace; keep `disclose?` as a boolean wrapper for backward compatibility.

### 1.5c — Exhaustive Verification (`spec/exhaustive_verification_spec.rb`)
Single spec iterating all 2^20 (1,048,576) boolean input combinations, verifying `DecisionTree#disclose?` and `RuleEngine#evaluate` agree on every one. Should run in <30 seconds.

### 1.5d — Scenario Library (`lib/nasfaa/scenarios.yml`)
15-20 named real-world scenarios with descriptions, inputs, expected results, rule IDs, and regulatory citations. Serves triple duty: regression tests, documentation, quiz seed data.

**Verification:** Exhaustive spec passes (0 disagreements), scenario specs pass, both engines return identical results.

---

## Phase 2: Interactive CLI

Two modes using Ruby stdlib (`OptionParser`) — no new runtime dependencies.

### Walkthrough Mode (`bin/nasfaa walkthrough`)
Steps through each decision box interactively. Presents the box number, question text (from the PDF), collects yes/no. Skips irrelevant boxes based on prior answers. Shows result with regulatory citation and full path trace from the audit trail.

Requires a question-sequence data file (`lib/nasfaa/questions.yml`) mapping each box to its field, text, and yes/no successors — essentially the PDF's DAG as structured data.

### Quiz Mode (`bin/nasfaa quiz`)
Draws from the scenario library. Presents a scenario description and inputs, asks the operator for permit/deny. Reveals the correct answer with citation. Tracks score. Optional `--random` flag generates arbitrary boolean combinations for advanced practice.

### Evaluate Mode (`bin/nasfaa evaluate`)
Non-interactive. Accepts flags (`--includes-fti=false --is-fafsa-data=true`) or JSON on stdin. Returns result, rule ID, and citation. Useful for scripting and integration.

**Verification:** CLI specs using StringIO for stdin/stdout simulation. Manual walkthrough of a known scenario.

---

## Phase 3: Visualization

Generate a Mermaid (or Graphviz) diagram from the structured box data (`questions.yml` from Phase 2). This validates the YAML rules visually against the PDF and provides the diagram component for the browser walkthrough.

```bash
nasfaa diagram --format=mermaid > decision_tree.mmd
```

**Verification:** Generated diagram visually matches the PDF layout. Crossing lines are identifiable in the output.

---

## Phase 4: Node.js + Browser

### Node Module (`nodejs/`)
Port the YAML rule engine (not the imperative decision tree) — the YAML is language-neutral and the evaluator is ~50 lines of JavaScript. Share `nasfaa_rules.yml` between Ruby and Node (symlink or copy at build). Port `DisclosureData` as a simple property bag. Run the same exhaustive 2^20 cross-verification and scenario library tests.

### Browser Walkthrough (`nodejs/web/walkthrough.html`)
Single-page app, no framework (vanilla HTML/CSS/JS). Presents one question at a time. Optionally highlights current position on a Mermaid diagram. Shows result with citation and audit trail. All logic runs client-side from the embedded YAML.

### Browser Quiz (`nodejs/web/quiz.html`)
Same quiz flow as CLI. Score tracking via localStorage. Optional timer.

**Verification:** `npm test` passes all ported tests. Browser pages work as static files (no server needed).

---

## Phase 5: Lambda API

Serve the YAML rules from a publicly available AWS Lambda. The Lambda loads `nasfaa_rules.yml`, accepts a JSON payload of boolean inputs, evaluates the rule engine, and returns the result with rule ID, citation, and audit trail. Enables third-party integrations without requiring the Ruby gem or Node module.

**Verification:** Deploy Lambda, `curl` with a known scenario, verify response matches Ruby/Node engines.

---

## Phase 6 (Future): Regulatory Change Tracking

Version YAML rules with effective dates. Build a diff tool (`nasfaa diff v1 v2`) showing which rules changed. Low urgency until the first regulatory change occurs.

---

## Dependency Graph

```
Phase 1 (Gem)
    |
Phase 1.5 (Rule Engine + Audit Trail + Verification)
    |
    +---> Phase 2 (CLI)
    +---> Phase 3 (Visualization)
    +---> Phase 4 (Node.js + Browser)
    +---> Phase 5 (Lambda API)
              |
          Phase 6 (Versioning) — independent, anytime
```

Phases 2, 3, 4, 5 can proceed in parallel after 1.5.

---

## Additional Ideas Worth Considering

- **Crossing-line annotator**: Given the structured box graph from `questions.yml`, automatically detect which edges would cross in a standard top-to-bottom layout. Output a crossing list that can be fed back to an LLM alongside the diagram. Automates the exact workflow we discovered in this session.

- **REPL mode**: `bin/nasfaa repl` drops into an interactive session where you can construct `DisclosureData` objects and evaluate them, inspect traces, compare engines. Useful for ad-hoc exploration beyond the walkthrough's fixed question sequence.

- **Compliance report generator**: Given a set of disclosure scenarios (e.g., all disclosures a school made in a quarter), produce a formatted PDF/HTML report showing the decision path and citation for each. Useful for audit preparation.
