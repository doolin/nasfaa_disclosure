# NASFAA Data Sharing Decision Tree

<details>
<summary>NEXT:</summary>

- Phase 2: Interactive CLI (walkthrough, quiz, evaluate modes)
- Phase 3: Visualization (Mermaid/Graphviz diagram generation)
- Phase 4: Node.js + Browser port
- See [docs/ROADMAP.md](docs/ROADMAP.md) for full plan.
</details>


---

Disclosing student financial aid data is governed by a
number of regulations which specify who and under what
circumstances financial aid data can be disclosed. The
National Association of Student Financial Aid Administrators
(NASFAA) published a handy disclosure decision tree in
PDF format to help administrators determine disclosure
eligibility. As you can see, it's quite nice.

In a caffeine-induced fit of programming inspiration,
I decided to see how well the generative AI tooling
with the Cursor IDE would perform on writing a program
to determine disclosure eligibility based on the diagram
displayed in the PDF (it's not technically a tree, and
that matters).


## Motivation

<img align="right" width="250px" src=./docs/nasfaa-2025-page-1.png alt="NASFAA
decision diagram" />

At the time of writing, I am employed in a role which has no requirement
for shipping code for any reason. However, I like programming.
It's sort of a hobby. In this case, the disclosure document
was published to an internal Slack channel, and I wondered
how well I could leverage generative AI to implement the
decision graph. Any future role I might land will require
either using generative AI directly for programming, or being
in a position of leadership which will require understanding
its strengths and limitations.

The implementation has a first and definite definition of
done, which is passing all correctly specified unit tests.
A very nice little hobby project with the following goals:

1. Clock the amount of time spent on the actual implementation
as measured by commit history between between successive commits.
2. Evaluate how well Cursor can implement given the document
and minimal prompting.
3. Uncover gaps in my knowledge on current agentic tools and
prompting ability.
4. Write it all up here in the README.

With respect to #3, prompting is an art form, and from
observation, it's a somewhat perishable skill. It requires
practice to get good, stay good, and importantly to keep
up with the power curve. I know that agentic styles are
all the rage, but prompting will still have its place so
it's smart to keep a sharp edge.

## Design

Cursor was given a few design instructions:

- Data and processing strictly separated, with the
decision code carrying no data. The data is wrapped
in a class which implements predicates for querying
boolean state. This is one (of many) sensible designs
supported in Ruby. I would likely implement it similarly
in C using a struct defined as an imcomplete types.

- The data is assumed to have been acquired elsewhere
and rendered into booleans. Acquiring this sort of data
likely requires a bit of non-trivial SQL, whether it's
queried direcly and preprocessed into a view, data store,
whatever. Separating the data acquisition from the processing
increases human legibility and greatly simplifies maintenance
and extension or modifation
at the cost of one or at most a few layers of abstraction.
Specifically, testing the logic is very easy when every
predicate resolves to a boolean.

## Implementation

- Cursor IDE.
- PDF read by Cursor.
- IDE writes as much of the implementation as possible
in agent mode.
- Prompt to refine the implementation as necessary.

## Timeline

Partly estimated and partly extracted from the commit history.


## Results

- It has been a number of years since I implemented a decision
graph of this complexity, and I learned a couple of tricks from
the implementation.

- My prompting skills are rusty. There are a few commits which
represent wasted time due to inefficient prompting.

- Agentic Cursor is not too bad given good prompts and good
guidelines. In my rush to implement, I did not provide a
guideline file, something which would have paid off very
quickly. (I could used guidelines from other projects.)

- The agent-emitted decision code is minimal and terse, especially
in the specs. This terseness required significant cognitive
effort to review, to the extent that part of the spec
code was rewritten to provide a more readable pattern to
the agent. This rewriting cost more time than manually
writing specs, as the the decision graph had to be manually
traversed and checked against the implementation. At that
point rewriting becomes more efficient.

- On the other hand, the agent-emitted data code worked
really well and needed very little adjusting. By design,
the data is wrapped in a class which is instantiated by
a hash of the relevant boolean values. A predicate method
is defined for each boolean, which is how each value is
assessed. Using explicit predicate methods vastly increases
legibility with a very small amount of overhead compare to
the cost of retrieving the base data from a store such as
a file or database.

- The code was sufficiently novel that autocomplete got
nearly all the conditional statements completely wrong.


## Manual verification

I had a suspicion that parts of Cursor's implementation were
incorrect, in particular the FTI branch, and some of the early
decisions in the non-FTI branch. Doubts were induced by flip
flopping specs and implementation as I directed the agent to
write good practice code while ensuring 100% line and branch
coverage.

The first thing standing out is Cursor's use of RSpec short
form assertions, which are inconvenient for systematic,
mannual verification. I prefer DAMP (Descriptive And
Meaningful Phrases) and explicit specs over terse and
implicit. I find such specs reduce cognitive load when
revisiting work which has been sidelined a while.

## Conclusions & lessons

Overall, not too bad, but not a slam dunk either. The main
benefits came early, at the start. Cursor set up the project
with appropriate files, some initial logic, and the associated
specs.

From my end, I wasted time redoing prompts for things such
as spec formating which probably could have been managed
via a configuration file.

Rewriting specs in a form which could be manually verified
was tedious, but necessary for a maintainable component.
The way the specs were manually reconstructed will allow
test-first modification of the decision logic: find the
relevant testing clause(s), update or extend as necessary,
make the specs pass.



# Technical Reference

## Architecture

The project is structured as a Ruby gem (`nasfaa`) with two independent
evaluation engines that have been proven equivalent across all possible inputs:

| Component | Purpose | File |
|---|---|---|
| `Nasfaa::DecisionTree` | Imperative decision logic (Ruby `if/elsif`) | `lib/nasfaa/decision_tree.rb` |
| `Nasfaa::RuleEngine` | Declarative first-match-wins YAML evaluator | `lib/nasfaa/rule_engine.rb` |
| `Nasfaa::DisclosureData` | Boolean input model (20 fields) | `lib/nasfaa/disclosure_data.rb` |
| `Nasfaa::Trace` | Audit trail (rule ID, result, path, notes) | `lib/nasfaa/trace.rb` |
| `Nasfaa::Scenarios` | 23 named real-world scenarios with citations | `lib/nasfaa/scenario.rb` |
| `nasfaa_rules.yml` | 23 rules — the language-neutral specification | `nasfaa_rules.yml` |
| `nasfaa_scenarios.yml` | Scenario definitions (inputs, expected results) | `nasfaa_scenarios.yml` |

Key architectural insight: the YAML rules are a language-neutral specification.
Once verified exhaustively, they become the portable target for other platforms.
Rather than hand-translating Ruby `if/elsif` logic to JavaScript, you build a
YAML evaluator in each language and share the same rule file.

## Usage

```ruby
require 'nasfaa'

# Create a disclosure request
data = Nasfaa::DisclosureData.new(
  includes_fti: true,
  used_for_aid_admin: true,
  to_school_official_legitimate_interest: true
)

# Evaluate with the imperative decision tree (boolean)
tree = Nasfaa::DecisionTree.new(data)
tree.disclose?  # => true

# Evaluate with the YAML rule engine (rich audit trail)
engine = Nasfaa::RuleEngine.new
trace = engine.evaluate(data)
trace.permitted?    # => true
trace.rule_id       # => "FTI_R2_aid_admin_school_official"
trace.result        # => :permit
trace.path          # => ["FTI_R1_student", "FTI_R2_aid_admin_school_official"]

# Query the scenario library
scenario = Nasfaa::Scenarios.find('court_subpoena_for_student_records')
scenario.name        # => "Court Issues Subpoena for Student Financial Aid Records"
scenario.citation    # => "FERPA 34 CFR §99.31(a)(9); §99.31(a)(4)(i) — ..."
scenario.expected_result  # => :permit_with_caution

Nasfaa::Scenarios.by_tag('fti')      # => 5 FTI-related scenarios
Nasfaa::Scenarios.permits            # => 19 permit scenarios
Nasfaa::Scenarios.denials            # => 4 deny scenarios
```

## YAML Rules

The `nasfaa_rules.yml` file encodes the decision tree as 23 rules evaluated
in first-match-wins order. Each rule specifies a `when_all` array of boolean
conditions (negated conditions are prefixed with `!`) and a result:

```yaml
- id: FTI_R2_aid_admin_school_official
  when_all: [includes_fti, used_for_aid_admin, to_school_official_legitimate_interest]
  result: permit
```

The rules are organized into four sections matching the PDF's structure:

| Section | Rules | Governs |
|---|---|---|
| FTI Branch (Page 2) | 5 | IRC §6103 — tax return information |
| FAFSA-Specific (Page 1) | 7 | HEA §1090/§1098h — FAFSA data allowances |
| FERPA Gate + 99.31 Exceptions | 10 | FERPA 34 CFR §99.30–§99.37 |
| Catch-All Deny | 1 | No applicable exception |

Four result types: `permit`, `deny`, `permit_with_scope` (contributor access
limited to personally provided data), and `permit_with_caution` (judicial
order — consult counsel).

## Input Fields

The `DisclosureData` model wraps 20 boolean fields. All default to `false`.

| Field | PDF Box | Description |
|---|---|---|
| `includes_fti` | 1 (FTI) | Data includes Federal Tax Information |
| `disclosure_to_student` | 1/2 | Disclosure is to the data subject |
| `is_fafsa_data` | 3 | Data is FAFSA data per ED definition |
| `disclosure_to_contributor_parent_or_spouse` | 4 | To a FAFSA contributor |
| `used_for_aid_admin` | 2 (FTI), 5 | For financial aid administration |
| `disclosure_to_scholarship_org` | 3 (FTI), 6 | To scholarship/tribal/assistance org |
| `explicit_written_consent` | 3 (FTI), 6 | Student's explicit written consent |
| `research_promote_attendance` | 7 | Institutional research on persistence |
| `hea_written_consent` | 8 | HEA §1090(a)(3)(C) consent |
| `contains_pii` | 9 | Contains personally identifiable information |
| `ferpa_written_consent` | 10 | FERPA written consent |
| `directory_info_and_not_opted_out` | 11 | Directory info, student hasn't opted out |
| `to_school_official_legitimate_interest` | 4 (FTI), 12 | School official with LEI |
| `due_to_judicial_order_or_subpoena_or_financial_aid` | 13 | Judicial order or subpoena |
| `to_other_school_enrollment_transfer` | 14 | To another school for enrollment |
| `to_authorized_representatives` | 15 | Comptroller/AG/Secretary/state ed auths |
| `to_research_org_ferpa` | 16 | FERPA research exception |
| `to_accrediting_agency` | 17 | Accrediting organization |
| `parent_of_dependent_student` | 18 | Parent of IRS-dependent student |
| `otherwise_permitted_under_99_31` | 19 | Catch-all FERPA §99.31 |

## Exhaustive Verification

A central claim of this project is that the imperative `DecisionTree` and the
declarative `RuleEngine` produce identical results for every possible input.
This is not a sampling claim — it is proven by exhaustive enumeration.

### The problem space

With 20 boolean input fields, the full input space is 2^20 = 1,048,576
combinations. Naively testing all of them is feasible (Ruby can do it in
under 30 seconds), but we can do better by exploiting the structure of the
decision tree.

### Structural optimization

The NASFAA decision tree has an important structural property: **Boxes 11–19
(the FERPA §99.31 exceptions) are independent yes/no exits with no further
branching.** Each exception is a simple gate: if true, permit; if false,
continue to the next. No exception depends on any other exception, and none
feeds back into earlier logic.

This means the 20 input fields partition naturally into two groups:

**Core fields (12)** — fields that participate in branching logic, where the
value of one field determines which subsequent fields matter:

| Field | Why it's core |
|---|---|
| `includes_fti` | Top-level branch split (FTI vs non-FTI) |
| `disclosure_to_student` | Universal early exit |
| `is_fafsa_data` | Determines FAFSA-specific path |
| `disclosure_to_contributor_parent_or_spouse` | FAFSA contributor check |
| `used_for_aid_admin` | FTI Box 2 and FAFSA Box 5 |
| `disclosure_to_scholarship_org` | FTI Box 3 and FAFSA Box 6 |
| `explicit_written_consent` | Required with scholarship org |
| `research_promote_attendance` | FAFSA Box 7 |
| `hea_written_consent` | FAFSA Box 8 |
| `contains_pii` | FAFSA Box 9 (PII gate) |
| `ferpa_written_consent` | FERPA Box 10 (consent gate) |
| `to_school_official_legitimate_interest` | **Dual role**: FTI Box 4 AND FERPA Box 12 |

Note that `to_school_official_legitimate_interest` appears in both the FTI
branch (where it determines permit vs deny for aid administrators) and the
FERPA 99.31 exceptions (Box 12). This dual role forces it into the core set.

**Independent exit fields (8)** — the remaining FERPA §99.31 exceptions
(Boxes 11, 13–19). Each is a simple yes → permit gate:

- `directory_info_and_not_opted_out`
- `due_to_judicial_order_or_subpoena_or_financial_aid`
- `to_other_school_enrollment_transfer`
- `to_authorized_representatives`
- `to_research_org_ferpa`
- `to_accrediting_agency`
- `parent_of_dependent_student`
- `otherwise_permitted_under_99_31`

### Why 9 independent configurations suffice

For the 8 independent fields, we test 9 configurations:

1. **All false** — no §99.31 exception applies; the result depends entirely
   on the core fields
2. **Each field individually true** (8 configs) — verifies that each exception
   independently triggers a permit when reached

We do *not* need to test all 2^8 = 256 combinations of independent fields
because the first-match-wins evaluation means only the first true exception
fires. Having two true is functionally identical to having one true — the
second is never evaluated. This is a consequence of the tree structure: these
are parallel exit ramps, not interacting conditions.

### Final test matrix

| Core combinations | × | Independent configurations | = | Total |
|---|---|---|---|---|
| 2^12 = 4,096 | × | 9 | = | **36,864** |

This is a 28× reduction from the naive 2^20 approach, with zero loss of
coverage. The spec runs in under 0.5 seconds.

### What the exhaustive test found

The first run discovered **1,728 disagreements**, all in the FTI branch.
Analysis revealed two related bugs in the imperative `DecisionTree`:

1. **Missing deny guard (576 cases):** When `used_for_aid_admin=true` but
   `to_school_official_legitimate_interest=false`, the PDF says deny (Box 4
   "No"), but the code fell through to the scholarship check and permitted.

2. **Wrong prerequisite (1,152 cases):** The scholarship check (Box 3, the
   Box 2 "No" path) incorrectly required `used_for_aid_admin=true`. Per the
   PDF, Box 3 is only reachable when Box 2 answers "No" (i.e., the data is
   *not* used for aid administration). With `used_for_aid_admin=false`, the
   code skipped the scholarship check entirely and denied.

The root cause was a single code block that conflated two separate branches
of the decision tree:

```ruby
# BEFORE (buggy): scholarship check nested under aid_admin guard
return true if used_for_aid_admin? && to_school_official_legitimate_interest?
if used_for_aid_admin? && disclosure_to_scholarship_org? && explicit_written_consent?
  return true
end

# AFTER (correct): explicit deny guard separates the two branches
return true if used_for_aid_admin? && to_school_official_legitimate_interest?
return false if used_for_aid_admin?  # Box 4 No → Deny
return true if disclosure_to_scholarship_org? && explicit_written_consent?
```

The YAML rules, which were verified against the canonical PDF, already encoded
this correctly via the `FTI_R2b_aid_admin_deny` deny guard. The exhaustive
test proved the YAML was right and the imperative code was wrong.

After the fix: **0 disagreements across all 36,864 combinations.**

## Scenario Library

The `nasfaa_scenarios.yml` file contains 23 named real-world scenarios — one
for every rule in the YAML. Each scenario describes a situation a financial
aid administrator would actually encounter, with the boolean inputs that
characterize it, the expected decision, the governing rule, and the
regulatory citation.

The scenario library serves three purposes:

1. **Regression tests** — each scenario is verified against both engines
   (59 specs confirm the correct rule fires with the correct result)
2. **Documentation** — the narrative descriptions explain *why* each rule
   applies, making the YAML rules human-readable
3. **Quiz seed data** — descriptions can be presented as training questions
   for financial aid staff (Phase 2 CLI)

### Scenario coverage by section

| Section | Scenarios | Result types |
|---|---|---|
| FTI Branch (IRC §6103) | 5 | 2 permit, 2 deny, 1 permit |
| FAFSA-Specific (HEA §1090/§1098h) | 7 | 5 permit, 1 permit_with_scope, 1 permit |
| FERPA Gate + 99.31 Exceptions | 10 | 8 permit, 1 permit_with_caution, 1 permit |
| Denials (no legal basis) | 1 | 1 deny |

### Example scenario

> **Court Issues Subpoena for Student Financial Aid Records**
>
> A court issues a lawfully issued subpoena requiring the university to
> produce a student's financial aid records as part of a civil proceeding.
> While the subpoena compels disclosure under FERPA §99.31(a)(9), the
> institution should consult legal counsel before responding to ensure
> compliance with the specific notification and procedural requirements of
> §99.31(a)(9)(ii), which may require reasonable effort to notify the student
> before disclosure.
>
> Inputs: `due_to_judicial_order_or_subpoena_or_financial_aid: true`
> Result: **permit_with_caution** — Rule: `FERPA_R3_judicial_or_finaid_related`
> Citation: FERPA 34 CFR §99.31(a)(9); §99.31(a)(4)(i)

## Testing

The test suite comprises 203 examples across 6 spec files:

| Spec file | Examples | Tests |
|---|---|---|
| `disclosure_data_spec.rb` | 71 | Field initialization, predicates, legacy mapping |
| `nasfaa_data_sharing_decision_tree_spec.rb` | 41 | Imperative decision tree, box-by-box |
| `rule_engine_spec.rb` | 17 | YAML engine, cross-engine agreement |
| `trace_spec.rb` | 14 | Audit trail struct, RuleEngine integration |
| `exhaustive_verification_spec.rb` | 1 | 36,864 input combinations, 0 disagreements |
| `scenario_spec.rb` | 59 | All 23 scenarios, rule coverage, metadata integrity |

```bash
bundle install
bundle exec rspec          # 203 examples, 0 failures (<1 second)
bundle exec rubocop        # 0 offenses
bundle exec rake           # runs both spec and rubocop
```

## Legal References

- **FTI**: Internal Revenue Code §6103 (tax return information)
- **FAFSA**: Higher Education Act §1090(a), §1098h (FAFSA data sharing)
- **FERPA**: 20 USC §1232g; 34 CFR Part 99 (student education records)
- **FERPA consent**: 34 CFR §99.30 (prior written consent)
- **FERPA exceptions**: 34 CFR §99.31(a)(1)–(a)(16)
- **Canonical source**: [NASFAA Data Sharing Decision Tree](docs/NASFAA_Data_Sharing_Decision_Tree.pdf)

## Time Spent (from commit history)

Method: group consecutive commits into sessions when the gap between commits
is ≤ 60 minutes; session duration = last_commit_time − first_commit_time.
Larger gaps start a new session. This approximates active work time without
counting idle/overnight gaps.

| Date       | Start    | End      | Commits | Duration |
|------------|----------|----------|---------|----------|
| 2025-08-26 | 15:24:07 | 18:14:28 | 8       | 2:50:21  |
| 2025-08-27 | 04:10:56 | 05:04:19 | 3       | 0:53:23  |
| 2025-09-13 | 10:29:57 | 10:29:57 | 1       | 0:00:00  |
| 2025-09-13 | 11:54:45 | 11:54:45 | 1       | 0:00:00  |
| 2025-09-13 | 16:42:26 | 17:04:20 | 2       | 0:21:54  |
| 2025-09-14 | 04:26:52 | 04:26:52 | 1       | 0:00:00  |
| 2025-09-15 | 05:25:37 | 05:25:37 | 1       | 0:00:00  |

Totals:
- Active time: 4:05:38
- Commits: 17
- Note: 0-duration commits represent time that cannot be extracted solely from the commit log.
