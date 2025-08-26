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
# Create a disclosure request hash
disclosure_request = {
  includes_fti: false,
  recipient_type: :student,
  data_type: :fafsa_data,
  purpose: :financial_aid,
  consent: { hea: false, ferpa: false },
  contains_pii: true
}

# Instantiate the decision tree
tree = NasfaaDataSharingDecisionTree.new(disclosure_request)

# Check specific conditions
tree.disclosure_to_student?                    # => true
tree.is_fafsa_data?                           # => true
tree.for_financial_aid_purposes?              # => true
tree.has_hea_consent?                         # => false
```

## Testing

Run the test suite with:

```bash
rspec spec/nasfaa_data_sharing_decision_tree_spec.rb
```

All 59 predicate functions are thoroughly tested with both positive and negative scenarios.

## Legal Basis

The implementation references specific sections of federal law including:
- 1098h(c)(1) - FUTURE Act provisions
- 1090(a)(3)(C) - Higher Education Act  
- 99.30-99.31 - FERPA regulations
- Section 152 of the Internal Revenue Code

## Next Steps

This is the first step in implementing the complete decision tree. Future steps will include:
- Implementing the complete decision flow logic
- Adding outcome determination methods
- Creating a user-friendly interface
- Adding validation and error handling
