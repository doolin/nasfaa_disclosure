# Fix Box 5 Yes Transition

## Context

Box 5 ("Will the information be used for the application, award, and/or administration of financial aid?") currently routes Yes → `result_FAFSA_R3_used_for_aid_admin` (immediate permit). The PDF shows Box 5 Yes → **Box 12** (school official with legitimate educational interest, 99.31(a)(1)). This is a crossing-line error from the original diagram transcription — exactly the failure mode documented in memory.

The fix changes the decision logic so that FAFSA data used for aid admin still requires a school official / LEI check (or another FERPA 99.31 exception) before disclosure is permitted.

## What changes

Box 5 Yes currently: **permit immediately**
Box 5 Yes should be: **route to Box 12** (`ferpa_school_official`), then continue through the FERPA 99.31 exception chain (Boxes 12–19). Box 12 becomes a DAG join point with two entry paths: (1) Box 10 No → Box 11 No → Box 12, and (2) Box 5 Yes → Box 12.

## Files to modify

### 1. `nasfaa_questions.yml` — DAG definition
- **Line 165**: Change `on_yes: result_FAFSA_R3_used_for_aid_admin` → `on_yes: ferpa_school_official`
- Remove or repurpose the `result_FAFSA_R3_used_for_aid_admin` result node (lines 313–318) — it no longer has an inbound edge. Decide: delete it, or keep it in case a future rule revision reinstates a direct permit. Recommend deletion to keep the YAML clean.
- Update the DAG comment block (line 207–209) to note that Box 12 is also reached from Box 5 Yes.

### 2. `nasfaa_rules.yml` — rule engine
- **Lines 83–85**: Rule `FAFSA_R3_used_for_aid_admin` currently permits when `!includes_fti AND is_fafsa_data AND used_for_aid_admin`. This must be split or replaced:
  - New rule: `FAFSA_R3_aid_admin_school_official` — permits when `!includes_fti AND is_fafsa_data AND used_for_aid_admin AND to_school_official_legitimate_interest`
  - The remaining FERPA 99.31 exceptions (Boxes 13–19) already fire for `!includes_fti` inputs, so a Box 5 Yes + Box 12 No case will naturally fall through to those rules.
  - **Ordering matters**: The new `FAFSA_R3_aid_admin_school_official` rule must appear before the existing `FERPA_R2_school_official_LEI` rule, since it's more specific (FAFSA data + aid admin + LEI vs. just LEI).
  - Consider whether a deny guard is needed after the aid admin + non-LEI case to prevent unintended fall-through (same pattern as `FTI_R2b_aid_admin_deny`). Analyze: if Box 5 Yes + Box 12 No, the path continues to Boxes 13–19. Those rules already exist and apply. No deny guard needed — the existing `NONFTI_DENY_default` catches any case that exhausts all exceptions.

### 3. `lib/nasfaa/decision_tree.rb` — imperative engine
- **Line 32**: `return true if disclosure_request.used_for_aid_admin?` — this is the direct permit that must change.
- Replace with: if `used_for_aid_admin?`, check `ferpa_99_31_exceptions_apply?` (which already includes Box 12 as its second check). If any exception applies → permit. Otherwise fall through to deny.
- Alternatively, restructure so that Box 5 Yes jumps into the FERPA chain starting at Box 12 (skipping Box 11 / directory info). This could mean extracting a `ferpa_99_31_exceptions_from_box_12?` helper, or simply inlining the check.
- Recommended approach: extract `ferpa_99_31_exceptions_apply?` to accept an optional starting box, or split into `ferpa_box_12_onwards?` (Boxes 12–19) and keep `ferpa_99_31_exceptions_apply?` calling `ferpa_box_12_onwards?` after checking Box 11. This keeps the imperative code aligned with the DAG structure.

### 4. `spec/support/paths.rb` — canonical path table
- **Line 18**: `'FAFSA_R3_used_for_aid_admin' => { compact: 'nnyny', result: :permit }` — this path no longer terminates at Box 5. It now continues through Boxes 12–19.
- Replace with the new path(s). Box 5 Yes → Box 12 Yes would be compact `'nnynyy'` → rule `FAFSA_R3_aid_admin_school_official`, result `:permit`.
- Box 5 Yes → Box 12 No → Box 13 Yes, etc. — these paths merge with existing FERPA exception paths but with a different prefix. Each needs its own entry OR the existing FERPA entries need to account for the Box 5 Yes prefix.
- **This is the hardest part**: the path table currently assumes each FERPA exception has one entry point (via Box 10 No → Box 11 No → Box 12...). With Box 5 Yes → Box 12, there are now parallel paths to the same results. The table needs entries for both entry points, OR the walkthrough engine needs to handle DAG convergence (Box 12 reached from two parents).
- Enumerate all new paths through Box 5 Yes:
  - `nnyny` + `y` (Box 12 Yes) → permit via school official LEI
  - `nnyny` + `ny` (Box 12 No, Box 13 Yes) → permit_with_caution via judicial
  - `nnyny` + `nny` (Box 12 No, Box 13 No, Box 14 Yes) → permit via transfer
  - `nnyny` + `nnny` (Box 14 No, Box 15 Yes) → permit via authorized reps
  - `nnyny` + `nnnny` (Box 15 No, Box 16 Yes) → permit via research org
  - `nnyny` + `nnnnny` (Box 16 No, Box 17 Yes) → permit via accrediting
  - `nnyny` + `nnnnnny` (Box 17 No, Box 18 Yes) → permit via parent dependent
  - `nnyny` + `nnnnnnny` (Box 18 No, Box 19 Yes) → permit via otherwise permitted
  - `nnyny` + `nnnnnnnн` (all No through Box 19) → deny

### 5. `nasfaa_scenarios.yml` — scenario library
- **Lines 151–166**: The `aid_office_processes_awards` scenario needs updating. Its inputs currently set `used_for_aid_admin: true` but don't set `to_school_official_legitimate_interest`. After the fix, this scenario would hit the deny path (Box 5 Yes → Box 12 No → ... → all No → deny). Either:
  - Add `to_school_official_legitimate_interest: true` to its inputs and update the rule_id to `FAFSA_R3_aid_admin_school_official`
  - Or update the scenario narrative to reflect that aid admin alone isn't sufficient — you also need a 99.31 exception
- Add a new scenario for Box 5 Yes → Box 12 No → deny (aid admin use but no FERPA exception)

### 6. Spec files to update
- `spec/walkthrough_spec.rb` — line 127–129: the `FAFSA_R3` walkthrough test sends `nnyny` and expects rule `FAFSA_R3_used_for_aid_admin`. Update to send the new longer path and expect the new rule.
- `spec/walkthrough_spec.rb` — line 319: cross-verification table entry for `FAFSA_R3_used_for_aid_admin`
- `spec/rule_engine_spec.rb` — lines 57–61: `permits FAFSA data for aid admin` test
- `spec/nasfaa_data_sharing_decision_tree_spec.rb` — lines 129–134: `disclosure is FAFSA data for financial aid purposes` test
- `spec/exhaustive_verification_spec.rb` — the exhaustive 36,864 combinations should catch any disagreements automatically, serving as the final verification gate

## Unifying transition definitions

Box 5 transitions are currently defined in **three independent places**:
1. `nasfaa_questions.yml` — `on_yes` / `on_no` edges
2. `nasfaa_rules.yml` — `when_all` conditions (implicit transitions via rule ordering)
3. `lib/nasfaa/decision_tree.rb` — imperative `if/return` logic

**Methodology for unification**: The YAML question DAG (`nasfaa_questions.yml`) should be the single source of truth for transitions. The rule engine (`nasfaa_rules.yml`) encodes the same logic as flat first-match rules — these must agree but express the logic differently (conditions vs. edges). The imperative decision tree should be derived from or verified against the DAG.

The existing exhaustive verification spec (`spec/exhaustive_verification_spec.rb`) already enforces agreement between the imperative tree and the rule engine across all 36,864 inputs. The walkthrough specs enforce agreement between the DAG and the rule engine. Together, these form a three-way cross-check: if any of the three representations disagrees, the specs catch it. This is the existing unification mechanism and it works — the issue was an upstream transcription error from the PDF, not a drift between representations.

**Recommendation**: No new unification infrastructure needed. Fix the transition in all three places, run the exhaustive spec, and let it confirm agreement.

## Verification

1. Fix all three representations (DAG, rules, imperative tree)
2. Run `bundle exec rspec spec/exhaustive_verification_spec.rb` — 0 disagreements
3. Run full suite `bundle exec rspec` — all passing, coverage maintained
4. Manually run `bin/nasfaa walkthrough` and trace Box 5 Yes → Box 12
5. Run `bin/nasfaa evaluate nnynyy` and confirm it reaches the new school official LEI result
