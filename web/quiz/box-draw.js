// box-draw.js — JavaScript port of Nasfaa::BoxDraw.
//
// Mirrors lib/nasfaa/box_draw.rb: 60-char wide thin (┌─┐│└┘) and heavy
// (╔═╗║╚═╝) box frames with word-wrapped inner content.
//
// Differences from the Ruby version:
//   * No ANSI escape sequences — the browser renders styling via CSS,
//     so box_line never has to skip wrapping for colored text.
//   * No terminal-width centering: the centering happens via CSS on the
//     <pre> container instead.  box_margin always returns ''.
//   * boxLine / boxHeavyLine return strings with embedded "\n" when the
//     content wraps over multiple lines.

(function (root) {
  'use strict';

  const BOX_WIDTH = 60;          // ─/═ count between corners
  const INNER_WIDTH = BOX_WIDTH - 2;  // 58 — one space padding each side

  function repeat(ch, n) {
    return n > 0 ? ch.repeat(n) : '';
  }

  // Word-wrap plain text to fit within +width+ characters.  Returns an array
  // of strings; words longer than +width+ get their own line (and overflow,
  // matching the Ruby behavior).
  function wrapText(text, width) {
    if (!text) return [''];
    const words = String(text).split(/\s+/).filter(Boolean);
    if (words.length === 0) return [''];

    const lines = [];
    let current = '';
    for (const word of words) {
      if (current.length === 0) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = current + ' ' + word;
      } else {
        lines.push(current);
        current = word;
      }
    }
    lines.push(current);
    return lines;
  }

  // ── Thin style ─────────────────────────────────────────────────

  function boxTop(title) {
    if (title) {
      const label = '─ ' + title + ' ';
      const fill = repeat('─', Math.max(BOX_WIDTH - label.length, 0));
      return '┌' + label + fill + '┐';
    }
    return '┌' + repeat('─', BOX_WIDTH) + '┐';
  }

  function boxDivider() {
    return '├' + repeat('─', BOX_WIDTH) + '┤';
  }

  function boxBottom() {
    return '└' + repeat('─', BOX_WIDTH) + '┘';
  }

  function boxLine(text) {
    const t = (text == null) ? '' : String(text);
    const lines = wrapText(t, INNER_WIDTH);
    return lines.map((line) => {
      const pad = repeat(' ', Math.max(INNER_WIDTH - line.length, 0));
      return '│ ' + line + pad + ' │';
    }).join('\n');
  }

  // ── Heavy style ────────────────────────────────────────────────

  function boxHeavyTop() {
    return '╔' + repeat('═', BOX_WIDTH) + '╗';
  }

  function boxHeavyDivider() {
    return '╠' + repeat('═', BOX_WIDTH) + '╣';
  }

  function boxHeavyBottom() {
    return '╚' + repeat('═', BOX_WIDTH) + '╝';
  }

  function boxHeavyLine(text) {
    const t = (text == null) ? '' : String(text);
    const lines = wrapText(t, INNER_WIDTH);
    return lines.map((line) => {
      const pad = repeat(' ', Math.max(INNER_WIDTH - line.length, 0));
      return '║ ' + line + pad + ' ║';
    }).join('\n');
  }

  const BoxDraw = {
    BOX_WIDTH,
    INNER_WIDTH,
    wrapText,
    boxTop,
    boxDivider,
    boxBottom,
    boxLine,
    boxHeavyTop,
    boxHeavyDivider,
    boxHeavyBottom,
    boxHeavyLine,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = BoxDraw;
  } else {
    root.NasfaaBoxDraw = BoxDraw;
  }
})(typeof self !== 'undefined' ? self : this);
