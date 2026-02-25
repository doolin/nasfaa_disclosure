# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  minimum_coverage line: 90
  minimum_coverage_by_file 0
end

require 'nasfaa'
require_relative 'support/paths'

# A minimal IO mock that responds to getch, simulating single-key terminal mode.
# Used in walkthrough and quiz specs to test the getch-based input path.
class SingleKeyInput
  def initialize(chars)
    @chars = chars.chars
  end

  def getch
    char = @chars.shift
    raise 'Unexpected end of input' unless char

    char
  end
end

# A getch-capable input that returns nil when exhausted (mimics StringIO#getch
# after io/console is loaded).  Used to test the nil-guard in Walkthrough#read_char.
class NilGetchInput
  def initialize(chars)
    @chars = chars.chars
  end

  def getch
    @chars.shift # returns nil when empty
  end
end

# Simulates a non-TTY stdin (e.g., piped input) after io/console has been loaded.
# Responds to getch (which io/console patches onto all IO objects) but isatty
# returns false, so single_key? correctly falls back to line-based input.
class NonTtyInput
  def initialize(answers)
    @answers = answers.dup
  end

  def getch
    raise 'getch should not be called on a non-TTY input'
  end

  def isatty # rubocop:disable Naming/PredicateMethod
    false
  end

  def gets
    answer = @answers.shift
    "#{answer}\n" if answer
  end
end

# Simulates a real TTY stdin with io/console loaded.  Responds to both getch
# and isatty (returning true), so single_key? correctly uses single-key mode.
class TtyInput
  def initialize(chars)
    @chars = chars.chars
  end

  def getch
    char = @chars.shift
    raise 'Unexpected end of input' unless char

    char
  end

  def isatty # rubocop:disable Naming/PredicateMethod
    true
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
