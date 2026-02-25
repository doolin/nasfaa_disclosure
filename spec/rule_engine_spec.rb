# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe Nasfaa::RuleEngine do
  let(:engine) { described_class.new }

  describe '#evaluate' do
    context 'FTI branch' do
      it 'permits disclosure to student' do
        data = Nasfaa::DisclosureData.new(includes_fti: true, disclosure_to_student: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FTI_R1_student')
        expect(result[:result]).to eq(:permit)
      end

      it 'permits aid admin with school official LEI' do
        data = Nasfaa::DisclosureData.new(includes_fti: true, used_for_aid_admin: true,
                                          to_school_official_legitimate_interest: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FTI_R2_aid_admin_school_official')
        expect(result[:result]).to eq(:permit)
      end

      it 'denies aid admin without school official LEI' do
        data = Nasfaa::DisclosureData.new(includes_fti: true, used_for_aid_admin: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FTI_R2b_aid_admin_deny')
        expect(result[:result]).to eq(:deny)
      end

      it 'permits scholarship org with explicit written consent' do
        data = Nasfaa::DisclosureData.new(includes_fti: true, disclosure_to_scholarship_org: true,
                                          explicit_written_consent: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FTI_R3_scholarship_with_consent')
        expect(result[:result]).to eq(:permit)
      end

      it 'denies FTI by default' do
        data = Nasfaa::DisclosureData.new(includes_fti: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FTI_DENY_default')
        expect(result[:result]).to eq(:deny)
      end
    end

    context 'non-FTI branch' do
      it 'permits disclosure to student' do
        data = Nasfaa::DisclosureData.new(disclosure_to_student: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FAFSA_R1_to_student')
        expect(result[:result]).to eq(:permit)
      end

      it 'permits FAFSA data for aid admin' do
        data = Nasfaa::DisclosureData.new(is_fafsa_data: true, used_for_aid_admin: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FAFSA_R3_used_for_aid_admin')
      end

      it 'permits FAFSA data without PII' do
        data = Nasfaa::DisclosureData.new(is_fafsa_data: true, contains_pii: false)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FAFSA_R7_no_pii')
        expect(result[:result]).to eq(:permit)
      end

      it 'permits with FERPA written consent' do
        data = Nasfaa::DisclosureData.new(ferpa_written_consent: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FERPA_R0_written_consent')
      end

      it 'permits judicial order with caution note' do
        data = Nasfaa::DisclosureData.new(due_to_judicial_order_or_subpoena_or_financial_aid: true)
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('FERPA_R3_judicial_or_finaid_related')
        expect(result[:result]).to eq(:permit_with_caution)
        expect(result[:caution_note]).to include('consult counsel')
      end

      it 'denies non-FTI by default' do
        data = Nasfaa::DisclosureData.new
        result = engine.evaluate(data)
        expect(result[:rule_id]).to eq('NONFTI_DENY_default')
        expect(result[:result]).to eq(:deny)
      end
    end

    context 'agreement with DecisionTree' do
      it 'agrees on permit for every existing spec scenario' do
        tree_permit_scenarios = [
          { disclosure_to_student: true },
          { includes_fti: true, disclosure_to_student: true },
          { includes_fti: true, used_for_aid_admin: true, to_school_official_legitimate_interest: true },
          { is_fafsa_data: true, used_for_aid_admin: true },
          { is_fafsa_data: true, disclosure_to_scholarship_org: true, explicit_written_consent: true },
          { is_fafsa_data: true, research_promote_attendance: true },
          { is_fafsa_data: true, hea_written_consent: true },
          { is_fafsa_data: true, contains_pii: false },
          { ferpa_written_consent: true },
          { directory_info_and_not_opted_out: true },
          { to_school_official_legitimate_interest: true },
          { to_other_school_enrollment_transfer: true },
          { to_authorized_representatives: true },
          { to_research_org_ferpa: true },
          { to_accrediting_agency: true },
          { parent_of_dependent_student: true },
          { otherwise_permitted_under_99_31: true }
        ]

        tree_permit_scenarios.each do |scenario|
          data = Nasfaa::DisclosureData.new(scenario)
          tree = Nasfaa::DecisionTree.new(data)
          result = engine.evaluate(data)

          expect(tree.disclose?).to be(true), "DecisionTree disagrees on #{scenario}"
          expect(%i[permit permit_with_scope permit_with_caution]).to include(result[:result]),
                                                                      "RuleEngine disagrees on #{scenario}"
        end
      end

      it 'agrees on deny for every existing deny scenario' do
        tree_deny_scenarios = [
          {},
          { includes_fti: true },
          { includes_fti: true, used_for_aid_admin: true },
          { is_fafsa_data: true, contains_pii: true },
          { is_fafsa_data: false }
        ]

        tree_deny_scenarios.each do |scenario|
          data = Nasfaa::DisclosureData.new(scenario)
          tree = Nasfaa::DecisionTree.new(data)
          result = engine.evaluate(data)

          expect(tree.disclose?).to be(false), "DecisionTree disagrees on #{scenario}"
          expect(result[:result]).to eq(:deny), "RuleEngine disagrees on #{scenario}"
        end
      end
    end
  end

  describe '#rules' do
    it 'loads all rules from YAML' do
      expect(engine.rules.length).to eq(21)
    end

    it 'has a catch-all for FTI' do
      fti_default = engine.rules.find { |r| r['id'] == 'FTI_DENY_default' }
      expect(fti_default['when_all']).to eq(['includes_fti'])
    end

    it 'has a catch-all for non-FTI' do
      nonfti_default = engine.rules.find { |r| r['id'] == 'NONFTI_DENY_default' }
      expect(nonfti_default['when_all']).to eq(['!includes_fti'])
    end
  end
end
