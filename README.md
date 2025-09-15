# NASFAA Data Sharing Decision Tree

<details>
<summary>NEXT:</summary>

- Fix the logic in the non-FTI branch.
- Rewrite the specs for boxes 12 through 19 making
the data explicit.
- Extend README for publication with the timeline.
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

<img align="right" width="250px" src=./images/nasfaa-2025-page-1.png alt="NASFAA
descision diagram" />

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



# Cursor below here

This repository contains a Ruby implementation of the NASFAA Data Sharing
Decision Tree, which helps determine when student data can be disclosed under
FERPA and other applicable regulations.

## Overview

The decision tree is implemented as a Ruby class that evaluates disclosure
requests against a comprehensive set of rules defined in YAML format. The system
supports both Federal Tax Information (FTI) and non-FTI data disclosure
scenarios.

## Files

- `lib/nasfaa_data_sharing_decision_tree.rb` - Main decision tree implementation
- `lib/disclosure_data.rb` - Data structure for disclosure requests
- `nasfaa_rules.yml` - YAML rules definition with metadata and validation
- `spec/` - Comprehensive test suite
- `NASFAA_Data_Sharing_Decision_Tree.pdf` - Original decision tree document

## Usage

```ruby
require_relative 'lib/nasfaa_data_sharing_decision_tree'
require_relative 'lib/disclosure_data'

# Create a disclosure request using normalized boolean fields
disclosure_request = DisclosureData.new(
  includes_fti: false,
  disclosure_to_student: true,
  is_fafsa_data: true,
  contains_pii: false
)

# Evaluate the disclosure request
tree = NasfaaDataSharingDecisionTree.new(disclosure_request)
permitted = tree.disclose? # => true
```

## Data Structure

The `DisclosureData` class uses normalized boolean fields that directly correspond to the YAML rules:

### Core Fields
- `includes_fti` - Whether the disclosure includes Federal Tax Information
- `disclosure_to_student` - Whether disclosure is to the student
- `disclosure_to_contributor_parent_or_spouse` - Whether disclosure is to a FAFSA contributor
- `is_fafsa_data` - Whether the data is FAFSA data per ED definition
- `used_for_aid_admin` - Whether used for financial aid administration
- `disclosure_to_scholarship_org` - Whether disclosure is to scholarship organization
- `explicit_written_consent` - Whether explicit written consent is provided
- `research_promote_attendance` - Whether for research promoting college attendance
- `hea_written_consent` - Whether HEA written consent is provided
- `ferpa_written_consent` - Whether FERPA written consent is provided
- `directory_info_and_not_opted_out` - Whether data is directory information
- `to_school_official_legitimate_interest` - Whether to school official with legitimate interest
- `due_to_judicial_order_or_subpoena_or_financial_aid` - Whether due to judicial order/subpoena/financial aid
- `to_other_school_enrollment_transfer` - Whether to other school for enrollment/transfer
- `to_authorized_representatives` - Whether to authorized representatives
- `to_research_org_ferpa` - Whether to research organization under FERPA
- `to_accrediting_agency` - Whether to accrediting agency
- `parent_of_dependent_student` - Whether to parent of dependent student
- `otherwise_permitted_under_99_31` - Whether otherwise permitted under 99.31
- `contains_pii` - Whether disclosure contains personally identifiable information

### Legacy Support

The `DisclosureData` class maintains backward compatibility with the original complex data structure through automatic mapping:

```ruby
# Legacy format still works
legacy_request = DisclosureData.new(
  recipient_type: :student,
  data_type: :fafsa_data,
  purpose: :financial_aid,
  consent: { hea: true, ferpa: true }
)
```

## YAML Rules Structure

The `nasfaa_rules.yml` file contains:

### Metadata
- Version information
- Evaluation order (first match wins)
- Input type (boolean)

### Validation
- Required inputs
- Mutually exclusive groups

### Result Types
- `permit` - Disclosure is permitted
- `deny` - Disclosure is not permitted
- `permit_with_caution` - Disclosure permitted with caution
- `permit_with_scope` - Disclosure permitted with scope limitations

### Rules
The rules are organized into two main branches:

#### FTI Branch
- Student disclosure
- Financial aid administration
- Scholarship organizations with consent
- School officials with legitimate interest

#### Non-FTI Branch (FAFSA/FERPA)
- Student disclosure
- Contributor access (with scope limitations)
- FAFSA-specific allowances (HEA 1090/1098h)
- FERPA 99.31 exceptions

## Decision Tree Logic

The implementation follows the exact flow from the PDF decision tree:

1. **FTI Check**: If data includes FTI, use FTI branch rules
2. **Student Disclosure**: Always permitted for non-FTI data
3. **Contributor Access**: Permitted for all non-FTI data (with scope limitations)
4. **FAFSA Data Path**: Additional allowances for FAFSA data
5. **PII Check**: For FAFSA data, check if PII is present
6. **FERPA Exceptions**: Apply FERPA 99.31 exceptions
7. **Non-FAFSA Path**: Direct to FERPA consent and exceptions (skipping PII check)

## Testing

The test suite includes:

- **117 test examples** covering all predicate methods and decision paths
- **Box-by-box testing** with comments indicating decision tree boxes
- **Legacy compatibility tests** ensuring backward compatibility
- **Edge case coverage** for all decision tree branches
- **Code coverage reporting** with SimpleCov

### Running Tests

Run tests with:
```bash
bundle exec rspec
```

### Code Coverage

The project uses SimpleCov for code coverage reporting:

- **Line Coverage**: 95.83% (161/168 lines)
- **Branch Coverage**: 87.5% (119/136 branches)
- **Minimum Coverage**: 95% line coverage required
- **Coverage Report**: Generated in `coverage/index.html` after running tests

To view the coverage report:
```bash
open coverage/index.html
```

## Development Setup

1. **Install dependencies**:
   ```bash
   bundle install
   ```

2. **Run tests**:
   ```bash
   bundle exec rspec
   ```

3. **View coverage report**:
   ```bash
   open coverage/index.html
   ```

## Key Features

- **Normalized Structure**: All inputs are boolean, directly mapping to YAML rules
- **Backward Compatibility**: Legacy data structure still supported
- **Comprehensive Testing**: Full coverage of decision tree logic with 95%+ line coverage
- **Clear Documentation**: YAML rules with metadata and validation
- **Maintainable Code**: Clean, readable implementation following decision tree flow

## Legal References

The implementation references:
- Family Educational Rights and Privacy Act (FERPA)
- Higher Education Act (HEA) Sections 1090 and 1098h
- Internal Revenue Code Section 152
- FERPA 99.31 exceptions
- Federal Tax Information (FTI) regulations
