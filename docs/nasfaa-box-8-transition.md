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

## Appendix: Investigation Method (Detailed)

This appendix records exactly how the transition error was identified, including tool
use, image extraction steps, and how each extracted image was interpreted.

### Why a visual method was required

The NASFAA artifact is titled as a "tree" but functions as a DAG with crossing edges.
Text extraction alone does not preserve edge geometry, so label adjacency (`Yes`/`No`)
can be misread. For transition validation, we traced rendered arrows and connectors,
not just node text.

### Tool use

1. **Read source images directly**
   - Used `ReadFile` on:
     - `docs/nasfaa-2025-page-1.png`
     - `docs/nasfaa-2025-page-2.png`
   - Purpose: establish baseline visual understanding of global flow.

2. **Generate focused crops and coordinate aids**
   - Used `Shell` with Python/Pillow scripts to create derivative inspection images.
   - Purpose: isolate ambiguous zones (Boxes 7/8/9 and nearby crossing edges).

3. **Cross-check implementation graph**
   - Compared observed PDF edges against:
     - `nasfaa_questions.yml`
     - `nasfaa_rules.yml`
     - `lib/nasfaa/decision_tree.rb`
   - Purpose: determine whether mismatch is edge destination, branch inversion, or terminal-vs-fallthrough.

### Image extraction commands (exact workflow)

First-pass targeted zooms:

```shell
python - <<'PY'
from PIL import Image
img=Image.open('/Users/daviddoolin/src/nasfaa/docs/nasfaa-2025-page-1.png')
c1=img.crop((430,140,790,470)).resize((720,660))
c1.save('/Users/daviddoolin/src/nasfaa/docs/page1-box7-8-9-zoom.png')
c2=img.crop((180,180,600,560)).resize((840,760))
c2.save('/Users/daviddoolin/src/nasfaa/docs/page1-box4-5-10-12-zoom.png')
PY
```

Coordinate grid overlay for orientation:

```shell
python - <<'PY'
from PIL import Image, ImageDraw
img=Image.open('/Users/daviddoolin/src/nasfaa/docs/nasfaa-2025-page-1.png')
canvas=img.copy()
d=ImageDraw.Draw(canvas)
for x in range(0, img.width, 200):
    d.line((x,0,x,img.height), fill=(255,0,0), width=2)
    d.text((x+5,5), str(x), fill=(255,0,0))
for y in range(0, img.height, 200):
    d.line((0,y,img.width,y), fill=(255,0,0), width=2)
    d.text((5,y+5), str(y), fill=(255,0,0))
canvas.save('/Users/daviddoolin/src/nasfaa/docs/page1-grid.png')
PY
```

Second-pass higher-resolution crops in ambiguous regions:

```shell
python - <<'PY'
from PIL import Image
img=Image.open('/Users/daviddoolin/src/nasfaa/docs/nasfaa-2025-page-1.png')
img.crop((950,420,1676,1180)).resize((1452,1520)).save('/Users/daviddoolin/src/nasfaa/docs/box7-8-9-zoom2.png')
img.crop((420,500,1300,1200)).resize((1760,1400)).save('/Users/daviddoolin/src/nasfaa/docs/box4-5-10-11-12-zoom2.png')
img.crop((900,900,1676,1550)).resize((1552,1300)).save('/Users/daviddoolin/src/nasfaa/docs/box12-13-14-zoom2.png')
img.crop((1080,260,1676,1100)).resize((1192,1680)).save('/Users/daviddoolin/src/nasfaa/docs/box9-right-context-zoom.png')
PY
```

### Image evidence and how each was used

Source references:
- `docs/nasfaa-2025-page-1.png` — full-page DAG context on non-FTI side
- `docs/nasfaa-2025-page-2.png` — FTI branch sanity check

Extracted inspection images:
- `docs/page1-grid.png`
  - Used to reference approximate coordinates and ensure crops covered full connector segments.
- `docs/page1-box7-8-9-zoom.png`
  - First pass on Box 7/8/9 area; too tight for reliable full connector tracing.
- `docs/page1-box4-5-10-12-zoom.png`
  - First pass on Box 4/5/10/11/12 region; used for orientation and branch context.
- `docs/box7-8-9-zoom2.png`
  - Primary evidence for Box 7 and Box 8 branches.
  - Showed Box 7 `Yes` feeding up/right into Box 9 and Box 7 `No` dropping into Box 8.
  - Showed Box 8 `No` dropping into the gray "Disclosure Not Permitted (Review ...)" node.
- `docs/box4-5-10-11-12-zoom2.png`
  - Verified neighboring branch topology to avoid misattributing crossing connectors.
- `docs/box12-13-14-zoom2.png`
  - Used to inspect downstream continuation patterns and reduce false positives from nearby lines.
- `docs/box9-right-context-zoom.png`
  - Highest-confidence local evidence around Box 9 and Box 8 terminals.
  - Confirmed Box 8 `No` branch terminates at gray node in rendered geometry.

### Step-by-step determination

1. Start from full page (`nasfaa-2025-page-1.png`) to map the local neighborhood
   around Boxes 7/8/9 and identify likely crossing points.
2. Use `page1-grid.png` to define larger crop windows that preserve connector context.
3. Inspect `box7-8-9-zoom2.png` and `box9-right-context-zoom.png` together:
   - Box 7 `Yes` branch is routed to Box 9.
   - Box 7 `No` branch drops to Box 8.
   - Box 8 `No` branch drops to gray terminal text block (not to Box 9).
4. Use `box4-5-10-11-12-zoom2.png` and `box12-13-14-zoom2.png` to ensure nearby
   connectors were not being visually conflated with Box 8 branches.
5. Compare observed transitions to current DAG:
   - `fafsa_research` transitions appear aligned with PDF rendering.
   - `fafsa_hea_consent.on_no` appears to be the likely mismatched transition.

### Confidence and caveat

- Confidence is high for the geometric reading of Box 8 `No` -> gray terminal.
- The plan still marks implementation as "needs discussion" because semantic mapping
  of the gray terminal into current result taxonomy (`deny` vs. specialized result)
  requires a project-level decision.
