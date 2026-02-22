# NASFAA Decision Tree — Development Roadmap

## Context

The project is a Ruby gem implementing the NASFAA FERPA/FAFSA disclosure decision tree with two independent evaluation engines (imperative `DecisionTree` and declarative YAML `RuleEngine`) proven equivalent across all 36,864 input combinations, plus an interactive walkthrough powered by a question DAG. 270 specs, 94%+ line coverage, rubocop clean.

Key insight from this session: the YAML rules are a language-neutral specification that, once verified exhaustively, becomes the portable target for other platforms. This reframes the work — rather than hand-translating Ruby `if/elsif` logic to JavaScript, we build a YAML evaluator in each language and share the same rule file.

---

## Phase 1: Ruby Gem Packaging ✅

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

## Phase 1.5: YAML Rule Engine + Audit Trail + Exhaustive Verification ✅

This phase creates the infrastructure that makes every subsequent phase dramatically better. The YAML becomes executable, not just documentation.

### 1.5a — Rule Engine (`lib/nasfaa/rule_engine.rb`) ✅
Loads `nasfaa_rules.yml`, evaluates a `DisclosureData` instance against rules in order, returns first match. ~40 lines of core logic. The `when_all` conditions map to bracket notation on `DisclosureData`; negated conditions (prefixed `!`) invert the lookup. 17 specs.

### 1.5b — Audit Trail (`lib/nasfaa/trace.rb`) ✅
`Nasfaa::Trace` struct returned by the rule engine: `rule_id`, `result`, `path` (all rules evaluated before match), `scope_note`, `caution_note`. Provides `permitted?` and `denied?` convenience methods. 14 specs.

### 1.5c — Exhaustive Verification (`spec/exhaustive_verification_spec.rb`) ✅
Single spec testing 36,864 input combinations (2^12 core fields × 9 independent FERPA 99.31 configurations) — a 28× reduction from naive 2^20 by exploiting the tree's structure (Boxes 11–19 are independent yes/no exits). Runs in <0.5 seconds.

Found and fixed 1,728 disagreements in the FTI branch: the imperative `DecisionTree` lacked a deny guard after Box 4 "No" and incorrectly nested the scholarship check (Box 3) under the aid administration guard (Box 2). The YAML rules were already correct. After the fix: 0 disagreements.

### 1.5d — Scenario Library (`nasfaa_scenarios.yml`, `lib/nasfaa/scenario.rb`) ✅
23 named real-world scenarios (one per YAML rule) with narrative descriptions, boolean inputs, expected results, rule IDs, and regulatory citations. Organized into FTI (5), FAFSA-specific (7), FERPA + 99.31 exceptions (10), and denials (1). All four result types represented. Loader class provides `.find(id)`, `.by_tag(tag)`, `.permits`, `.denials`. 59 specs verify rule correctness, cross-engine agreement, full rule coverage, and metadata integrity.

**Verification:** Exhaustive spec passes (0 disagreements), scenario specs pass, both engines return identical results. 203 total specs, 0 failures.

---

## Phase 2: Interactive CLI

Two modes using Ruby stdlib (`OptionParser`) — no new runtime dependencies.

### Walkthrough Mode (`bin/nasfaa walkthrough`) ✅
Steps through each decision box interactively. Presents the box number, question text (from the PDF), collects yes/no. Follows the DAG to the next question or result. Shows result with regulatory citation and full path trace.

Implemented as `Nasfaa::Walkthrough` class powered by `nasfaa_questions.yml` — a structured DAG with 23 question nodes and 23 result nodes mirroring the PDF's two-page layout. Compound questions (e.g., scholarship org + consent) use a `fields` array. The engine collects answers into a `DisclosureData` for cross-verification against the `RuleEngine`. 67 specs verify all 23 terminal paths, DAG structure, cross-verification, output formatting, and input handling.

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
Phase 1 (Gem) ✅
    |
Phase 1.5 (Rule Engine + Audit Trail + Verification) ✅
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
