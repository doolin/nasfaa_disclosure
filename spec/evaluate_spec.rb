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
    TERMINAL_PATHS.each do |rule_id, info|
      it "evaluates #{rule_id}" do
        compact = info[:compact] + assertion_char(info[:result])
        trace, output, = run_evaluate(compact)
        expect(trace.rule_id).to eq(rule_id)
        expect(trace.result).to eq(info[:result])
        expect(output).to include(rule_id)
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
      expect(output).to include('RESULT:')
      expect(output).not_to include('Assertion:')
    end
  end

  # ------------------------------------------------------------------
  # Output formatting
  # ------------------------------------------------------------------
  describe 'output formatting' do
    it 'wraps result in a heavy box-drawn result card' do
      _, output, = run_evaluate('ynnyp')
      expect(output).to include('╔')
      expect(output).to include('╚')
    end

    it 'displays result, rule, and path' do
      _, output, = run_evaluate('ynnyp')
      expect(output).to include('RESULT: permit')
      expect(output).to include('Rule: FTI_R3_scholarship_with_consent')
      expect(output).to include('fti_scholarship')
    end

    it 'displays scenario name and citation for named scenarios' do
      _, output, = run_evaluate('yy') # FTI_R1_student → student_views_own_fti
      expect(output).to include('Student Views Own Tax Return Information')
      expect(output).to include('Citation:')
    end

    it 'omits scenario section when no named scenario matches the rule' do
      output = StringIO.new
      evaluator = described_class.new('yy', output: output)
      allow(Nasfaa::Scenarios).to receive(:find_by_rule_id).and_return(nil)
      evaluator.run
      expect(output.string).not_to include('Citation:')
      expect(output.string).to include('RESULT:')
    end
  end

  # ------------------------------------------------------------------
  # Too short — assertion without any y/n answers
  # ------------------------------------------------------------------
  describe 'too short (assertion-only string)' do
    it 'raises ArgumentError for assertion-only permit string' do
      expect { described_class.new('p') }.to raise_error(ArgumentError, %r{No y/n answers provided})
    end

    it 'raises ArgumentError for assertion-only deny string' do
      expect { described_class.new('d') }.to raise_error(ArgumentError, %r{No y/n answers provided})
    end

    it 'raises at construction, not at run time' do
      expect { described_class.new('p') }.to raise_error(ArgumentError)
    end
  end

  # ------------------------------------------------------------------
  # Too long — more answers than the path consumes
  # ------------------------------------------------------------------
  describe 'too long (excess answers)' do
    it 'emits a warning when excess answers are provided' do
      # yy navigates to FTI_R1_student after 2 answers; the 3rd 'n' is excess
      _, output, = run_evaluate('yyn')
      expect(output).to include('WARNING')
      expect(output).to include('excess answer')
    end

    it 'warning reports the correct counts' do
      # 3 answers provided, 2 consumed (path length for FTI_R1_student)
      _, output, = run_evaluate('yyn')
      expect(output).to match(/1 excess.*3 provided.*2 consumed/)
    end

    it 'still returns the correct result despite excess answers' do
      trace, = run_evaluate('yyn')
      expect(trace.rule_id).to eq('FTI_R1_student')
    end

    it 'does not warn when the answer count exactly matches the path length' do
      _, output, = run_evaluate('yy')
      expect(output).not_to include('WARNING')
    end
  end

  # ------------------------------------------------------------------
  # Wrong characters
  # ------------------------------------------------------------------
  describe 'wrong characters' do
    it 'raises on a letter that is not y, n, p, or d' do
      expect { described_class.new('ynxn') }.to raise_error(ArgumentError, /Invalid characters/)
    end

    it 'raises on a digit in the string' do
      expect { described_class.new('y1n') }.to raise_error(ArgumentError, /Invalid characters/)
    end

    it 'raises on a space embedded in the string' do
      expect { described_class.new('y n') }.to raise_error(ArgumentError, /Invalid characters/)
    end

    it 'reports all invalid characters in the error message' do
      expect { described_class.new('axb') }.to raise_error(ArgumentError, /a.*x.*b|x.*a.*b|a, x, b/)
    end

    it 'raises on characters after assertion' do
      expect { described_class.new('ynpn') }.to raise_error(ArgumentError, /after assertion/)
    end
  end

  # ------------------------------------------------------------------
  # Error handling (original)
  # ------------------------------------------------------------------
  describe 'error handling' do
    it 'raises on empty string' do
      expect { described_class.new('') }.to raise_error(ArgumentError, /empty/)
    end

    it 'raises on nil' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /empty/)
    end
  end

  # ------------------------------------------------------------------
  # Mid-path exhaustion — answers run out before a result node is reached
  # ------------------------------------------------------------------
  describe 'mid-path exhaustion' do
    it 'raises ArgumentError with helpful message when a single answer runs out' do
      # 'y' answers FTI? yes, but still needs student? answer
      output = StringIO.new
      evaluator = described_class.new('y', output: output)
      expect { evaluator.run }.to raise_error(ArgumentError, /Too few answers.*'y'.*1 question/)
    end

    it 'raises ArgumentError with helpful message for string "yn"' do
      # 'yn': FTI? yes, student? no — then needs aid_admin? answer
      output = StringIO.new
      evaluator = described_class.new('yn', output: output)
      expect { evaluator.run }.to raise_error(ArgumentError, /Too few answers.*'yn'.*2 question/)
    end

    it 'tells the user to add more y/n characters' do
      output = StringIO.new
      evaluator = described_class.new('yn', output: output)
      expect { evaluator.run }.to raise_error(ArgumentError, %r{add more y/n characters})
    end

    it 'is an ArgumentError, not a RuntimeError' do
      output = StringIO.new
      evaluator = described_class.new('yn', output: output)
      expect { evaluator.run }.to raise_error(ArgumentError)
    end
  end

  # ------------------------------------------------------------------
  # Cross-verification warning
  # ------------------------------------------------------------------
  describe 'cross-verification warning' do
    it 'emits a WARNING when DAG and RuleEngine disagree on the rule' do
      output = StringIO.new
      evaluator = described_class.new('yy', output: output)
      fake_trace = instance_double(Nasfaa::Trace, rule_id: 'DIFFERENT_RULE')
      fake_engine = instance_double(Nasfaa::RuleEngine, evaluate: fake_trace)
      allow(Nasfaa::RuleEngine).to receive(:new).and_return(fake_engine)
      evaluator.run
      expect(output.string).to include('WARNING')
      expect(output.string).to include('DAG returned')
      expect(output.string).to include('FTI_R1_student')
      expect(output.string).to include('DIFFERENT_RULE')
    end

    it 'does not emit a warning when DAG and RuleEngine agree' do
      _, output, = run_evaluate('yy')
      expect(output).not_to include('WARNING: DAG returned')
    end
  end
end
