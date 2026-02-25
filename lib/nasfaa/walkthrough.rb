# frozen_string_literal: true

require 'yaml'

module Nasfaa
  # Interactive walkthrough engine that steps through the NASFAA Data Sharing
  # Decision Tree one question at a time, navigating the DAG defined in
  # nasfaa_questions.yml.
  #
  # The engine presents each question with its PDF box number and help text,
  # collects a yes/no answer, and follows the corresponding edge to the next
  # node. When a result node is reached, it displays the decision, rule ID,
  # regulatory citation, and the full path of questions traversed.
  #
  # Designed for testability: accepts injectable input/output streams.
  #
  # Usage:
  #   walkthrough = Nasfaa::Walkthrough.new
  #   trace = walkthrough.run   # interactive session, returns Trace
  #
  #   # In tests:
  #   input = StringIO.new("yes\nno\nyes\n")
  #   output = StringIO.new
  #   walkthrough = Nasfaa::Walkthrough.new(input: input, output: output)
  #   trace = walkthrough.run
  class Walkthrough
    include BoxDraw

    QUESTIONS_PATH = File.expand_path('../../nasfaa_questions.yml', __dir__)

    attr_reader :answers, :path

    def initialize(input: $stdin, output: $stdout, questions_path: QUESTIONS_PATH, colorizer: Colorizer.new, pdf_text: false)
      @input = input
      @output = output
      @colorizer = colorizer
      @pdf_text = pdf_text
      data = YAML.safe_load_file(questions_path)
      @start = data['start']
      @nodes = data['nodes']
      @answers = {}
      @path = []
    end

    # Runs the interactive walkthrough from the start node to a result.
    # Returns a Nasfaa::Trace with the decision and path.
    def run
      current = @start

      loop do
        node = @nodes[current]
        raise "Unknown node: #{current}" unless node

        if node['type'] == 'result'
          display_result(node)
          return build_trace(node)
        end

        @path << current
        response = ask_question(node)
        if response == :quit
          @output.puts
          @output.puts 'Walkthrough ended.'
          return nil
        end

        record_answer(node, response)
        current = response ? node['on_yes'] : node['on_no']
      end
    end

    # Builds a DisclosureData from the answers collected during the walkthrough.
    # Useful for cross-verifying the DAG result against the RuleEngine.
    def to_disclosure_data
      DisclosureData.new(@answers)
    end

    private

    def ask_question(node)
      @output.puts
      @output.puts box_top("Box #{node['box']}")
      @output.puts box_line(node['text'])
      if @pdf_text && node['pdf_text']
        wrap_text("PDF: #{node['pdf_text']}", INNER_WIDTH).each do |line|
          @output.puts box_line(@colorizer.dim(line))
        end
      end
      @output.puts box_line("(#{node['help']})") if node['help']
      @output.puts box_bottom

      if single_key?
        @output.print '[y/n/q] > '
        loop do
          case read_char
          when 'y' then return true
          when 'n' then return false
          when 'q' then return :quit
          end
        end
      else
        @output.print '[yes/no] > '
        loop do
          answer = @input.gets&.strip&.downcase
          case answer
          when 'yes', 'y' then return true
          when 'no', 'n' then return false
          when 'quit', 'q' then return :quit
          when nil
            raise 'Unexpected end of input'
          else
            @output.print 'Please answer yes or no > '
          end
        end
      end
    end

    def single_key?
      @input.respond_to?(:getch)
    end

    def read_char
      raw = @input.getch
      raise 'Unexpected end of input' if raw.nil?

      # Ctrl-C (\x03) and Ctrl-\ (\x1c): treat as quit without echoing control chars
      if ["\x03", "\x1c"].include?(raw)
        @output.puts
        return 'q'
      end

      char = raw.downcase
      if %w[y n q].include?(char)
        @output.print char
        @output.puts
      end
      char
    end

    def record_answer(node, response)
      fields = node['fields'] || [node['field']]
      fields.each { |f| @answers[f.to_sym] = response }
    end

    def display_result(node)
      result_text = node['result'].upcase
      colored_result = node['result'].start_with?('permit') ? @colorizer.permit(result_text) : @colorizer.deny(result_text)
      @output.puts
      @output.puts box_heavy_top
      @output.puts box_heavy_line("RESULT: #{colored_result}")
      @output.puts box_heavy_divider
      @output.puts box_heavy_line(node['message'])
      @output.puts box_heavy_line
      @output.puts box_heavy_line(@colorizer.dim("Rule:     #{node['rule_id']}"))
      @output.puts box_heavy_line(@colorizer.dim("Citation: #{node['citation']}"))
      @output.puts box_heavy_line("Path:     #{@path.join(' -> ')}")
      @output.puts box_heavy_bottom
    end

    def build_trace(node)
      Trace.new(
        rule_id: node['rule_id'],
        result: node['result'].to_sym,
        path: @path
      )
    end
  end
end
