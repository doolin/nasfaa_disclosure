# frozen_string_literal: true

class DisclosureData
  attr_accessor :includes_fti, :disclosure_to_student, :disclosure_to_contributor_parent_or_spouse,
                :is_fafsa_data, :used_for_aid_admin, :disclosure_to_scholarship_org,
                :explicit_written_consent, :research_promote_attendance, :hea_written_consent,
                :ferpa_written_consent, :directory_info_and_not_opted_out, :to_school_official_legitimate_interest,
                :due_to_judicial_order_or_subpoena_or_financial_aid, :to_other_school_enrollment_transfer,
                :to_authorized_representatives, :to_research_org_ferpa, :to_accrediting_agency,
                :parent_of_dependent_student, :otherwise_permitted_under_99_31, :contains_pii

  def initialize(data = {})
    # Initialize all boolean fields with defaults
    @includes_fti = data[:includes_fti] || false
    @disclosure_to_student = data[:disclosure_to_student] || false
    @disclosure_to_contributor_parent_or_spouse = data[:disclosure_to_contributor_parent_or_spouse] || false
    @is_fafsa_data = data[:is_fafsa_data] || false
    @used_for_aid_admin = data[:used_for_aid_admin] || false
    @disclosure_to_scholarship_org = data[:disclosure_to_scholarship_org] || false
    @explicit_written_consent = data[:explicit_written_consent] || false
    @research_promote_attendance = data[:research_promote_attendance] || false
    @hea_written_consent = data[:hea_written_consent] || false
    @ferpa_written_consent = data[:ferpa_written_consent] || false
    @directory_info_and_not_opted_out = data[:directory_info_and_not_opted_out] || false
    @to_school_official_legitimate_interest = data[:to_school_official_legitimate_interest] || false
    @due_to_judicial_order_or_subpoena_or_financial_aid = data[:due_to_judicial_order_or_subpoena_or_financial_aid] || false
    @to_other_school_enrollment_transfer = data[:to_other_school_enrollment_transfer] || false
    @to_authorized_representatives = data[:to_authorized_representatives] || false
    @to_research_org_ferpa = data[:to_research_org_ferpa] || false
    @to_accrediting_agency = data[:to_accrediting_agency] || false
    @parent_of_dependent_student = data[:parent_of_dependent_student] || false
    @otherwise_permitted_under_99_31 = data[:otherwise_permitted_under_99_31] || false
    @contains_pii = data[:contains_pii] || false

    # Legacy support for old data structure
    setup_legacy_mapping(data)
  end

  def [](key)
    case key
    when :includes_fti
      @includes_fti
    when :disclosure_to_student
      @disclosure_to_student
    when :disclosure_to_contributor_parent_or_spouse
      @disclosure_to_contributor_parent_or_spouse
    when :is_fafsa_data
      @is_fafsa_data
    when :used_for_aid_admin
      @used_for_aid_admin
    when :disclosure_to_scholarship_org
      @disclosure_to_scholarship_org
    when :explicit_written_consent
      @explicit_written_consent
    when :research_promote_attendance
      @research_promote_attendance
    when :hea_written_consent
      @hea_written_consent
    when :ferpa_written_consent
      @ferpa_written_consent
    when :directory_info_and_not_opted_out
      @directory_info_and_not_opted_out
    when :to_school_official_legitimate_interest
      @to_school_official_legitimate_interest
    when :due_to_judicial_order_or_subpoena_or_financial_aid
      @due_to_judicial_order_or_subpoena_or_financial_aid
    when :to_other_school_enrollment_transfer
      @to_other_school_enrollment_transfer
    when :to_authorized_representatives
      @to_authorized_representatives
    when :to_research_org_ferpa
      @to_research_org_ferpa
    when :to_accrediting_agency
      @to_accrediting_agency
    when :parent_of_dependent_student
      @parent_of_dependent_student
    when :otherwise_permitted_under_99_31
      @otherwise_permitted_under_99_31
    when :contains_pii
      @contains_pii
    else
      false
    end
  end

  private

  def setup_legacy_mapping(data)
    # Map legacy complex data structure to normalized boolean fields
    if data[:recipient_type]
      case data[:recipient_type]
      when :student
        @disclosure_to_student = true
      when :parent_contributor, :spouse_contributor
        @disclosure_to_contributor_parent_or_spouse = true
      when :scholarship_organization, :tribal_organization
        @disclosure_to_scholarship_org = true
      when :school_official
        @to_school_official_legitimate_interest = true if data[:has_educational_interest]
      when :other_school
        @to_other_school_enrollment_transfer = true if data[:purpose] == :enrollment_or_transfer
      when :federal_representative, :state_local_authority
        @to_authorized_representatives = true
      when :research_organization
        @to_research_org_ferpa = true if research_purpose_valid?(data[:research_purpose])
      when :accrediting_agency
        @to_accrediting_agency = true
      when :parent
        @parent_of_dependent_student = true if data[:student_dependency_status] == :dependent
      end
    end

    if data[:data_type]
      case data[:data_type]
      when :fafsa_data
        @is_fafsa_data = true
      when :directory_information
        @directory_info_and_not_opted_out = true
      end
    end

    if data[:purpose]
      case data[:purpose]
      when :financial_aid
        @used_for_aid_admin = true
      when :research_college_attendance
        @research_promote_attendance = true
      when :financial_aid_related
        @due_to_judicial_order_or_subpoena_or_financial_aid = true
      end
    end

    if data[:consent]
      @hea_written_consent = true if data[:consent][:hea]
      @ferpa_written_consent = true if data[:consent][:ferpa]
      @explicit_written_consent = true if data[:consent][:explicit_written]
    end

    if data[:legal_basis]
      case data[:legal_basis]
      when :judicial_order, :subpoena
        @due_to_judicial_order_or_subpoena_or_financial_aid = true
      end
    end

    @contains_pii = data[:contains_pii] if data.key?(:contains_pii)
    @otherwise_permitted_under_99_31 = data[:other_99_31_exception] if data.key?(:other_99_31_exception)
  end

  def research_purpose_valid?(purpose)
    %i[predictive_tests student_aid_programs improve_instruction].include?(purpose)
  end
end
