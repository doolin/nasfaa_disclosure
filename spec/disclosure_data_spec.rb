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

  # Data Predicates - Direct queries of the data state
  describe '#includes_fti?' do
    context 'when disclosure includes FTI' do
      let(:data) { DisclosureData.new(includes_fti: true) }
      it { expect(data.includes_fti?).to be true }
    end

    context 'when disclosure does not include FTI' do
      let(:data) { DisclosureData.new(includes_fti: false) }
      it { expect(data.includes_fti?).to be false }
    end
  end

  describe '#disclosure_to_student?' do
    context 'when disclosure is to student' do
      let(:data) { DisclosureData.new(disclosure_to_student: true) }
      it { expect(data.disclosure_to_student?).to be true }
    end

    context 'when disclosure is not to student' do
      let(:data) { DisclosureData.new(disclosure_to_student: false) }
      it { expect(data.disclosure_to_student?).to be false }
    end
  end

  describe '#fafsa_data?' do
    context 'when data type is FAFSA data' do
      let(:data) { DisclosureData.new(is_fafsa_data: true) }
      it { expect(data.fafsa_data?).to be true }
    end

    context 'when data type is not FAFSA data' do
      let(:data) { DisclosureData.new(is_fafsa_data: false) }
      it { expect(data.fafsa_data?).to be false }
    end
  end

  describe '#disclosure_to_contributor_parent_or_spouse?' do
    context 'when disclosure is to parent contributor' do
      let(:data) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to spouse contributor' do
      let(:data) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: false) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be false }
    end
  end

  describe '#used_for_aid_admin?' do
    context 'when purpose is financial aid' do
      let(:data) { DisclosureData.new(used_for_aid_admin: true) }
      it { expect(data.used_for_aid_admin?).to be true }
    end

    context 'when purpose is not financial aid' do
      let(:data) { DisclosureData.new(used_for_aid_admin: false) }
      it { expect(data.used_for_aid_admin?).to be false }
    end
  end

  describe '#disclosure_to_scholarship_org?' do
    context 'when disclosure is to scholarship organization' do
      let(:data) { DisclosureData.new(disclosure_to_scholarship_org: true) }
      it { expect(data.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to tribal organization' do
      let(:data) { DisclosureData.new(disclosure_to_scholarship_org: true) }
      it { expect(data.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { DisclosureData.new(disclosure_to_scholarship_org: false) }
      it { expect(data.disclosure_to_scholarship_org?).to be false }
    end
  end

  describe '#explicit_written_consent?' do
    context 'when explicit written consent is provided' do
      let(:data) { DisclosureData.new(explicit_written_consent: true) }
      it { expect(data.explicit_written_consent?).to be true }
    end

    context 'when explicit written consent is not provided' do
      let(:data) { DisclosureData.new(explicit_written_consent: false) }
      it { expect(data.explicit_written_consent?).to be false }
    end
  end

  describe '#research_promote_attendance?' do
    context 'when purpose is research promoting college attendance' do
      let(:data) { DisclosureData.new(research_promote_attendance: true) }
      it { expect(data.research_promote_attendance?).to be true }
    end

    context 'when purpose is not research promoting college attendance' do
      let(:data) { DisclosureData.new(research_promote_attendance: false) }
      it { expect(data.research_promote_attendance?).to be false }
    end
  end

  describe '#hea_written_consent?' do
    context 'when HEA consent is provided' do
      let(:data) { DisclosureData.new(hea_written_consent: true) }
      it { expect(data.hea_written_consent?).to be true }
    end

    context 'when HEA consent is not provided' do
      let(:data) { DisclosureData.new(hea_written_consent: false) }
      it { expect(data.hea_written_consent?).to be false }
    end
  end

  describe '#contains_pii?' do
    context 'when disclosure contains PII' do
      let(:data) { DisclosureData.new(contains_pii: true) }
      it { expect(data.contains_pii?).to be true }
    end

    context 'when disclosure does not contain PII' do
      let(:data) { DisclosureData.new(contains_pii: false) }
      it { expect(data.contains_pii?).to be false }
    end
  end

  describe '#ferpa_written_consent?' do
    context 'when FERPA consent is provided' do
      let(:data) { DisclosureData.new(ferpa_written_consent: true) }
      it { expect(data.ferpa_written_consent?).to be true }
    end

    context 'when FERPA consent is not provided' do
      let(:data) { DisclosureData.new(ferpa_written_consent: false) }
      it { expect(data.ferpa_written_consent?).to be false }
    end
  end

  describe '#directory_info_and_not_opted_out?' do
    context 'when data type is directory information' do
      let(:data) { DisclosureData.new(directory_info_and_not_opted_out: true) }
      it { expect(data.directory_info_and_not_opted_out?).to be true }
    end

    context 'when data type is not directory information' do
      let(:data) { DisclosureData.new(directory_info_and_not_opted_out: false) }
      it { expect(data.directory_info_and_not_opted_out?).to be false }
    end
  end

  describe '#to_school_official_legitimate_interest?' do
    context 'when disclosure is to school official with educational interest' do
      let(:data) { DisclosureData.new(to_school_official_legitimate_interest: true) }
      it { expect(data.to_school_official_legitimate_interest?).to be true }
    end

    context 'when disclosure is to school official without educational interest' do
      let(:data) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(data.to_school_official_legitimate_interest?).to be false }
    end

    context 'when disclosure is not to school official' do
      let(:data) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(data.to_school_official_legitimate_interest?).to be false }
    end
  end

  describe '#due_to_judicial_order_or_subpoena_or_financial_aid?' do
    context 'when legal basis is judicial order' do
      let(:data) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when legal basis is subpoena' do
      let(:data) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when purpose is financial aid related' do
      let(:data) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when none of the conditions are met' do
      let(:data) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: false) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be false }
    end
  end

  describe '#to_other_school_enrollment_transfer?' do
    context 'when disclosure is to other school for enrollment' do
      let(:data) { DisclosureData.new(to_other_school_enrollment_transfer: true) }
      it { expect(data.to_other_school_enrollment_transfer?).to be true }
    end

    context 'when disclosure is to other school but not for enrollment' do
      let(:data) { DisclosureData.new(to_other_school_enrollment_transfer: false) }
      it { expect(data.to_other_school_enrollment_transfer?).to be false }
    end

    context 'when disclosure is not to other school' do
      let(:data) { DisclosureData.new(to_other_school_enrollment_transfer: false) }
      it { expect(data.to_other_school_enrollment_transfer?).to be false }
    end
  end

  describe '#to_authorized_representatives?' do
    context 'when disclosure is to federal representative' do
      let(:data) { DisclosureData.new(to_authorized_representatives: true) }
      it { expect(data.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to state/local authority' do
      let(:data) { DisclosureData.new(to_authorized_representatives: true) }
      it { expect(data.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { DisclosureData.new(to_authorized_representatives: false) }
      it { expect(data.to_authorized_representatives?).to be false }
    end
  end

  describe '#to_research_org_ferpa?' do
    context 'when disclosure is to research organization for predictive tests' do
      let(:data) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for student aid programs' do
      let(:data) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for improving instruction' do
      let(:data) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is not to research organization' do
      let(:data) { DisclosureData.new(to_research_org_ferpa: false) }
      it { expect(data.to_research_org_ferpa?).to be false }
    end
  end

  describe '#to_accrediting_agency?' do
    context 'when disclosure is to accrediting agency' do
      let(:data) { DisclosureData.new(to_accrediting_agency: true) }
      it { expect(data.to_accrediting_agency?).to be true }
    end

    context 'when disclosure is not to accrediting agency' do
      let(:data) { DisclosureData.new(to_accrediting_agency: false) }
      it { expect(data.to_accrediting_agency?).to be false }
    end
  end

  describe '#parent_of_dependent_student?' do
    context 'when disclosure is to parent of dependent student' do
      let(:data) { DisclosureData.new(parent_of_dependent_student: true) }
      it { expect(data.parent_of_dependent_student?).to be true }
    end

    context 'when disclosure is to parent of independent student' do
      let(:data) { DisclosureData.new(parent_of_dependent_student: false) }
      it { expect(data.parent_of_dependent_student?).to be false }
    end

    context 'when disclosure is not to parent' do
      let(:data) { DisclosureData.new(parent_of_dependent_student: false) }
      it { expect(data.parent_of_dependent_student?).to be false }
    end
  end

  describe '#otherwise_permitted_under_99_31?' do
    context 'when otherwise permitted under 99.31' do
      let(:data) { DisclosureData.new(otherwise_permitted_under_99_31: true) }
      it { expect(data.otherwise_permitted_under_99_31?).to be true }
    end

    context 'when not otherwise permitted under 99.31' do
      let(:data) { DisclosureData.new(otherwise_permitted_under_99_31: false) }
      it { expect(data.otherwise_permitted_under_99_31?).to be false }
    end
  end
end
