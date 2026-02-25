# frozen_string_literal: true

# Canonical table of all 22 terminal paths through the NASFAA decision DAG.
#
# compact  — y/n answers only (no trailing assertion character)
# result   — expected Trace#result symbol
#
# Assertions (p/d) are derived: permit family → 'p', deny → 'd'.
# This table is the single source of truth shared between evaluate_spec
# and evaluate_mutation_spec.
TERMINAL_PATHS = {
  'FTI_R1_student' => { compact: 'yy', result: :permit },
  'FTI_R2_aid_admin_school_official' => { compact: 'ynyy', result: :permit },
  'FTI_R2b_aid_admin_deny' => { compact: 'ynyn', result: :deny },
  'FTI_R3_scholarship_with_consent' => { compact: 'ynny', result: :permit },
  'FTI_DENY_default' => { compact: 'ynnn', result: :deny },
  'FAFSA_R1_to_student' => { compact: 'ny', result: :permit },
  'FAFSA_R3_used_for_aid_admin' => { compact: 'nnyny', result: :permit },
  'FAFSA_R4_scholarship_with_consent' => { compact: 'nnynny', result: :permit },
  'FAFSA_R6_HEA_written_consent' => { compact: 'nnynnnny', result: :permit },
  'FAFSA_R7_no_pii' => { compact: 'nnynnnnnn', result: :permit },
  'FERPA_R0_written_consent' => { compact: 'nnny', result: :permit },
  'FERPA_R1_directory_info' => { compact: 'nnnny', result: :permit },
  'FERPA_R2_school_official_LEI' => { compact: 'nnnnny', result: :permit },
  'FERPA_R3_judicial_or_finaid_related' => { compact: 'nnnnnny', result: :permit_with_caution },
  'FERPA_R4_other_school_enrollment' => { compact: 'nnnnnnny', result: :permit },
  'FERPA_R5_authorized_representatives' => { compact: 'nnnnnnnny', result: :permit },
  'FERPA_R6_research_org_predictive_tests_admin_aid_improve_instruction' \
                                                                         => { compact: 'nnnnnnnnny', result: :permit },
  'FERPA_R7_accrediting_agency' => { compact: 'nnnnnnnnnny', result: :permit },
  'FERPA_R8_parent_of_dependent_student' => { compact: 'nnnnnnnnnnny', result: :permit },
  'FERPA_R9_otherwise_permitted_99_31' => { compact: 'nnnnnnnnnnnny', result: :permit },
  'NONFTI_DENY_default' => { compact: 'nnnnnnnnnnnnn', result: :deny }
}.freeze

PERMIT_RESULTS = %i[permit permit_with_scope permit_with_caution].freeze

def assertion_char(result)
  PERMIT_RESULTS.include?(result) ? 'p' : 'd'
end
