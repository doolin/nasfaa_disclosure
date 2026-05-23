# NASFAA Disclosure Walkthrough — Web Port

Static single-page port of the NASFAA Data Sharing Decision Tree CLI
walkthrough (`lib/nasfaa/walkthrough.rb`).

Target URL: `blurbpress.com/nasfaa/walkthrough`.

## Layout

```
web/walkthrough/
  build.rb                  # YAML -> JSON build step
  rules.json                # generated from nasfaa_rules.yml
  questions.json            # generated from nasfaa_questions.yml
  scenarios.json            # generated from nasfaa_scenarios.yml

  engine.js                 # port of Nasfaa::RuleEngine
  dag.js                    # port of Walkthrough DAG navigation
  box-draw.js               # port of Nasfaa::BoxDraw

  index.html / app.js / styles.css   # the walkthrough page
  test.html  / tests.js              # scenario test harness

  run-tests-node.mjs        # node-side scenario runner
  run-dag-cross-verify.mjs  # exhaustive DAG vs RuleEngine check
```

The YAML files in the repo root remain the canonical source of truth.

## Regenerate JSON from YAML

After editing any of `nasfaa_rules.yml`, `nasfaa_questions.yml`, or
`nasfaa_scenarios.yml`, regenerate the JSON copies that the browser
loads:

```sh
ruby web/walkthrough/build.rb
```

Output is UTF-8, LF endings, no BOM.

## Run locally

The browser needs to fetch the JSON files, so plain `file://` will not
work in most browsers. Serve the directory:

```sh
cd web/walkthrough
python3 -m http.server 8000
# open http://localhost:8000/
```

Then:

- `index.html` — interactive walkthrough. Press `y`/`n` to answer or
  `q` to quit. `r` restarts after a result.
- `test.html` — runs every scenario from `scenarios.json` through
  `engine.js` and reports pass/fail per scenario.

## Run the tests in Node

For pre-commit or CI without a browser:

```sh
node web/walkthrough/run-tests-node.mjs
# exits 0 on all-pass

node web/walkthrough/run-dag-cross-verify.mjs
# exhaustively walks every yes/no path through the DAG and confirms
# engine.js' RuleEngine agrees on every terminal rule_id
```

## Deploy

The repo-root `Makefile` syncs this directory to
`s3://blurbpress.com/nasfaa/walkthrough/` via `aws s3 sync` using the
`blurbpress_deploy` profile.

```sh
make deploy-walkthrough    # build + sync just this page
make deploy                # build + sync shared + walkthrough + quiz
make verify                # curl deployed URLs and report HTTP codes
```

The build step (`make build`) regenerates `data.js`, `rules.json`,
`questions.json`, and `scenarios.json` from the canonical YAML. The
sync excludes source-only files (`build.rb`, `*.mjs`, `verify_*`,
`README.md`).

## Theming

Colors come from the shared design-token system in `docs/web-styling/`. See
[`docs/web-styling/README.md`](../../docs/web-styling/README.md) for the token vocabulary
and the available themes (light / dark / vt102 / system).

The footer shows a small `theme [m]: <name>` toggle. Click it or press
`m` to cycle: light -> dark -> vt102 -> system -> light. The choice
persists in `localStorage`; when no choice is stored the page follows
`prefers-color-scheme`.

## Why JSON, not YAML, in the browser

The Ruby gem keeps YAML as the canonical source. The browser does not
ship with a YAML parser, and adding a runtime YAML lib would mean a
bundler. Instead, `build.rb` converts each YAML file to JSON at
build time and the static site loads JSON. When you change YAML,
re-run `build.rb` and commit the regenerated JSON alongside.

## Cross-verification

Three independent checks guard against drift between the canonical
Ruby gem, the YAML, and the JS port:

1. **DAG vs RuleEngine** (in-browser, on every walkthrough completion)
   — `app.js` runs the accumulated inputs through `engine.js` and
   surfaces any disagreement in the result panel.
2. **DAG vs RuleEngine, exhaustively** (`run-dag-cross-verify.mjs`)
   — enumerates every yes/no path through the DAG and confirms
   every terminal rule_id matches what the engine returns for the
   same inputs.
3. **Scenarios vs RuleEngine** (`run-tests-node.mjs` / `test.html`)
   — the 24 named scenarios are the canonical contract; when rules
   change, scenarios are what verify the rule still does what it
   should.

### Known DAG / engine divergence

`run-dag-cross-verify.mjs` is **diagnostic, not gating**. It compares
the DAG terminal (path-dependent) against the engine's first-match-wins
result (state-dependent) and may report a small number of verdict
disagreements on paths the canonical Ruby walkthrough spec doesn't
exercise (specifically Box 4 Yes / contributor paths that route into
the FERPA chain without ever asking Boxes 5/7/9). These reproduce
against the canonical Ruby gem on the same inputs — they're a known
property of the rule set, not a bug in this port.

The gating check is `run-tests-node.mjs` (24/24 scenarios pass).
