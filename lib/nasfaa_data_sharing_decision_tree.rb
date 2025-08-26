require_relative 'disclosure_data'

class NasfaaDataSharingDecisionTree
  attr_accessor :disclosure_request

  def initialize(disclosure_request)
    @disclosure_request = disclosure_request
  end

  def disclose?
    # First check if this involves FTI - if so, use FTI branch
    return fti_disclosure_permitted? if includes_federal_tax_information?

    # Otherwise, use main decision tree
    main_disclosure_permitted?
  end

  # Page 1 - Main Decision Tree Predicates

  def includes_federal_tax_information?
    # Question 1: Does the disclosure include Federal Tax Information (FTI)?
    disclosure_request[:includes_fti]
  end

  def disclosure_to_student?
    # Question 2: Is the disclosure to the student?
    disclosure_request[:recipient_type] == :student
  end

  def is_fafsa_data?
    # Question 3: Is the information being requested considered FAFSA data per ED's definition?
    disclosure_request[:data_type] == :fafsa_data
  end

  def disclosure_to_parent_or_spouse_contributor?
    # Question 4: Is the disclosure to the student's parent or spouse contributor to the FAFSA?
    %i[parent_contributor spouse_contributor].include?(disclosure_request[:recipient_type])
  end

  def for_financial_aid_purposes?
    # Question 5: Will the information be used for the application, award, and/or administration of financial aid?
    disclosure_request[:purpose] == :financial_aid
  end

  def to_scholarship_or_tribal_organization_with_consent?
    # Question 6: Is the disclosure to a scholarship granting organization, tribal organization, or other organization
    # assisting the applicant in applying for and receiving federal, state, local, or tribal financial assistance?
    %i[scholarship_organization tribal_organization].include?(disclosure_request[:recipient_type])
  end

  def for_research_promoting_college_attendance?
    # Question 7: Is the disclosure for research by or on behalf of the institution to promote college attendance, persistence, and completion?
    disclosure_request[:purpose] == :research_college_attendance
  end

  def has_hea_consent?
    # Question 8: Has the student provided written consent for disclosure under the Higher Education Act (HEA)?
    disclosure_request[:consent][:hea]
  end

  def contains_pii?
    # Question 9: Does the disclosure contain personally identifiable information (PII)?
    disclosure_request[:contains_pii]
  end

  def has_ferpa_consent?
    # Question 10: Has the student provided written consent for disclosure under FERPA?
    disclosure_request[:consent][:ferpa]
  end

  def is_directory_information?
    # Question 11: Is the information being requested considered directory information (if the student hasn't opted out)?
    disclosure_request[:data_type] == :directory_information
  end

  def to_school_officials_with_educational_interest?
    # Question 12: Is the disclosure to other school officials determined to have a legitimate educational interest?
    disclosure_request[:recipient_type] == :school_official &&
      disclosure_request[:has_educational_interest]
  end

  def judicial_order_or_financial_aid_related?
    # Question 13: Is the information being requested as a result of a judicial order or subpoena,
    # or in relation to financial aid for which the student has applied or received?
    %i[judicial_order subpoena].include?(disclosure_request[:legal_basis]) ||
      disclosure_request[:purpose] == :financial_aid_related
  end

  def to_other_school_for_enrollment?
    # Question 14: Is the disclosure to officials of another school where the student seeks or intends to enroll,
    # or where the student is already enrolled for purposes related to the student's enrollment or transfer?
    disclosure_request[:recipient_type] == :other_school &&
      disclosure_request[:purpose] == :enrollment_or_transfer
  end

  def to_authorized_federal_representatives?
    # Question 15: Is the disclosure to authorized representatives of the Comptroller General, Attorney General,
    # Secretary, or state and local educational authorities?
    %i[federal_representative state_local_authority].include?(disclosure_request[:recipient_type])
  end

  def to_research_organization?
    # Question 16: Is the disclosure to an organization conducting research for, or on behalf of, your institution to:
    # (A) Develop, validate, or administer predictive tests; (B) Administer student aid programs; or (C) Improve instruction?
    disclosure_request[:recipient_type] == :research_organization &&
      disclosure_request[:research_purpose] == :predictive_tests ||
      disclosure_request[:research_purpose] == :student_aid_programs ||
      disclosure_request[:research_purpose] == :improve_instruction
  end

  def to_accrediting_agency?
    # Question 17: Is the disclosure to an accrediting agency to carry out their accrediting functions?
    disclosure_request[:recipient_type] == :accrediting_agency
  end

  def to_parent_of_dependent_student?
    # Question 18: Is the disclosure to the parent of a dependent student, as defined in section 152 of the Internal Revenue Code?
    disclosure_request[:recipient_type] == :parent &&
      disclosure_request[:student_dependency_status] == :dependent
  end

  def otherwise_permitted_under_99_31?
    # Question 19: Is the disclosure otherwise permitted under 99.31?
    disclosure_request[:other_99_31_exception]
  end

  # Page 2 - FTI Branch Predicates

  def fti_disclosure_to_student?
    # FTI Question 1: Is the disclosure to the student?
    disclosure_request[:recipient_type] == :student
  end

  def fti_for_financial_aid_purposes?
    # FTI Question 2: Will the information be used for the application, award, or administration of financial aid?
    disclosure_request[:purpose] == :financial_aid
  end

  def fti_to_scholarship_organization_with_consent?
    # FTI Question 3: Is the disclosure to a scholarship granting organization, tribal organization, or other organization
    # assisting the applicant in applying for and receiving federal, state, local, or tribal financial assistance,
    # and has the student provided explicit written consent?
    %i[scholarship_organization tribal_organization].include?(disclosure_request[:recipient_type]) &&
      disclosure_request[:consent][:explicit_written]
  end

  def fti_to_school_officials_with_educational_interest?
    # FTI Question 4: Is the disclosure to other school officials determined to have a legitimate educational interest?
    disclosure_request[:recipient_type] == :school_official &&
      disclosure_request[:has_educational_interest]
  end

  private

  def fti_disclosure_permitted?
    # FTI Branch Logic (Page 2)
    return true if fti_disclosure_to_student?
    return true if fti_for_financial_aid_purposes?
    return true if fti_to_scholarship_organization_with_consent?
    return true if fti_to_school_officials_with_educational_interest?

    false
  end

  def main_disclosure_permitted?
    # Main Decision Tree Logic (Page 1)
    # Follow the actual decision tree flow from the PDF

    # Box 2: Is disclosure to student?
    return true if disclosure_to_student?

    # Box 3: Is it FAFSA data?
    if is_fafsa_data?
      # Box 4: Is disclosure to parent/spouse contributor?
      return true if disclosure_to_parent_or_spouse_contributor?

      # Box 5: Is it for financial aid purposes?
      return true if for_financial_aid_purposes?

      # Box 6: Is it to scholarship/tribal organization with consent?
      return true if to_scholarship_or_tribal_organization_with_consent?

      # Box 7: Is it for research promoting college attendance?
      return true if for_research_promoting_college_attendance?

      # Box 8: Has HEA consent?
      return true if has_hea_consent?

      # Box 9: Contains PII?
      if contains_pii?
        # Box 10: Has FERPA consent?
        return true if has_ferpa_consent?

        # Box 11: Is directory information?
        return true if is_directory_information?

        # Box 12: To school officials with educational interest?
        return true if to_school_officials_with_educational_interest?

        # Box 13: Judicial order or financial aid related?
        return true if judicial_order_or_financial_aid_related?

        # Box 14: To other school for enrollment?
        return true if to_other_school_for_enrollment?

        # Box 15: To authorized federal representatives?
        return true if to_authorized_federal_representatives?

        # Box 16: To research organization?
        return true if to_research_organization?

        # Box 17: To accrediting agency?
        return true if to_accrediting_agency?

        # Box 18: To parent of dependent student?
        return true if to_parent_of_dependent_student?

        # Box 19: Otherwise permitted under 99.31?
        return true if otherwise_permitted_under_99_31?
      end
    end

    # If not FAFSA data, check if it's directory information
    return true if is_directory_information?

    false
  end
end
