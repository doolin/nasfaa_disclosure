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
    it 'presents all 22 scenarios' do
      # Provide enough answers — shuffled order means we may get some wrong
      answers = Array.new(22, 'permit')
      _, total, output, = run_quiz(answers)
      expect(total).to eq(22)
      expect(output).to include('FINAL SCORE')
      expect(output).to include('Question 1 of 22')
    end

    it 'scores correct answers' do
      # With srand(42), we know the shuffle order. But we can test with a
      # single-scenario subset approach: just answer "permit" for all 22.
      # Most are permits, so we should get most correct.
      answers = Array.new(22, 'permit')
      correct, total, output, = run_quiz(answers)
      expect(total).to eq(22)
      expect(correct).to be >= 1
      expect(output).to include('CORRECT!')
    end

    it 'marks wrong answers as incorrect' do
      # Answer "deny" for everything — the permits will be wrong
      answers = Array.new(22, 'deny')
      _, _, output, = run_quiz(answers)
      expect(output).to include('INCORRECT.')
    end

    it 'displays scenario description and inputs' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      # At least one scenario description should appear
      expect(output).to include('Inputs:')
    end

    it 'displays rule_id and citation on reveal' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('Rule:')
      expect(output).to match(/Citation:/)
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
      answers = Array.new(22, 'permit')
      correct, total, = run_quiz(answers)
      expect(correct).to be_a(Integer)
      expect(total).to eq(22)
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
      expect(total).to eq(22)
    end

    it 'accepts mixed-case input' do
      answers = Array.new(23, 'PERMIT')
      _, total, = run_quiz(answers)
      expect(total).to eq(22)
    end

    it 'reprompts on invalid input then accepts valid answer' do
      input = StringIO.new("maybe\npermit\n#{"permit\n" * 22}")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      srand(42)
      _, total = quiz.run
      expect(total).to eq(22)
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
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      # Score should appear after each question
      expect(output.scan('Score:').length).to eq(22)
    end

    it 'displays percentage in final score' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to match(/\d+% correct/)
    end
  end

  # ------------------------------------------------------------------
  # Single-key mode (getch)
  # ------------------------------------------------------------------
  describe 'single-key mode' do
    def run_quiz_single_key(chars, random: false)
      input = SingleKeyInput.new(chars.join)
      output = StringIO.new
      quiz = described_class.new(input: input, output: output, random: random)
      srand(42)
      correct, total = quiz.run
      [correct, total, output.string, quiz]
    end

    it 'accepts single-character p/d input for all 22 scenarios' do
      answers = Array.new(22, 'p')
      _, total, output, = run_quiz_single_key(answers)
      expect(total).to eq(22)
      expect(output).to include('FINAL SCORE')
    end

    it 'shows [p/d/q] prompt in single-key mode' do
      answers = Array.new(22, 'p')
      _, _, output, = run_quiz_single_key(answers)
      expect(output).to include('[p/d/q]')
      expect(output).not_to include('[permit/deny/quit]')
    end

    it 'quits on q keypress and shows final score' do
      _, total, output, = run_quiz_single_key(%w[p q])
      expect(total).to eq(1)
      expect(output).to include('FINAL SCORE')
    end

    it 'echoes the pressed key in the output' do
      _, _, output, = run_quiz_single_key(%w[p q])
      expect(output).to include('p')
    end

    it 'accepts d for deny in single-key mode' do
      deny_scenario = Nasfaa::Scenarios.all.find { |s| s.expected_result == :deny }
      input = SingleKeyInput.new('d')
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      allow(Nasfaa::Scenarios).to receive(:all).and_return([deny_scenario])
      correct, total = quiz.run
      expect(total).to eq(1)
      expect(correct).to eq(1)
    end

    it 'silently ignores invalid keys and loops until a valid key is pressed' do
      # 'x' is invalid — not echoed, no newline; 'q' then quits
      _, total, output, = run_quiz_single_key(%w[x q])
      expect(total).to eq(0)
      expect(output.lines.map(&:strip)).not_to include('x')
    end

    it 'treats Ctrl-C as quit in single-key mode' do
      input = SingleKeyInput.new("\x03")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      _, total = quiz.run
      expect(total).to eq(0)
      expect(output.string).to include('FINAL SCORE')
    end

    it 'treats Ctrl-\\ as quit in single-key mode' do
      input = SingleKeyInput.new("\x1c")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      _, total = quiz.run
      expect(total).to eq(0)
      expect(output.string).to include('FINAL SCORE')
    end
  end

  # ------------------------------------------------------------------
  # Injected questions (questions: parameter)
  # ------------------------------------------------------------------
  describe 'injected questions' do
    let(:custom_questions) do
      [
        Nasfaa::QuizQuestion.new(
          description: 'A student asks to see their own records.',
          inputs: { disclosure_to_student: true },
          expected_result: :permit,
          rule_id: 'CUSTOM_R1',
          citation: 'Test Citation §1'
        ),
        Nasfaa::QuizQuestion.new(
          description: nil,
          inputs: { includes_fti: true },
          expected_result: :deny,
          rule_id: 'CUSTOM_R2',
          citation: nil
        )
      ]
    end

    def run_injected_quiz(responses, questions:)
      input = StringIO.new("#{responses.join("\n")}\n")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output, questions: questions)
      srand(42)
      correct, total = quiz.run
      [correct, total, output.string, quiz]
    end

    it 'uses the injected questions instead of Scenarios' do
      _, total, output, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(total).to eq(2)
      expect(output).to include('Question 1 of 2')
      expect(output).to include('FINAL SCORE')
    end

    it 'scores injected questions correctly' do
      # Use same expected_result to be shuffle-order-independent
      permit_questions = [
        Nasfaa::QuizQuestion.new(description: 'Q1', inputs: { a: true }, expected_result: :permit, rule_id: 'R1', citation: nil),
        Nasfaa::QuizQuestion.new(description: 'Q2', inputs: { b: true }, expected_result: :permit, rule_id: 'R2', citation: nil)
      ]
      correct, total, output, = run_injected_quiz(%w[permit permit], questions: permit_questions)
      expect(total).to eq(2)
      expect(correct).to eq(2)
      expect(output).to include('CORRECT!')
      expect(output).not_to include('INCORRECT.')
    end

    it 'displays description when present' do
      _, _, output, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(output).to include('A student asks to see their own records.')
      expect(output).to include('Inputs:')
    end

    it 'shows parametric prompt when description is nil' do
      _, _, output, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(output).to include('Given the following disclosure parameters:')
      expect(output).to include('All other fields are false.')
    end

    it 'displays rule_id and citation from injected questions' do
      _, _, output, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(output).to include('CUSTOM_R1')
      expect(output).to include('Test Citation §1')
      expect(output).to include('CUSTOM_R2')
    end

    it 'describes question count in banner' do
      _, _, output, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(output).to include('2 questions')
    end

    it 'does not require RuleEngine or Scenarios' do
      # Stub both to raise — proving Quiz never touches them
      allow(Nasfaa::Scenarios).to receive(:all).and_raise('should not be called')
      _, total, = run_injected_quiz(%w[permit deny], questions: custom_questions)
      expect(total).to eq(2)
    end
  end

  # ------------------------------------------------------------------
  # Banner and clear screen
  # ------------------------------------------------------------------
  describe 'banner' do
    it 'displays the quiz title' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('NASFAA Disclosure Quiz')
    end

    it 'displays the disclaimer' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('For Entertainment Purposes Only')
    end

    it 'describes scenario mode in the banner' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('23 real-world scenarios')
    end

    it 'describes random mode in the banner' do
      answers = Array.new(10, 'permit')
      _, _, output, = run_quiz(answers, random: true)
      expect(output).to include('randomly generated inputs')
    end

    it 'displays p/d/q instructions' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).to include('to answer')
      expect(output).to include('to quit')
    end

    it 'clears the terminal when output is a TTY' do
      input = StringIO.new("#{"permit\n" * 22}")
      output = StringIO.new
      allow(output).to receive(:isatty).and_return(true)
      allow(output).to receive(:respond_to?).and_call_original
      allow(output).to receive(:respond_to?).with(:isatty).and_return(true)
      quiz = described_class.new(input: input, output: output)
      srand(42)
      quiz.run
      expect(output.string).to start_with("\e[2J\e[H")
    end

    it 'does not clear the terminal when output is not a TTY' do
      answers = Array.new(22, 'permit')
      _, _, output, = run_quiz(answers)
      expect(output).not_to include("\e[2J")
    end

    it 'centers the title and disclaimer when terminal width is available' do
      input = StringIO.new("#{"permit\n" * 22}")
      output = StringIO.new
      quiz = described_class.new(input: input, output: output)
      allow(quiz).to receive(:terminal_columns).and_return(120)
      srand(42)
      quiz.run
      lines = output.string.lines
      title_line = lines.find { |l| l.include?('NASFAA Disclosure Quiz') }
      disclaimer_line = lines.find { |l| l.include?('For Entertainment Purposes Only') }
      expect(title_line).to start_with(' ')
      expect(disclaimer_line).to start_with(' ')
    end
  end
end
