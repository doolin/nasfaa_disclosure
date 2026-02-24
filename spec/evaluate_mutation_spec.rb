# frozen_string_literal: true

require 'stringio'
require_relative 'spec_helper'

# ---------------------------------------------------------------------------
# Input mutation testing for Nasfaa::Evaluate
#
# Five mutation categories systematically exercise the evaluator boundary:
#
#   1. Prefix exhaustion  — every truncation of every known path raises
#                           ArgumentError with a helpful message
#   2. Suffix extension   — one extra answer produces a WARNING and the
#                           correct terminal result
#   3. Single-char flip   — flipping each y↔n in every known path routes
#                           to the expected terminal (precomputed) or raises
#                           ArgumentError (never RuntimeError)
#   4. Invalid chars      — every non-y/n/p/d character, including the full
#                           ASCII printable set, whitespace, control chars,
#                           and 🐙, raises ArgumentError /Invalid characters/
#   5. Assertion polarity — correct assertion → passed true;
#                           wrong assertion   → passed false + FAIL output
# ---------------------------------------------------------------------------

# Precomputes the expected outcome of an arbitrary compact string at spec
# load time.  Returns a Trace on success or an ArgumentError on failure.
# Called inside describe/context blocks (collection phase), not inside `it`.
module MutationHelper
  def self.run_silent(compact)
    Nasfaa::Evaluate.new(compact, output: StringIO.new).run
  rescue ArgumentError => e
    e
  end
end

# ---------------------------------------------------------------------------
# Invalid character set — go bananas
# ---------------------------------------------------------------------------
INVALID_CHARS = (
  # Uppercase: omit D/N/P/Y because parse() lowercases input before validation,
  # so those are silently accepted as their valid lowercase counterparts.
  (('A'..'Z').to_a - %w[D N P Y]) +
  (('a'..'z').to_a - %w[y n p d]) + # every lowercase except the four valid ones
  ('0'..'9').to_a +
  [
    ' ', "\t", "\n", "\r", # whitespace
    '!', '@', '#', '$', '%', '^',
    '&', '*', '(', ')', '-', '+',
    '=', '[', ']', '{', '}', '|',
    ';', ':', ',', '.', '<', '>', '?', '/',
    '🐙' # 🐙 because correctness knows no bounds
  ]
).freeze

RSpec.describe Nasfaa::Evaluate, 'input mutation' do
  def run_evaluate(compact)
    output = StringIO.new
    evaluator = described_class.new(compact, output: output)
    trace = evaluator.run
    [trace, output.string, evaluator]
  end

  # -------------------------------------------------------------------------
  # Category 1 — Prefix exhaustion
  #
  # Every proper prefix of every known path must raise ArgumentError with
  # a message that names the prefix string and how many questions it answered.
  # -------------------------------------------------------------------------
  describe 'Category 1: prefix exhaustion' do
    TERMINAL_PATHS.each do |rule_id, info|
      answers = info[:compact]

      (1...answers.length).each do |prefix_len|
        prefix = answers[0, prefix_len]

        it "#{rule_id}: prefix '#{prefix}' (#{prefix_len}/#{answers.length}) raises ArgumentError" do
          output = StringIO.new
          evaluator = described_class.new(prefix, output: output)
          expect { evaluator.run }.to raise_error(
            ArgumentError,
            /Too few answers.*'#{Regexp.escape(prefix)}'.*#{prefix_len} question/
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Category 2 — Suffix extension
  #
  # Appending one extra character to a complete path should:
  #   • still reach the correct terminal (rule_id and result unchanged)
  #   • emit a WARNING with exact excess/provided/consumed counts
  # -------------------------------------------------------------------------
  describe 'Category 2: suffix extension' do
    TERMINAL_PATHS.each do |rule_id, info|
      path_len = info[:compact].length

      %w[y n].each do |extra|
        extended = info[:compact] + extra

        it "#{rule_id}: '#{info[:compact]}' + '#{extra}' → correct terminal with excess warning" do
          trace, output, = run_evaluate(extended)
          expect(trace.rule_id).to eq(rule_id)
          expect(trace.result).to eq(info[:result])
          expect(output).to match(
            /WARNING: 1 excess answer\(s\) ignored \(#{path_len + 1} provided, #{path_len} consumed\)/
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Category 3 — Single-character flip (y ↔ n)
  #
  # For each position in each known path, flip the character and verify the
  # evaluator reaches the precomputed expected terminal or raises ArgumentError.
  # Expected outcomes are computed at spec load time (collection phase) so
  # that any subsequent change to the routing logic fails the test.
  # -------------------------------------------------------------------------
  describe 'Category 3: single-character flip' do
    TERMINAL_PATHS.each do |rule_id, info|
      answers = info[:compact]

      answers.chars.each_with_index do |char, i|
        flipped = answers.dup
        flipped[i] = char == 'y' ? 'n' : 'y'

        expected = MutationHelper.run_silent(flipped)

        if expected.is_a?(ArgumentError)
          it "#{rule_id}[#{i}] '#{char}'→'#{flipped[i]}': '#{flipped}' raises ArgumentError" do
            output = StringIO.new
            evaluator = described_class.new(flipped, output: output)
            expect { evaluator.run }.to raise_error(ArgumentError)
          end
        else
          flip_rule_id = expected.rule_id
          flip_result  = expected.result

          it "#{rule_id}[#{i}] '#{char}'→'#{flipped[i]}': '#{flipped}' → #{flip_rule_id}" do
            trace, = run_evaluate(flipped)
            expect(trace.rule_id).to eq(flip_rule_id)
            expect(trace.result).to eq(flip_result)
          end
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Category 4 — Invalid character injection
  #
  # Every character outside {y, n, p, d} injected at the start of a valid
  # string must raise ArgumentError matching /Invalid characters/.
  # Covers uppercase, lowercase (minus the four valid), digits, punctuation,
  # whitespace, and the 🐙 easter egg.
  # -------------------------------------------------------------------------
  describe 'Category 4: invalid character injection' do
    INVALID_CHARS.each do |char|
      label = char.encode('UTF-8').inspect.gsub('"', "'")

      it "rejects #{label} injected into a valid string" do
        expect { described_class.new("#{char}yy") }.to raise_error(
          ArgumentError,
          /Invalid characters/
        )
      end
    end
  end

  # -------------------------------------------------------------------------
  # Category 5 — Assertion polarity
  #
  # For every path:
  #   • correct assertion (p for permit family, d for deny) → passed == true
  #   • wrong assertion                                      → passed == false,
  #                                                            output includes FAIL
  # -------------------------------------------------------------------------
  describe 'Category 5: assertion polarity' do
    TERMINAL_PATHS.each do |rule_id, info|
      correct = assertion_char(info[:result])
      wrong   = correct == 'p' ? 'd' : 'p'

      it "#{rule_id}: correct assertion '#{correct}' → passed == true" do
        _, _, evaluator = run_evaluate(info[:compact] + correct)
        expect(evaluator.passed).to be true
      end

      it "#{rule_id}: wrong assertion '#{wrong}' → passed == false with FAIL output" do
        _, output, evaluator = run_evaluate(info[:compact] + wrong)
        expect(evaluator.passed).to be false
        expect(output).to include('Assertion: FAIL')
      end
    end
  end
end
