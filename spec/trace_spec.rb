# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe Nasfaa::Trace do
  describe '#permitted?' do
    it 'is true for permit' do
      trace = described_class.new(result: :permit)
      expect(trace.permitted?).to be true
    end

    it 'is true for permit_with_scope' do
      trace = described_class.new(result: :permit_with_scope)
      expect(trace.permitted?).to be true
    end

    it 'is true for permit_with_caution' do
      trace = described_class.new(result: :permit_with_caution)
      expect(trace.permitted?).to be true
    end

    it 'is false for deny' do
      trace = described_class.new(result: :deny)
      expect(trace.permitted?).to be false
    end
  end

  describe '#denied?' do
    it 'is true for deny' do
      trace = described_class.new(result: :deny)
      expect(trace.denied?).to be true
    end

    it 'is false for permit' do
      trace = described_class.new(result: :permit)
      expect(trace.denied?).to be false
    end
  end

  describe 'fields' do
    let(:trace) do
      described_class.new(
        rule_id: 'FERPA_R3_judicial_or_finaid_related',
        result: :permit_with_caution,
        path: %w[FTI_R1_student FTI_R2_aid_admin_school_official FERPA_R3_judicial_or_finaid_related],
        scope_note: nil,
        caution_note: 'Consult counsel.'
      )
    end

    it 'exposes rule_id' do
      expect(trace.rule_id).to eq('FERPA_R3_judicial_or_finaid_related')
    end

    it 'exposes path of evaluated rules' do
      expect(trace.path).to eq(%w[FTI_R1_student FTI_R2_aid_admin_school_official FERPA_R3_judicial_or_finaid_related])
    end

    it 'exposes caution_note' do
      expect(trace.caution_note).to eq('Consult counsel.')
    end

    it 'exposes nil scope_note' do
      expect(trace.scope_note).to be_nil
    end
  end

  describe 'integration with RuleEngine' do
    let(:engine) { Nasfaa::RuleEngine.new }

    it 'returns a Trace from evaluate' do
      data = Nasfaa::DisclosureData.new(includes_fti: true, disclosure_to_student: true)
      trace = engine.evaluate(data)
      expect(trace).to be_a(described_class)
    end

    it 'records the path of rules evaluated before matching' do
      data = Nasfaa::DisclosureData.new(includes_fti: true)
      trace = engine.evaluate(data)
      expect(trace.rule_id).to eq('FTI_DENY_default')
      expect(trace.path).to eq(%w[FTI_R1_student FTI_R2_aid_admin_school_official FTI_R2b_aid_admin_deny
                                  FTI_R3_scholarship_with_consent FTI_DENY_default])
    end

    it 'first-match path is just one rule when it matches immediately' do
      data = Nasfaa::DisclosureData.new(includes_fti: true, disclosure_to_student: true)
      trace = engine.evaluate(data)
      expect(trace.path).to eq(%w[FTI_R1_student])
    end

    it 'non-FTI default traverses all non-FTI rules' do
      data = Nasfaa::DisclosureData.new
      trace = engine.evaluate(data)
      expect(trace.rule_id).to eq('NONFTI_DENY_default')
      expect(trace.path.length).to eq(21)
      expect(trace.path.last).to eq('NONFTI_DENY_default')
    end
  end
end
