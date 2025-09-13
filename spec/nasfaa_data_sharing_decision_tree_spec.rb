# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe NasfaaDataSharingDecisionTree do
  let(:tree) { described_class.new(disclosure_request) }

  describe '#disclose?' do
    context 'when disclosure includes FTI' do
      context 'and disclosure is to student' do
        let(:data) do
          {
            includes_fti: true,
            disclosure_to_student: true
          }
        end
        let(:disclosure_request) { DisclosureData.new(data) }

        it { expect(tree.disclose?).to be true }
      end

      context 'and disclosure is NOT to student' do
        let(:data) do
          {
            includes_fti: true,
            disclosure_to_student: false,
            used_for_aid_admin: true
          }
        end
        let(:disclosure_request) { DisclosureData.new(data) }

        it 'may be released to a legitimate interest' do
          data[:to_school_official_legitimate_interest] = true

          expect(tree.disclose?).to be true
        end

        it 'may be NOT released to a NON-legitimate interest' do
          data[:to_school_official_legitimate_interest] = false

          expect(tree.disclose?).to be false
        end

        it 'may be released to a scholarship organization with explicit written consent' do
          data[:disclosure_to_scholarship_org] = true
          data[:explicit_written_consent] = true

          expect(tree.disclose?).to be true
        end

        it 'may be NOT released to a scholarship organization WITHOUT explicit written consent' do
          data[:disclosure_to_scholarship_org] = true
          data[:explicit_written_consent] = false

          expect(tree.disclose?).to be false
        end
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
