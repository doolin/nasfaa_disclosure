// box-draw.js — JS port of Nasfaa::BoxDraw.
//
// Same Unicode glyphs and widths as lib/nasfaa/box_draw.rb. Words wrap at
// INNER_WIDTH; single words longer than INNER_WIDTH appear on their own
// line and overflow the right border (no truncation). No ANSI handling
// here — in the browser we use CSS for colour.
//
// Each "box_*line" returns a single string with embedded \n where wrapping
// occurred, so callers can simply do `pre.textContent = lines.join('\n')`.

export const BOX_WIDTH = 60;
export const INNER_WIDTH = 58;
export const TOTAL_WIDTH = 62;

const HORZ_LIGHT = '─'; // ─
const HORZ_HEAVY = '═'; // ═

function repeat(ch, n) {
  return n > 0 ? ch.repeat(n) : '';
}

function pad(text, width) {
  const diff = width - visualLength(text);
  return diff > 0 ? text + ' '.repeat(diff) : text;
}

// Strip ANSI escape sequences (rare in the browser, but a no-op there)
// before measuring so colour codes do not skew the padding.
function visualLength(text) {
  return String(text).replace(/\[[0-9;]*m/g, '').length;
}

// Word-wrap plain text. Single words longer than width go on their own
// line uncut, matching the Ruby helper.
export function wrapText(text, width = INNER_WIDTH) {
  if (text === '' || text == null) return [''];
  const lines = [];
  let current = '';
  for (const word of String(text).split(/\s+/).filter(Boolean)) {
    if (current === '') {
      current = word;
    } else if (current.length + 1 + word.length <= width) {
      current = `${current} ${word}`;
    } else {
      lines.push(current);
      current = word;
    }
  }
  lines.push(current);
  return lines;
}

// ── Thin style ─────────────────────────────────────────────────

export function boxTop(title) {
  if (title) {
    const label = `${HORZ_LIGHT} ${title} `;
    const fill = repeat(HORZ_LIGHT, BOX_WIDTH - label.length);
    return `┌${label}${fill}┐`;
  }
  return `┌${repeat(HORZ_LIGHT, BOX_WIDTH)}┐`;
}

export function boxDivider() {
  return `├${repeat(HORZ_LIGHT, BOX_WIDTH)}┤`;
}

export function boxBottom() {
  return `└${repeat(HORZ_LIGHT, BOX_WIDTH)}┘`;
}

export function boxLine(text = '') {
  const t = String(text);
  return wrapText(t, INNER_WIDTH)
    .map((line) => `│ ${pad(line, INNER_WIDTH)} │`)
    .join('\n');
}

// ── Heavy style ────────────────────────────────────────────────

export function boxHeavyTop() {
  return `╔${repeat(HORZ_HEAVY, BOX_WIDTH)}╗`;
}

export function boxHeavyDivider() {
  return `╠${repeat(HORZ_HEAVY, BOX_WIDTH)}╣`;
}

export function boxHeavyBottom() {
  return `╚${repeat(HORZ_HEAVY, BOX_WIDTH)}╝`;
}

export function boxHeavyLine(text = '') {
  const t = String(text);
  return wrapText(t, INNER_WIDTH)
    .map((line) => `║ ${pad(line, INNER_WIDTH)} ║`)
    .join('\n');
}

// Convenience: render a question node as a complete thin box. Mirrors
// Walkthrough#ask_question's panel (minus the prompt). Returns a single
// newline-joined string suitable for a <pre>.
export function renderQuestionBox(node) {
  const out = [boxTop(`Box ${node.box}`)];
  out.push(boxLine(node.text));
  if (node.help) out.push(boxLine(`(${node.help})`));
  out.push(boxBottom());
  return out.join('\n');
}

// Convenience: render a result node as a complete heavy box, mirroring
// Walkthrough#display_result.
export function renderResultBox(node, pathIds) {
  const out = [boxHeavyTop()];
  out.push(boxHeavyLine(`RESULT: ${String(node.result).toUpperCase()}`));
  out.push(boxHeavyDivider());
  out.push(boxHeavyLine(node.message));
  out.push(boxHeavyLine(''));
  out.push(boxHeavyLine(`Rule:     ${node.rule_id}`));
  out.push(boxHeavyLine(`Citation: ${node.citation}`));
  out.push(boxHeavyLine(`Path:     ${(pathIds || []).join(' -> ')}`));
  out.push(boxHeavyBottom());
  return out.join('\n');
}
