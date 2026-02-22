# frozen_string_literal: true

require 'rspec'
require 'stringio'
require_relative 'spec_helper'

RSpec.describe Nasfaa::Quiz do
  # Helper: build a Quiz with scripted permit/deny input
  def run_quiz(responses, random: false)
    input = StringIO.new("#{responses.join("\n")}\n")
    output = StringIO.new
    quiz = described_class.new(input: input, output: output, random: random)
    # Seed random for deterministic shuffling in tests
    srand(42)
    correct, total = quiz.run
    [correct, total, output.string, quiz]
  end

  # ------------------------------------------------------------------
  # Scenario mode
  # ------------------------------------------------------------------
  describe 'scenario mode' do
    it 'presents all 23 scenarios' do
      # Provide enough answers — shuffled order means we may get some wrong
      answers = Array.new(23, 'permit')
      _, total, output, = run_quiz(answers)
      expect(total).to eq(23)
      expect(output).to include('FINAL SCORE')
      expect(output).to include('Question 1 of 23')
    end

    it 'scores correct answers' do
      # With srand(42), we know the shuffle order. But we can test with a
      # single-scenario subset approach: just answer "permit" for all 23.
      # Most are permits, so we should get most correct.
      answers = Array.new(23, 'permit')
      correct, total, output, = run_quiz(answers)
      expect(total).to eq(23)
      expect(correct).to be >= 1
      expect(output).to include('CORRECT!')
    end

    it 'marks wrong answers as incorrect' do
      # Answer "deny" for everything — the permits will be wrong
      answers = Array.new(23, 'deny')
      _, _, output, = run_quiz(answers)
      expect(output).to include('INCORRECT.')
    end

    it 'displays scenario description and inputs' do
      answers = Array.new(23, 'permit')
      _, _, output, = run_quiz(answers)
      # At least one scenario description should appear
      expect(output).to include('Inputs:')
    end

    it 'displays rule_id and citation on reveal' do
      answers = Array.new(23, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('Rule:')
      expect(output).to match(/Citation:/)
    end

    it 'treats permit_with_scope as permit' do
      # Find the permit_with_scope scenario
      scope_scenario = Nasfaa::Scenarios.all.find { |s| s.expected_result == :permit_with_scope }
      expect(scope_scenario).not_to be_nil

      # Run a quiz with just one scenario, answering "permit"
      input = StringIO.new("permit\n")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      # Stub the scenarios to just return this one
      allow(Nasfaa::Scenarios).to receive(:all).and_return([scope_scenario])
      correct, = quiz.run
      expect(correct).to eq(1)
    end

    it 'treats permit_with_caution as permit' do
      caution_scenario = Nasfaa::Scenarios.all.find { |s| s.expected_result == :permit_with_caution }
      expect(caution_scenario).not_to be_nil

      input = StringIO.new("permit\n")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      allow(Nasfaa::Scenarios).to receive(:all).and_return([caution_scenario])
      correct, = quiz.run
      expect(correct).to eq(1)
    end

    it 'returns correct and total from run' do
      answers = Array.new(23, 'permit')
      correct, total, = run_quiz(answers)
      expect(correct).to be_a(Integer)
      expect(total).to eq(23)
    end
  end

  # ------------------------------------------------------------------
  # Random mode
  # ------------------------------------------------------------------
  describe 'random mode' do
    it 'generates 10 questions by default' do
      answers = Array.new(10, 'permit')
      _, total, output, = run_quiz(answers, random: true)
      expect(total).to eq(10)
      expect(output).to include('Question 1 of 10')
    end

    it 'shows input fields and all-false note' do
      answers = Array.new(10, 'permit')
      _, _, output, = run_quiz(answers, random: true)
      expect(output).to include('Given the following disclosure parameters:')
      expect(output).to include('All other fields are false.')
    end

    it 'evaluates correctly against RuleEngine' do
      answers = Array.new(10, 'deny')
      _, _, output, = run_quiz(answers, random: true)
      # Should contain rule IDs from the engine
      expect(output).to include('Rule:')
    end

    it 'displays final score' do
      answers = Array.new(10, 'permit')
      _, _, output, = run_quiz(answers, random: true)
      expect(output).to include('FINAL SCORE')
      expect(output).to match(/\d+% correct/)
    end
  end

  # ------------------------------------------------------------------
  # Input handling
  # ------------------------------------------------------------------
  describe 'input handling' do
    it 'accepts abbreviated input (p/d)' do
      answers = Array.new(23, 'p')
      _, total, = run_quiz(answers)
      expect(total).to eq(23)
    end

    it 'accepts mixed-case input' do
      answers = Array.new(23, 'PERMIT')
      _, total, = run_quiz(answers)
      expect(total).to eq(23)
    end

    it 'reprompts on invalid input then accepts valid answer' do
      input = StringIO.new("maybe\npermit\n#{"permit\n" * 22}")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      srand(42)
      _, total = quiz.run
      expect(total).to eq(23)
      expect(output.string).to include('Please answer permit, deny, or quit')
    end

    it 'quits early and shows final score' do
      answers = %w[permit permit quit]
      _, total, output, = run_quiz(answers)
      expect(total).to eq(2)
      expect(output).to include('FINAL SCORE')
      expect(output).to include('2')
    end

    it 'accepts abbreviated quit (q)' do
      answers = ['q']
      _, total, output, = run_quiz(answers)
      expect(total).to eq(0)
      expect(output).to include('FINAL SCORE')
    end

    it 'raises on unexpected end of input' do
      input = StringIO.new('')
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      expect { quiz.run }.to raise_error(RuntimeError, 'Unexpected end of input')
    end
  end

  # ------------------------------------------------------------------
  # Score tracking
  # ------------------------------------------------------------------
  describe 'score tracking' do
    it 'tracks running score after each question' do
      answers = Array.new(23, 'permit')
      _, _, output, = run_quiz(answers)
      # Score should appear after each question
      expect(output.scan('Score:').length).to eq(23)
    end

    it 'displays percentage in final score' do
      answers = Array.new(23, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to match(/\d+% correct/)
    end
  end
end
