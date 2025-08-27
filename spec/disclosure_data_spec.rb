# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe DisclosureData do
  describe 'normalized boolean fields' do
    let(:data) do
      DisclosureData.new(
        includes_fti: true,
        disclosure_to_student: true,
        disclosure_to_contributor_parent_or_spouse: false,
        is_fafsa_data: true,
        used_for_aid_admin: false,
        disclosure_to_scholarship_org: true,
        explicit_written_consent: true,
        research_promote_attendance: false,
        hea_written_consent: true,
        ferpa_written_consent: false,
        directory_info_and_not_opted_out: true,
        to_school_official_legitimate_interest: false,
        due_to_judicial_order_or_subpoena_or_financial_aid: true,
        to_other_school_enrollment_transfer: false,
        to_authorized_representatives: true,
        to_research_org_ferpa: false,
        to_accrediting_agency: true,
        parent_of_dependent_student: false,
        otherwise_permitted_under_99_31: true,
        contains_pii: true
      )
    end

    it 'supports bracket notation for all normalized fields' do
      expect(data[:includes_fti]).to be true
      expect(data[:disclosure_to_student]).to be true
      expect(data[:disclosure_to_contributor_parent_or_spouse]).to be false
      expect(data[:is_fafsa_data]).to be true
      expect(data[:used_for_aid_admin]).to be false
      expect(data[:disclosure_to_scholarship_org]).to be true
      expect(data[:explicit_written_consent]).to be true
      expect(data[:research_promote_attendance]).to be false
      expect(data[:hea_written_consent]).to be true
      expect(data[:ferpa_written_consent]).to be false
      expect(data[:directory_info_and_not_opted_out]).to be true
      expect(data[:to_school_official_legitimate_interest]).to be false
      expect(data[:due_to_judicial_order_or_subpoena_or_financial_aid]).to be true
      expect(data[:to_other_school_enrollment_transfer]).to be false
      expect(data[:to_authorized_representatives]).to be true
      expect(data[:to_research_org_ferpa]).to be false
      expect(data[:to_accrediting_agency]).to be true
      expect(data[:parent_of_dependent_student]).to be false
      expect(data[:otherwise_permitted_under_99_31]).to be true
      expect(data[:contains_pii]).to be true
    end

    it 'supports dot notation for all normalized fields' do
      expect(data.includes_fti).to be true
      expect(data.disclosure_to_student).to be true
      expect(data.disclosure_to_contributor_parent_or_spouse).to be false
      expect(data.is_fafsa_data).to be true
      expect(data.used_for_aid_admin).to be false
      expect(data.disclosure_to_scholarship_org).to be true
      expect(data.explicit_written_consent).to be true
      expect(data.research_promote_attendance).to be false
      expect(data.hea_written_consent).to be true
      expect(data.ferpa_written_consent).to be false
      expect(data.directory_info_and_not_opted_out).to be true
      expect(data.to_school_official_legitimate_interest).to be false
      expect(data.due_to_judicial_order_or_subpoena_or_financial_aid).to be true
      expect(data.to_other_school_enrollment_transfer).to be false
      expect(data.to_authorized_representatives).to be true
      expect(data.to_research_org_ferpa).to be false
      expect(data.to_accrediting_agency).to be true
      expect(data.parent_of_dependent_student).to be false
      expect(data.otherwise_permitted_under_99_31).to be true
      expect(data.contains_pii).to be true
    end

    it 'returns false for missing keys' do
      expect(data[:missing_key]).to be false
    end

    it 'handles default values correctly' do
      empty_data = DisclosureData.new
      expect(empty_data.includes_fti).to be false
      expect(empty_data.disclosure_to_student).to be false
      expect(empty_data.contains_pii).to be false
    end
  end

  describe 'legacy compatibility' do
    it 'maps legacy recipient_type to normalized fields' do
      data = DisclosureData.new(
        recipient_type: :student,
        has_educational_interest: true
      )
      expect(data.disclosure_to_student).to be true
      expect(data.to_school_official_legitimate_interest).to be false
    end

    it 'maps legacy data_type to normalized fields' do
      data = DisclosureData.new(data_type: :fafsa_data)
      expect(data.is_fafsa_data).to be true
    end

    it 'maps legacy purpose to normalized fields' do
      data = DisclosureData.new(purpose: :financial_aid)
      expect(data.used_for_aid_admin).to be true
    end

    it 'maps legacy consent to normalized fields' do
      data = DisclosureData.new(consent: { hea: true, ferpa: true, explicit_written: true })
      expect(data.hea_written_consent).to be true
      expect(data.ferpa_written_consent).to be true
      expect(data.explicit_written_consent).to be true
    end

    it 'maps legacy legal_basis to normalized fields' do
      data = DisclosureData.new(legal_basis: :judicial_order)
      expect(data.due_to_judicial_order_or_subpoena_or_financial_aid).to be true
    end

    it 'maps legacy other_99_31_exception to normalized field' do
      data = DisclosureData.new(other_99_31_exception: true)
      expect(data.otherwise_permitted_under_99_31).to be true
    end

    it 'handles school official without educational interest' do
      data = DisclosureData.new(recipient_type: :school_official, has_educational_interest: false)
      expect(data.to_school_official_legitimate_interest).to be false
    end

    it 'handles other school without enrollment purpose' do
      data = DisclosureData.new(recipient_type: :other_school, purpose: :research)
      expect(data.to_other_school_enrollment_transfer).to be false
    end

    it 'handles research organization with invalid purpose' do
      data = DisclosureData.new(recipient_type: :research_organization, research_purpose: :invalid_purpose)
      expect(data.to_research_org_ferpa).to be false
    end

    it 'handles parent of independent student' do
      data = DisclosureData.new(recipient_type: :parent, student_dependency_status: :independent)
      expect(data.parent_of_dependent_student).to be false
    end

    it 'handles missing contains_pii key' do
      data = DisclosureData.new({})
      expect(data.contains_pii).to be false
    end

    it 'handles missing other_99_31_exception key' do
      data = DisclosureData.new({})
      expect(data.otherwise_permitted_under_99_31).to be false
    end

    it 'handles research purpose validation for predictive_tests' do
      data = DisclosureData.new(recipient_type: :research_organization, research_purpose: :predictive_tests)
      expect(data.to_research_org_ferpa).to be true
    end

    it 'handles research purpose validation for student_aid_programs' do
      data = DisclosureData.new(recipient_type: :research_organization, research_purpose: :student_aid_programs)
      expect(data.to_research_org_ferpa).to be true
    end

    it 'handles research purpose validation for improve_instruction' do
      data = DisclosureData.new(recipient_type: :research_organization, research_purpose: :improve_instruction)
      expect(data.to_research_org_ferpa).to be true
    end
  end
end
