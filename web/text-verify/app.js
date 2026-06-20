// app.js — text verification checklist (tabular).
//
// Renders every node in nasfaa_questions.yml as a row in either the
// Questions table or the Results table.  Columns differ per type
// (questions have walkthrough text + PDF text; results have rule
// metadata + message + citation).  State persists in localStorage.

(function () {
  'use strict';

  const STORAGE_KEY = 'nasfaa-text-verify-v1';

  const data = window.NASFAA_VERIFY_DATA;
  if (!data) {
    document.body.innerHTML = '<pre>data.js not built. Run: ruby web/text-verify/build.rb</pre>';
    return;
  }

  const state = loadState();

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch {
      return {};
    }
  }

  function saveState() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('localStorage save failed:', e);
    }
  }

  function entryFor(id) {
    if (!state[id]) state[id] = { verified: false, notes: '' };
    if (state[id].notes == null) state[id].notes = '';
    return state[id];
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function notesCell(id, entry) {
    return `<td class="col-notes">
      <textarea data-notes-for="${escapeHtml(id)}" rows="2"
                placeholder="notes…">${escapeHtml(entry.notes)}</textarea>
    </td>`;
  }

  function checkCell(id, entry) {
    const checked = entry.verified ? 'checked' : '';
    return `<td class="col-check">
      <input type="checkbox" data-verify-for="${escapeHtml(id)}" ${checked}
             aria-label="Verified against printed PDF">
    </td>`;
  }

  // Display just the leading box number — tables are already scoped to a
  // page, so "1 (Page 2)" or "1 (both pages)" → "1".
  function boxNumber(boxStr) {
    return String(boxStr || '').split(/\s+/)[0];
  }

  function questionRow(id, node) {
    const entry = entryFor(id);
    const cls = entry.verified ? 'verified' : '';
    return `<tr class="${cls}" data-id="${escapeHtml(id)}">
      <td class="col-box">${escapeHtml(boxNumber(node.box))}</td>
      <td class="col-id"><code>${escapeHtml(id)}</code></td>
      <td class="col-text">${escapeHtml(node.text || '')}</td>
      <td class="col-pdf">${escapeHtml(node.pdf_text || '')}</td>
      ${notesCell(id, entry)}
      ${checkCell(id, entry)}
    </tr>`;
  }

  function resultRow(id, node) {
    const entry = entryFor(id);
    const cls = entry.verified ? 'verified' : '';
    return `<tr class="${cls}" data-id="${escapeHtml(id)}">
      <td class="col-id"><code>${escapeHtml(id)}</code></td>
      <td class="col-rule"><code>${escapeHtml(node.rule_id || '')}</code></td>
      <td class="col-result result-${escapeHtml(node.result || '')}">${escapeHtml(node.result || '')}</td>
      <td class="col-msg">${escapeHtml(node.message || '')}</td>
      <td class="col-cite">${escapeHtml(node.citation || '')}</td>
      ${notesCell(id, entry)}
      ${checkCell(id, entry)}
    </tr>`;
  }

  // Page assignment.  The `box` field carries "(Page 1)" or "(Page 2)"
  // for question nodes; "both pages" is the shared entry — bucketed
  // into Page 1 since the PDF starts there.  Result nodes have no box
  // label; FTI results live on page 2, everything else on page 1.
  function pageFor(id, node) {
    if (node.type === 'question') {
      const box = node.box || '';
      if (box.includes('Page 2')) return 2;
      return 1;
    }
    return id.startsWith('result_FTI_') ? 2 : 1;
  }

  function render() {
    const filter = document.querySelector('input[name="filter"]:checked').value;
    const buckets = {
      'p1-q-body': [], 'p1-r-body': [],
      'p2-q-body': [], 'p2-r-body': []
    };
    let total = 0;
    let verified = 0;

    for (const [id, node] of Object.entries(data.nodes)) {
      total += 1;
      const e = entryFor(id);
      if (e.verified) verified += 1;
      if (filter === 'verified' && !e.verified) continue;
      if (filter === 'unverified' && e.verified) continue;
      const page = pageFor(id, node);
      const isQuestion = node.type === 'question';
      const bucket = `p${page}-${isQuestion ? 'q' : 'r'}-body`;
      buckets[bucket].push(isQuestion ? questionRow(id, node) : resultRow(id, node));
    }

    const emptyQ = '<tr><td colspan="6" class="empty">— none —</td></tr>';
    const emptyR = '<tr><td colspan="7" class="empty">— none —</td></tr>';
    document.getElementById('p1-q-body').innerHTML = buckets['p1-q-body'].join('') || emptyQ;
    document.getElementById('p1-r-body').innerHTML = buckets['p1-r-body'].join('') || emptyR;
    document.getElementById('p2-q-body').innerHTML = buckets['p2-q-body'].join('') || emptyQ;
    document.getElementById('p2-r-body').innerHTML = buckets['p2-r-body'].join('') || emptyR;
    document.getElementById('counts').textContent =
      `${verified} verified / ${total} total`;
  }

  document.addEventListener('change', (ev) => {
    const t = ev.target;
    if (t.matches('input[name="filter"]')) {
      render();
      return;
    }
    const verifyId = t.getAttribute('data-verify-for');
    if (verifyId) {
      entryFor(verifyId).verified = t.checked;
      saveState();
      // Leave the row in place — toggling "verified" marks it green via
      // the row class, it does not hide it.  The filter only re-applies
      // on an explicit filter change (or reload), so you can tick a row
      // off without it vanishing out from under you.
      const row = t.closest('tr');
      if (row) row.classList.toggle('verified', t.checked);
      updateCounts();
    }
  });

  document.addEventListener('input', (ev) => {
    const notesId = ev.target.getAttribute('data-notes-for');
    if (notesId) {
      entryFor(notesId).notes = ev.target.value;
      saveState();
    }
  });

  function updateCounts() {
    let total = 0;
    let verified = 0;
    for (const id of Object.keys(data.nodes)) {
      total += 1;
      if (entryFor(id).verified) verified += 1;
    }
    document.getElementById('counts').textContent =
      `${verified} verified / ${total} total`;
  }

  document.getElementById('reset-btn').addEventListener('click', () => {
    if (!confirm('Reset all verification state? This cannot be undone.')) return;
    for (const k of Object.keys(state)) delete state[k];
    saveState();
    render();
  });

  document.getElementById('export-btn').addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `nasfaa-text-verify-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  render();
})();
