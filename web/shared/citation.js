/* citation.js — shared HEA / IRC / FERPA section linker.
 *
 * Plain script (no modules) so it works from file://. Attaches to
 * window.NasfaaCitation. The caller passes already-HTML-escaped text
 * in and gets HTML out with citation references wrapped in <a> tags.
 *
 * Citation strings in nasfaa_scenarios.yml (and walkthrough question
 * messages) chain semicolon-separated references belonging to one of
 * three legal bodies:
 *   HEA   — Higher Education Act,    20 U.S.C.   (law.cornell.edu)
 *   IRC   — Internal Revenue Code,   26 U.S.C.   (law.cornell.edu)
 *   FERPA — Family Educational Rights & Privacy Act, 34 CFR Part 99
 *           (ecfr.gov)
 *
 * A body name "sticks" to subsequent chunks until a new body is named.
 * The optional `initialBody` argument seeds the body context so a
 * reference on a wrapped line picks up the body named on the
 * previous line.
 */
(function (root) {
  'use strict';

  const CITATION_BODIES = [
    { name: 'HEA',   match: /\bHEA\b/,   url: 'https://www.law.cornell.edu/uscode/text/20/' },
    { name: 'IRC',   match: /\bIRC\b/,   url: 'https://www.law.cornell.edu/uscode/text/26/' },
    { name: 'FERPA', match: /\bFERPA\b/, url: 'https://www.ecfr.gov/current/title-34/section-' },
  ];

  // A reference is identified by its structure — a legal body (named here
  // or inherited from an earlier chunk) plus a section number — not by any
  // marker glyph. Matches an optional body prefix, then a section number
  // (>= 2 digits, optional letter/decimal), then any subsections. The base
  // section (group 2) drives the URL; the subsections (group 3) ride along
  // in the anchor text only. A bare number with no body in context is left
  // untouched (see the `if (!body) return match` guard below), so ordinary
  // numbers don't get linked.
  const REF_RE = /(?:(HEA|IRC|FERPA\s+34\s+CFR)\s+)?(\d{2,}[a-z]*(?:\.\d+)?)((?:\([a-zA-Z0-9]+\))*)/g;

  function linkifyCitation(escapedText, initialBody) {
    let currentBody = initialBody || null;
    const html = String(escapedText).split(';').map(function (chunk) {
      // Body-only chunks (e.g. "FERPA does not apply…") still need to
      // update context for any references in later chunks.
      for (var i = 0; i < CITATION_BODIES.length; i++) {
        var body = CITATION_BODIES[i];
        if (body.match.test(chunk)) { currentBody = body; break; }
      }
      return chunk.replace(REF_RE, function (match, bodyText, section) {
        var body;
        if (bodyText) {
          body = CITATION_BODIES.find(function (b) { return b.match.test(bodyText); });
          if (body) currentBody = body;
        }
        if (!body) body = currentBody;
        if (!body) return match;
        var href = body.url + section;
        return '<a class="citation-link" href="' + href +
               '" target="_blank" rel="noopener">' + match + '</a>';
      });
    }).join(';');
    return { html: html, finalBody: currentBody };
  }

  root.NasfaaCitation = {
    CITATION_BODIES: CITATION_BODIES,
    REF_RE: REF_RE,
    linkifyCitation: linkifyCitation,
  };

  // Node test runner compatibility.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = root.NasfaaCitation;
  }
})(typeof self !== 'undefined' ? self : this);
