# NASFAA shared color system — design rationale

## Approach (Stripe-inspired)

- **Semantic tokens, never color names.** Every CSS custom property is
  named for its *role* (`--color-permit`, `--color-fg-muted`,
  `--color-disclaimer`) rather than the underlying hue. Pages bind to
  roles, so swapping a theme rebinds the entire vocabulary in one block.
- **HSL-step palette generation with WCAG contrast targets.** Each
  theme is built so that the foreground-on-background pairs hit at
  least WCAG AA (4.5:1 for body text, 3:1 for large text / UI). Where
  the cost is low, we exceed AA into AAA territory. Lightness steps
  between fg / fg-muted / fg-subtle are tuned in HSL space, not picked
  by eye.
- **Independent dark-mode derivation, not inversion.** The dark theme
  is built fresh: backgrounds shift toward warm-neutral charcoal,
  accents shift to lighter / less saturated hues to compensate for the
  perceptual bloom of saturated color on dark surfaces. (A naive
  inversion of the light theme would leave the accent blue too dark
  and the green permit-color visually muddy.)
- **CVD-safe permit / deny pair.** Permit = green, deny = orange-red,
  caution = amber. This axis is distinguishable for deuteranopia and
  protanopia (the most common color-vision deficiencies). Result
  meaning is reinforced by box-draw glyphs in the page content, not
  carried by color alone.
- **VT102 preset preserved verbatim.** The original cyan-on-near-black
  terminal aesthetic is selectable as `data-theme="vt102"` and uses
  the literal color values from the existing `web/walkthrough/styles.css`
  so the look is unchanged when that preset is active.

## Measured contrast ratios

Computed by hand from the WCAG 2.x relative-luminance formula
(`L = 0.2126·R' + 0.7152·G' + 0.0722·B'`, sRGB linearization).

| Theme  | Pair                          | Hex pair             | Ratio    | Standard |
|--------|-------------------------------|----------------------|----------|----------|
| LIGHT  | `--color-fg` on `--color-bg`        | `#1a1f2c` / `#ffffff` | **16.5:1** | AAA |
| LIGHT  | `--color-fg-muted` on `--color-bg`  | `#5b6470` / `#ffffff` | **5.8:1**  | AA  |
| LIGHT  | `--color-fg-subtle` on `--color-bg` | `#8a929d` / `#ffffff` | **3.1:1**  | AA large/UI |
| LIGHT  | `--color-accent` on `--color-bg`    | `#0a6cbf` / `#ffffff` | **5.3:1**  | AA  |
| LIGHT  | `--color-permit` on `--color-bg`    | `#1a7f37` / `#ffffff` | **5.1:1**  | AA  |
| LIGHT  | `--color-deny` on `--color-bg`      | `#b42318` / `#ffffff` | **6.5:1**  | AA  |
| LIGHT  | `--color-caution` on `--color-bg`   | `#8a5a00` / `#ffffff` | **5.9:1**  | AA  |
| DARK   | `--color-fg` on `--color-bg`        | `#e6ebf2` / `#11161d` | **15.1:1** | AAA |
| DARK   | `--color-fg-muted` on `--color-bg`  | `#a3adbc` / `#11161d` | **8.1:1**  | AAA |
| DARK   | `--color-fg-subtle` on `--color-bg` | `#6b7585` / `#11161d` | **3.9:1**  | AA large/UI |
| DARK   | `--color-accent` on `--color-bg`    | `#6cb6ff` / `#11161d` | **8.5:1**  | AAA |
| DARK   | `--color-permit` on `--color-bg`    | `#5fd17a` / `#11161d` | **9.5:1**  | AAA |
| DARK   | `--color-deny` on `--color-bg`      | `#ff8b7a` / `#11161d` | **7.9:1**  | AAA |
| DARK   | `--color-caution` on `--color-bg`   | `#f0c674` / `#11161d` | **11.4:1** | AAA |
| VT102  | `--color-fg` on `--color-bg`        | `#b6f7c1` / `#06120e` | **15.5:1** | AAA |
| VT102  | `--color-fg-muted` on `--color-bg`  | `#5a8a6f` / `#06120e` | **4.8:1**  | AA  |
| VT102  | `--color-fg-subtle` on `--color-bg` | `#3a5a47` / `#06120e` | 2.5:1    | decorative only (scanlines / dividers — see note) |

**Note on `--color-fg-subtle` in VT102.** The original walkthrough/quiz
pages used the same dim green for both text-muted content and
decorative dividers/scanlines. In the new system those uses are
separated: `--color-fg-muted` carries the muted *text* role and passes
AA (4.8:1), while `--color-fg-subtle` carries the decorative role
(dashed borders, scanline tint) and is allowed to be below 3:1
because no body text is painted with it. This mirrors the WCAG
exemption for incidental / decorative elements.

## Recommended toggle HTML

The `theme-toggle.css` file styles a small fixed-position cycle
button suitable for the footer area. Recommended snippet for the
walkthrough and quiz pages:

```html
<link rel="stylesheet" href="../shared/tokens.css" />
<link rel="stylesheet" href="../shared/theme-toggle.css" />
<!-- ... page content ... -->
<button type="button"
        class="theme-toggle"
        onclick="NasfaaTheme.cycle()"
        aria-label="Cycle color theme">[theme]</button>
<script src="../shared/theme.js"></script>
```

Pages may bind a keyboard shortcut (e.g. `t` for "theme") that calls
`NasfaaTheme.cycle()` in addition to or instead of the button. The
walkthrough already uses `t` for "tests" — recommend `T` (shift-t) or
a different key for theme there.

## Known gaps

- **VT102 quiz vs walkthrough palette delta.** The two original pages
  use slightly different cyan-green hex values (walkthrough bg
  `#06120e` / fg `#b6f7c1`; quiz bg `#06090b` / fg `#b8f5d8`). The
  unified vt102 token block uses the walkthrough's values. The
  perceptual delta is below 1 JND for normal vision. If exact
  per-page byte-equivalence is required, the quiz wiring agent can
  add `[data-theme="vt102"] body.quiz-page { ... }` overrides or
  introduce a `vt102-quiz` preset.
- **No high-contrast theme.** A future `data-theme="hc"` preset
  could push everything to true black/white for low-vision users.
  Out of scope for this pass.
- **Scanlines opacity is a hard 0/1.** A future enhancement could
  expose `--scanlines-opacity` as a user-tunable slider.
