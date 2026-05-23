# NASFAA Disclosure Quiz — Web Port

Static page port of the NASFAA disclosure quiz (`lib/nasfaa/quiz.rb`).
Deployed at `https://blurbpress.com/nasfaa/disclosure-quiz/`.

The browser app loads `rules.json` and `scenarios.json` (built from the
canonical YAML at the project root) and runs the quiz entirely
client-side. Single-page app, vanilla JS, no framework, no build step
for the browser.

## File layout

```
web/quiz/
  index.html       Terminal-styled single-page app
  styles.css       Dark / cyan-green palette, blinking block cursor, scanlines
  app.js           DOM driver, keystroke handler, render loop
  engine.js        JS port of Nasfaa::RuleEngine (~50 lines)
  quiz.js          Quiz state machine (scenario + random modes)
  box-draw.js      JS port of Nasfaa::BoxDraw (Unicode box frames)
  rules.json       Built from ../../nasfaa_rules.yml
  scenarios.json   Built from ../../nasfaa_scenarios.yml
  build.js         Regenerates rules.json + scenarios.json from YAML
  README.md        This file
```

## Build first

`data.js`, `rules.json`, and `scenarios.json` in this directory are
**gitignored build artifacts**. After a fresh clone (or after
editing either canonical YAML file), regenerate them:

```
make build          # from the repo root
# or just this page's bundle:
node web/quiz/build.js
```

If you open `index.html` without building first, the page detects the
missing data and renders a terminal-framed "NOT BUILT" notice telling
you to run `make build` — no broken-page mystery.

`build.js` shells out to `ruby -ryaml -rjson` so it uses the same
parser as the canonical Ruby code (no `npm install` needed).

## Running locally

The app is fully static. From the project root:

```
python3 -m http.server 8000
# then open: http://localhost:8000/web/quiz/
```

Opening `web/quiz/index.html` directly via `file://` also works in
most browsers (the app uses `XMLHttpRequest` as a fallback for local
file loads).

### Scenario mode (default)

```
http://localhost:8000/web/quiz/
```

Shuffles the 24 named scenarios and presents the description + inputs
for each. The reveal shows the actual result, rule ID, and citation.

### Random mode

```
http://localhost:8000/web/quiz/?mode=random
http://localhost:8000/web/quiz/?mode=random&count=5
```

Generates `count` (default 10) random boolean disclosure inputs and
evaluates them with the JS RuleEngine. No description — just the input
bag, like the CLI's random mode.

## Controls

- `p` / `P` — answer **permit**
- `d` / `D` — answer **deny**
- `q` / `Q` — quit (jumps straight to the final score)
- `Space` / `Enter` — advance past the reveal to the next question
- `m` / `M` — cycle color theme (light → dark → vt102 → system)

## Theming

Colors come from the shared token system in [`docs/web-styling/`](../../docs/web-styling/README.md).
Three themes are selectable (`light`, `dark`, `vt102`); the page also
honors `prefers-color-scheme` when no theme is stored. Use the `m`
keystroke or click the `theme [m]:` toggle in the build footer to
cycle. The active theme is persisted in `localStorage` under
`nasfaa-theme`.

`permit_with_caution` and `permit_with_scope` both count as **permit**.

On touch-only devices (coarse pointer), on-screen `[P] [D] [Q]
[Space]` buttons appear automatically.

## Deploy

The repo-root `Makefile` syncs this directory to
`s3://blurbpress.com/nasfaa/disclosure-quiz/` via `aws s3 sync` using the
`blurbpress_deploy` profile.

```sh
make deploy-quiz   # build + sync just this page
make deploy        # build + sync shared + walkthrough + quiz
make verify        # curl deployed URLs and report HTTP codes
```

The build step (`make build`) regenerates `data.js`, `rules.json`,
and `scenarios.json` from the canonical YAML. The sync excludes
source-only files (`build.js`, `README.md`).

## Verification checklist

- `node web/quiz/build.js` runs and produces valid JSON.
- `rules.json` and `scenarios.json` round-trip through `JSON.parse`.
- Opening `index.html` shows the terminal frame with a banner, the
  first question card, and a blinking cursor.
- Walking through 3–5 scenarios produces the expected reveal.
- `?mode=random&count=5` produces 5 randomly-generated questions.
- `bundle exec rspec` (at project root) still passes — no Ruby files
  were modified.
