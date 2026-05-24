// box-draw.js — JS port of Nasfaa::BoxDraw.
//
// Plain script; attaches helpers to `window.Nasfaa.BoxDraw`.
// Same Unicode glyphs and widths as lib/nasfaa/box_draw.rb.

(function (global) {
  'use strict';

  const BOX_WIDTH = 60;
  const INNER_WIDTH = 58;
  const TOTAL_WIDTH = 62;

  const HORZ_LIGHT = '─';
  const HORZ_HEAVY = '═';

  function repeat(ch, n) {
    return n > 0 ? ch.repeat(n) : '';
  }

  function visualLength(text) {
    return String(text).replace(/\[[0-9;]*m/g, '').length;
  }

  function pad(text, width) {
    const diff = width - visualLength(text);
    return diff > 0 ? text + ' '.repeat(diff) : text;
  }

  function wrapText(text, width) {
    const w = width || INNER_WIDTH;
    if (text === '' || text == null) return [''];
    const lines = [];
    let current = '';
    for (const word of String(text).split(/\s+/).filter(Boolean)) {
      if (current === '') {
        current = word;
      } else if (current.length + 1 + word.length <= w) {
        current = current + ' ' + word;
      } else {
        lines.push(current);
        current = word;
      }
    }
    lines.push(current);
    return lines;
  }

  function boxTop(title) {
    if (title) {
      const label = HORZ_LIGHT + ' ' + title + ' ';
      const fill = repeat(HORZ_LIGHT, BOX_WIDTH - label.length);
      return '┌' + label + fill + '┐';
    }
    return '┌' + repeat(HORZ_LIGHT, BOX_WIDTH) + '┐';
  }

  function boxDivider() {
    return '├' + repeat(HORZ_LIGHT, BOX_WIDTH) + '┤';
  }

  function boxBottom() {
    return '└' + repeat(HORZ_LIGHT, BOX_WIDTH) + '┘';
  }

  function boxLine(text) {
    return wrapText(String(text == null ? '' : text), INNER_WIDTH)
      .map((line) => '│ ' + pad(line, INNER_WIDTH) + ' │')
      .join('\n');
  }

  function boxHeavyTop() {
    return '╔' + repeat(HORZ_HEAVY, BOX_WIDTH) + '╗';
  }

  function boxHeavyDivider() {
    return '╠' + repeat(HORZ_HEAVY, BOX_WIDTH) + '╣';
  }

  function boxHeavyBottom() {
    return '╚' + repeat(HORZ_HEAVY, BOX_WIDTH) + '╝';
  }

  function boxHeavyLine(text) {
    return wrapText(String(text == null ? '' : text), INNER_WIDTH)
      .map((line) => '║ ' + pad(line, INNER_WIDTH) + ' ║')
      .join('\n');
  }

  function renderQuestionBox(node) {
    const out = [boxTop('Box ' + node.box)];
    out.push(boxLine(node.text));
    if (node.help) out.push(boxLine('(' + node.help + ')'));
    out.push(boxBottom());
    return out.join('\n');
  }

  function renderResultBox(node, pathIds) {
    const out = [boxTop()];
    out.push(boxLine('RESULT: ' + String(node.result).toUpperCase()));
    out.push(boxDivider());
    out.push(boxLine(node.message));
    out.push(boxLine(''));
    out.push(boxLine('Rule:     ' + node.rule_id));
    out.push(boxLine('Citation: ' + node.citation));
    out.push(boxLine('Path:     ' + (pathIds || []).join(' -> ')));
    out.push(boxBottom());
    return out.join('\n');
  }

  global.Nasfaa = global.Nasfaa || {};
  global.Nasfaa.BoxDraw = {
    BOX_WIDTH: BOX_WIDTH,
    INNER_WIDTH: INNER_WIDTH,
    TOTAL_WIDTH: TOTAL_WIDTH,
    wrapText: wrapText,
    boxTop: boxTop,
    boxDivider: boxDivider,
    boxBottom: boxBottom,
    boxLine: boxLine,
    boxHeavyTop: boxHeavyTop,
    boxHeavyDivider: boxHeavyDivider,
    boxHeavyBottom: boxHeavyBottom,
    boxHeavyLine: boxHeavyLine,
    renderQuestionBox: renderQuestionBox,
    renderResultBox: renderResultBox,
  };
})(typeof window !== 'undefined' ? window : globalThis);
