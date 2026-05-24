/* glyphs.js — shared Unicode symbols used across nasfaa web pages.
 *
 * Centralizes character choices that show up in multiple places
 * (path separators, future progress bar stipples, etc.) so iterating
 * on the visual is a one-file edit instead of a hunt through app.js
 * and box-draw.js.
 *
 * Plain script (no modules) so it works from file://. Attaches to
 * window.NasfaaGlyphs.
 */
(function (root) {
  'use strict';

  root.NasfaaGlyphs = {
    // Sequence separator: pre-spaced (space + arrow + space) so callers
    // can use it directly as a join() separator or string-concat token.
    // Examples in nasfaa: path display ("A → B → C"), verify cross-note
    // ("engine and DAG both → FAFSA_R1").
    ARROW_SEP: ' → ',
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = root.NasfaaGlyphs;
  }
})(typeof self !== 'undefined' ? self : this);
