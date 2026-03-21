# Fix Box 8 No Transition

> **NOTE**: This plan should be reviewed before implementation. The PDF appears to
> terminate Box 8 No at a gray "Disclosure Not Permitted (Review ...)" box, while
> current code routes Box 8 No into Box 9 and then FERPA exceptions. Because the
> decision artifact is a DAG with crossing lines, this is an edge-level transition
> question, not a node-text question.

## Context

Box 8 asks:

> "Has the student provided written consent for disclosure under the Higher Education Act (HEA)? 1090(a)(3)(C)"

Current implementation routes Box 8 **No** to Box 9 (`fafsa_pii`), allowing eventual
permit outcomes via no-PII and FERPA exception paths.

The PDF rendering indicates Box 8 **No** goes to a gray terminal:

> "Disclosure Not Permitted (Review 99.31(a)(9)(ii) and consult legal counsel if subpoena, court order, or other law enforcement request)"

If this reading is correct, Box 8 No should terminate immediately and not fall through
to Box 9.

## What changes

Box 8 No currently: **route to Box 9** (`fafsa_pii`)

Box 8 No should be: **terminal deny/review result node** (gray box semantics), with no
further DAG traversal.

This is different from Box 5 and Box 7 plans:
- not a join-point correction
- not a yes/no inversion
- instead, a **terminal-vs-fallthrough** transition error

## Files to modify

### 1. `nasfaa_questions.yml` — DAG definition
- **Box 8 node (`fafsa_hea_consent`)** currently:
  - `on_yes: result_FAFSA_R6_HEA_written_consent`
  - `on_no: fafsa_pii`
- Change Box 8 No to a terminal result node, e.g.:
  - `on_no: result_FAFSA_R6b_no_hea_consent_review_deny`
- Add the new result node in the Non-FTI results section with:
  - `result: deny`
  - explicit message text matching the gray PDF outcome
  - citation/reference that captures the review note language

### 2. `nasfaa_rules.yml` — rule engine
- Keep `FAFSA_R6_HEA_written_consent` (permit on HEA consent).
- Add a deny guard rule for Box 8 No semantics, placed **before**
  `FAFSA_R7_no_pii` and FERPA rules so it cannot fall through:

  Example shape (exact final conditions to confirm):

  ```yaml
  - id: FAFSA_R6b_no_hea_consent_review_deny
    when_all: ["!includes_fti", is_fafsa_data, "!research_promote_attendance", "!hea_written_consent"]
    result: deny
    caution_note: "Review 99.31(a)(9)(ii) and consult legal counsel if subpoena/court order/law enforcement request."
  ```

- **Ordering is critical**: this deny rule must come after `FAFSA_R6_HEA_written_consent`
  and before `FAFSA_R7_no_pii`, or Box 8 No can still resolve as permit.

### 3. `lib/nasfaa/decision_tree.rb` — imperative engine
- Current flow:
  - permit if `!research_promote_attendance? && hea_written_consent?`
  - otherwise continue to PII (`contains_pii?`) and FERPA chain
- Update to terminate on Box 8 No path before PII checks:
  - if branch is in Box 8 context and HEA consent is not present, return deny
- Recommended explicit guard:

  ```ruby
  return false if !disclosure_request.research_promote_attendance? &&
                  !disclosure_request.hea_written_consent?
  ```

  placed immediately after the existing Box 8 permit condition.

### 4. `spec/support/paths.rb` — canonical path table
- Add a new terminal path for Box 8 No deny result.
- Remove any path assumptions that Box 8 No continues to Box 9 for permit outcomes.
- Expected impact:
  - one additional terminal rule/result entry
  - `TERMINAL_PATHS` cardinality update

### 5. `nasfaa_scenarios.yml` — scenario library
- Add explicit scenario for Box 8 No terminal outcome:
  - FAFSA data branch reaching Box 8
  - `hea_written_consent: false`
  - expected deny + review note
- Revisit any scenario currently relying on Box 8 No fall-through to Box 9/FERPA.
- Ensure scenario narratives align with terminal behavior (no implied downstream FERPA rescue).

### 6. Spec files to update
- `spec/walkthrough_spec.rb`
  - add/modify path test for Box 8 No terminal
  - update cross-verification table to include the new rule id
  - update question/result node count assertions if result nodes increase
- `spec/rule_engine_spec.rb`
  - add explicit example for new Box 8 No deny rule
  - ensure order-sensitive tests catch accidental fall-through
- `spec/nasfaa_data_sharing_decision_tree_spec.rb`
  - add imperative path assertion for Box 8 No -> deny
- `spec/evaluate_spec.rb`
  - add compact-string path coverage for new terminal path
- `spec/exhaustive_verification_spec.rb`
  - serves as final consistency gate between imperative and declarative engines

### 7. Documentation updates
- `README.md`
  - update walkthrough narrative if it implies Box 8 No continues to Box 9
  - update any rule-count/result-count tables if counts change
- `docs/ROADMAP.md`
  - add or update Box 8 transition note and link to this plan

## Unifying transition definitions

Box 8 transitions are represented in the same three places as other high-risk edges:
1. `nasfaa_questions.yml` (explicit DAG edges)
2. `nasfaa_rules.yml` (first-match rule order)
3. `lib/nasfaa/decision_tree.rb` (imperative branch flow)

The existing validation strategy remains the right one:
- Walkthrough specs enforce DAG behavior
- Rule engine specs enforce declarative semantics
- Exhaustive verification enforces DecisionTree vs RuleEngine agreement

For this fix, ensure all three representations are updated together so the deny guard
is not accidentally bypassed by rule ordering or imperative fall-through.

## Open questions for discussion

1. Should the gray terminal map to plain `deny`, or to a new result type with mandatory review text?
2. If mapped to `deny`, where should the review language live (`message`, `caution_note`, scenario narrative)?
3. Does the current `FERPA_R3_judicial_or_finaid_related` caution note duplicate text that actually belongs to this Box 8 gray terminal in the PDF?

## Verification

1. Update DAG, rules, and imperative tree in lockstep.
2. Run `bundle exec rspec spec/exhaustive_verification_spec.rb` (expect 0 disagreements).
3. Run full suite `bundle exec rspec`.
4. Manual walkthrough trace around Boxes 7/8/9:
   - path reaching Box 8 with HEA consent `Yes` -> permit
   - path reaching Box 8 with HEA consent `No` -> immediate terminal deny/review
5. Evaluate-mode checks:
   - add compact path for new Box 8 No terminal
   - confirm no extra answers are consumed past Box 8 on that path
