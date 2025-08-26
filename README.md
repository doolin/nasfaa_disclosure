# NASFAA Data Sharing Decision Tree

This repository contains a Ruby implementation of the NASFAA Data Sharing Decision Tree for Postsecondary Institutions. The decision tree helps institutions determine when they can legally share student data, particularly FAFSA (Free Application for Federal Student Aid) data and Federal Tax Information (FTI).

## Implementation

The implementation is structured as a Ruby class with predicate functions for each decision box in the original PDF flowchart:

### Main Decision Tree (Page 1)
- 19 numbered decision boxes covering various scenarios for data disclosure
- Includes checks for FTI, student consent, financial aid purposes, FERPA compliance, and more

### FTI Branch (Page 2)  
- 4 specialized decision boxes for Federal Tax Information
- Stricter sharing requirements due to sensitive nature of tax data

## Usage

```ruby
# Create a disclosure request using DisclosureData
disclosure_request = DisclosureData.new({
  includes_fti: false,
  recipient_type: :student,
  data_type: :fafsa_data,
  purpose: :financial_aid,
  consent: { hea: false, ferpa: false },
  contains_pii: true
})

# Instantiate the decision tree
tree = NasfaaDataSharingDecisionTree.new(disclosure_request)

# Check specific conditions
tree.disclosure_to_student?                    # => true
tree.is_fafsa_data?                           # => true
tree.for_financial_aid_purposes?              # => true
tree.has_hea_consent?                         # => false

# Determine if disclosure is permitted
tree.disclose?                                # => true
```

## Testing

Run the test suite with:

```bash
rspec spec/nasfaa_data_sharing_decision_tree_spec.rb
```

All 83 predicate functions and the main `disclose?` method are thoroughly tested with both positive and negative scenarios.

## Legal Basis

The implementation references specific sections of federal law including:
- 1098h(c)(1) - FUTURE Act provisions
- 1090(a)(3)(C) - Higher Education Act  
- 99.30-99.31 - FERPA regulations
- Section 152 of the Internal Revenue Code

## Decision Tree Logic

The `disclose?` method implements the complete decision tree logic from the PDF:

1. **FTI Branch**: If the disclosure includes Federal Tax Information, only 4 specific conditions permit disclosure
2. **Main Branch**: For non-FTI data, the method follows the 19-box decision tree with proper branching logic
3. **FAFSA Data Path**: Most conditions require the data to be FAFSA data, with additional checks for PII
4. **Directory Information**: Directory information is permitted regardless of FAFSA data status

The implementation is clean, readable, and follows the exact flow of the original decision tree.

## Next Steps

The decision tree implementation is now complete. Future enhancements could include:
- Adding detailed reasoning for decisions
- Creating a user-friendly interface
- Adding validation and error handling
- Performance optimizations for high-volume usage
