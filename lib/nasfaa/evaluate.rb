# frozen_string_literal: true

require 'stringio'
require 'yaml'

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
    include BoxDraw

    VALID_CHARS = %w[y n p d].freeze

    attr_reader :trace, :assertion, :passed

    def initialize(compact_string, output: $stdout, colorizer: Colorizer.new, pdf_text: true)
      @output = output
      @colorizer = colorizer
      @pdf_text = pdf_text
      @answers, @assertion = parse(compact_string)
      @trace = nil
      @passed = nil
    end

    def run
      input = StringIO.new(@answers.map { |c| "#{c}\n" }.join)
      silent = StringIO.new
      walkthrough = Walkthrough.new(input: input, output: silent)
      begin
        @trace = walkthrough.run
      rescue RuntimeError => e
        raise unless e.message == 'Unexpected end of input'

        raise ArgumentError,
              "Too few answers: '#{@answers.join}' answered #{@answers.length} question(s) " \
              'but did not reach a result — add more y/n characters'
      end

      warn_excess_answers(walkthrough)
      cross_verify(walkthrough)
      check_assertion
      display_pdf_questions(walkthrough.path) if @pdf_text
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

      raise ArgumentError, 'No y/n answers provided' if answers.empty?

      [answers, assertion]
    end

    def warn_excess_answers(walkthrough)
      excess = @answers.length - walkthrough.path.length
      return unless excess.positive?

      @output.puts "WARNING: #{excess} excess answer(s) ignored (#{@answers.length} provided, #{walkthrough.path.length} consumed)"
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
      result_text = @trace.result.to_s
      colored_result = result_text.start_with?('permit') ? @colorizer.permit(result_text) : @colorizer.deny(result_text)
      scenario = Scenarios.find_by_rule_id(@trace.rule_id)

      @output.puts box_heavy_top
      @output.puts box_heavy_line("RESULT: #{colored_result}")
      @output.puts box_heavy_divider
      @output.puts box_heavy_line("Rule: #{@trace.rule_id}", colorize: @colorizer.method(:dim))
      if scenario
        @output.puts box_heavy_line("Citation: #{scenario.citation}", colorize: @colorizer.method(:dim))
        @output.puts box_heavy_line
        @output.puts box_heavy_line(scenario.name)
        @output.puts box_heavy_line
        @output.puts box_heavy_line(scenario.description)
        @output.puts box_heavy_line
      end
      @output.puts box_heavy_line("Path: #{@trace.path.join(' -> ')}")
      if @assertion
        @output.puts box_heavy_divider
        display_assertion
      end
      @output.puts box_heavy_bottom
    end

    def display_pdf_questions(path)
      nodes = YAML.safe_load_file(Walkthrough::QUESTIONS_PATH)['nodes']
      path.each do |node_id|
        node = nodes[node_id]
        @output.puts
        @output.puts box_top("Box #{node['box']}")
        @output.puts box_line(node['text'])
        wrap_text("PDF: #{node['pdf_text']}", INNER_WIDTH).each do |line|
          @output.puts box_line(@colorizer.yellow(line))
        end
        @output.puts box_line("(#{node['help']})") if node['help']
        @output.puts box_bottom
      end
    end

    def display_assertion
      expected = @assertion
      if @passed
        @output.puts box_heavy_line("Assertion: #{@colorizer.correct('PASS')} (expected #{expected})")
      else
        @output.puts box_heavy_line("Assertion: #{@colorizer.incorrect('FAIL')} (expected #{expected}, got #{@trace.result})")
      end
    end
  end
end
