# NASFAA Decision Tree — Development Roadmap

## Context

The project is a Ruby gem implementing the NASFAA FERPA/FAFSA disclosure decision tree with two independent evaluation engines (imperative `DecisionTree` and declarative YAML `RuleEngine`) proven equivalent across all 36,864 input combinations, plus an interactive walkthrough, quiz, and evaluate mode powered by a question DAG and scenario library. 322 specs, 96%+ line coverage, rubocop clean.

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

Implemented as `Nasfaa::Walkthrough` class powered by `nasfaa_questions.yml` — a structured DAG with 23 question nodes and 22 result nodes mirroring the PDF's two-page layout. Compound questions (e.g., scholarship org + consent) use a `fields` array. The engine collects answers into a `DisclosureData` for cross-verification against the `RuleEngine`. 66 specs verify all 22 terminal paths, DAG structure, cross-verification, output formatting, and input handling.

### Quiz Mode (`bin/nasfaa quiz`) ✅
Draws from the scenario library. Presents a scenario description and inputs, asks the operator for permit/deny. Reveals the correct answer with citation. Tracks score. Optional `--random` flag generates arbitrary boolean combinations for advanced practice.

Implemented as `Nasfaa::Quiz` class with two modes: scenario mode (shuffles all 23 named scenarios) and random mode (generates arbitrary boolean `DisclosureData` combinations evaluated by the `RuleEngine`). Follows the same injectable I/O pattern as Walkthrough. Accepts abbreviated input (`p`/`d`) and mixed case. For `permit_with_scope` and `permit_with_caution` results, answering "permit" counts as correct. 18 specs cover both modes, input handling, and score tracking.

### Evaluate Mode (`bin/nasfaa evaluate`) ✅
Non-interactive. Accepts a compact string of y/n answers to navigate the walkthrough DAG, with an optional trailing p/d assertion. Returns result, rule ID, path, and pass/fail. Useful for scripting and quick verification.

Implemented as `Nasfaa::Evaluate` class that feeds the compact string to a `Walkthrough` instance via StringIO, cross-verifies with the `RuleEngine`, and optionally checks the result against an assertion. 33 specs cover all 22 terminal paths, assertion pass/fail, cross-verification, and error handling.

---

## Phase 2.5: CLI Polish ✅

UX improvements to all CLI modes (walkthrough, quiz, evaluate). No new features — refines the existing interactive experience.

- **Box-draw formatting** ✅: Unicode box-drawing characters wrap each question (light box) and result (heavy box) for visual separation in the terminal. Word-wrap inside boxes; ANSI-colored text bypasses wrap to avoid splitting escape sequences.

- **PDF-exact text mode** (`--pdf-text`) ✅: `bin/nasfaa walkthrough --pdf-text` displays the verbatim text from each PDF box (stored as `pdf_text:` in `nasfaa_questions.yml`) alongside the paraphrased question text, labeled `PDF:` in dim. All 23 question nodes populated from the two-page PDF images. Off by default.

- **Single-keystroke advance** ✅: `y`/`n`/`q` (and `p`/`d`/`q` in quiz) register immediately on keypress without requiring Enter. Uses raw terminal mode (`io/console`). Detected via `input.respond_to?(:getch)` so tests use StringIO unmodified.

- **Colorized output** ✅: Colorblind-safe palette (deuteranopia/protanopia friendly): bold cyan / bold yellow for dark terminals, bold blue / yellow for light terminals. `--color=dark|light|none`. Implemented as `Nasfaa::Colorizer` thin wrapper; all output goes through it.

- **Rich evaluate output** ✅: `bin/nasfaa evaluate` renders a box-drawn result card with RESULT header, rule ID, regulatory citation, scenario name and narrative (when a named scenario covers the rule), answer path, and optional assertion pass/fail. Cross-verifies DAG result against RuleEngine and warns on disagreement.

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

- **Citation fields on question nodes**: Add a `citation:` field to question nodes in `nasfaa_questions.yml` (currently only result nodes carry citations). Enables the walkthrough and evaluate modes to surface the regulatory authority for each question, not just the final result. Regulatory text is publicly available — e.g., the FERPA exceptions gating Box 10 are at https://www.ecfr.gov/current/title-34/subtitle-A/part-99/subpart-D/section-99.31 — so citations can link directly to eCFR rather than paywalled summary documents.

- **Crossing-line annotator**: Given the structured box graph from `questions.yml`, automatically detect which edges would cross in a standard top-to-bottom layout. Output a crossing list that can be fed back to an LLM alongside the diagram. Automates the exact workflow we discovered in this session.

- **REPL mode**: `bin/nasfaa repl` drops into an interactive session where you can construct `DisclosureData` objects and evaluate them, inspect traces, compare engines. Useful for ad-hoc exploration beyond the walkthrough's fixed question sequence.

- **Compliance report generator**: Given a set of disclosure scenarios (e.g., all disclosures a school made in a quarter), produce a formatted PDF/HTML report showing the decision path and citation for each. Useful for audit preparation.

- **Property-based testing**: Use `rantly` or `propcheck` to generate arbitrary `DisclosureData` inputs and verify invariants that must hold regardless of input — e.g., the DAG and RuleEngine always agree, every path terminates in a result node, every result node carries a non-empty `rule_id`. Complements the existing exhaustive 2^12 spec with randomly-structured edge cases and shrinking on failure.

- **LLM natural-language evaluation**: Accept a free-text scenario description and use an LLM to extract the relevant boolean inputs, then evaluate against the rule engine. Example: `nasfaa evaluate --llm "A financial aid officer wants to share a student's tax return with their parent to help complete the FAFSA"` → extracts `{is_fti: true, disclosure_to_student: false, ...}`, runs the rule engine, returns the result with citation and audit trail. The structured YAML rules and the public regulatory text together give a frontier model enough grounding to reason correctly about most cases — the deterministic engine acts as a verifiable check on the extraction step.
