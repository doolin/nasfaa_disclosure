# Web styling — color tokens and theme switcher

Shared design foundation for the NASFAA web pages (`web/walkthrough/`
and `web/quiz/`). Provides three selectable themes (light, dark,
vt102), a CSS custom property vocabulary for semantic colors, and a
tiny JavaScript helper that persists the user's choice.

No build step. Works from `file://`. No modules.

## Source layout

The three shared files live under `web/shared/` as a single canonical
copy and ship to `s3://blurbpress.com/nasfaa/shared/`. Both pages
reference them via `../shared/...` from their own deploy subdirectories
(`/nasfaa/walkthrough/` and `/nasfaa/quiz/`) — same relative path works
under `file://` for local dev. The `/nasfaa/` namespace keeps shared
assets isolated from sibling projects on the blurbpress bucket.

```
web/shared/
  tokens.css           ← single canonical source
  theme.js
  theme-toggle.css

web/walkthrough/
  index.html           ← <link href="../shared/tokens.css"> etc.
  (page-specific files...)

web/quiz/
  index.html           ← <link href="../shared/tokens.css"> etc.
  (page-specific files...)
```

## Files

| File                | Purpose                                                |
|---------------------|--------------------------------------------------------|
| `tokens.css`        | CSS custom properties for all themes                   |
| `theme.js`          | `window.NasfaaTheme.set/cycle/current/stored`          |
| `theme-toggle.css`  | Styles for an unobtrusive theme cycle button           |

This directory (`docs/web-styling/`) also contains:

| File                | Purpose                                                |
|---------------------|--------------------------------------------------------|
| `DESIGN.md`         | Design rationale + measured contrast ratios            |
| `README.md`         | This file                                              |

## Wiring a page

Add to `<head>` (paths are relative to the page directory):

```html
<link rel="stylesheet" href="../shared/tokens.css" />
<link rel="stylesheet" href="../shared/theme-toggle.css" />
<link rel="stylesheet" href="styles.css" />  <!-- page-specific, uses var(--color-*) -->
```

Add somewhere visible (the page footer currently mirrors the shamrock-link style):

```html
<button type="button" class="theme-toggle inline" onclick="window.NasfaaTheme.cycle(); window.updateThemeLabel && updateThemeLabel();">
  theme [m]: <span id="theme-label">…</span>
</button>
```

Load the script before any code that calls `NasfaaTheme.*`:

```html
<script src="../shared/theme.js"></script>
```

Bind the `m` key in your page's key handler to call
`NasfaaTheme.cycle()` and re-render the label.

## Themes

- `light` — Stripe-derived light palette. 16.5:1 AAA on body text.
- `dark` — Stripe-derived dark palette. 15.1:1 AAA on body text.
- `vt102` — the original cyan-on-near-black terminal aesthetic
  preserved as a selectable preset. 15.5:1 AAA on body text.

Default (no `data-theme` attribute) follows `prefers-color-scheme`
via a `@media` query inside `tokens.css`. An explicit user choice via
the toggle persists to `localStorage['nasfaa-theme']` and overrides
the media query.

See `DESIGN.md` for the full token vocabulary and per-token contrast
table.
