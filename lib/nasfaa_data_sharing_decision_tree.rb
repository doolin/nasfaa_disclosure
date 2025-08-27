# frozen_string_literal: true

require_relative 'disclosure_data'

class NasfaaDataSharingDecisionTree
  attr_accessor :disclosure_request

  def initialize(disclosure_request)
    @disclosure_request = disclosure_request
  end

  def disclose?
    # First check if this involves FTI - if so, use FTI branch
    return fti_disclosure_permitted? if disclosure_request.includes_fti?

    # Otherwise, use main decision tree
    main_disclosure_permitted?
  end

  def box10?
    !disclosure_request.disclosure_to_student? && !disclosure_request.fafsa_data? && disclosure_request.ferpa_written_consent?
  end

  # Box 10 is "No".
  def box11?
    disclosure_request.directory_info_and_not_opted_out?
  end

  private

  def fti_disclosure_permitted?
    # FTI Branch Logic (Page 2)
    return true if disclosure_request.disclosure_to_student?
    return true if disclosure_request.used_for_aid_admin?
    return true if disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?
    return true if disclosure_request.to_school_official_legitimate_interest?

    false
  end

  def main_disclosure_permitted?
    # Main Decision Tree Logic (Page 1)
    # Follow the actual decision tree flow from the PDF

    # Box 2: Is disclosure to student?
    return true if disclosure_request.disclosure_to_student?

    # Box 4: Is disclosure to parent/spouse contributor? (applies to all non-FTI data)
    return true if disclosure_request.disclosure_to_contributor_parent_or_spouse?

    # Box 3: Is it FAFSA data?
    if disclosure_request.fafsa_data?
      # Box 5: Is it for financial aid purposes?
      return true if disclosure_request.used_for_aid_admin?

      # Box 6: Is it to scholarship/tribal organization with consent?
      return true if disclosure_request.disclosure_to_scholarship_org? && disclosure_request.explicit_written_consent?

      # Box 7: Is it for research promoting college attendance?
      return true if disclosure_request.research_promote_attendance?

      # Box 8: Has HEA consent?
      return true if disclosure_request.hea_written_consent?

      # Box 9: Contains PII?
      if disclosure_request.contains_pii?
        # Box 10: Has FERPA consent?
        return true if disclosure_request.ferpa_written_consent?

        # Box 11: Is directory information?
        return true if disclosure_request.directory_info_and_not_opted_out?

        # Box 12: To school officials with educational interest?
        return true if disclosure_request.to_school_official_legitimate_interest?

        # Box 13: Judicial order or financial aid related?
        return true if disclosure_request.due_to_judicial_order_or_subpoena_or_financial_aid?

        # Box 14: To other school for enrollment?
        return true if disclosure_request.to_other_school_enrollment_transfer?

        # Box 15: To authorized federal representatives?
        return true if disclosure_request.to_authorized_representatives?

        # Box 16: To research organization?
        return true if disclosure_request.to_research_org_ferpa?

        # Box 17: To accrediting agency?
        return true if disclosure_request.to_accrediting_agency?

        # Box 18: To parent of dependent student?
        return true if disclosure_request.parent_of_dependent_student?

        # Box 19: Otherwise permitted under 99.31?
        return true if disclosure_request.otherwise_permitted_under_99_31?
      end
    else
      # Box 3 "No" → Box 10: Has FERPA consent? (skip Box 9 PII check for non-FAFSA data)
      return true if disclosure_request.ferpa_written_consent?
      return true if box10?
      return true if box11?

      # # Box 11: Is directory information?
      # return true if directory_info_and_not_opted_out?

      # Box 12: To school officials with educational interest?
      return true if disclosure_request.to_school_official_legitimate_interest?

      # Box 13: Judicial order or financial aid related?
      return true if disclosure_request.due_to_judicial_order_or_subpoena_or_financial_aid?

      # Box 14: To other school for enrollment?
      return true if disclosure_request.to_other_school_enrollment_transfer?

      # Box 15: To authorized federal representatives?
      return true if disclosure_request.to_authorized_representatives?

      # Box 16: To research organization?
      return true if disclosure_request.to_research_org_ferpa?

      # Box 17: To accrediting agency?
      return true if disclosure_request.to_accrediting_agency?

      # Box 18: To parent of dependent student?
      return true if disclosure_request.parent_of_dependent_student?

      # Box 19: Otherwise permitted under 99.31?
      return true if disclosure_request.otherwise_permitted_under_99_31?
    end

    false
  end
end
