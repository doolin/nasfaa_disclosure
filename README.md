# NASFAA Data Sharing Decision Tree

This repository contains a Ruby implementation of the NASFAA Data Sharing Decision Tree, which helps determine when student data can be disclosed under FERPA and other applicable regulations.

## Overview

The decision tree is implemented as a Ruby class that evaluates disclosure requests against a comprehensive set of rules defined in YAML format. The system supports both Federal Tax Information (FTI) and non-FTI data disclosure scenarios.

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

- **97 test examples** covering all predicate methods and decision paths
- **Box-by-box testing** with comments indicating decision tree boxes
- **Legacy compatibility tests** ensuring backward compatibility
- **Edge case coverage** for all decision tree branches

Run tests with:
```bash
rspec
```

## Key Features

- **Normalized Structure**: All inputs are boolean, directly mapping to YAML rules
- **Backward Compatibility**: Legacy data structure still supported
- **Comprehensive Testing**: Full coverage of decision tree logic
- **Clear Documentation**: YAML rules with metadata and validation
- **Maintainable Code**: Clean, readable implementation following decision tree flow

## Legal References

The implementation references:
- Family Educational Rights and Privacy Act (FERPA)
- Higher Education Act (HEA) Sections 1090 and 1098h
- Internal Revenue Code Section 152
- FERPA 99.31 exceptions
- Federal Tax Information (FTI) regulations
