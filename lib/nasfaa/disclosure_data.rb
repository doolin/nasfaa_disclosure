# frozen_string_literal: true

module Nasfaa
  class DisclosureData
    attr_accessor :includes_fti, :disclosure_to_student, :disclosure_to_contributor_parent_or_spouse,
                  :is_fafsa_data, :used_for_aid_admin, :disclosure_to_scholarship_org,
                  :explicit_written_consent, :research_promote_attendance, :hea_written_consent,
                  :ferpa_written_consent, :directory_info_and_not_opted_out, :to_school_official_legitimate_interest,
                  :due_to_judicial_order_or_subpoena_or_financial_aid, :to_other_school_enrollment_transfer,
                  :to_authorized_representatives, :to_research_org_ferpa, :to_accrediting_agency,
                  :parent_of_dependent_student, :otherwise_permitted_under_99_31, :contains_pii

    FIELDS = %i[
      includes_fti disclosure_to_student disclosure_to_contributor_parent_or_spouse
      is_fafsa_data used_for_aid_admin disclosure_to_scholarship_org
      explicit_written_consent research_promote_attendance hea_written_consent
      ferpa_written_consent directory_info_and_not_opted_out to_school_official_legitimate_interest
      due_to_judicial_order_or_subpoena_or_financial_aid to_other_school_enrollment_transfer
      to_authorized_representatives to_research_org_ferpa to_accrediting_agency
      parent_of_dependent_student otherwise_permitted_under_99_31 contains_pii
    ].freeze

    def initialize(data = {})
      FIELDS.each { |field| instance_variable_set(:"@#{field}", data[field] || false) }
      setup_legacy_mapping(data)
    end

    def [](key)
      FIELDS.include?(key) ? instance_variable_get(:"@#{key}") : false
    end

    # Data Predicates
    def includes_fti? = @includes_fti
    def disclosure_to_student? = @disclosure_to_student
    def fafsa_data? = @is_fafsa_data
    def disclosure_to_contributor_parent_or_spouse? = @disclosure_to_contributor_parent_or_spouse
    def used_for_aid_admin? = @used_for_aid_admin
    def disclosure_to_scholarship_org? = @disclosure_to_scholarship_org
    def explicit_written_consent? = @explicit_written_consent
    def research_promote_attendance? = @research_promote_attendance
    def hea_written_consent? = @hea_written_consent
    def contains_pii? = @contains_pii
    def ferpa_written_consent? = @ferpa_written_consent
    def directory_info_and_not_opted_out? = @directory_info_and_not_opted_out
    def to_school_official_legitimate_interest? = @to_school_official_legitimate_interest
    def due_to_judicial_order_or_subpoena_or_financial_aid? = @due_to_judicial_order_or_subpoena_or_financial_aid
    def to_other_school_enrollment_transfer? = @to_other_school_enrollment_transfer
    def to_authorized_representatives? = @to_authorized_representatives
    def to_research_org_ferpa? = @to_research_org_ferpa
    def to_accrediting_agency? = @to_accrediting_agency
    def parent_of_dependent_student? = @parent_of_dependent_student
    def otherwise_permitted_under_99_31? = @otherwise_permitted_under_99_31

    # Alias: the YAML rules use is_fafsa_data as the input name
    alias is_fafsa_data? fafsa_data?

    private

    def setup_legacy_mapping(data)
      map_recipient_type(data)
      map_data_type(data)
      map_purpose(data)
      map_consent(data)
      map_legal_basis(data)
      @contains_pii = data[:contains_pii] if data.key?(:contains_pii)
      @otherwise_permitted_under_99_31 = data[:other_99_31_exception] if data.key?(:other_99_31_exception)
    end

    def map_recipient_type(data)
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

    def map_data_type(data)
      case data[:data_type]
      when :fafsa_data
        @is_fafsa_data = true
      when :directory_information
        @directory_info_and_not_opted_out = true
      end
    end

    def map_purpose(data)
      case data[:purpose]
      when :financial_aid
        @used_for_aid_admin = true
      when :research_college_attendance
        @research_promote_attendance = true
      when :financial_aid_related
        @due_to_judicial_order_or_subpoena_or_financial_aid = true
      end
    end

    def map_consent(data)
      return unless data[:consent]

      @hea_written_consent = true if data[:consent][:hea]
      @ferpa_written_consent = true if data[:consent][:ferpa]
      @explicit_written_consent = true if data[:consent][:explicit_written]
    end

    def map_legal_basis(data)
      case data[:legal_basis]
      when :judicial_order, :subpoena
        @due_to_judicial_order_or_subpoena_or_financial_aid = true
      end
    end

    def research_purpose_valid?(purpose)
      %i[predictive_tests student_aid_programs improve_instruction].include?(purpose)
    end
  end
end
