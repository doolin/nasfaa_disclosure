# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe NasfaaDataSharingDecisionTree do
  let(:tree) { described_class.new(disclosure_request) }

  # Box 1
  describe '#includes_fti?' do
    context 'when disclosure includes FTI' do
      let(:disclosure_request) { DisclosureData.new(includes_fti: true) }
      it { expect(tree.includes_fti?).to be true }
    end

    context 'when disclosure does not include FTI' do
      let(:disclosure_request) { DisclosureData.new(includes_fti: false) }
      it { expect(tree.includes_fti?).to be false }
    end
  end

  # Box 2
  describe '#disclosure_to_student?' do
    context 'when disclosure is to student' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_student: true) }
      it { expect(tree.disclosure_to_student?).to be true }
    end

    context 'when disclosure is not to student' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_student: false) }
      it { expect(tree.disclosure_to_student?).to be false }
    end
  end

  # Box 3
  describe '#fafsa_data?' do
    context 'when data type is FAFSA data' do
      let(:disclosure_request) { DisclosureData.new(is_fafsa_data: true) }
      it { expect(tree.fafsa_data?).to be true }
    end

    context 'when data type is not FAFSA data' do
      let(:disclosure_request) { DisclosureData.new(is_fafsa_data: false) }
      it { expect(tree.fafsa_data?).to be false }
    end
  end

  # Box 4
  describe '#disclosure_to_contributor_parent_or_spouse?' do
    context 'when disclosure is to parent contributor' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(tree.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to spouse contributor' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: true) }
      it { expect(tree.disclosure_to_contributor_parent_or_spouse?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_contributor_parent_or_spouse: false) }
      it { expect(tree.disclosure_to_contributor_parent_or_spouse?).to be false }
    end
  end

  # Box 5
  describe '#used_for_aid_admin?' do
    context 'when purpose is financial aid' do
      let(:disclosure_request) { DisclosureData.new(used_for_aid_admin: true) }
      it { expect(tree.used_for_aid_admin?).to be true }
    end

    context 'when purpose is not financial aid' do
      let(:disclosure_request) { DisclosureData.new(used_for_aid_admin: false) }
      it { expect(tree.used_for_aid_admin?).to be false }
    end
  end

  # Box 6
  describe '#disclosure_to_scholarship_org?' do
    context 'when disclosure is to scholarship organization' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_scholarship_org: true) }
      it { expect(tree.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to tribal organization' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_scholarship_org: true) }
      it { expect(tree.disclosure_to_scholarship_org?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_scholarship_org: false) }
      it { expect(tree.disclosure_to_scholarship_org?).to be false }
    end
  end

  # Box 6b
  describe '#explicit_written_consent?' do
    context 'when explicit written consent is provided' do
      let(:disclosure_request) { DisclosureData.new(explicit_written_consent: true) }
      it { expect(tree.explicit_written_consent?).to be true }
    end

    context 'when explicit written consent is not provided' do
      let(:disclosure_request) { DisclosureData.new(explicit_written_consent: false) }
      it { expect(tree.explicit_written_consent?).to be false }
    end
  end

  # Box 7
  describe '#research_promote_attendance?' do
    context 'when purpose is research promoting college attendance' do
      let(:disclosure_request) { DisclosureData.new(research_promote_attendance: true) }
      it { expect(tree.research_promote_attendance?).to be true }
    end

    context 'when purpose is not research promoting college attendance' do
      let(:disclosure_request) { DisclosureData.new(research_promote_attendance: false) }
      it { expect(tree.research_promote_attendance?).to be false }
    end
  end

  # Box 8
  describe '#hea_written_consent?' do
    context 'when HEA consent is provided' do
      let(:disclosure_request) { DisclosureData.new(hea_written_consent: true) }
      it { expect(tree.hea_written_consent?).to be true }
    end

    context 'when HEA consent is not provided' do
      let(:disclosure_request) { DisclosureData.new(hea_written_consent: false) }
      it { expect(tree.hea_written_consent?).to be false }
    end
  end

  # Box 9
  describe '#contains_pii?' do
    context 'when disclosure contains PII' do
      let(:disclosure_request) { DisclosureData.new(contains_pii: true) }
      it { expect(tree.contains_pii?).to be true }
    end

    context 'when disclosure does not contain PII' do
      let(:disclosure_request) { DisclosureData.new(contains_pii: false) }
      it { expect(tree.contains_pii?).to be false }
    end
  end

  # Box 10
  describe '#ferpa_written_consent?' do
    context 'when FERPA consent is provided' do
      let(:disclosure_request) { DisclosureData.new(ferpa_written_consent: true) }
      it { expect(tree.ferpa_written_consent?).to be true }
    end

    context 'when FERPA consent is not provided' do
      let(:disclosure_request) { DisclosureData.new(ferpa_written_consent: false) }
      it { expect(tree.ferpa_written_consent?).to be false }
    end
  end

  # Box 11
  describe '#directory_info_and_not_opted_out?' do
    context 'when data type is directory information' do
      let(:disclosure_request) { DisclosureData.new(directory_info_and_not_opted_out: true) }
      it { expect(tree.directory_info_and_not_opted_out?).to be true }
    end

    context 'when data type is not directory information' do
      let(:disclosure_request) { DisclosureData.new(directory_info_and_not_opted_out: false) }
      it { expect(tree.directory_info_and_not_opted_out?).to be false }
    end
  end

  # Box 12
  describe '#to_school_official_legitimate_interest?' do
    context 'when disclosure is to school official with educational interest' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: true) }
      it { expect(tree.to_school_official_legitimate_interest?).to be true }
    end

    context 'when disclosure is to school official without educational interest' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(tree.to_school_official_legitimate_interest?).to be false }
    end

    context 'when disclosure is not to school official' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(tree.to_school_official_legitimate_interest?).to be false }
    end
  end

  # Box 13
  describe '#due_to_judicial_order_or_subpoena_or_financial_aid?' do
    context 'when legal basis is judicial order' do
      let(:disclosure_request) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(tree.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when legal basis is subpoena' do
      let(:disclosure_request) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(tree.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when purpose is financial aid related' do
      let(:disclosure_request) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true) }
      it { expect(tree.due_to_judicial_order_or_subpoena_or_financial_aid?).to be true }
    end

    context 'when none of the conditions are met' do
      let(:disclosure_request) { DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: false) }
      it { expect(tree.due_to_judicial_order_or_subpoena_or_financial_aid?).to be false }
    end
  end

  # Box 14
  describe '#to_other_school_enrollment_transfer?' do
    context 'when disclosure is to other school for enrollment' do
      let(:disclosure_request) { DisclosureData.new(to_other_school_enrollment_transfer: true) }
      it { expect(tree.to_other_school_enrollment_transfer?).to be true }
    end

    context 'when disclosure is to other school but not for enrollment' do
      let(:disclosure_request) { DisclosureData.new(to_other_school_enrollment_transfer: false) }
      it { expect(tree.to_other_school_enrollment_transfer?).to be false }
    end

    context 'when disclosure is not to other school' do
      let(:disclosure_request) { DisclosureData.new(to_other_school_enrollment_transfer: false) }
      it { expect(tree.to_other_school_enrollment_transfer?).to be false }
    end
  end

  # Box 15
  describe '#to_authorized_representatives?' do
    context 'when disclosure is to federal representative' do
      let(:disclosure_request) { DisclosureData.new(to_authorized_representatives: true) }
      it { expect(tree.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to state/local authority' do
      let(:disclosure_request) { DisclosureData.new(to_authorized_representatives: true) }
      it { expect(tree.to_authorized_representatives?).to be true }
    end

    context 'when disclosure is to neither' do
      let(:disclosure_request) { DisclosureData.new(to_authorized_representatives: false) }
      it { expect(tree.to_authorized_representatives?).to be false }
    end
  end

  # Box 16
  describe '#to_research_org_ferpa?' do
    context 'when disclosure is to research organization for predictive tests' do
      let(:disclosure_request) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(tree.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for student aid programs' do
      let(:disclosure_request) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(tree.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is to research organization for improving instruction' do
      let(:disclosure_request) { DisclosureData.new(to_research_org_ferpa: true) }
      it { expect(tree.to_research_org_ferpa?).to be true }
    end

    context 'when disclosure is not to research organization' do
      let(:disclosure_request) { DisclosureData.new(to_research_org_ferpa: false) }
      it { expect(tree.to_research_org_ferpa?).to be false }
    end
  end

  # Box 17
  describe '#to_accrediting_agency?' do
    context 'when disclosure is to accrediting agency' do
      let(:disclosure_request) { DisclosureData.new(to_accrediting_agency: true) }
      it { expect(tree.to_accrediting_agency?).to be true }
    end

    context 'when disclosure is not to accrediting agency' do
      let(:disclosure_request) { DisclosureData.new(to_accrediting_agency: false) }
      it { expect(tree.to_accrediting_agency?).to be false }
    end
  end

  # Box 18
  describe '#parent_of_dependent_student?' do
    context 'when disclosure is to parent of dependent student' do
      let(:disclosure_request) { DisclosureData.new(parent_of_dependent_student: true) }
      it { expect(tree.parent_of_dependent_student?).to be true }
    end

    context 'when disclosure is to parent of independent student' do
      let(:disclosure_request) { DisclosureData.new(parent_of_dependent_student: false) }
      it { expect(tree.parent_of_dependent_student?).to be false }
    end

    context 'when disclosure is not to parent' do
      let(:disclosure_request) { DisclosureData.new(parent_of_dependent_student: false) }
      it { expect(tree.parent_of_dependent_student?).to be false }
    end
  end

  # Box 19
  describe '#otherwise_permitted_under_99_31?' do
    context 'when otherwise permitted under 99.31' do
      let(:disclosure_request) { DisclosureData.new(otherwise_permitted_under_99_31: true) }
      it { expect(tree.otherwise_permitted_under_99_31?).to be true }
    end

    context 'when not otherwise permitted under 99.31' do
      let(:disclosure_request) { DisclosureData.new(otherwise_permitted_under_99_31: false) }
      it { expect(tree.otherwise_permitted_under_99_31?).to be false }
    end
  end

  # Box 10 - Direct test of the box10? method
  describe '#box10?' do
    context 'when all Box 10 conditions are met' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: false,
          is_fafsa_data: false,
          ferpa_written_consent: true
        )
      end

      it 'returns true' do
        expect(tree.box10?).to be true
      end
    end

    context 'when disclosure is to student' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: true,
          is_fafsa_data: false,
          ferpa_written_consent: true
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when disclosure is FAFSA data' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: false,
          is_fafsa_data: true,
          ferpa_written_consent: true
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when no FERPA consent is provided' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: false,
          is_fafsa_data: false,
          ferpa_written_consent: false
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when only disclosure_to_student is true' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: true,
          is_fafsa_data: false,
          ferpa_written_consent: false
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when only is_fafsa_data is true' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: false,
          is_fafsa_data: true,
          ferpa_written_consent: false
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when only ferpa_written_consent is true' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: true,
          is_fafsa_data: true,
          ferpa_written_consent: true
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end

    context 'when all conditions are false' do
      let(:disclosure_request) do
        DisclosureData.new(
          disclosure_to_student: false,
          is_fafsa_data: false,
          ferpa_written_consent: false
        )
      end

      it 'returns false' do
        expect(tree.box10?).to be false
      end
    end
  end

  # Box 11 - Direct test of the box11? method
  describe '#box11?' do
    context 'when directory_info_and_not_opted_out? is true' do
      let(:disclosure_request) do
        DisclosureData.new(directory_info_and_not_opted_out: true)
      end

      it 'returns true' do
        expect(tree.box11?).to be true
      end
    end

    context 'when directory_info_and_not_opted_out? is false' do
      let(:disclosure_request) do
        DisclosureData.new(directory_info_and_not_opted_out: false)
      end

      it 'returns false' do
        expect(tree.box11?).to be false
      end
    end

    context 'when directory_info_and_not_opted_out? is not specified' do
      let(:disclosure_request) do
        DisclosureData.new({})
      end

      it 'returns false' do
        expect(tree.box11?).to be false
      end
    end
  end

  # FTI Branch Predicates (Page 2)
  describe '#disclosure_to_student?' do
    context 'when FTI disclosure is to student' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_student: true) }
      it { expect(tree.disclosure_to_student?).to be true }
    end

    context 'when FTI disclosure is not to student' do
      let(:disclosure_request) { DisclosureData.new(disclosure_to_student: false) }
      it { expect(tree.disclosure_to_student?).to be false }
    end
  end

  describe '#used_for_aid_admin?' do
    context 'when FTI is for financial aid purposes' do
      let(:disclosure_request) { DisclosureData.new(used_for_aid_admin: true) }
      it { expect(tree.used_for_aid_admin?).to be true }
    end

    context 'when FTI is not for financial aid purposes' do
      let(:disclosure_request) { DisclosureData.new(used_for_aid_admin: false) }
      it { expect(tree.used_for_aid_admin?).to be false }
    end
  end

  describe '#disclosure_to_scholarship_org? && #explicit_written_consent?' do
    context 'when FTI disclosure is to scholarship organization with explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(disclosure_to_scholarship_org: true, explicit_written_consent: true)
      end
      it { expect(tree.disclosure_to_scholarship_org? && tree.explicit_written_consent?).to be true }
    end

    context 'when FTI disclosure is to tribal organization with explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(disclosure_to_scholarship_org: true, explicit_written_consent: true)
      end
      it { expect(tree.disclosure_to_scholarship_org? && tree.explicit_written_consent?).to be true }
    end

    context 'when FTI disclosure is to scholarship organization without explicit written consent' do
      let(:disclosure_request) do
        DisclosureData.new(disclosure_to_scholarship_org: true, explicit_written_consent: false)
      end
      it { expect(tree.disclosure_to_scholarship_org? && tree.explicit_written_consent?).to be false }
    end

    context 'when FTI disclosure is not to scholarship or tribal organization' do
      let(:disclosure_request) do
        DisclosureData.new(disclosure_to_scholarship_org: false, explicit_written_consent: true)
      end
      it { expect(tree.disclosure_to_scholarship_org? && tree.explicit_written_consent?).to be false }
    end
  end

  describe '#to_school_official_legitimate_interest?' do
    context 'when FTI disclosure is to school official with educational interest' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: true) }
      it { expect(tree.to_school_official_legitimate_interest?).to be true }
    end

    context 'when FTI disclosure is to school official without educational interest' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(tree.to_school_official_legitimate_interest?).to be false }
    end

    context 'when FTI disclosure is not to school official' do
      let(:disclosure_request) { DisclosureData.new(to_school_official_legitimate_interest: false) }
      it { expect(tree.to_school_official_legitimate_interest?).to be false }
    end
  end

  # Main disclose? method tests
  describe '#disclose?' do
    context 'when disclosure includes FTI' do
      context 'and disclosure is to student' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: true, disclosure_to_student: true) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is for financial aid purposes' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: true, used_for_aid_admin: true) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is to scholarship organization with explicit written consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: true, disclosure_to_scholarship_org: true, explicit_written_consent: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is to school official with legitimate interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: true, to_school_official_legitimate_interest: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and no other conditions are met' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: true) }
        it { expect(tree.disclose?).to be false }
      end
    end

    context 'when disclosure does not include FTI' do
      context 'and disclosure is to student' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, disclosure_to_student: true) }
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is to contributor parent or spouse' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, disclosure_to_contributor_parent_or_spouse: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data for financial aid purposes' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, used_for_aid_admin: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data to scholarship organization with explicit written consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, disclosure_to_scholarship_org: true,
                             explicit_written_consent: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data for research promoting college attendance' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, research_promote_attendance: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with HEA written consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, hea_written_consent: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII and has FERPA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true, ferpa_written_consent: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII and is directory information' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             directory_info_and_not_opted_out: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to school official with legitimate interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             to_school_official_legitimate_interest: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII under judicial order' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             due_to_judicial_order_or_subpoena_or_financial_aid: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to other school for enrollment' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             to_other_school_enrollment_transfer: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to federal representative' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             to_authorized_representatives: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to research organization' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true, to_research_org_ferpa: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to accrediting agency' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true, to_accrediting_agency: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII to parent of dependent student' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             parent_of_dependent_student: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is FAFSA data with PII otherwise permitted under 99.31' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true,
                             otherwise_permitted_under_99_31: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but has FERPA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, ferpa_written_consent: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but is directory information' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, directory_info_and_not_opted_out: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data and no other conditions met' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, is_fafsa_data: false) }
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data but contains no PII and no other conditions met' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: false) }
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data with PII but no other conditions met' do
        let(:disclosure_request) { DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: true) }
        it { expect(tree.disclose?).to be false }
      end

      # Additional edge cases to improve coverage
      context 'and disclosure is FAFSA data without PII but has FERPA consent' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: false, ferpa_written_consent: true)
        end
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data without PII but is directory information' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: false,
                             directory_info_and_not_opted_out: true)
        end
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is FAFSA data without PII but to school official with legitimate interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: true, contains_pii: false,
                             to_school_official_legitimate_interest: true)
        end
        it { expect(tree.disclose?).to be false }
      end

      context 'and disclosure is not FAFSA data but to school official with legitimate interest' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, to_school_official_legitimate_interest: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but under judicial order' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false,
                             due_to_judicial_order_or_subpoena_or_financial_aid: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but to other school for enrollment' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, to_other_school_enrollment_transfer: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but to authorized representatives' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, to_authorized_representatives: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but to research organization' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, to_research_org_ferpa: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but to accrediting agency' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, to_accrediting_agency: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but to parent of dependent student' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, parent_of_dependent_student: true)
        end
        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is not FAFSA data but otherwise permitted under 99.31' do
        let(:disclosure_request) do
          DisclosureData.new(includes_fti: false, is_fafsa_data: false, otherwise_permitted_under_99_31: true)
        end
        it { expect(tree.disclose?).to be true }
      end
    end
  end
end
