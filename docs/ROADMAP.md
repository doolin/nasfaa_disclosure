# NASFAA Decision Tree — Development Roadmap

## Context

The project is a Ruby gem implementing the NASFAA FERPA/FAFSA disclosure decision tree with two independent evaluation engines (imperative `DecisionTree` and declarative YAML `RuleEngine`) proven equivalent across all 36,864 input combinations, plus an interactive walkthrough, quiz, and evaluate mode powered by a question DAG and scenario library. 322 specs, 96%+ line coverage, rubocop clean.

Key insight from this session: the YAML rules are a language-neutral specification that, once verified exhaustively, becomes the portable target for other platforms. This reframes the work — rather than hand-translating Ruby `if/elsif` logic to JavaScript, we build a YAML evaluator in each language and share the same rule file.

---

## Release Gates: v0.1.0

The initial public release is gated on four items. All four must be done before announcing.

1. **Unify UX look and feel.** Walkthrough, quiz, and test pages currently share the design tokens and theme switcher but the higher-level layout (banner, question/result framing, footer, padding, typography rhythm) drifts between them. Pick one canonical visual grammar and apply it across all three pages. Detail entry: [§ Unify UX across web pages](#unify-ux-across-web-pages).
2. **Landing page at `/nasfaa/` with project writeup.** A simple HTML page at the root of the `/nasfaa/` namespace (`https://blurbpress.com/nasfaa/`) that links to the walkthrough and quiz, and tells the story of the project. Content drawn from the top-level README, the commit log (PDF-transcription error class, Box 5 / Box 8 fixes, etc.), and curated lessons from the agent memory (diagram spatial reasoning, gitignored build artifacts, etc.). Detail entry: [§ Landing page with project writeup](#landing-page-with-project-writeup).
3. **Rule display more human oriented.** Result rule IDs like `FAFSA_R6b_no_hea_consent_review_deny` are inscrutable to non-developers. Add a human-readable label and (optional) one-sentence rationale to each rule, and use those as the primary display in result cards (CLI + web). The rule ID stays available as a small reference. Detail entry: [§ Human-oriented rule display](#human-oriented-rule-display).
4. **Text matching from PDF.** Every user-visible question and result string must match the NASFAA PDF verbatim — or the page must offer a verbatim-mode toggle alongside the paraphrased text. Detail entry: existing [§ PDF text fidelity audit](#additional-ideas-worth-considering) under Additional Ideas (will be promoted on completion).

Everything beyond these four is post-v0.1.0.

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

## Phase 4: Node.js + Browser ✅

Static SPAs live under `web/walkthrough/` (target: blurbpress.com/nasfaa/disclose-or-not) and `web/quiz/` (target: blurbpress.com/nasfaa/disclosure-quiz). Each:

- Vanilla HTML/CSS/JS, no framework, no build step (works via `file://`).
- JS port of `Nasfaa::RuleEngine`, `BoxDraw`, and (walkthrough) the DAG walker. Plain scripts attached to `window.Nasfaa.*`.
- Canonical YAML stays the source of truth; `build.rb` / `build.js` regenerate `rules.json` / `questions.json` / `scenarios.json` and a `data.js` bundle (`window.NASFAA_DATA` / `window.NASFAA_QUIZ_DATA`) that the HTML loads via `<script>` tag — no fetch, no modules.
- Terminal aesthetic: monospace, dark bg, blinking `▌` cursor, faint scanlines, single-keystroke input, Unicode box-drawn frames mirroring the CLI.
- Touch-controls fallback on coarse-pointer devices.
- Footer shows build SHA (short form, `dev` fallback) and a shamrock link to blurbpress.com.
- `web/walkthrough/test.html` runs all 24 scenarios through the JS engine and reports pass/fail — same scenarios file as the Ruby specs (rule changes show up immediately).
- Cross-engine verification confirmed: both web engines pass 24/24 scenarios against `nasfaa_scenarios.yml`.

**Open gaps:** see "Web page styling refresh", "PDF text fidelity audit", "Citation hyperlinks" in Additional Ideas below.

---

## Phase 5: Hosting ✅ (originally scoped as a Lambda API; resolved as S3-static)

The original plan was a Lambda-backed API serving the YAML rules. The sister project on blurbpress.com (cantilever-fea) deploys as static S3, which fits this app's needs too — the JS engine already runs the rules client-side, so there's no compute layer to host. The Lambda handlers that were built earlier (`lambda.js` in each page directory) have been removed.

**Status:**
- `s3://blurbpress.com/nasfaa/shared/` — canonical theme + tokens
- `s3://blurbpress.com/nasfaa/disclose-or-not/` — walkthrough page (`https://blurbpress.com/nasfaa/disclose-or-not/`)
- `s3://blurbpress.com/nasfaa/disclosure-quiz/` — quiz page (`https://blurbpress.com/nasfaa/disclosure-quiz/`)
- Deploy via `make deploy` from the repo root using the `blurbpress_deploy` AWS profile.
- Verify via `make verify` (HTTP 200 checks).

**Open gap (deferred):** If a third party ever wants a JSON evaluation endpoint (POST inputs → trace JSON) without embedding the JS engine, that's a small Lambda + API Gateway add-on. Not needed for the current consumers.

---

## Phase 6 (Future): Regulatory Change Tracking

Version YAML rules with effective dates. Build a diff tool (`nasfaa diff v1 v2`) showing which rules changed. Low urgency until the first regulatory change occurs.

---

## v0.1.0 Release-Gate Detail

The four blockers listed at the top of this document. Each has its own working notes here so the release-gate list stays scannable.

### Unify UX across web pages

**Goal:** walkthrough, quiz, and test page feel like the same product. Today the design tokens and theme switcher are shared, but the higher-level visual grammar diverges.

**Diverges between pages today:**
- **Banner:** walkthrough has a multi-line title + subtitle + hint + disclaimer block built in HTML; quiz builds its banner as a `<pre>`-rendered string in JS. Different fonts/spacing/colors.
- **Frame:** walkthrough wraps each question in its own thin Unicode box and each result in a heavy Unicode box, then shows the path display separately. Quiz puts everything (banner, score bar, question card, reveal, prompt) inside one `<pre id="screen">`. Test page is a card list with no terminal frame.
- **Footer:** walkthrough has a `<footer>` element with `tests · source · build` links; quiz has its own `.build-footer` element; test page has just a "walkthrough" link.
- **Touch controls:** walkthrough exposes 4 buttons (Y/N/Q/R); quiz exposes 4 buttons (P/D/Q/Space). Styles differ.
- **Score / progress:** quiz only.

**Plan:**
- Pick one canonical surface (single-screen `<pre>` per the quiz, OR per-card frames per the walkthrough) and apply across all three pages.
- Standardize: header band, prompt line, footer row, touch-control row.
- Single `Banner` helper (CSS class + JS builder) used by both pages.
- Single `TouchBar` helper.
- The shared tokens and theme switcher are already in place; this just builds higher-level components on top.

**Acceptance:** screenshots of all three pages side-by-side show the same banner treatment, same prompt-line position, same footer style, same touch-bar style.

### Landing page with project writeup

**Goal:** a static HTML page at `https://blurbpress.com/nasfaa/` (i.e., `s3://blurbpress.com/nasfaa/index.html`) that introduces the project to a first-time visitor and links into the walkthrough and quiz.

**Content sources:**
- **README.md** — motivation, design choices, the two-engine architecture, the 24-scenario contract.
- **Commit log** — selected highlights: Box 5 / Box 8 / Box 9 transition fixes; the PDF-transcription error class as a recurring theme; the static-S3 deploy story; the quiz-engine extraction.
- **Curated agent memory** — public-facing lessons only, not workflow tics. Strong candidates: the diagram-spatial-reasoning rule (crossing lines are an LLM failure mode), the gitignored-build-artifacts technique, the deployment-target clarification (clubstraylight vs slacronym). Skip "user prefers DAMP specs", commit cadence, etc.

**Structure (draft):**
1. One-paragraph TL;DR with two big CTA buttons → walkthrough, quiz.
2. The PDF. Embedded thumbnail of page 1, link to the full PDF.
3. The architecture. Two engines + exhaustive cross-verification + scenario contract.
4. Lessons learned. Three or four bullets from the agent memory, in story form.
5. Source links: GitHub, the canonical YAML files, the test harness.

**Style:** the same unified UX from gate #1 — terminal aesthetic, theme switcher, shamrock-link in the corner.

**Build/deploy:** add `web/landing/` (or repurpose the existing `web/` root structure). Add a `deploy-landing` Makefile target syncing to `s3://blurbpress.com/nasfaa/`. The existing `make deploy` should include it.

**Acceptance:** `https://blurbpress.com/nasfaa/` returns 200 and shows the writeup. Walkthrough and quiz are reachable via clear in-page links.

### Human-oriented rule display

**Goal:** when a result fires, the user sees a plain-language explanation, not a developer rule_id like `FAFSA_R6b_no_hea_consent_review_deny`.

**Today:**
- Result cards (CLI + web) lead with `RESULT: PERMIT` then show `Rule: FAFSA_R6b_no_hea_consent_review_deny` and `Citation: ...`.
- The `message:` field on each result node in `nasfaa_questions.yml` and the `caution_note` field on some rules in `nasfaa_rules.yml` already carry human prose, but they're shown small/below.

**Plan:**
- Add a `label:` field on each rule in `nasfaa_rules.yml` (short, plain-English: "HEA written consent missing — disclosure not permitted") and on each result node in `nasfaa_questions.yml` (likely the same label). Consider whether `label` should live on the rule or on the result node; the rule is the more canonical home if we want the CLI's rule-engine-only path to use it too.
- Optionally add a `rationale:` field on each rule (one-sentence justification: "The Higher Education Act §1090(a)(3)(C) requires written consent before this category of FAFSA data can be released to a non-aid-administration third party.").
- Update the result-card rendering in `Trace`-derived output (CLI), in `Walkthrough#display_result` (Ruby walkthrough), in `web/walkthrough/box-draw.js#renderResultBox`, and in `web/quiz/app.js#renderReveal` to lead with the human label, then the message, then the rule_id as a small reference at the bottom.
- Update scenarios in `nasfaa_scenarios.yml` to use the new labels in their narrative if helpful.

**Acceptance:** a non-developer reading any result card can summarize the outcome in one sentence without consulting the rule_id.

### PDF text matching

See [§ PDF text fidelity audit](#additional-ideas-worth-considering) under Additional Ideas. Audit `pdf_text:` on every question node + every result node `message:` field against the canonical PDF; either bring them to verbatim parity or add a `--pdf-text`-style toggle on the web pages. Already partially done in the CLI (`bin/nasfaa walkthrough --pdf-text` populates `pdf_text:`). The web pages need their own verbatim-mode toggle and a drift check that flags divergence in CI.

**Acceptance:** every question and result string is either verbatim from the PDF or has both forms available behind a toggle. A grep / diff script can verify no drift.

---

## Dependency Graph

```
Phase 1 (Gem) ✅
    |
Phase 1.5 (Rule Engine + Audit Trail + Verification) ✅
    |
    +---> Phase 2 (CLI) ✅
    +---> Phase 2.5 (CLI Polish) ✅
    +---> Phase 3 (Visualization)
    +---> Phase 4 (Node.js + Browser) ✅
    +---> Phase 5 (Lambda API) ✅ (code) — deploy outstanding
              |
          Phase 6 (Versioning) — independent, anytime
```

---

## Additional Ideas Worth Considering

- **Citation fields on question nodes**: Add a `citation:` field to question nodes in `nasfaa_questions.yml` (currently only result nodes carry citations). Enables the walkthrough and evaluate modes to surface the regulatory authority for each question, not just the final result. Regulatory text is publicly available — e.g., the FERPA exceptions gating Box 10 are at https://www.ecfr.gov/current/title-34/subtitle-A/part-99/subpart-D/section-99.31 — so citations can link directly to eCFR rather than paywalled summary documents.

- **Crossing-line annotator**: Given the structured box graph from `questions.yml`, automatically detect which edges would cross in a standard top-to-bottom layout. Output a crossing list that can be fed back to an LLM alongside the diagram. Automates the exact workflow we discovered in this session.

- **REPL mode**: `bin/nasfaa repl` drops into an interactive session where you can construct `DisclosureData` objects and evaluate them, inspect traces, compare engines. Useful for ad-hoc exploration beyond the walkthrough's fixed question sequence.

- **Compliance report generator**: Given a set of disclosure scenarios (e.g., all disclosures a school made in a quarter), produce a formatted PDF/HTML report showing the decision path and citation for each. Useful for audit preparation.

- **Property-based testing**: Use `rantly` or `propcheck` to generate arbitrary `DisclosureData` inputs and verify invariants that must hold regardless of input — e.g., the DAG and RuleEngine always agree, every path terminates in a result node, every result node carries a non-empty `rule_id`. Complements the existing exhaustive 2^12 spec with randomly-structured edge cases and shrinking on failure.

- **LLM natural-language evaluation**: Accept a free-text scenario description and use an LLM to extract the relevant boolean inputs, then evaluate against the rule engine. Example: `nasfaa evaluate --llm "A financial aid officer wants to share a student's tax return with their parent to help complete the FAFSA"` → extracts `{is_fti: true, disclosure_to_student: false, ...}`, runs the rule engine, returns the result with citation and audit trail. The structured YAML rules and the public regulatory text together give a frontier model enough grounding to reason correctly about most cases — the deterministic engine acts as a verifiable check on the extraction step.

- **Slide deck generator**: Generate a presentation from the structured data — decision tree overview, key branch points (FTI vs. FAFSA vs. FERPA), example scenarios with walk-through paths, and regulatory citations. Could target Reveal.js (HTML), Mermaid-embedded Markdown (for Marp/Slidev), or PDF via LaTeX Beamer. The YAML scenarios and box graph provide all the content; the generator handles layout and sequencing. Useful for compliance training sessions and onboarding new financial aid staff.

- **Print-ready DAG poster**: Print the official PDF of the decision tree DAG distributed by NASFAA to use for manual QA. Print at Copy Central: one copy on 100lb stock in color, plus 10 copies black and white. Good first task for a clawbot — find the nearest Copy Central, place the order, let the human know when it's ready to pick up.

- **Fix Box 5 Yes transition** ✅: Box 5 Yes now routes through the FERPA §99.31 exception chain starting at Box 12 (school official LEI) rather than auto-permitting. The standalone `FAFSA_R3_used_for_aid_admin` rule was deleted entirely — aid admin permits now surface as `FERPA_R2_school_official_LEI` (or whichever §99.31 exception matches), giving the walkthrough and rule engine a single shared rule_id per terminal. Cascading `!used_for_aid_admin` guards added to `FAFSA_R4`, `FAFSA_R6`, `FAFSA_R6b`, and `FAFSA_R7` keep the engines aligned with the DAG flow. `DecisionTree`'s Box 5 Yes branch checks `ferpa_written_consent` before falling into the §99.31 chain to mirror the rule engine's flatten (FERPA_R0 has no `!aid_admin` guard since the rule syntax can't express path-based exclusion). Exhaustive verification (36,864 combos) passes with 0 disagreements. Plan: [nasfaa-box-5-transition.md](nasfaa-box-5-transition.md)

- **Box 7 Yes/No transition** ✅ *(no fix needed)*: The original plan claimed Box 7's branches were inverted. Re-reading the PDF zoom ([box9-right-context-zoom.png](box9-right-context-zoom.png)) directly confirms the current implementation is correct: Box 7 **Yes** (research) arrow goes up-right to **Box 9** (PII), Box 7 **No** arrow goes down to **Box 8** (HEA consent). Statutory citations match this routing too — Box 7 cites §1090(a)(3)(C)(ii) (the research carve-out) while Box 8 cites §1090(a)(3)(C) (the general consent). The plan-writing agent appears to have conflated Box 7 with Box 8 (the gray-terminal fix that did land). The detailed plan at [nasfaa-box-7-transition.md](nasfaa-box-7-transition.md) is kept for archival purposes but should be considered superseded by this resolution.

- **Fix Box 8 No transition** ✅: Box 8 No now terminates at `FAFSA_R6b_no_hea_consent_review_deny` matching the gray PDF terminal. Adds `!disclosure_to_contributor_parent_or_spouse` guard so contributor paths still route through FERPA correctly. The duplicate §99.31(a)(9)(ii) caution text moved from `FERPA_R3_judicial_or_finaid_related` (where it was misattributed) to the new Box 8 deny rule. Exhaustive verification (36,864 combos) passes with 0 disagreements. Plan: [nasfaa-box-8-transition.md](nasfaa-box-8-transition.md)

- **Fix FAFSA_R6 contributor over-permit** *(follow-up surfaced during Box 8 fix)*: `FAFSA_R6_HEA_written_consent` permits whenever `!FTI && fafsa && !research && hea_consent`, regardless of `disclosure_to_contributor_parent_or_spouse`. Per the DAG, contributor=Yes routes through Box 10 (FERPA consent) and should not auto-permit via HEA. Both `DecisionTree` and `RuleEngine` have the same gap, so exhaustive verification doesn't catch it — but the walkthrough disagrees with both engines when contributor=Yes && hea_consent=Yes && !ferpa_consent && no 99.31 exceptions. Fix: add `!disclosure_to_contributor_parent_or_spouse` to FAFSA_R6's `when_all` and add the matching guard in `decision_tree.rb`.

- **Recreate decision tree from original references**: Build the decision tree directly from the primary regulatory sources (IRC §6103, HEA §1090/§1098h, FERPA 34 CFR Part 99) rather than from the NASFAA PDF. Compare the independently derived tree against the current NASFAA-sourced implementation to identify any discrepancies, missing branches, or simplifications NASFAA introduced. Would validate the current logic against statute and potentially surface edge cases the PDF glosses over. Also serves as an audit of whether NASFAA's packaging introduced editorial choices — simplifications, omissions, or groupings — that diverge from what the regulations actually require.

- **Web page styling refresh — accessible color system + light/dark modes**: The current terminal aesthetic is a fun VT102 throwback but the cyan-on-near-black palette is too bright for sustained reading and isn't WCAG 508-compliant. Redesign using the accessible color system from <https://stripe.com/blog/accessible-color-systems> — derive a palette of foreground / dim / accent / permit / deny / caution tokens that hit AA contrast (≥4.5:1) on both backgrounds. Implement both light and dark themes via CSS custom properties under `[data-theme="dark"]` / `[data-theme="light"]`, with a theme toggle in the page footer (default to system `prefers-color-scheme`). Preserve the terminal aesthetic (monospace, scanlines optional and toggleable, blinking cursor) but soften the palette and ensure the permit/deny accent colors are distinguishable for the common color-vision deficiencies. Apply to both [web/walkthrough/](../web/walkthrough/) and [web/quiz/](../web/quiz/), plus [web/walkthrough/test.html](../web/walkthrough/test.html).

- **PDF text fidelity audit**: Walk through every question and result node in `nasfaa_questions.yml` and every rule message in `nasfaa_rules.yml` against the canonical PDF (`docs/NASFAA_Data_Sharing_Decision_Tree.pdf`). Two deliverables: (1) verify every `pdf_text:` field on question nodes is verbatim (the CLI's `--pdf-text` mode and the web pages' help text rely on it); (2) decide for each user-facing string in result nodes / rule messages whether to track the PDF verbatim, paraphrase, or offer both via a `--pdf-text` equivalent toggle on the web pages. Output a diff report identifying any drift, then update the YAML to bring drift back to zero. Also add a CI check (or rake task) that flags future drift when the PDF is updated.

- **Quiz scenario accuracy deep dive**: The 24 scenarios in `nasfaa_scenarios.yml` were authored alongside the rules but haven't been independently verified for real-world plausibility and regulatory accuracy. For each scenario, audit: (a) does the narrative match the inputs (e.g., "aid office staff have been designated as school officials with LEI" should set `to_school_official_legitimate_interest: true`)? (b) does the expected rule match what a financial aid administrator would actually do? (c) does the citation point to the right regulation? (d) is the scenario representative of a situation that actually occurs in practice, or is it a contrived edge case? Likely outcome: 3–6 scenarios get rewritten or replaced. Consider sourcing scenarios from NASFAA's published guidance or training materials.

- **Hyperlink every citation reference**: Every `citation:` field on result nodes (and the `Citation:` line in `Trace`-derived output) currently contains plain text like "FERPA 34 CFR §99.31(a)(1)" or "IRC §6103(l)(13)". Build a citation-resolution layer that maps each citation string to its public regulatory URL — eCFR for FERPA / Title 34 (e.g., `https://www.ecfr.gov/current/title-34/subtitle-A/part-99/subpart-D/section-99.31`), USC for HEA and IRC (e.g., `https://www.law.cornell.edu/uscode/text/20/1090`). The mapping lives in a new YAML or JSON file so the same lookup powers the CLI (could open via `open <url>` on macOS), the walkthrough/quiz web pages (`<a href>` in the result card), and the test harness. Render as clickable links on the web; print as `Citation: TEXT (url)` in the terminal.

- **Update the README "Timeline" section**: It currently reads "Partly estimated and partly extracted from the commit history." with no table. Extract the actual timeline from `git log` (per-phase elapsed wall-clock and approximate active hours), and render as a Markdown table: phase / scope / commits / wall-clock / notes. Include the recent Box 5/8 fixes, the static-page web work, and the Lambda handler builds. Tie each row back to the relevant section of this roadmap.

- **Marp presentation for the work**: Generate a [Marp](https://marp.app) slide deck (`docs/presentation.md`) that walks through the project: motivation, architecture (two engines + exhaustive cross-verification + 24-scenario contract), the PDF-transcription error class (Box 5 / Box 8 fixes, Box 9 PII inversion, why crossing-line diagrams are an LLM failure mode), the CLI / web ports, and lessons. Embed screenshots of the walkthrough / quiz / test harness. Single `marp` command should render to PDF and HTML for sharing. Useful for talks and for new contributors who want the 20-minute overview before diving into the YAML.

- **Deploy to blurbpress.com** ✅: Static S3 deploy from the repo-root `Makefile` (`make deploy`). Shared theme assets at `s3://blurbpress.com/nasfaa/shared/`, pages at `/nasfaa/disclose-or-not/` and `/nasfaa/disclosure-quiz/`. The Lambda handlers from the original (mistaken) plan have been removed; blurbpress is S3-static. Build SHA is captured at build time and baked into each page's `data.js`. A `make verify` target HTTP-probes all the deployed URLs.

- **Mobile / browser test matrix**: The web pages have touch-controls fallback and `prefers-reduced-motion` overrides, but neither has been tested in a real browser on a real device. Smoke-test in Chrome / Firefox / Safari (desktop) and Safari iOS / Chrome Android. Capture screenshots into `docs/screenshots/` for the README. Likely surfaces small font-size / overflow / cursor-blink issues to fix.

- **Dedupe web-styling shared assets** ✅: Resolved by namespacing the deploy paths under `/nasfaa/` on blurbpress.com. The canonical `web/shared/` directory ships once to `s3://blurbpress.com/nasfaa/shared/`, and both pages reference it via the relative path `../shared/...` from their own deploy subdirectories (`/nasfaa/disclose-or-not/` and `/nasfaa/disclosure-quiz/`). Same relative path works under `file://` for local dev. No bucket-root collision with sibling projects on blurbpress because everything lives under the `/nasfaa/` namespace. The earlier duplicated-and-mirror-tagged copies under each page directory have been removed.
