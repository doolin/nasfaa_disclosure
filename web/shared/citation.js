/* citation.js — shared HEA / IRC / FERPA section linker.
 *
 * Plain script (no modules) so it works from file://. Attaches to
 * window.NasfaaCitation. The caller passes already-HTML-escaped text
 * in and gets HTML out with §-references wrapped in <a> tags.
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
 * §-reference on a wrapped line picks up the body named on the
 * previous line.
 */
(function (root) {
  'use strict';

  const CITATION_BODIES = [
    { name: 'HEA',   match: /\bHEA\b/,   url: 'https://www.law.cornell.edu/uscode/text/20/' },
    { name: 'IRC',   match: /\bIRC\b/,   url: 'https://www.law.cornell.edu/uscode/text/26/' },
    { name: 'FERPA', match: /\bFERPA\b/, url: 'https://www.ecfr.gov/current/title-34/section-' },
  ];

  // Matches an optional body prefix followed by §section(subsections).
  // The anchor text reads as the whole reference ("FERPA 34 CFR §99.10")
  // when both parts are present, or just the bare "§N(...)" otherwise.
  const REF_RE = /(?:(HEA|IRC|FERPA\s+34\s+CFR)\s+)?§(\d+[a-z]*(?:\.\d+)?)((?:\([a-zA-Z0-9]+\))*)/g;

  function linkifyCitation(escapedText, initialBody) {
    let currentBody = initialBody || null;
    const html = String(escapedText).split(';').map(function (chunk) {
      // Body-only chunks (e.g. "FERPA does not apply…") still need to
      // update context for any §refs in later chunks.
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
