# Fix Box 7 Yes/No Transition Swap

> **NOTE**: This plan needs discussion before implementation. The swap has regulatory
> implications — specifically whether §1090(a)(3)(C) consent is research-specific or
> general-purpose — that should be verified against the statute before changing the logic.
> The PDF arrows suggest a swap, but the current "general HEA consent" interpretation
> in the help text may reflect intentional editorial judgment by NASFAA. Compare against
> the primary regulatory source before proceeding.

## Context

Box 7 ("Is the disclosure for research by or on behalf of the institution to promote college attendance, persistence, and completion?") has its Yes/No transitions swapped compared to the PDF.

Current implementation:
- Box 7 **Yes** (IS research) → Box 9 (PII check) — skips consent
- Box 7 **No** (NOT research) → Box 8 (HEA consent under §1090(a)(3)(C)) — checks consent

PDF shows:
- Box 7 **Yes** (IS research) → Box 8 (HEA consent) — checks consent for research
- Box 7 **No** (NOT research) → Box 9 (PII check) — skips consent

This is a different type of error from the Box 5 fix (wrong destination). Here the destinations are correct but assigned to the wrong branches — a Yes/No inversion. This is the same class of error as the Box 9 PII inversion previously fixed, likely caused by crossing lines in the PDF where the Box 7 Yes arrow crosses over Box 8 to reach Box 9 (or vice versa).

The regulatory logic supports the swap: Box 8 asks about §1090(a)(3)(C) consent, which is the consent provision for research promoting college attendance — the same activity Box 7 asks about. It makes no sense to check §1090(a)(3)(C) consent when the purpose is NOT research (Box 7 No), and skip it when it IS research (Box 7 Yes).

## What changes

Box 7 Yes currently: **Box 9** (`fafsa_pii` — PII check)
Box 7 Yes should be: **Box 8** (`fafsa_hea_consent` — HEA consent check)

Box 7 No currently: **Box 8** (`fafsa_hea_consent`)
Box 7 No should be: **Box 9** (`fafsa_pii`)

The downstream structure is unchanged — Box 8 Yes still permits, Box 8 No still goes to Box 9, and Box 9 branches to permit (no PII) or Box 10 (has PII). Only the entry point from Box 7 flips.

## Files to modify

### 1. `nasfaa_questions.yml` — DAG definition
- **Line 185**: Change `on_yes: fafsa_pii` → `on_yes: fafsa_hea_consent`
- **Line 186**: Change `on_no: fafsa_hea_consent` → `on_no: fafsa_pii`
- **Line 91** (rule engine comment in the YAML): Update `# Box 8 is only reached via Box 7 No` → `# Box 8 is reached via Box 7 Yes (research needs consent)`

### 2. `nasfaa_rules.yml` — rule engine
- **Lines 91–94**: Rule `FAFSA_R6_HEA_written_consent` currently has:
  ```yaml
  when_all: ["!includes_fti", is_fafsa_data, "!research_promote_attendance", hea_written_consent]
  ```
  Change `"!research_promote_attendance"` → `"research_promote_attendance"` (remove negation).

  The rule comment (line 91) says "Box 8 is only reached via Box 7 No (not research)" — update to "Box 8 is reached via Box 7 Yes (is research)."

- **Lines 96–99**: Rule `FAFSA_R7_no_pii` currently has:
  ```yaml
  when_all: ["!includes_fti", is_fafsa_data, "!contains_pii"]
  ```
  After the swap, Box 9 is reached via two paths: Box 7 No (directly) and Box 8 No (via Box 7 Yes → Box 8 No). The `!contains_pii` condition already handles both cases correctly — no change needed here. But consider whether an additional `"!research_promote_attendance"` OR `"!hea_written_consent"` guard is needed to prevent the rule from firing for inputs where Box 7 Yes → Box 8 Yes should have already matched FAFSA_R6. Analysis: FAFSA_R6 appears earlier in the rule list and will match first when both `research_promote_attendance` and `hea_written_consent` are true, so FAFSA_R7 only fires for the residual cases. No guard needed.

### 3. `lib/nasfaa/decision_tree.rb` — imperative engine
- **Line 38**: Update comment from `# Yes → skip to Box 9 (PII check); No → Box 8 (HEA consent)` to `# Yes → Box 8 (HEA consent); No → skip to Box 9 (PII check)`
- **Line 40**: Update comment from `# Box 8: Has HEA consent? (only reached when Box 7 = No)` to `# Box 8: Has HEA consent? (only reached when Box 7 = Yes)`
- **Line 41**: Change:
  ```ruby
  return true if !disclosure_request.research_promote_attendance? && disclosure_request.hea_written_consent?
  ```
  to:
  ```ruby
  return true if disclosure_request.research_promote_attendance? && disclosure_request.hea_written_consent?
  ```
  (Remove the `!` negation.)

### 4. `spec/support/paths.rb` — canonical path table
- **Line 20**: `'FAFSA_R6_HEA_written_consent' => { compact: 'nnynnnny', result: :permit }`

  Current path `nnynnnny` decodes as: Box 1 No, Box 2 No, Box 3 Yes, Box 4 No, Box 5 No, Box 6 No, **Box 7 No**, **Box 8 Yes** → permit.

  After the swap, FAFSA_R6 is reached via Box 7 **Yes** → Box 8 Yes. The compact path becomes `nnynnnyy` (Box 7 Yes instead of No at position 7).

- **Line 21**: `'FAFSA_R7_no_pii' => { compact: 'nnynnnnnn', result: :permit }`

  Current path `nnynnnnnn` decodes as: ...Box 7 (position 7) is **No**, Box 8 (position 8) is **No**, Box 9 (position 9) is **No** → permit (no PII).

  After the swap, Box 7 No goes directly to Box 9 (skipping Box 8). The path becomes `nnynnnnn` (one character shorter — 8 instead of 9). Box 7 No → Box 9 No → permit.

  But wait: Box 9 is also reached via Box 7 Yes → Box 8 No. That path would be `nnynnnynn` (Box 7 Yes, Box 8 No, Box 9 No) → also reaches FAFSA_R7. The path table needs an entry for this alternate route as well, OR only the shortest/most-direct path is kept. Recommend adding both paths since they represent different user journeys:
  - `'FAFSA_R7_no_pii' => { compact: 'nnynnnnn', result: :permit }` (Box 7 No → Box 9 No)
  - A second entry for the Box 7 Yes → Box 8 No → Box 9 No path: `'FAFSA_R7_no_pii_via_research' => { compact: 'nnynnnynn', result: :permit }` — or handle via the existing DAG convergence mechanism

  Similarly, the FERPA paths (Box 9 Yes → Box 10 → ...) now have an additional entry point via Box 7 No → Box 9 Yes. These parallel paths need entries in the table, similar to the Box 5 → Box 12 DAG convergence in the Box 5 plan.

  Enumerate affected paths through Box 7 No → Box 9 Yes → Box 10 → ...:
  - `nnynnnyn` + FERPA chain (Box 10 Yes → permit, Box 10 No → Box 11...)

  And through Box 7 Yes → Box 8 No → Box 9 Yes → Box 10 → ...:
  - `nnynnnynn` + FERPA chain

  These are DAG convergence paths — Box 9, like Box 12, becomes a multi-entry node.

### 5. `nasfaa_scenarios.yml` — scenario library
- **Lines 186–203**: Scenario `institutional_researcher_studies_persistence` — currently sets `research_promote_attendance: true` and expects rule `FAFSA_R7_no_pii`. The scenario description says "research promoting college attendance (Box 7 Yes) still requires passing the PII gate (Box 9)." After the swap, Box 7 Yes goes to Box 8 first (HEA consent), not Box 9. Update the description and either:
  - Add `hea_written_consent: false` to inputs (researcher doesn't have consent) so it falls through Box 8 No → Box 9 No → permit via `FAFSA_R7_no_pii`. Update description accordingly.
  - Or add `hea_written_consent: true` to inputs and change expected rule to `FAFSA_R6_HEA_written_consent`. This changes the scenario from "de-identified research" to "consented research."
  - Recommend keeping the de-identified angle (add `hea_written_consent: false`) and creating a new scenario for Box 7 Yes → Box 8 Yes (research with consent → permit).

- **Lines 205–220**: Scenario `state_grant_agency_with_hea_consent` — currently sets `hea_written_consent: true` (without `research_promote_attendance`) and expects rule `FAFSA_R6_HEA_written_consent`. After the swap, FAFSA_R6 requires `research_promote_attendance: true`. This scenario would no longer match FAFSA_R6. Either:
  - Add `research_promote_attendance: true` to inputs — but a state grant agency isn't doing research, so the narrative breaks.
  - Or rethink the scenario entirely. If §1090(a)(3)(C) consent is research-specific (not general), then a state grant agency wouldn't use this consent mechanism. The scenario may need to be rewritten to use a different authorization basis (e.g., FERPA 99.31 exception).
  - **This is the scenario most affected by the swap and the strongest reason to discuss before implementing.** The "general HEA consent" interpretation may be NASFAA's editorial choice rather than a transcription error.

### 6. Spec files to update
- `spec/walkthrough_spec.rb` — **line 146–150**: Test `permits FAFSA with HEA written consent (FAFSA_R6)` sends `nnynnnny` (Box 7 No → Box 8 Yes). After swap, the path is `nnynnnyy` (Box 7 Yes → Box 8 Yes). Update the input sequence.
- `spec/walkthrough_spec.rb` — **line 152–154**: Test for `FAFSA_R7` sends `nnynnnnnn`. After swap, path is `nnynnnnn` (shorter — Box 7 No goes directly to Box 9, skipping Box 8). Update the input sequence.
- `spec/walkthrough_spec.rb` — **line 321**: Cross-verification table entry `'FAFSA_R6_HEA_written_consent' => %w[no no yes no no no no yes]`. Update Box 7 answer from `no` to `yes`.
- `spec/rule_engine_spec.rb` — **line 100**: The permit mapping `{ is_fafsa_data: true, research_promote_attendance: true }` expects a permit. After the swap, this input would match `FAFSA_R7_no_pii` (since `contains_pii` defaults to false). Verify this is still the desired behavior or update.
- `spec/nasfaa_data_sharing_decision_tree_spec.rb` — **line 146**: Test creates `DisclosureData.new(includes_fti: false, is_fafsa_data: true, research_promote_attendance: true)` and likely expects a permit. After the swap, this still permits (via `FAFSA_R7_no_pii` since `contains_pii` defaults false). Check if the test should be more specific about which rule fires.
- `spec/exhaustive_verification_spec.rb` — the exhaustive 36,864 combinations will automatically catch any disagreements between the imperative tree and rule engine after the swap. This is the final verification gate.

## Unifying transition definitions

Same methodology as the Box 5 plan: the three representations (DAG, rules, imperative tree) must all be updated consistently. The existing exhaustive verification spec enforces three-way agreement. The error originated at the PDF transcription stage and propagated to all three representations identically, so fixing all three and running the exhaustive spec confirms consistency.

## Open questions for discussion

1. **Is §1090(a)(3)(C) consent research-specific or general?** The current help text says "broader than FERPA consent." If NASFAA intentionally interprets §1090(a)(3)(C) as a general consent mechanism (not limited to research), then the current Box 7 routing may be an editorial choice, not an error. The PDF arrows suggest a swap, but the regulatory interpretation matters.

2. **State grant agency scenario**: If the swap is correct, the `state_grant_agency_with_hea_consent` scenario loses its authorization basis. State grant agencies receiving FAFSA data would need to rely on a FERPA 99.31 exception (e.g., Box 15 — authorized representatives) rather than HEA consent. Is this the correct regulatory outcome?

3. **Should both fixes (Box 5 and Box 7) be implemented together?** They're independent changes, but implementing them together would require only one pass through the exhaustive verification and scenario library updates.

## Verification

1. Fix all three representations (DAG, rules, imperative tree)
2. Run `bundle exec rspec spec/exhaustive_verification_spec.rb` — 0 disagreements
3. Run full suite `bundle exec rspec` — all passing, coverage maintained
4. Manually run `bin/nasfaa walkthrough` and verify:
   - Box 7 Yes → Box 8 (consent check) → Box 8 Yes → Permit
   - Box 7 No → Box 9 (PII check) → Box 9 No → Permit
5. Run `bin/nasfaa evaluate nnynnnyy` and confirm it reaches `FAFSA_R6_HEA_written_consent`
6. Run `bin/nasfaa evaluate nnynnnnn` and confirm it reaches `FAFSA_R7_no_pii`
