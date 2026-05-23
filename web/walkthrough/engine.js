// engine.js — JS port of Nasfaa::RuleEngine
//
// First-match-wins evaluator for nasfaa_rules.yml (consumed as rules.json).
// Equivalent to lib/nasfaa/rule_engine.rb. Pure data-in/data-out, no I/O.
//
// Usage:
//   import { RuleEngine } from './engine.js';
//   const engine = new RuleEngine(rulesJson.rules);
//   const trace = engine.evaluate({ includes_fti: true, disclosure_to_student: true });
//   // => { ruleId: 'FTI_R1_student', result: 'permit', path: ['FTI_R1_student'], scopeNote: undefined, cautionNote: undefined }
//
// Inputs are a flat boolean bag. Missing keys are treated as false (matches
// Ruby's `disclosure_data[:missing]` semantics in DisclosureData).
//
// The Trace shape mirrors Ruby's Nasfaa::Trace struct (with snake_case
// fields converted to camelCase for JS idiom).

export class RuleEngine {
  constructor(rules) {
    if (!Array.isArray(rules)) {
      throw new TypeError('RuleEngine requires an array of rules');
    }
    this.rules = rules;
  }

  // Returns Trace ({ruleId, result, path, scopeNote, cautionNote}) or null
  // if no rule matched (should not occur in practice — the YAML carries
  // catch-all deny rules for both branches).
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

export function permitted(trace) {
  if (!trace) return false;
  return ['permit', 'permit_with_scope', 'permit_with_caution'].includes(trace.result);
}

export function denied(trace) {
  return Boolean(trace) && trace.result === 'deny';
}
