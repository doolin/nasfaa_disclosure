// engine.js — JS port of Nasfaa::RuleEngine
//
// First-match-wins evaluator for nasfaa_rules.yml. Plain script
// (no ES modules) so it loads under file:// without a server.
// Attaches `window.Nasfaa.RuleEngine` / `permitted` / `denied`.

(function (global) {
  'use strict';

  class RuleEngine {
    constructor(rules) {
      if (!Array.isArray(rules)) {
        throw new TypeError('RuleEngine requires an array of rules');
      }
      this.rules = rules;
    }

    evaluate(inputs) {
      const bag = inputs || {};
      const path = [];
      for (const rule of this.rules) {
        path.push(rule.id);
        if (this._matches(rule, bag)) {
          return {
            ruleId: rule.id,
            result: rule.result,
            path: path.slice(),
            scopeNote: rule.scope_note,
            cautionNote: rule.caution_note,
          };
        }
      }
      return null;
    }

    _matches(rule, bag) {
      return rule.when_all.every((condition) => {
        if (condition.startsWith('!')) {
          return !bag[condition.slice(1)];
        }
        return Boolean(bag[condition]);
      });
    }
  }

  function permitted(trace) {
    if (!trace) return false;
    return ['permit', 'permit_with_scope', 'permit_with_caution'].includes(trace.result);
  }

  function denied(trace) {
    return Boolean(trace) && trace.result === 'deny';
  }

  global.Nasfaa = global.Nasfaa || {};
  global.Nasfaa.RuleEngine = RuleEngine;
  global.Nasfaa.permitted = permitted;
  global.Nasfaa.denied = denied;
})(typeof window !== 'undefined' ? window : globalThis);
