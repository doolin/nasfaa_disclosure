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

  function escapeHtml(s) {
    return String(s).replace(/[&<>]/g, function (c) {
      return c === '&' ? '&amp;' : c === '<' ? '&lt;' : '&gt;';
    });
  }

  // Wrap a single boxLine around a citation string with <a> tags injected
  // for each HEA/IRC/FERPA §-reference. Word-wraps using plain-text length
  // so padding stays right after HTML markup is added. Threads body context
  // across wrapped lines via NasfaaCitation.linkifyCitation's finalBody.
  function renderCitationBoxLine(text) {
    var Citation = (typeof window !== 'undefined' ? window : globalThis).NasfaaCitation;
    if (!Citation || !Citation.linkifyCitation) {
      // Linker not loaded — fall back to a plain (escaped) box line.
      return escapeHtml(boxLine(text));
    }
    var lines = wrapText(text, INNER_WIDTH);
    var body = null;
    return lines.map(function (line) {
      var pad = repeat(' ', Math.max(INNER_WIDTH - line.length, 0));
      var linked = Citation.linkifyCitation(escapeHtml(line), body);
      body = linked.finalBody;
      return '│ ' + linked.html + pad + ' │';
    }).join('\n');
  }

  function resultColorClass(result) {
    if (result === 'permit') return 'result-permit';
    if (result === 'deny') return 'result-deny';
    return 'result-caution'; // permit_with_caution / permit_with_scope
  }

  // Returns HTML (not plain text) so dev-only Rule + Path lines can be
  // wrapped in <span class="dev"> and the result-type word in the top
  // border can be colored. The caller sets via innerHTML.
  function renderResultBox(node, pathIds, opts) {
    const devMode = !!(opts && opts.devMode);
    const verifyLine = (opts && opts.verifyLine) || '';
    const resultWord = String(node.result).toUpperCase();
    const cls = resultColorClass(node.result);
    const top = escapeHtml(boxTop(resultWord))
      .replace(resultWord, '<span class="' + cls + '">' + resultWord + '</span>');
    const out = [top];
    out.push(escapeHtml(boxLine(node.message)));
    out.push(escapeHtml(boxLine('')));
    out.push(renderCitationBoxLine('Citation: ' + node.citation)
      .replace('Citation:', '<span class="label">Citation:</span>'));
    if (devMode) {
      const devLines = [
        escapeHtml(boxLine('')),
        escapeHtml(boxLine('Rule:     ' + node.rule_id)),
        escapeHtml(boxLine('Path:     ' + (pathIds || []).join(' ⟶ '))),
      ];
      if (verifyLine) devLines.push(escapeHtml(boxLine(verifyLine)));
      out.push('<span class="dev">' + devLines.join('\n') + '</span>');
    }
    out.push(escapeHtml(boxBottom()));
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
    renderCitationBoxLine: renderCitationBoxLine,
    escapeHtml: escapeHtml,
  };
})(typeof window !== 'undefined' ? window : globalThis);
