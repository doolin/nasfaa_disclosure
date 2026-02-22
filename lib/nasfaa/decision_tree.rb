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

      # Box 1: Does the disclosure include Federal Tax Information (FTI)?
      if disclosure_request.includes_fti?
        # Box 2: Will the information be used for financial aid by a legitimate interest?
        # Yes branch to Box 4
        return true if disclosure_request.used_for_aid_admin? && disclosure_request.to_school_official_legitimate_interest?

        # Box 2: Is the disclosure to scholarship org with written consent?
        if disclosure_request.used_for_aid_admin? && disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?
          return true
        end
      else # disclosure does not include FTI
        # Main Branch (Page 1)
        # Box 2: Is the disclosure to the student? Handled above.

        # Box 3: Is it FAFSA data?
        if disclosure_request.fafsa_data?
          # Box 4: Is the disclosure to parent/spouse contributor?
          return true if disclosure_request.disclosure_to_contributor_parent_or_spouse?

          # Box 5: Will it be used for financial aid?
          return true if disclosure_request.used_for_aid_admin?

          # Box 6: Is it to scholarship org with consent?
          return true if disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?

          # Box 7: Is it for research promoting attendance?
          return true if disclosure_request.research_promote_attendance?

          # Box 8: Has HEA consent?
          return true if disclosure_request.hea_written_consent?

          # Box 9: Contains PII?
          # No PII → Disclosure Permitted; Yes PII → continue to Box 10
          return true unless disclosure_request.contains_pii?
          # Box 10: Has FERPA consent?
          return true if disclosure_request.ferpa_written_consent?

          # Check FERPA 99.31 exceptions (Boxes 11-19)

        elsif disclosure_request.ferpa_written_consent?
          # Box 3 "No" → Box 10: Has FERPA consent?
          return true

          # Check FERPA 99.31 exceptions (Boxes 11-19)

        end
        return true if ferpa_99_31_exceptions_apply?
      end
      false
    end

    private

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
