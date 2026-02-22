# frozen_string_literal: true

require 'stringio'

module Nasfaa
  # Non-interactive evaluator that accepts a compact string of y/n characters
  # to navigate the walkthrough DAG, with an optional trailing p/d assertion.
  #
  # Each y/n character answers one question in the DAG in order. An optional
  # trailing p (permit) or d (deny) asserts the expected result.
  #
  # Usage:
  #   eval = Nasfaa::Evaluate.new('ynnyp')
  #   trace = eval.run   # => Trace (permit, FTI_R3_scholarship_with_consent)
  #
  #   eval = Nasfaa::Evaluate.new('yy')
  #   trace = eval.run   # => Trace (permit, FTI_R1_student), no assertion
  class Evaluate
    VALID_CHARS = %w[y n p d].freeze

    attr_reader :trace, :assertion, :passed

    def initialize(compact_string, output: $stdout)
      @output = output
      @answers, @assertion = parse(compact_string)
      @trace = nil
      @passed = nil
    end

    def run
      input = StringIO.new(@answers.map { |c| "#{c}\n" }.join)
      silent = StringIO.new
      walkthrough = Walkthrough.new(input: input, output: silent)
      @trace = walkthrough.run

      cross_verify(walkthrough)
      check_assertion
      display_result
      @trace
    end

    private

    def parse(compact_string)
      raise ArgumentError, 'Input string cannot be empty' if compact_string.nil? || compact_string.empty?

      chars = compact_string.downcase.chars
      invalid = chars.reject { |c| VALID_CHARS.include?(c) }
      raise ArgumentError, "Invalid characters: #{invalid.join(', ')}" unless invalid.empty?

      assertion = nil
      answers = []

      chars.each do |c|
        if %w[p d].include?(c) && assertion.nil?
          assertion = c == 'p' ? :permit : :deny
        elsif assertion
          raise ArgumentError, "Unexpected character '#{c}' after assertion"
        else
          answers << c
        end
      end

      raise ArgumentError, 'No y/n answers provided' if answers.empty? && assertion.nil?

      [answers, assertion]
    end

    def cross_verify(walkthrough)
      data = walkthrough.to_disclosure_data
      engine_trace = RuleEngine.new.evaluate(data)
      return if engine_trace.rule_id == @trace.rule_id

      @output.puts "WARNING: DAG returned #{@trace.rule_id} but RuleEngine returned #{engine_trace.rule_id}"
    end

    def check_assertion
      return unless @assertion

      result_simple = %i[permit permit_with_scope permit_with_caution].include?(@trace.result) ? :permit : :deny
      @passed = result_simple == @assertion
    end

    def display_result
      @output.puts "Result:   #{@trace.result}"
      @output.puts "Rule:     #{@trace.rule_id}"
      @output.puts "Path:     #{@trace.path.join(' -> ')}"
      display_assertion if @assertion
    end

    def display_assertion
      expected = @assertion
      if @passed
        @output.puts "Assertion: PASS (expected #{expected})"
      else
        @output.puts "Assertion: FAIL (expected #{expected}, got #{@trace.result})"
      end
    end
  end
end
