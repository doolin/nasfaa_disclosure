// engine.js — JavaScript port of Nasfaa::RuleEngine.
//
// Mirrors lib/nasfaa/rule_engine.rb: first-match-wins evaluation of an
// ordered rule list against a flat boolean-input bag.  Same shape as the
// Ruby Trace: { ruleId, result, path, scopeNote, cautionNote }.
//
// Usage (browser, ES module-ish via <script>):
//   const engine = new RuleEngine(rulesData.rules);
//   const trace = engine.evaluate({ includes_fti: true, disclosure_to_student: true });
//   // => { ruleId: 'FTI_R1_student', result: 'permit', path: [...], ... }
//
// `rules` is the array under the top-level "rules" key of rules.json.
// Inputs are a plain object whose keys are DisclosureData field names.
// Unset keys are treated as false (matching Ruby DisclosureData defaults).

(function (root) {
  'use strict';

  class RuleEngine {
    constructor(rules) {
      if (!Array.isArray(rules)) {
        throw new TypeError('RuleEngine expects an array of rule objects');
      }
      this.rules = rules;
    }

    evaluate(inputs) {
      const data = inputs || {};
      const path = [];
      for (const rule of this.rules) {
        path.push(rule.id);
        if (this._matches(rule, data)) {
          return {
            ruleId: rule.id,
            result: rule.result,
            path: path.slice(),
            scopeNote: rule.scope_note || null,
            cautionNote: rule.caution_note || null,
          };
        }
      }
      return null;
    }

    _matches(rule, data) {
      const conditions = rule.when_all || [];
      return conditions.every((cond) => {
        if (typeof cond !== 'string') return false;
        if (cond.startsWith('!')) {
          return !data[cond.slice(1)];
        }
        return !!data[cond];
      });
    }
  }

  // Field list mirrors lib/nasfaa/disclosure_data.rb FIELDS.
  const DISCLOSURE_FIELDS = Object.freeze([
    'includes_fti',
    'disclosure_to_student',
    'disclosure_to_contributor_parent_or_spouse',
    'is_fafsa_data',
    'used_for_aid_admin',
    'disclosure_to_scholarship_org',
    'explicit_written_consent',
    'research_promote_attendance',
    'hea_written_consent',
    'ferpa_written_consent',
    'directory_info_and_not_opted_out',
    'to_school_official_legitimate_interest',
    'due_to_judicial_order_or_subpoena_or_financial_aid',
    'to_other_school_enrollment_transfer',
    'to_authorized_representatives',
    'to_research_org_ferpa',
    'to_accrediting_agency',
    'parent_of_dependent_student',
    'otherwise_permitted_under_99_31',
    'contains_pii',
  ]);

  const NasfaaEngine = { RuleEngine, DISCLOSURE_FIELDS };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = NasfaaEngine;
  } else {
    root.NasfaaEngine = NasfaaEngine;
  }
})(typeof self !== 'undefined' ? self : this);
