# frozen_string_literal: true

require 'rspec'
require 'stringio'
require_relative 'spec_helper'

RSpec.describe Nasfaa::Evaluate do
  def run_evaluate(compact_string)
    output = StringIO.new
    evaluator = described_class.new(compact_string, output: output)
    trace = evaluator.run
    [trace, output.string, evaluator]
  end

  # ------------------------------------------------------------------
  # All 22 terminal paths
  # ------------------------------------------------------------------
  describe 'all 22 terminal paths' do
    # Compact strings derived from walkthrough_spec cross-verification paths.
    # Each maps y=yes, n=no, with trailing assertion p=permit or d=deny.
    paths = {
      'FTI_R1_student' => { compact: 'yyp', result: :permit },
      'FTI_R2_aid_admin_school_official' => { compact: 'ynyyp', result: :permit },
      'FTI_R2b_aid_admin_deny' => { compact: 'ynynd', result: :deny },
      'FTI_R3_scholarship_with_consent' => { compact: 'ynnyp', result: :permit },
      'FTI_DENY_default' => { compact: 'ynnnd', result: :deny },
      'FAFSA_R1_to_student' => { compact: 'nyp', result: :permit },
      'FAFSA_R2_to_contributor_scope_limited' => { compact: 'nnyyp', result: :permit_with_scope },
      'FAFSA_R3_used_for_aid_admin' => { compact: 'nnynyp', result: :permit },
      'FAFSA_R4_scholarship_with_consent' => { compact: 'nnynnyyp', result: :permit },
      'FAFSA_R6_HEA_written_consent' => { compact: 'nnynnnnyp', result: :permit },
      'FAFSA_R7_no_pii' => { compact: 'nnynnnnnnp', result: :permit },
      'FERPA_R0_written_consent' => { compact: 'nnnyp', result: :permit },
      'FERPA_R1_directory_info' => { compact: 'nnnnyp', result: :permit },
      'FERPA_R2_school_official_LEI' => { compact: 'nnnnnyp', result: :permit },
      'FERPA_R3_judicial_or_finaid_related' => { compact: 'nnnnnnyp', result: :permit_with_caution },
      'FERPA_R4_other_school_enrollment' => { compact: 'nnnnnnnyp', result: :permit },
      'FERPA_R5_authorized_representatives' => { compact: 'nnnnnnnnyp', result: :permit },
      'FERPA_R6_research_org_predictive_tests_admin_aid_improve_instruction' => { compact: 'nnnnnnnnnyp', result: :permit },
      'FERPA_R7_accrediting_agency' => { compact: 'nnnnnnnnnnyp', result: :permit },
      'FERPA_R8_parent_of_dependent_student' => { compact: 'nnnnnnnnnnnyp', result: :permit },
      'FERPA_R9_otherwise_permitted_99_31' => { compact: 'nnnnnnnnnnnnyp', result: :permit },
      'NONFTI_DENY_default' => { compact: 'nnnnnnnnnnnnnd', result: :deny }
    }

    paths.each do |rule_id, info|
      it "evaluates #{rule_id}" do
        trace, output, = run_evaluate(info[:compact])
        expect(trace.rule_id).to eq(rule_id)
        expect(trace.result).to eq(info[:result])
        expect(output).to include("Rule:     #{rule_id}")
      end
    end
  end

  # ------------------------------------------------------------------
  # Assertion pass/fail
  # ------------------------------------------------------------------
  describe 'assertion' do
    it 'passes when assertion matches result' do
      _, output, evaluator = run_evaluate('yyp')
      expect(evaluator.passed).to be true
      expect(output).to include('Assertion: PASS')
    end

    it 'fails when assertion does not match result' do
      _, output, evaluator = run_evaluate('yyd')
      expect(evaluator.passed).to be false
      expect(output).to include('Assertion: FAIL')
    end

    it 'treats permit_with_scope as permit for assertion' do
      _, _, evaluator = run_evaluate('nnyyp')
      expect(evaluator.trace.result).to eq(:permit_with_scope)
      expect(evaluator.passed).to be true
    end

    it 'treats permit_with_caution as permit for assertion' do
      _, _, evaluator = run_evaluate('nnnnnnyp')
      expect(evaluator.trace.result).to eq(:permit_with_caution)
      expect(evaluator.passed).to be true
    end
  end

  # ------------------------------------------------------------------
  # No assertion
  # ------------------------------------------------------------------
  describe 'without assertion' do
    it 'returns result without assertion line' do
      _, output, evaluator = run_evaluate('yy')
      expect(evaluator.assertion).to be_nil
      expect(evaluator.passed).to be_nil
      expect(output).to include('Result:')
      expect(output).not_to include('Assertion:')
    end
  end

  # ------------------------------------------------------------------
  # Output formatting
  # ------------------------------------------------------------------
  describe 'output formatting' do
    it 'displays result, rule, and path' do
      _, output, = run_evaluate('ynnyp')
      expect(output).to include('Result:   permit')
      expect(output).to include('Rule:     FTI_R3_scholarship_with_consent')
      expect(output).to include('Path:     fti_check -> fti_to_student -> fti_aid_admin -> fti_scholarship')
    end
  end

  # ------------------------------------------------------------------
  # Error handling
  # ------------------------------------------------------------------
  describe 'error handling' do
    it 'raises on empty string' do
      expect { described_class.new('') }.to raise_error(ArgumentError, /empty/)
    end

    it 'raises on nil' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /empty/)
    end

    it 'raises on invalid characters' do
      expect { described_class.new('ynxn') }.to raise_error(ArgumentError, /Invalid characters/)
    end

    it 'raises on characters after assertion' do
      expect { described_class.new('ynpn') }.to raise_error(ArgumentError, /after assertion/)
    end

    it 'propagates unexpected end of input for too few answers' do
      output = StringIO.new
      evaluator = described_class.new('y', output: output)
      expect { evaluator.run }.to raise_error(RuntimeError, 'Unexpected end of input')
    end
  end
end
