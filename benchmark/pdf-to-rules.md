# Benchmark: PDF + DAG → rules file

**Task for the agent under evaluation.** Read the canonical NASFAA Data
Sharing Decision Tree PDF and reproduce its logic as a machine-evaluable
rules file in the format specified below. You are given the *format* and a
few *template* rules — not the answers. You must derive every rule from
the diagram.

This is a standing benchmark. The held-out answer key is this repo's
canonical `nasfaa_rules.yml`. A submission is scored by **behavioural
equivalence**: both rule sets are run over every valid input combination
(the repo enumerates 36,864 after applying the mutually-exclusive groups —
see `spec/exhaustive_verification_spec.rb`, the same machinery that
cross-checks the project's two engines) and must produce the same result
for every combination. Getting individual rules "plausible" is not enough;
the *ordered* rule set must classify every input vector identically to the
key.

---

## Input

`docs/NASFAA_Data_Sharing_Decision_Tree.pdf` — a two-page flowchart.

- **Page 1** is the non-FTI path: FAFSA/HEA data and the FERPA 99.31
  exceptions.
- **Page 2** is the FTI path (federal tax information, IRC 6103).
- The chart is a **DAG of numbered decision boxes**. Each box is a
  yes/no question; edges are labelled Yes/No; multiple paths can converge
  on a shared box (it is a DAG, not a pure tree). Some edges **cross** in
  the drawing — trace each line endpoint to endpoint; do not infer a
  target from proximity. Leaf nodes are outcomes (permit / deny, sometimes
  with a caution).

Your job is to linearise that DAG into an **ordered, first-match-wins**
rule list that is behaviourally identical to walking the diagram.

---

## Output format

A single YAML file with these top-level keys, in this order:

```yaml
metadata:
  version: "1.0"
  description: "NASFAA Data Sharing Decision Tree Rules"
  evaluation_order: "first_match_wins"   # rules are tried top-to-bottom
  input_type: "boolean"                  # every input is true/false

validation:
  required_inputs: ["includes_fti"]      # inputs that must be supplied
  mutually_exclusive_groups:             # groups that can't be co-true
    - ["includes_fti", "!includes_fti"]  # "!" = the negated form

result_types:                            # the full outcome vocabulary
  permit: "Disclosure is permitted"
  deny: "Disclosure is not permitted"
  permit_with_caution: "Disclosure permitted with caution"
  permit_with_scope: "Disclosure permitted with scope limitations"

inputs:
  # EVERY predicate you reference in a rule must be declared here as
  # `name: boolean`, with a comment citing the box / statute it encodes.
  includes_fti: boolean                  # top-level FTI vs non-FTI split
  disclosure_to_student: boolean
  # ... one line per input ...

results:
  # Reserved/disambiguation section. May be left as comments.

rules:
  # The ordered decision list. See the rule schema and templates below.
```

### Rule schema

Each entry in `rules:` is a map:

| Key | Required | Meaning |
|-----|----------|---------|
| `id` | yes | Stable unique identifier. Convention: `BRANCH_Rn_short_name`. Guards inserted between numbered rules take a letter suffix (`R2b`). Terminal catch-alls are named `<BRANCH>_DENY_default`. |
| `when_all` | yes | A list of conditions, **all** of which must hold (logical AND). Each item is an input name (must be true) or a negated input name with a leading `!` (must be false). Quote any item starting with `!` so YAML doesn't read it as a tag: `"!includes_fti"`. |
| `result` | yes | Exactly one value from `result_types`. |
| `caution_note` | optional | Free-text guidance. Use on outcomes that permit/deny but require human review. |
| `scope_note` | optional | Free-text scope limitation. Use with `permit_with_scope`. |

### Evaluation semantics (these drive correctness)

1. **First match wins.** Rules are evaluated top to bottom; the first rule
   whose `when_all` is fully satisfied decides the outcome. **Order is part
   of the logic** — the same rules in a different order can give different
   answers.
2. **Booleans, absent = false.** Any input not supplied is treated as
   false. A `"!x"` condition is satisfied when `x` is false or absent.
3. **Branch pin.** The first condition of every rule pins the top-level
   branch: `includes_fti` (Page 2) or `"!includes_fti"` (Page 1). No rule
   spans both branches.
4. **Guards before fall-throughs.** A "No" edge that must terminate (e.g.
   a deny) has to appear **before** any later, more permissive rule that
   would otherwise rescue that input vector. Encode "No" edges as negated
   conditions, and place terminal denies ahead of the broader permits they
   must pre-empt. This is the most common source of behavioural mismatch.
5. **Shared gates.** A box reachable from several paths becomes a single
   rule carrying just the branch pin plus that gate's condition; the
   ordering ensures every path that should reach it does.
6. **Catch-all per branch.** Each branch ends with a terminal
   `when_all: ["<branch pin>"]` rule (no other conditions) giving the
   default outcome for "fell through everything above."

---

## Template rules (format illustration — NOT the answer set)

These show every structural case. Reproduce the *shapes*, not these exact
rules; the answer set is larger and you must derive it from the diagram.

```yaml
# (a) Simple permit: branch pin + one positive condition.
- id: FTI_R1_student
  when_all: [includes_fti, disclosure_to_student]
  result: permit

# (b) Multi-condition permit: several conditions AND-ed.
- id: FTI_R2_aid_admin_school_official
  when_all: [includes_fti, used_for_aid_admin, to_school_official_legitimate_interest]
  result: permit

# (c) Guard deny placed BEFORE a fall-through. Aid-admin without the
#     school-official basis must deny here, or it would wrongly fall
#     through to a later scholarship permit. Note this rule sits directly
#     after (b) and before the scholarship rule.
- id: FTI_R2b_aid_admin_deny
  when_all: [includes_fti, used_for_aid_admin]
  result: deny

# (d) Negated conditions encode "No" edges / path guards (Page 1 branch).
- id: FAFSA_R1_to_student
  when_all: ["!includes_fti", disclosure_to_student]
  result: permit

# (e) permit_with_caution.
- id: FERPA_R3_judicial_or_finaid_related
  when_all: ["!includes_fti", due_to_judicial_order_or_subpoena_or_financial_aid]
  result: permit_with_caution

# (f) An outcome carrying a caution_note (here a deny that needs review).
- id: FAFSA_R6b_no_hea_consent_review_deny
  when_all: ["!includes_fti", is_fafsa_data, "!disclosure_to_contributor_parent_or_spouse", "!used_for_aid_admin", "!research_promote_attendance", "!hea_written_consent"]
  result: deny
  caution_note: "Review 99.31(a)(9)(ii) and consult legal counsel if subpoena, court order, or other law enforcement request."

# (g) permit_with_scope + scope_note. ILLUSTRATIVE shape only — this exact
#     rule is not in the answer; it shows how to attach a scope limitation.
- id: EXAMPLE_scope_limited
  when_all: ["!includes_fti", some_scoped_exception]
  result: permit_with_scope
  scope_note: "Only the specific fields required for the stated purpose."

# (h) Shared gate reachable from multiple paths (just branch pin + gate).
- id: FERPA_R0_written_consent
  when_all: ["!includes_fti", ferpa_written_consent]
  result: permit

# (i) Terminal catch-all for the branch (branch pin only).
- id: NONFTI_DENY_default
  when_all: ["!includes_fti"]
  result: deny
```

---

## Completeness checklist (cover all cases)

A correct submission must:

- [ ] Handle **both** branches: every FTI box on Page 2 and every non-FTI
      box (FAFSA/HEA *and* the FERPA 99.31 exceptions) on Page 1.
- [ ] Declare in `inputs:` **every** predicate referenced by any rule, and
      reference no undeclared input.
- [ ] Use only the four `result_types`; attach `caution_note`/`scope_note`
      only where the outcome warrants it.
- [ ] Encode each "No" edge as a negated condition, with **guard denies
      ordered before** the permits they must pre-empt.
- [ ] Route convergent paths through shared-gate rules rather than
      duplicating them.
- [ ] End **each** branch with its `*_DENY_default` (or appropriate
      default) catch-all.
- [ ] Be **first-match-wins correct**: walking the rules top-to-bottom for
      any input vector yields the same outcome as walking the diagram.

## Scoring

The submission is run against the held-out canonical `nasfaa_rules.yml`
over every valid input combination (the 36,864 the exhaustive spec
enumerates). Score = fraction of input vectors whose outcome matches the
key. A perfect score requires the ordered rule set to be behaviourally
identical, not merely similar. Mismatches are reported as the input
vectors that diverge, which localise the offending rule or its ordering.

Run the scorer with `bin/benchmark-rules <candidate.yml>` (or
`make benchmark CANDIDATE=<candidate.yml>`). For the step-by-step
procedure of administering this benchmark to an agent, see
[`onboarding.md`](onboarding.md).
