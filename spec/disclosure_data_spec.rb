# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe Nasfaa::DisclosureData do
  describe 'normalized boolean fields' do
    let(:data) do
      described_class.new(
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
      empty_data = described_class.new
      expect(empty_data.includes_fti).to be false
      expect(empty_data.disclosure_to_student).to be false
      expect(empty_data.contains_pii).to be false
    end
  end

  describe 'legacy compatibility' do
    it 'maps legacy recipient_type to normalized fields' do
      data = described_class.new(
        recipient_type: :student,
        has_educational_interest: true
      )
      expect(data.disclosure_to_student).to be true
      expect(data.to_school_official_legitimate_interest).to be false
    end

    it 'maps legacy data_type to normalized fields' do
      data = described_class.new(data_type: :fafsa_data)
      expect(data.is_fafsa_data).to be true
    end

    it 'maps legacy purpose to normalized fields' do
      data = described_class.new(purpose: :financial_aid)
      expect(data.used_for_aid_admin).to be true
    end

    it 'maps legacy consent to normalized fields' do
      data = described_class.new(consent: { hea: true, ferpa: true, explicit_written: true })
      expect(data.hea_written_consent).to be true
      expect(data.ferpa_written_consent).to be true
      expect(data.explicit_written_consent).to be true
    end

    it 'maps legacy legal_basis to normalized fields' do
      data = described_class.new(legal_basis: :judicial_order)
      expect(data.due_to_judicial_order_or_subpoena_or_financial_aid).to be true
    end

    it 'maps legacy other_99_31_exception to normalized field' do
      data = described_class.new(other_99_31_exception: true)
      expect(data.otherwise_permitted_under_99_31).to be true
    end

    it 'handles school official without educational interest' do
      data = described_class.new(recipient_type: :school_official, has_educational_interest: false)
      expect(data.to_school_official_legitimate_interest).to be false
    end

    it 'handles other school without enrollment purpose' do
      data = described_class.new(recipient_type: :other_school, purpose: :research)
      expect(data.to_other_school_enrollment_transfer).to be false
    end

    it 'handles research organization with invalid purpose' do
      data = described_class.new(recipient_type: :research_organization, research_purpose: :invalid_purpose)
      expect(data.to_research_org_ferpa).to be false
    end

    it 'handles parent of independent student' do
      data = described_class.new(recipient_type: :parent, student_dependency_status: :independent)
      expect(data.parent_of_dependent_student).to be false
    end

    it 'handles missing contains_pii key' do
      data = described_class.new({})
      expect(data.contains_pii).to be false
    end

    it 'handles missing other_99_31_exception key' do
      data = described_class.new({})
      expect(data.otherwise_permitted_under_99_31).to be false
    end

    it 'handles research purpose validation for predictive_tests' do
      data = described_class.new(recipient_type: :research_organization, research_purpose: :predictive_tests)
      expect(data.to_research_org_ferpa).to be true
    end

    it 'handles research purpose validation for student_aid_programs' do
      data = described_class.new(recipient_type: :research_organization, research_purpose: :student_aid_programs)
      expect(data.to_research_org_ferpa).to be true
    end

    it 'handles research purpose validation for improve_instruction' do
      data = described_class.new(recipient_type: :research_organization, research_purpose: :improve_instruction)
      expect(data.to_research_org_ferpa).to be true
    end

    it 'maps spouse_contributor to disclosure_to_contributor_parent_or_spouse' do
      data = described_class.new(recipient_type: :spouse_contributor)
      expect(data.disclosure_to_contributor_parent_or_spouse).to be true
    end

    it 'maps scholarship_organization to disclosure_to_scholarship_org' do
      data = described_class.new(recipient_type: :scholarship_organization)
      expect(data.disclosure_to_scholarship_org).to be true
    end

    it 'maps tribal_organization to disclosure_to_scholarship_org' do
      data = described_class.new(recipient_type: :tribal_organization)
      expect(data.disclosure_to_scholarship_org).to be true
    end

    it 'maps school_official with educational interest to to_school_official_legitimate_interest' do
      data = described_class.new(recipient_type: :school_official, has_educational_interest: true)
      expect(data.to_school_official_legitimate_interest).to be true
    end

    it 'maps other_school with enrollment_or_transfer purpose to to_other_school_enrollment_transfer' do
      data = described_class.new(recipient_type: :other_school, purpose: :enrollment_or_transfer)
      expect(data.to_other_school_enrollment_transfer).to be true
    end

    it 'maps federal_representative to to_authorized_representatives' do
      data = described_class.new(recipient_type: :federal_representative)
      expect(data.to_authorized_representatives).to be true
    end

    it 'maps state_local_authority to to_authorized_representatives' do
      data = described_class.new(recipient_type: :state_local_authority)
      expect(data.to_authorized_representatives).to be true
    end

    it 'maps accrediting_agency to to_accrediting_agency' do
      data = described_class.new(recipient_type: :accrediting_agency)
      expect(data.to_accrediting_agency).to be true
    end

    it 'maps parent of dependent student to parent_of_dependent_student' do
      data = described_class.new(recipient_type: :parent, student_dependency_status: :dependent)
      expect(data.parent_of_dependent_student).to be true
    end

    it 'leaves all fields false for unknown recipient_type' do
      data = described_class.new(recipient_type: :unknown_type)
      expect(data.disclosure_to_student).to be false
      expect(data.disclosure_to_contributor_parent_or_spouse).to be false
      expect(data.disclosure_to_scholarship_org).to be false
      expect(data.to_authorized_representatives).to be false
    end

    it 'maps directory_information data_type to directory_info_and_not_opted_out' do
      data = described_class.new(data_type: :directory_information)
      expect(data.directory_info_and_not_opted_out).to be true
    end

    it 'maps research_college_attendance purpose to research_promote_attendance' do
      data = described_class.new(purpose: :research_college_attendance)
      expect(data.research_promote_attendance).to be true
    end

    it 'maps financial_aid_related purpose to due_to_judicial_order_or_subpoena_or_financial_aid' do
      data = described_class.new(purpose: :financial_aid_related)
      expect(data.due_to_judicial_order_or_subpoena_or_financial_aid).to be true
    end

    it 'maps subpoena legal_basis to due_to_judicial_order_or_subpoena_or_financial_aid' do
      data = described_class.new(legal_basis: :subpoena)
      expect(data.due_to_judicial_order_or_subpoena_or_financial_aid).to be true
    end

    it 'skips all consent fields when consent key is absent' do
      data = described_class.new({})
      expect(data.hea_written_consent).to be false
      expect(data.ferpa_written_consent).to be false
      expect(data.explicit_written_consent).to be false
    end

    it 'leaves consent fields false when consent values are false' do
      data = described_class.new(consent: { hea: false, ferpa: false, explicit_written: false })
      expect(data.hea_written_consent).to be false
      expect(data.ferpa_written_consent).to be false
      expect(data.explicit_written_consent).to be false
    end
  end

  # Data Predicates - Direct queries of the data state
  describe '#includes_fti?' do
    context 'when disclosure includes FTI' do
      let(:data) { described_class.new(includes_fti: true) }
      it { expect(data.includes_fti?).to be true }
    end

    context 'when disclosure does not include FTI' do
      let(:data) { described_class.new(includes_fti: false) }
      it { expect(data.includes_fti?).to be false }
    end
  end

  describe '#disclosure_to_student?' do
    context 'when disclosure is to student' do
      let(:data) { described_class.new(disclosure_to_student: true) }
      it { expect(data.disclosure_to_student?).to be true }
    end

    context 'when disclosure is not to student' do
      let(:data) { described_class.new(disclosure_to_student: false) }
      it { expect(data.disclosure_to_student?).to be false }
    end
  end

  describe '#fafsa_data?' do
    context 'when data type is FAFSA data' do
      let(:data) { described_class.new(is_fafsa_data: true) }
      it { expect(data.fafsa_data?).to be true }
    end

    context 'when data type is not FAFSA data' do
      let(:data) { described_class.new(is_fafsa_data: false) }
      it { expect(data.fafsa_data?).to be false }
    end
  end

  describe '#is_fafsa_data?' do
    context 'when data type is FAFSA data' do
      let(:data) { described_class.new(is_fafsa_data: true) }
      it { expect(data.is_fafsa_data?).to be true }
    end

    context 'when data type is not FAFSA data' do
      let(:data) { described_class.new(is_fafsa_data: false) }
      it { expect(data.is_fafsa_data?).to be false }
    end
  end

  describe '#disclosure_to_contributor_parent_or_spouse?' do
    context 'when disclosure is to parent contributor' do
      let(:data) { described_class.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to spouse contributor' do
      let(:data) { described_class.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { described_class.new(disclosure_to_contributor_parent_or_spouse: false) }
      it { expect(data.disclosure_to_contributor_parent_or_spouse?).to be false }
    end
  end

  describe '#used_for_aid_admin?' do
    context 'when purpose is financial aid' do
      let(:data) { described_class.new(used_for_aid_admin: true) }
      it { expect(data.used_for_aid_admin?).to be true }
    end

    context 'when purpose is not financial aid' do
      let(:data) { described_class.new(used_for_aid_admin: false) }
      it { expect(data.used_for_aid_admin?).to be false }
    end
  end

  describe '#disclosure_to_scholarship_org?' do
    context 'when disclosure is to scholarship organization' do
      let(:data) { described_class.new(disclosure_to_scholarship_org: true) }
      it { expect(data.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to tribal organization' do
      let(:data) { described_class.new(disclosure_to_scholarship_org: true) }
      it { expect(data.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { described_class.new(disclosure_to_scholarship_org: false) }
      it { expect(data.disclosure_to_scholarship_org?).to be false }
    end
  end

  describe '#explicit_written_consent?' do
    context 'when explicit written consent is provided' do
      let(:data) { described_class.new(explicit_written_consent: true) }
      it { expect(data.explicit_written_consent?).to be true }
    end

    context 'when explicit written consent is not provided' do
      let(:data) { described_class.new(explicit_written_consent: false) }
      it { expect(data.explicit_written_consent?).to be false }
    end
  end

  describe '#research_promote_attendance?' do
    context 'when purpose is research promoting college attendance' do
      let(:data) { described_class.new(research_promote_attendance: true) }
      it { expect(data.research_promote_attendance?).to be true }
    end

    context 'when purpose is not research promoting college attendance' do
      let(:data) { described_class.new(research_promote_attendance: false) }
      it { expect(data.research_promote_attendance?).to be false }
    end
  end

  describe '#hea_written_consent?' do
    context 'when HEA consent is provided' do
      let(:data) { described_class.new(hea_written_consent: true) }
      it { expect(data.hea_written_consent?).to be true }
    end

    context 'when HEA consent is not provided' do
      let(:data) { described_class.new(hea_written_consent: false) }
      it { expect(data.hea_written_consent?).to be false }
    end
  end

  describe '#contains_pii?' do
    context 'when disclosure contains PII' do
      let(:data) { described_class.new(contains_pii: true) }
      it { expect(data.contains_pii?).to be true }
    end

    context 'when disclosure does not contain PII' do
      let(:data) { described_class.new(contains_pii: false) }
      it { expect(data.contains_pii?).to be false }
    end
  end

  describe '#ferpa_written_consent?' do
    context 'when FERPA consent is provided' do
      let(:data) { described_class.new(ferpa_written_consent: true) }
      it { expect(data.ferpa_written_consent?).to be true }
    end

    context 'when FERPA consent is not provided' do
      let(:data) { described_class.new(ferpa_written_consent: false) }
      it { expect(data.ferpa_written_consent?).to be false }
    end
  end

  describe '#directory_info_and_not_opted_out?' do
    context 'when data type is directory information' do
      let(:data) { described_class.new(directory_info_and_not_opted_out: true) }
      it { expect(data.directory_info_and_not_opted_out?).to be true }
    end

    context 'when data type is not directory information' do
      let(:data) { described_class.new(directory_info_and_not_opted_out: false) }
      it { expect(data.directory_info_and_not_opted_out?).to be false }
    end
  end

  describe '#to_school_official_legitimate_interest?' do
    context 'when disclosure is to school official with educational interest' do
      let(:data) { described_class.new(to_school_official_legitimate_interest: true) }
      it { expect(data.to_school_official_legitimate_interest?).to be true }
    end

    context 'when disclosure is to school official without educational interest' do
      let(:data) { described_class.new(to_school_official_legitimate_interest: false) }
      it { expect(data.to_school_official_legitimate_interest?).to be false }
    end

    context 'when disclosure is not to school official' do
      let(:data) { described_class.new(to_school_official_legitimate_interest: false) }
      it { expect(data.to_school_official_legitimate_interest?).to be false }
    end
  end

  describe '#due_to_judicial_order_or_subpoena_or_financial_aid?' do
    context 'when legal basis is judicial order' do
      let(:data) { described_class.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when legal basis is subpoena' do
      let(:data) { described_class.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when purpose is financial aid related' do
      let(:data) { described_class.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when none of the conditions are met' do
      let(:data) { described_class.new(due_to_judicial_order_or_subpoena_or_financial_aid: false) }
      it { expect(data.due_to_judicial_order_or_subpoena_or_financial_aid?).to be false }
    end
  end

  describe '#to_other_school_enrollment_transfer?' do
    context 'when disclosure is to other school for enrollment' do
      let(:data) { described_class.new(to_other_school_enrollment_transfer: true) }
      it { expect(data.to_other_school_enrollment_transfer?).to be true }
    end

    context 'when disclosure is to other school but not for enrollment' do
      let(:data) { described_class.new(to_other_school_enrollment_transfer: false) }
      it { expect(data.to_other_school_enrollment_transfer?).to be false }
    end

    context 'when disclosure is not to other school' do
      let(:data) { described_class.new(to_other_school_enrollment_transfer: false) }
      it { expect(data.to_other_school_enrollment_transfer?).to be false }
    end
  end

  describe '#to_authorized_representatives?' do
    context 'when disclosure is to federal representative' do
      let(:data) { described_class.new(to_authorized_representatives: true) }
      it { expect(data.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to state/local authority' do
      let(:data) { described_class.new(to_authorized_representatives: true) }
      it { expect(data.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:data) { described_class.new(to_authorized_representatives: false) }
      it { expect(data.to_authorized_representatives?).to be false }
    end
  end

  describe '#to_research_org_ferpa?' do
    context 'when disclosure is to research organization for predictive tests' do
      let(:data) { described_class.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for student aid programs' do
      let(:data) { described_class.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for improving instruction' do
      let(:data) { described_class.new(to_research_org_ferpa: true) }
      it { expect(data.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is not to research organization' do
      let(:data) { described_class.new(to_research_org_ferpa: false) }
      it { expect(data.to_research_org_ferpa?).to be false }
    end
  end

  describe '#to_accrediting_agency?' do
    context 'when disclosure is to accrediting agency' do
      let(:data) { described_class.new(to_accrediting_agency: true) }
      it { expect(data.to_accrediting_agency?).to be true }
    end

    context 'when disclosure is not to accrediting agency' do
      let(:data) { described_class.new(to_accrediting_agency: false) }
      it { expect(data.to_accrediting_agency?).to be false }
    end
  end

  describe '#parent_of_dependent_student?' do
    context 'when disclosure is to parent of dependent student' do
      let(:data) { described_class.new(parent_of_dependent_student: true) }
      it { expect(data.parent_of_dependent_student?).to be true }
    end

    context 'when disclosure is to parent of independent student' do
      let(:data) { described_class.new(parent_of_dependent_student: false) }
      it { expect(data.parent_of_dependent_student?).to be false }
    end

    context 'when disclosure is not to parent' do
      let(:data) { described_class.new(parent_of_dependent_student: false) }
      it { expect(data.parent_of_dependent_student?).to be false }
    end
  end

  describe '#otherwise_permitted_under_99_31?' do
    context 'when otherwise permitted under 99.31' do
      let(:data) { described_class.new(otherwise_permitted_under_99_31: true) }
      it { expect(data.otherwise_permitted_under_99_31?).to be true }
    end

    context 'when not otherwise permitted under 99.31' do
      let(:data) { described_class.new(otherwise_permitted_under_99_31: false) }
      it { expect(data.otherwise_permitted_under_99_31?).to be false }
    end
  end
end
