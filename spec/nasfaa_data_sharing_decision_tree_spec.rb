require 'rspec'
require_relative '../lib/nasfaa_data_sharing_decision_tree'
require_relative '../lib/disclosure_data'

RSpec.describe NasfaaDataSharingDecisionTree do
  let(:disclosure_request) { {} }
  let(:tree) { described_class.new(disclosure_request) }

  describe '#includes_federal_tax_information?' do # Box 1
    context 'when disclosure includes FTI' do
      let(:disclosure_request) { DisclosureData.new(includes_fti: true) }
      it { expect(tree.includes_federal_tax_information?).to be true }
    end

    context 'when disclosure does not include FTI' do
      let(:disclosure_request) { DisclosureData.new(includes_fti: false) }
      it { expect(tree.includes_federal_tax_information?).to be false }
    end
  end

  describe '#disclosure_to_student?' do # Box 2
    context 'when disclosure is to student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.disclosure_to_student?).to be true }
    end

    context 'when disclosure is not to student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :parent) }
      it { expect(tree.disclosure_to_student?).to be false }
    end
  end

  describe '#is_fafsa_data?' do # Box 3
    context 'when data type is FAFSA data' do
      let(:disclosure_request) { DisclosureData.new(data_type: :fafsa_data) }
      it { expect(tree.is_fafsa_data?).to be true }
    end

    context 'when data type is not FAFSA data' do
      let(:disclosure_request) { DisclosureData.new(data_type: :directory_information) }
      it { expect(tree.is_fafsa_data?).to be false }
    end
  end

  describe '#disclosure_to_parent_or_spouse_contributor?' do # Box 4
    context 'when disclosure is to parent contributor' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :parent_contributor) }
      it { expect(tree.disclosure_to_parent_or_spouse_contributor?).to be true }
    end

    context 'when disclosure is to spouse contributor' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :spouse_contributor) }
      it { expect(tree.disclosure_to_parent_or_spouse_contributor?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.disclosure_to_parent_or_spouse_contributor?).to be false }
    end
  end

  describe '#for_financial_aid_purposes?' do # Box 5
    context 'when purpose is financial aid' do
      let(:disclosure_request) { DisclosureData.new(purpose: :financial_aid) }
      it { expect(tree.for_financial_aid_purposes?).to be true }
    end

    context 'when purpose is not financial aid' do
      let(:disclosure_request) { DisclosureData.new(purpose: :research) }
      it { expect(tree.for_financial_aid_purposes?).to be false }
    end
  end

  describe '#to_scholarship_or_tribal_organization_with_consent?' do # Box 6
    context 'when disclosure is to scholarship organization' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :scholarship_organization) }
      it { expect(tree.to_scholarship_or_tribal_organization_with_consent?).to be true }
    end

    context 'when disclosure is to tribal organization' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :tribal_organization) }
      it { expect(tree.to_scholarship_or_tribal_organization_with_consent?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.to_scholarship_or_tribal_organization_with_consent?).to be false }
    end
  end

  describe '#for_research_promoting_college_attendance?' do # Box 7
    context 'when purpose is research promoting college attendance' do
      let(:disclosure_request) { DisclosureData.new(purpose: :research_college_attendance) }
      it { expect(tree.for_research_promoting_college_attendance?).to be true }
    end

    context 'when purpose is not research promoting college attendance' do
      let(:disclosure_request) { DisclosureData.new(purpose: :financial_aid) }
      it { expect(tree.for_research_promoting_college_attendance?).to be false }
    end
  end

  describe '#has_hea_consent?' do # Box 8
    context 'when HEA consent is provided' do
      let(:disclosure_request) { DisclosureData.new(consent: { hea: true }) }
      it { expect(tree.has_hea_consent?).to be true }
    end

    context 'when HEA consent is not provided' do
      let(:disclosure_request) { DisclosureData.new(consent: { hea: false }) }
      it { expect(tree.has_hea_consent?).to be false }
    end
  end

  describe '#contains_pii?' do # Box 9
    context 'when disclosure contains PII' do
      let(:disclosure_request) { DisclosureData.new(contains_pii: true) }
      it { expect(tree.contains_pii?).to be true }
    end

    context 'when disclosure does not contain PII' do
      let(:disclosure_request) { DisclosureData.new(contains_pii: false) }
      it { expect(tree.contains_pii?).to be false }
    end
  end

  describe '#has_ferpa_consent?' do # Box 10
    context 'when FERPA consent is provided' do
      let(:disclosure_request) { DisclosureData.new(consent: { ferpa: true }) }
      it { expect(tree.has_ferpa_consent?).to be true }
    end

    context 'when FERPA consent is not provided' do
      let(:disclosure_request) { DisclosureData.new(consent: { ferpa: false }) }
      it { expect(tree.has_ferpa_consent?).to be false }
    end
  end

  describe '#is_directory_information?' do # Box 11
    context 'when data type is directory information' do
      let(:disclosure_request) { DisclosureData.new(data_type: :directory_information) }
      it { expect(tree.is_directory_information?).to be true }
    end

    context 'when data type is not directory information' do
      let(:disclosure_request) { DisclosureData.new(data_type: :fafsa_data) }
      it { expect(tree.is_directory_information?).to be false }
    end
  end

  describe '#to_school_officials_with_educational_interest?' do # Box 12
    context 'when disclosure is to school official with educational interest' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :school_official, has_educational_interest: true) }
      it { expect(tree.to_school_officials_with_educational_interest?).to be true }
    end

    context 'when disclosure is to school official without educational interest' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :school_official, has_educational_interest: false) }
      it { expect(tree.to_school_officials_with_educational_interest?).to be false }
    end

    context 'when disclosure is not to school official' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student, has_educational_interest: true) }
      it { expect(tree.to_school_officials_with_educational_interest?).to be false }
    end
  end

  describe '#judicial_order_or_financial_aid_related?' do # Box 13
    context 'when legal basis is judicial order' do
      let(:disclosure_request) { DisclosureData.new(legal_basis: :judicial_order) }
      it { expect(tree.judicial_order_or_financial_aid_related?).to be true }
    end

    context 'when legal basis is subpoena' do
      let(:disclosure_request) { DisclosureData.new(legal_basis: :subpoena) }
      it { expect(tree.judicial_order_or_financial_aid_related?).to be true }
    end

    context 'when purpose is financial aid related' do
      let(:disclosure_request) { DisclosureData.new(purpose: :financial_aid_related) }
      it { expect(tree.judicial_order_or_financial_aid_related?).to be true }
    end

    context 'when none of the conditions are met' do
      let(:disclosure_request) { DisclosureData.new(legal_basis: :other, purpose: :research) }
      it { expect(tree.judicial_order_or_financial_aid_related?).to be false }
    end
  end

  describe '#to_other_school_for_enrollment?' do # Box 14
    context 'when disclosure is to other school for enrollment' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :other_school, purpose: :enrollment_or_transfer) }
      it { expect(tree.to_other_school_for_enrollment?).to be true }
    end

    context 'when disclosure is to other school but not for enrollment' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :other_school, purpose: :research) }
      it { expect(tree.to_other_school_for_enrollment?).to be false }
    end

    context 'when disclosure is not to other school' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student, purpose: :enrollment_or_transfer) }
      it { expect(tree.to_other_school_for_enrollment?).to be false }
    end
  end

  describe '#to_authorized_federal_representatives?' do # Box 15
    context 'when disclosure is to federal representative' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :federal_representative) }
      it { expect(tree.to_authorized_federal_representatives?).to be true }
    end

    context 'when disclosure is to state/local authority' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :state_local_authority) }
      it { expect(tree.to_authorized_federal_representatives?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.to_authorized_federal_representatives?).to be false }
    end
  end

  describe '#to_research_organization?' do # Box 16
    context 'when disclosure is to research organization for predictive tests' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :research_organization, research_purpose: :predictive_tests)
      end
      it { expect(tree.to_research_organization?).to be true }
    end

    context 'when disclosure is to research organization for student aid programs' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :research_organization, research_purpose: :student_aid_programs)
      end
      it { expect(tree.to_research_organization?).to be true }
    end

    context 'when disclosure is to research organization for improving instruction' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :research_organization, research_purpose: :improve_instruction)
      end
      it { expect(tree.to_research_organization?).to be true }
    end

    context 'when disclosure is not to research organization' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student, research_purpose: :predictive_tests) }
      it { expect(tree.to_research_organization?).to be false }
    end
  end

  describe '#to_accrediting_agency?' do # Box 17
    context 'when disclosure is to accrediting agency' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :accrediting_agency) }
      it { expect(tree.to_accrediting_agency?).to be true }
    end

    context 'when disclosure is not to accrediting agency' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.to_accrediting_agency?).to be false }
    end
  end

  describe '#to_parent_of_dependent_student?' do # Box 18
    context 'when disclosure is to parent of dependent student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :parent, student_dependency_status: :dependent) }
      it { expect(tree.to_parent_of_dependent_student?).to be true }
    end

    context 'when disclosure is to parent of independent student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :parent, student_dependency_status: :independent) }
      it { expect(tree.to_parent_of_dependent_student?).to be false }
    end

    context 'when disclosure is not to parent' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student, student_dependency_status: :dependent) }
      it { expect(tree.to_parent_of_dependent_student?).to be false }
    end
  end

  describe '#otherwise_permitted_under_99_31?' do # Box 19
    context 'when other 99.31 exception applies' do
      let(:disclosure_request) { DisclosureData.new(other_99_31_exception: true) }
      it { expect(tree.otherwise_permitted_under_99_31?).to be true }
    end

    context 'when no other 99.31 exception applies' do
      let(:disclosure_request) { DisclosureData.new(other_99_31_exception: false) }
      it { expect(tree.otherwise_permitted_under_99_31?).to be false }
    end
  end

  # FTI Branch Predicates

  describe '#fti_disclosure_to_student?' do # FTI Box 1
    context 'when FTI disclosure is to student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student) }
      it { expect(tree.fti_disclosure_to_student?).to be true }
    end

    context 'when FTI disclosure is not to student' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :parent) }
      it { expect(tree.fti_disclosure_to_student?).to be false }
    end
  end

  describe '#fti_for_financial_aid_purposes?' do # FTI Box 2
    context 'when FTI is for financial aid purposes' do
      let(:disclosure_request) { DisclosureData.new(purpose: :financial_aid) }
      it { expect(tree.fti_for_financial_aid_purposes?).to be true }
    end

    context 'when FTI is not for financial aid purposes' do
      let(:disclosure_request) { DisclosureData.new(purpose: :research) }
      it { expect(tree.fti_for_financial_aid_purposes?).to be false }
    end
  end

  describe '#fti_to_scholarship_organization_with_consent?' do # FTI Box 3
    context 'when FTI disclosure is to scholarship organization with explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :scholarship_organization, consent: { explicit_written: true })
      end
      it { expect(tree.fti_to_scholarship_organization_with_consent?).to be true }
    end

    context 'when FTI disclosure is to tribal organization with explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :tribal_organization, consent: { explicit_written: true })
      end
      it { expect(tree.fti_to_scholarship_organization_with_consent?).to be true }
    end

    context 'when FTI disclosure is to scholarship organization without explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :scholarship_organization, consent: { explicit_written: false })
      end
      it { expect(tree.fti_to_scholarship_organization_with_consent?).to be false }
    end

    context 'when FTI disclosure is not to scholarship or tribal organization' do
      let(:disclosure_request) do
        DisclosureData.new(recipient_type: :student, consent: { explicit_written: true })
      end
      it { expect(tree.fti_to_scholarship_organization_with_consent?).to be false }
    end
  end

  describe '#fti_to_school_officials_with_educational_interest?' do # FTI Box 4
    context 'when FTI disclosure is to school official with educational interest' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :school_official, has_educational_interest: true) }
      it { expect(tree.fti_to_school_officials_with_educational_interest?).to be true }
    end

    context 'when FTI disclosure is to school official without educational interest' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :school_official, has_educational_interest: false) }
      it { expect(tree.fti_to_school_officials_with_educational_interest?).to be false }
    end

    context 'when FTI disclosure is not to school official' do
      let(:disclosure_request) { DisclosureData.new(recipient_type: :student, has_educational_interest: true) }
      it { expect(tree.fti_to_school_officials_with_educational_interest?).to be false }
    end
  end

  # Main disclose? method tests

  describe '#disclose?' do
    context 'when disclosure includes FTI' do
      context 'and disclosure is to student' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: true, recipient_type: :student) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is for financial aid purposes' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: true, purpose: :financial_aid) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is to scholarship organization with explicit consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: true, recipient_type: :scholarship_organization,
                             consent: { explicit_written: true })
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is to school official with educational interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: true, recipient_type: :school_official, has_educational_interest: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and none of the FTI conditions are met' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: true, recipient_type: :parent, purpose: :research)
        end
        it { expect(tree.disclose?).to be false }
      end
    end

    context 'when disclosure does not include FTI' do
      context 'and disclosure is to student' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, recipient_type: :student) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data to parent contributor' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, recipient_type: :parent_contributor)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data for financial aid purposes' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, purpose: :financial_aid)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data to scholarship organization' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, recipient_type: :scholarship_organization)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data for research promoting college attendance' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, purpose: :research_college_attendance)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with HEA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, consent: { hea: true })
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII and FERPA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true, consent: { ferpa: true })
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but has FERPA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :other_data, consent: { ferpa: true })
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but is directory information' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :directory_information)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to school official with educational interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :school_official, has_educational_interest: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII under judicial order' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             legal_basis: :judicial_order)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to other school for enrollment' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :other_school, purpose: :enrollment_or_transfer)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to federal representative' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :federal_representative)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to research organization' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :research_organization, research_purpose: :predictive_tests)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to accrediting agency' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :accrediting_agency)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to parent of dependent student' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             recipient_type: :parent, student_dependency_status: :dependent)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII otherwise permitted under 99.31' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true,
                             other_99_31_exception: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data and no other conditions met' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, data_type: :other_data) }
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data but contains no PII and no other conditions met' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: false)
        end
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data with PII but no other conditions met' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, data_type: :fafsa_data, contains_pii: true)
        end
        it { expect(tree.disclose?).to be false }
      end
    end
  end
end
