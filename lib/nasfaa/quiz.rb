# frozen_string_literal: true

module Nasfaa
  # Interactive quiz that tests the user's knowledge of FERPA/FAFSA/FTI
  # disclosure rules by presenting scenarios and asking for permit/deny.
  #
  # Two modes:
  #   Scenario mode (default) — draws from the 23 named scenarios in
  #     nasfaa_scenarios.yml, presenting descriptions and inputs.
  #   Random mode (--random) — generates arbitrary boolean DisclosureData
  #     combinations and evaluates them with the RuleEngine.
  #
  # Designed for testability: accepts injectable input/output streams.
  #
  # Usage:
  #   quiz = Nasfaa::Quiz.new
  #   correct, total = quiz.run
  #
  #   # Random mode:
  #   quiz = Nasfaa::Quiz.new(random: true)
  #   correct, total = quiz.run
  class Quiz
    RANDOM_QUESTION_COUNT = 10

    attr_reader :correct, :total

    def initialize(input: $stdin, output: $stdout, random: false)
      @input = input
      @output = output
      @random = random
      @engine = RuleEngine.new
      @correct = 0
      @total = 0
    end

    def run
      questions = build_questions
      questions.each_with_index do |question, index|
        present_question(question, index + 1, questions.length)
        answer = ask_permit_or_deny
        break if answer == :quit

        @total = index + 1
        check_answer(answer, question)
      end
      display_final_score
      [@correct, @total]
    end

    private

    def build_questions
      if @random
        Array.new(RANDOM_QUESTION_COUNT) { build_random_question }
      else
        Scenarios.all.shuffle
      end
    end

    def build_random_question
      fields_to_set = DisclosureData::FIELDS.sample(rand(1..5))
      inputs = fields_to_set.each_with_object({}) { |f, h| h[f] = true }
      data = DisclosureData.new(inputs)
      trace = @engine.evaluate(data)

      {
        description: nil,
        inputs: inputs,
        expected_result: trace.result,
        rule_id: trace.rule_id,
        citation: nil,
        random: true
      }
    end

    def present_question(question, number, total_count)
      @output.puts
      @output.puts '=' * 60
      @output.puts "Question #{number} of #{total_count}"
      @output.puts '=' * 60

      @output.puts
      if question.is_a?(Scenario)
        @output.puts question.description
        @output.puts
        @output.puts 'Inputs:'
        question.inputs.each do |field, value|
          @output.puts "  #{field}: #{value}"
        end
      else
        @output.puts 'Given the following disclosure parameters:'
        @output.puts
        question[:inputs].each do |field, value|
          @output.puts "  #{field}: #{value}"
        end
        @output.puts
        @output.puts '(All other fields are false.)'
      end
    end

    def ask_permit_or_deny
      @output.puts

      if single_key?
        @output.print '[p/d/q] > '
        loop do
          case read_char
          when 'p' then return :permit
          when 'd' then return :deny
          when 'q' then return :quit
          end
        end
      else
        @output.print 'Should this disclosure be permitted or denied? [permit/deny/quit] > '
        loop do
          answer = @input.gets&.strip&.downcase
          case answer
          when 'permit', 'p' then return :permit
          when 'deny', 'd' then return :deny
          when 'quit', 'q' then return :quit
          when nil
            raise 'Unexpected end of input'
          else
            @output.print 'Please answer permit, deny, or quit > '
          end
        end
      end
    end

    def single_key?
      @input.respond_to?(:getch)
    end

    def read_char
      char = @input.getch.downcase
      @output.print char
      @output.puts
      char
    end

    def check_answer(answer, question)
      expected = if question.is_a?(Scenario)
                   question.expected_result
                 else
                   question[:expected_result]
                 end

      # permit_with_scope and permit_with_caution count as "permit"
      expected_simple = %i[permit permit_with_scope permit_with_caution].include?(expected) ? :permit : :deny
      is_correct = answer == expected_simple
      @correct += 1 if is_correct

      @output.puts
      if is_correct
        @output.puts 'CORRECT!'
      else
        @output.puts 'INCORRECT.'
      end

      @output.puts "Answer: #{expected}"

      rule_id = question.is_a?(Scenario) ? question.expected_rule_id : question[:rule_id]
      citation = question.is_a?(Scenario) ? question.citation : question[:citation]

      @output.puts "Rule:     #{rule_id}"
      @output.puts "Citation: #{citation}" if citation
      @output.puts "Score:    #{@correct}/#{@total}"
    end

    def display_final_score
      @output.puts
      @output.puts '=' * 60
      @output.puts "FINAL SCORE: #{@correct}/#{@total}"
      pct = @total.positive? ? (@correct * 100.0 / @total).round(0) : 0
      @output.puts "#{pct}% correct"
      @output.puts '=' * 60
    end
  end
end
