# AGENTS

Orientation notes for an AI agent working in this repo. Read this before
touching rules, specs, or the web pages — it captures the non-obvious
invariants and the gotchas that have actually caused bugs here.

## What this project is

A NASFAA data-sharing disclosure decision tree, shipped two ways:

- **Ruby gem + CLI** (`bin/nasfaa`, `lib/nasfaa/`) — `walkthrough`,
  `quiz`, `evaluate`, and scenario-query modes.
- **Static web pages** (`web/`) deployed to S3 (`blurbpress.com/nasfaa/…`).

Source-of-truth order (this matters when something disagrees):
1. **The printed PDF is canonical.** When YAML and PDF conflict, the PDF wins.
2. **YAML** (`nasfaa_rules.yml`, `nasfaa_questions.yml`,
   `nasfaa_scenarios.yml`) is a secondary representation of the PDF.
3. **FTI logic** (IRC §6103 / Page 2) was manually verified and is assumed
   correct — don't "fix" it without checking the PDF first.

A wrong rule in the YAML is a **correctness bug**, not a data-entry typo —
treat it with the same seriousness as a code bug.

## The one invariant that will bite you: dual implementation

The decision logic exists **twice on purpose**, and an exhaustive spec
cross-checks them against each other:

- `lib/nasfaa/decision_tree.rb` — an **imperative** hand-written tree.
- `lib/nasfaa/rule_engine.rb` — a **data-driven** engine reading
  `nasfaa_rules.yml`.
- `spec/exhaustive_verification_spec.rb` — runs every input configuration
  through both and asserts they agree.

This redundancy is the safety net. So **a single rule change is never a
single-file edit.** Changing one rule typically requires coordinated edits
across all of:

- `nasfaa_rules.yml` (the rule)
- `lib/nasfaa/decision_tree.rb` (the second, imperative implementation)
- `nasfaa_questions.yml` (the question DAG — node ids, branches)
- `spec/support/paths.rb` (canonical compact paths)
- per-rule spec assertions and scenario narratives
- README / `docs/ROADMAP.md` rule-count text (drifts silently)

The exhaustive spec catches divergence between the two engines, but **not**
rule-count assertions, narrative text, or README mentions. After a rule
change, grep for the rule id and the old result everywhere.

> Aspiration logged in `docs/ROADMAP.md`: make `nasfaa_rules.yml` the only
> hand-edit needed and regenerate the rest. Not done yet. If you're about to
> hand-edit `decision_tree.rb` to match a YAML change, first enumerate every
> file that hard-codes rule-derived state — that list is the prerequisite for
> any automation, and the ROADMAP has working notes.

## Diagram / flowchart spatial reasoning — known failure mode

The decision logic comes from a flowchart with **crossing lines**, and
models reliably confuse which arrow goes where at intersections. The "Box 9
PII inversion" bug here was exactly this. When working from the diagram:

- Ask the human for a **crossing list** (`"Box X Yes → Box Y crosses Box A
  No → Box B"`). Cheap for a human to eyeball, eliminates the error class.
- The "tree" is really a **DAG** — multiple paths converge on shared nodes.
  Watch for converging branches.

## Build / test / deploy

Everything is driven by the top-level `Makefile`. Common targets:

- `bundle exec rspec` — Ruby suite. **Coverage gate is 100% line / 100%
  branch** (SimpleCov). Don't land a drop.
- `make test` — front-end Node tests (`node --test web/*/test-*.mjs`).
- `make test-coverage` — front-end coverage (Node built-in).
- `make build` — regenerates web `data.js` + JSON bundles from the YAML.
- `make survey` / `make time-analysis` / `make text-verify` — bin/ tools.
- `make deploy` (and `deploy-shared`/`-walkthrough`/`-quiz`/`-about`) —
  `aws s3 sync` to `blurbpress.com` under profile `blurbpress_deploy`.
- `make dry` / `make verify` — preview the sync / curl the live URLs.

Specs are **DAMP** (Descriptive And Meaningful Phrases): explicit data,
named examples, avoid RSpec short-form. Data and logic are strictly
separated — `DisclosureData` holds predicates, the trees hold decisions.

## Web pages — architecture and gotchas

- **Shared modules** live in `web/shared/` (tokens, theme, dev/label utils,
  citation linker, glyphs). Both pages `<link>`/`<script>` these via
  `../shared/…`, which resolves under both `file://` and S3.
- **`data.js` and the `*.json` bundles are gitignored build artifacts.** A
  fresh clone must run `make build` before the pages work. Each page's
  bootstrap detects the missing global and renders a terminal-styled "NOT
  BUILT" notice with the fix command — keep that pattern if you add a page.
- **Deploy paths are descriptive, code paths are terse.** URLs are
  `/nasfaa/disclose-or-not/` and `/nasfaa/disclosure-quiz/`; the source dirs
  stay `web/walkthrough/` and `web/quiz/` to match the CLI verbs. Only
  rewrite URL/deploy references when renaming, never code-internal paths.

### The `<pre>` + box-draw terminal aesthetic (read before editing UI)

The quiz/walkthrough screens are a single `<pre>` with `white-space: pre`.
The Unicode box frame (`│ … │`) is **baked into each line of text** by
`web/quiz/box-draw.js` (`boxTop`/`boxLine`/`boxBottom`, `INNER_WIDTH`).
Consequences that have caused real bugs:

- You can't drop a normal block element (`<details>`, etc.) into the frame
  without it fighting `white-space: pre`. Prefer the existing keyboard-toggle
  pattern (a state flag + re-`render()`, like dev-mode `Shift+D`, jump `j`,
  and the `[c]` cases toggle).
- HTML injected into a box line (anchors, clickable spans) must preserve the
  plain-text column width — see how citation links and the `.prompt-key`
  spans use `.replace()` on the escaped text and rely on padding/negative
  margins so the borders stay aligned.
- `render()` ends with `window.scrollTo(0, scrollHeight)`. That's right for a
  fresh reveal but wrong for in-place toggles — it yanked freshly-expanded
  content off-screen. Pass a scroll mode and `scrollIntoView` the relevant
  line instead (see `render('cases')` / `handleCases`).
- The **prompt line** (`.prompt-text`) must fit the frame. It was
  `white-space: pre` (no wrap) and overflowed when a chip was added; it's now
  `display:block` + `pre-wrap`, chips are `white-space:nowrap`, and the
  cursor is glued to `>` with a non-breaking space so it never orphans.
  Keep the longest prompt variant under the box width (~60 chars).

## Working conventions (this repo / maintainer)

- **Commit messages need approval.** When asked to commit, draft the message
  and show it **before** running `git commit` — the maintainer uses commit
  messages as their project-tracking log. (Trailer:
  `Co-Authored-By: Claude <noreply@anthropic.com>`.)
- **Commit before deploy.** Never `make deploy*` with uncommitted changes —
  the deploy is a public side effect that must follow the commit.
- **Destructive AWS ops:** default to dry-run + show the list + ask. The
  maintainer is hands-on about S3 deletes and will often do them personally.
- **Clean up orphaned state in the same session** — old S3 keys, stale
  caches — rather than queueing it; it's invisible until it bites.
- **Commit at logical boundaries**; don't batch unrelated work.

## Map of the repo

- `lib/nasfaa/` — gem code (two decision implementations, CLI modes,
  box-draw, colorizer, single-key reader).
- `spec/` — RSpec; `exhaustive_verification_spec.rb` is the cross-engine
  invariant; `spec/support/paths.rb` holds canonical paths.
- `nasfaa_{rules,questions,scenarios}.yml` — the canonical-ish data.
- `web/{shared,walkthrough,quiz,about,text-verify}/` — static pages;
  `text-verify` is local-only (not deployed).
- `bin/` — `nasfaa` CLI plus stdlib-only tooling
  (`coverage-survey`, `time-analysis`, `timeline`, `benchmark-rules`).
  `bin/timeline` classifies every commit into a development phase (ordered
  ruleset + override table for judgment calls; unmatched commits reported
  as unclassified, never force-fit) and emits the README "## Timeline"
  table. `bin/benchmark-rules <candidate.yml>` scores a candidate rules
  file against canonical `nasfaa_rules.yml` by behavioural equivalence over
  the 36,864 input vectors (`make benchmark`).
- `benchmark/` — the PDF→rules agent benchmark: `pdf-to-rules.md` (the
  prompt + rules-format spec), `onboarding.md` (operator runbook, run one
  step at a time). Scored by `bin/benchmark-rules`.
- `docs/ROADMAP.md` — release-gate status + working notes; `docs/time-spent.md`
  is generated by `bin/time-analysis`.
