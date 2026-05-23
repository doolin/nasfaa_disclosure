# Web styling — color tokens and theme switcher

Shared design foundation for the NASFAA web pages (`web/walkthrough/`
and `web/quiz/`). Provides three selectable themes (light, dark,
vt102), a CSS custom property vocabulary for semantic colors, and a
tiny JavaScript helper that persists the user's choice.

No build step. Works from `file://`. No modules.

## Source layout (and the duplication problem)

Each page directory currently contains **its own copy** of the three
shared files:

```
web/walkthrough/
  tokens.css           ← duplicated
  theme.js             ← duplicated
  theme-toggle.css     ← duplicated
  (page-specific files...)

web/quiz/
  tokens.css           ← duplicated
  theme.js             ← duplicated
  theme-toggle.css     ← duplicated
  (page-specific files...)
```

There is **no** `web/shared/` directory. The shared files live inline
in each page directory because the deploy target (`blurbpress.com`) is
a multi-project static S3 bucket — putting shared assets at
`s3://blurbpress.com/shared/` would collide with other projects'
namespace, and burying them under a project-specific subdirectory
(e.g. `nasfaa-shared/`) for one consumer felt worse than two copies.

Each duplicated file carries a `MIRROR:` header comment naming its
counterpart. **When you edit one copy, edit the other.** A grep-based
check is on the ROADMAP under "Dedupe web-styling shared assets".

If the duplication becomes painful, two options worth considering:

- **Symlink** each page's copies to a single canonical source
  (e.g. `web/shared/tokens.css`). `aws s3 sync` follows symlinks by
  default and uploads the dereferenced content, so the symlinked
  layout works for both local `file://` browsing and S3 deploy.
- **Build-time copy** in each page's `build.rb` / `build.js`: read
  from `web/shared/` and write into the page directory at the same
  time the generated `data.js` is produced. Adds a build step but
  eliminates drift.

## Files (per page)

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

Add to `<head>` (paths are local to the page directory):

```html
<link rel="stylesheet" href="tokens.css" />
<link rel="stylesheet" href="theme-toggle.css" />
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
<script src="theme.js"></script>
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
