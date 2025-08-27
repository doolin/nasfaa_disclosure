require_relative 'disclosure_data'

class NasfaaDataSharingDecisionTree
  attr_accessor :disclosure_request

  def initialize(disclosure_request)
    @disclosure_request = disclosure_request
  end

  def disclose?
    # First check if this involves FTI - if so, use FTI branch
    return fti_disclosure_permitted? if includes_fti?

    # Otherwise, use main decision tree
    main_disclosure_permitted?
  end

  # Normalized predicate methods that directly correspond to YAML inputs

  def includes_fti?
    # Question 1: Does the disclosure include Federal Tax Information (FTI)?
    disclosure_request[:includes_fti]
  end

  def disclosure_to_student?
    # Question 2: Is the disclosure to the student?
    disclosure_request[:disclosure_to_student]
  end

  def is_fafsa_data?
    # Question 3: Is the information being requested considered FAFSA data per ED's definition?
    disclosure_request[:is_fafsa_data]
  end

  def disclosure_to_contributor_parent_or_spouse?
    # Question 4: Is the disclosure to the student's parent or spouse contributor to the FAFSA?
    disclosure_request[:disclosure_to_contributor_parent_or_spouse]
  end

  def used_for_aid_admin?
    # Question 5: Will the information be used for the application, award, and/or administration of financial aid?
    disclosure_request[:used_for_aid_admin]
  end

  def disclosure_to_scholarship_org?
    # Question 6: Is the disclosure to a scholarship granting organization, tribal organization, or other organization
    # assisting the applicant in applying for and receiving federal, state, local, or tribal financial assistance?
    disclosure_request[:disclosure_to_scholarship_org]
  end

  def explicit_written_consent?
    # Question 6b: Has the student provided explicit written consent for scholarship organization disclosure?
    disclosure_request[:explicit_written_consent]
  end

  def research_promote_attendance?
    # Question 7: Is the disclosure for research by or on behalf of the institution to promote college attendance, persistence, and completion?
    disclosure_request[:research_promote_attendance]
  end

  def hea_written_consent?
    # Question 8: Has the student provided written consent for disclosure under the Higher Education Act (HEA)?
    disclosure_request[:hea_written_consent]
  end

  def contains_pii?
    # Question 9: Does the disclosure contain personally identifiable information (PII)?
    disclosure_request[:contains_pii]
  end

  def ferpa_written_consent?
    # Question 10: Has the student provided written consent for disclosure under FERPA?
    disclosure_request[:ferpa_written_consent]
  end

  def directory_info_and_not_opted_out?
    # Question 11: Is the information being requested considered directory information (if the student hasn't opted out)?
    disclosure_request[:directory_info_and_not_opted_out]
  end

  def to_school_official_legitimate_interest?
    # Question 12: Is the disclosure to other school officials determined to have a legitimate educational interest?
    disclosure_request[:to_school_official_legitimate_interest]
  end

  def due_to_judicial_order_or_subpoena_or_financial_aid?
    # Question 13: Is the information being requested as a result of a judicial order or subpoena,
    # or in relation to financial aid for which the student has applied or received?
    disclosure_request[:due_to_judicial_order_or_subpoena_or_financial_aid]
  end

  def to_other_school_enrollment_transfer?
    # Question 14: Is the disclosure to officials of another school where the student seeks or intends to enroll,
    # or where the student is already enrolled for purposes related to the student's enrollment or transfer?
    disclosure_request[:to_other_school_enrollment_transfer]
  end

  def to_authorized_representatives?
    # Question 15: Is the disclosure to authorized representatives of the Comptroller General, Attorney General,
    # Secretary, or state and local educational authorities?
    disclosure_request[:to_authorized_representatives]
  end

  def to_research_org_ferpa?
    # Question 16: Is the disclosure to an organization conducting research for, or on behalf of, your institution to:
    # (A) Develop, validate, or administer predictive tests; (B) Administer student aid programs; or (C) Improve instruction?
    disclosure_request[:to_research_org_ferpa]
  end

  def to_accrediting_agency?
    # Question 17: Is the disclosure to an accrediting agency to carry out their accrediting functions?
    disclosure_request[:to_accrediting_agency]
  end

  def parent_of_dependent_student?
    # Question 18: Is the disclosure to the parent of a dependent student, as defined in section 152 of the Internal Revenue Code?
    disclosure_request[:parent_of_dependent_student]
  end

  def otherwise_permitted_under_99_31?
    # Question 19: Is the disclosure otherwise permitted under 99.31?
    disclosure_request[:otherwise_permitted_under_99_31]
  end

  def box10?
    !disclosure_to_student? && !is_fafsa_data? && ferpa_written_consent?
  end

  private

  def fti_disclosure_permitted?
    # FTI Branch Logic (Page 2)
    return true if disclosure_to_student?
    return true if used_for_aid_admin?
    return true if disclosure_to_scholarship_org? && explicit_written_consent?
    return true if to_school_official_legitimate_interest?

    false
  end

  def main_disclosure_permitted?
    # Main Decision Tree Logic (Page 1)
    # Follow the actual decision tree flow from the PDF

    # Box 2: Is disclosure to student?
    return true if disclosure_to_student?

    return true if box10?

    # Box 4: Is disclosure to parent/spouse contributor? (applies to all non-FTI data)
    return true if disclosure_to_contributor_parent_or_spouse?

    # Box 3: Is it FAFSA data?
    if is_fafsa_data?
      # Box 5: Is it for financial aid purposes?
      return true if used_for_aid_admin?

      # Box 6: Is it to scholarship/tribal organization with consent?
      return true if disclosure_to_scholarship_org? && explicit_written_consent?

      # Box 7: Is it for research promoting college attendance?
      return true if research_promote_attendance?

      # Box 8: Has HEA consent?
      return true if hea_written_consent?

      # Box 9: Contains PII?
      if contains_pii?
        # Box 10: Has FERPA consent?
        return true if ferpa_written_consent?

        # Box 11: Is directory information?
        return true if directory_info_and_not_opted_out?

        # Box 12: To school officials with educational interest?
        return true if to_school_official_legitimate_interest?

        # Box 13: Judicial order or financial aid related?
        return true if due_to_judicial_order_or_subpoena_or_financial_aid?

        # Box 14: To other school for enrollment?
        return true if to_other_school_enrollment_transfer?

        # Box 15: To authorized federal representatives?
        return true if to_authorized_representatives?

        # Box 16: To research organization?
        return true if to_research_org_ferpa?

        # Box 17: To accrediting agency?
        return true if to_accrediting_agency?

        # Box 18: To parent of dependent student?
        return true if parent_of_dependent_student?

        # Box 19: Otherwise permitted under 99.31?
        return true if otherwise_permitted_under_99_31?
      end
    else
      # Box 3 "No" → Box 10: Has FERPA consent? (skip Box 9 PII check for non-FAFSA data)
      return true if ferpa_written_consent?

      # Box 11: Is directory information?
      return true if directory_info_and_not_opted_out?

      # Box 12: To school officials with educational interest?
      return true if to_school_official_legitimate_interest?

      # Box 13: Judicial order or financial aid related?
      return true if due_to_judicial_order_or_subpoena_or_financial_aid?

      # Box 14: To other school for enrollment?
      return true if to_other_school_enrollment_transfer?

      # Box 15: To authorized federal representatives?
      return true if to_authorized_representatives?

      # Box 16: To research organization?
      return true if to_research_org_ferpa?

      # Box 17: To accrediting agency?
      return true if to_accrediting_agency?

      # Box 18: To parent of dependent student?
      return true if parent_of_dependent_student?

      # Box 19: Otherwise permitted under 99.31?
      return true if otherwise_permitted_under_99_31?
    end

    false
  end
end
