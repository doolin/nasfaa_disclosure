---
name: coverage-survey
description: Survey the nasfaa project for weak test coverage + refactor-worthy code smells, so a test-writing session can target the highest-leverage files first.
allowed-tools: Bash, Read
---

# Coverage Survey

Run this at the **start** of any session focused on adding tests or
preparing code for refactor. It produces a single markdown report
with three things:

1. **Priority callout** — the most actionable gaps right now
2. **Ruby table** — per-file line + branch % from SimpleCov, plus
   exact uncovered lines/branches
3. **JS table** — every runtime module in `web/{quiz,walkthrough,
   shared}/`, marked `tested` or `untested` based on whether any
   test file (`test-*.{js,mjs}`, `run-*tests*.mjs`) references it
4. **Code smells** — long methods (Ruby), long functions (JS), case
   statements with >4 branches, and known duplicated helpers
   (`escapeHtml`, `wrapText`, `pad`, `repeat`, `visualLength`)

## Step 1: Refresh coverage data (Ruby only)

The script reads `coverage/.resultset.json` produced by SimpleCov.
If it's stale or missing, regenerate:

```bash
COVERAGE=1 bundle exec rspec
```

The JS side has no per-file coverage tool wired up yet — modules are
reported as tested or untested, not by line %. (See "Future work"
below.)

## Step 2: Run the survey

```bash
bin/coverage-survey            # markdown report to stdout
bin/coverage-survey --json     # raw JSON (for piping into other tools)
```

No bundler required — the script uses stdlib only, so it works even
when gems aren't installed.

## Step 3: Interpret the priority callout

The callout ranks gaps in this order:

- **Front-end untested modules** come first because the user has
  flagged front-end testing as critical, and untested JS is
  effectively at 0% coverage. The largest untested file is the
  highest-leverage target.
- **Ruby files with no coverage data** mean the file isn't `require`d
  by any spec — often dead code or a metadata file (e.g.
  `version.rb`).
- **Ruby files below 100%** list the specific files with gaps;
  cross-reference the detailed table for line/branch numbers.

## Step 4: Cross-reference smells

A file appearing in BOTH the priority list AND the smells section is
a doubly-strong target: refactoring it is desirable, AND adding
coverage first is required (per the `feedback_refactor_only_with_coverage`
guidance — "don't refactor until there is either coverage or I have
the time to manually verify").

## Step 5: Propose targets to the user

Don't just start writing tests. Pick the top 2–4 targets, present
them with rationale, and ask the user which to tackle first. Some
targets need test-infrastructure decisions (JSDOM vs jsdom-free
unit tests for DOM-touching JS, fixture strategy, etc.) — surface
those before writing.

## How the script works

- **Ruby coverage:** parses `coverage/.resultset.json` directly
  (SimpleCov format). Line array is indexed by line-1; `nil` =
  non-executable, `0` = uncovered, `>0` = hit count. Branches are
  keyed by source location; each entry has `:then`/`:else` (or
  similar) sub-keys with hit counts.
- **JS "tested" detection:** scans test files for relative
  `require()` / `import from '...'` strings and resolves them
  against the test file's directory. Any JS module that's the
  target of such an import is marked tested.
- **Smell detection:** line-pattern heuristics (no real parser),
  good enough for a survey. Long-method threshold is 40 lines.
  Edit `SMELL_METHOD_LINES` or `DUPE_CANDIDATES` in
  `bin/coverage-survey` to tune.

## Future work

When per-file JS coverage matters (which it will, soon), wire up
Node's built-in coverage:

```bash
node --test --experimental-test-coverage web/quiz/test-*.mjs
```

Then extend `bin/coverage-survey` to read its V8 LCOV output and
fold it into the JS table.

## When NOT to run

- If you're in the middle of writing tests for a specific file you
  already know is untested — running the survey just to confirm
  what you already know is overhead.
- If the user has named a specific file/method to cover — skip the
  survey and go straight to writing tests.
