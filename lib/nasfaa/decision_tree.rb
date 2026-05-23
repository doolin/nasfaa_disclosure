# frozen_string_literal: true

module Nasfaa
  class DecisionTree
    attr_accessor :disclosure_request

    def initialize(disclosure_request)
      @disclosure_request = disclosure_request
    end

    def disclose?
      # Box 1&2 always disclose to the student.
      return true if disclosure_request.disclosure_to_student?

      return fti_branch_permits? if disclosure_request.includes_fti?

      non_fti_branch_permits?
    end

    private

    # Box 1 Yes (FTI). Two narrow permits: aid admin + LEI, or
    # scholarship + explicit consent. Aid admin without LEI is an
    # immediate deny; everything else falls through to deny.
    def fti_branch_permits?
      return true if disclosure_request.used_for_aid_admin? && disclosure_request.to_school_official_legitimate_interest?
      return false if disclosure_request.used_for_aid_admin?
      return true if disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?

      false
    end

    # Box 1 No (non-FTI). Splits FAFSA vs non-FAFSA.
    def non_fti_branch_permits?
      return fafsa_branch_permits? if disclosure_request.fafsa_data?
      return true if disclosure_request.ferpa_written_consent?

      ferpa_99_31_exceptions_apply?
    end

    # Box 3 Yes (FAFSA data). Always returns a terminal verdict — the
    # Box 9 Yes path runs the 99.31 chain inline rather than falling
    # through to the caller.
    def fafsa_branch_permits?
      # Box 5 Yes: aid admin → Box 12 (LEI), skipping Boxes 6/7/8/9.
      # ferpa_consent check mirrors the rule engine's flatten (FERPA_R0
      # has no !aid_admin guard, so we include it to keep engines aligned).
      if disclosure_request.used_for_aid_admin?
        return true if disclosure_request.ferpa_written_consent?

        return ferpa_99_31_exceptions_apply?
      end

      # Box 6: scholarship org with explicit written consent.
      return true if disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?

      # Box 8 Yes: HEA consent (only reached when Box 7 research = No).
      return true if !disclosure_request.research_promote_attendance? && disclosure_request.hea_written_consent?

      # Box 8 No: terminal deny (gray PDF terminal). Bypassed when
      # contributor=Yes (Box 4) or research=Yes (Box 7).
      if !disclosure_request.disclosure_to_contributor_parent_or_spouse? &&
         !disclosure_request.research_promote_attendance? &&
         !disclosure_request.hea_written_consent?
        return false
      end

      # Box 9 No (no PII): permit.
      return true unless disclosure_request.contains_pii?

      # Box 10: FERPA consent → permit. Otherwise check 99.31 exceptions.
      return true if disclosure_request.ferpa_written_consent?

      ferpa_99_31_exceptions_apply?
    end

    def ferpa_99_31_exceptions_apply?
      # Box 11: Is directory information?
      return true if disclosure_request.directory_info_and_not_opted_out?

      # Box 12: To school officials with educational interest?
      return true if disclosure_request.to_school_official_legitimate_interest?

      # Box 13: Judicial order/subpoena/financial aid related?
      return true if disclosure_request.due_to_judicial_order_or_subpoena_or_financial_aid?

      # Box 14: To other school for enrollment?
      return true if disclosure_request.to_other_school_enrollment_transfer?

      # Box 15: To authorized representatives?
      return true if disclosure_request.to_authorized_representatives?

      # Box 16: To research organization?
      return true if disclosure_request.to_research_org_ferpa?

      # Box 17: To accrediting agency?
      return true if disclosure_request.to_accrediting_agency?

      # Box 18: To parent of dependent student?
      return true if disclosure_request.parent_of_dependent_student?

      # Box 19: Otherwise permitted under 99.31?
      return true if disclosure_request.otherwise_permitted_under_99_31?

      false
    end
  end
end
