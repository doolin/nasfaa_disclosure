# web/shared — color tokens and theme switcher

Shared foundation for the NASFAA web pages (`web/walkthrough/` and
`web/quiz/`). Provides three selectable themes (light, dark, vt102),
a CSS custom property vocabulary for semantic colors, and a tiny
JavaScript helper that persists the user's choice.

No build step. Works from `file://`. No modules.

## Files

| File                | Purpose                                                |
|---------------------|--------------------------------------------------------|
| `tokens.css`        | CSS custom properties for all themes                   |
| `theme.js`          | `window.NasfaaTheme.set/cycle/current/stored`          |
| `theme-toggle.css`  | Styles for an unobtrusive theme cycle button           |
| `DESIGN.md`         | Design rationale + measured contrast ratios            |
| `README.md`         | This file                                              |

## Wiring a page

Add to `<head>`:

```html
<link rel="stylesheet" href="../shared/tokens.css" />
<link rel="stylesheet" href="../shared/theme-toggle.css" />
<link rel="stylesheet" href="styles.css" />  <!-- page-specific, uses var(--color-*) -->
```

Add somewhere visible (lower-left mirrors the shamrock-link):

```html
<button type="button"
        class="theme-toggle"
        onclick="NasfaaTheme.cycle()"
        aria-label="Cycle color theme">[theme]</button>
```

Add before `</body>`:

```html
<script src="../shared/theme.js"></script>
```

Inside the page's own `styles.css`, replace hardcoded colors with
the tokens (e.g. `background: var(--color-bg); color: var(--color-fg);`).

## Token vocabulary

| Token                    | Semantic meaning                              | Light            | Dark             | VT102            |
|--------------------------|-----------------------------------------------|------------------|------------------|------------------|
| `--color-bg`             | Page background                               | `#ffffff`        | `#11161d`        | `#06120e`        |
| `--color-bg-elevated`    | Boxes, panels, raised surfaces                | `#f4f6f8`        | `#1b2230`        | `#06120e`        |
| `--color-fg`             | Primary text                                  | `#1a1f2c`        | `#e6ebf2`        | `#b6f7c1`        |
| `--color-fg-muted`       | Dim text, captions, footer                    | `#5b6470`        | `#a3adbc`        | `#5a8a6f`        |
| `--color-fg-subtle`      | Placeholders, hints, scanlines, dividers      | `#8a929d`        | `#6b7585`        | `#3a5a47`        |
| `--color-accent`         | Interactive (links, kbd, prompt, cursor)      | `#0a6cbf`        | `#6cb6ff`        | `#7df9d2`        |
| `--color-accent-fg`      | Text painted on accent-color fills            | `#ffffff`        | `#0b1220`        | `#06120e`        |
| `--color-border`         | Box borders, dividers (default weight)        | `#d4d8de`        | `#2a3242`        | `#5a8a6f`        |
| `--color-border-strong`  | Emphasized borders, focus outlines            | `#a8b0bb`        | `#3d475a`        | `#7df9d2`        |
| `--color-permit`         | Permit results, success tint                  | `#1a7f37`        | `#5fd17a`        | `#7df9d2`        |
| `--color-deny`           | Deny results, error tint                      | `#b42318`        | `#ff8b7a`        | `#ff6b6b`        |
| `--color-caution`        | Permit-with-caution / permit-with-scope       | `#8a5a00`        | `#f0c674`        | `#ffb86b`        |
| `--color-disclaimer`     | "For Entertainment Purposes Only" banner line | `#b42318`        | `#ff8b7a`        | `#ff6b6b`        |
| `--color-shamrock`       | Shamrock glyph in the corner link             | `#16a34a`        | `#4ade80`        | `#16a34a`        |
| `--color-accent-tint`    | Translucent accent fill (button backgrounds)  | `rgba(10,108,191,.10)` | `rgba(108,182,255,.12)` | `rgba(125,249,210,.12)` |
| `--color-permit-tint`    | Translucent permit fill                       | `rgba(26,127,55,.12)`  | `rgba(95,209,122,.14)`  | `rgba(125,249,210,.12)` |
| `--color-deny-tint`      | Translucent deny fill                         | `rgba(180,35,24,.12)`  | `rgba(255,139,122,.14)` | `rgba(255,107,107,.12)` |
| `--color-caution-tint`   | Translucent caution fill                      | `rgba(138,90,0,.12)`   | `rgba(240,198,116,.14)` | `rgba(255,184,107,.12)` |
| `--shadow-elevated`      | Drop shadow on raised boxes                   | soft slate       | deep black       | inset green glow |
| `--scanlines-opacity`    | Visibility of scanlines overlay (0–1)         | `0`              | `0`              | `1`              |

## Switching themes programmatically

```js
NasfaaTheme.set('dark');     // explicit light | dark | vt102
NasfaaTheme.set(null);       // clear -> follow prefers-color-scheme
NasfaaTheme.cycle();         // light -> dark -> vt102 -> system -> light ...
NasfaaTheme.current();       // -> 'light' | 'dark' | 'vt102' (effective)
NasfaaTheme.stored();        // -> 'light' | 'dark' | 'vt102' | null (saved pref)
```

Persistence is in `localStorage` under the key `nasfaa-theme`. If
the user clears site data the page falls back to
`prefers-color-scheme`.

## Adding a new theme

1. Open `tokens.css`.
2. Add a block:

   ```css
   [data-theme="mytheme"] {
     --color-bg: #...;
     --color-fg: #...;
     /* re-bind every --color-* and the two effect tokens */
   }
   ```

3. Add `'mytheme'` to the `THEMES` and `CYCLE` arrays in `theme.js`
   if you want it reachable from the cycle button.
4. Add a row to the token table above and a contrast-ratio entry in
   `DESIGN.md`.

## Measured AA contrast (fg on bg)

| Theme  | `--color-fg` on `--color-bg`        | `--color-fg-muted` on `--color-bg`  |
|--------|-------------------------------------|-------------------------------------|
| LIGHT  | 16.5:1 (AAA)                        | 5.8:1 (AA)                          |
| DARK   | 15.1:1 (AAA)                        | 8.1:1 (AAA)                         |
| VT102  | 15.5:1 (AAA)                        | 4.8:1 (AA)                          |

Full per-token ratios are in `DESIGN.md`.

## Constraints

- Do not modify files outside `web/shared/` from inside this
  directory's responsibility. The pages opt in by re-wiring their
  own `styles.css` to use the tokens.
- The page-specific CSS files (`web/walkthrough/styles.css`,
  `web/quiz/styles.css`) should reference tokens, not hex values.
- Keep the script and tokens free of build-step dependencies — both
  pages run from `file://` in addition to a normal web server.
