# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

# Core fields that interact with branching logic (12 fields, 2^12 = 4096 combos).
# to_school_official_legitimate_interest is core because it appears in both
# FTI Box 4 and FERPA Box 12 (99.31 exception).
CORE_FIELDS = %i[
  includes_fti disclosure_to_student is_fafsa_data
  disclosure_to_contributor_parent_or_spouse used_for_aid_admin
  disclosure_to_scholarship_org explicit_written_consent
  research_promote_attendance hea_written_consent
  contains_pii ferpa_written_consent to_school_official_legitimate_interest
].freeze

# Independent FERPA 99.31 exception fields (Boxes 11-19 minus Box 12).
# Each is a simple yes -> permit exit with no further branching.
INDEPENDENT_FIELDS = %i[
  directory_info_and_not_opted_out
  due_to_judicial_order_or_subpoena_or_financial_aid
  to_other_school_enrollment_transfer
  to_authorized_representatives
  to_research_org_ferpa
  to_accrediting_agency
  parent_of_dependent_student
  otherwise_permitted_under_99_31
].freeze

# 9 configurations: all-false base case + each independent field individually true.
# Multiple-true combos are redundant because first-match-wins means only
# the first true exception fires, and the result is always permit.
INDEPENDENT_CONFIGS = [
  {},
  *INDEPENDENT_FIELDS.map { |f| { f => true } }
].freeze

EXPECTED_COUNT = (1 << CORE_FIELDS.length) * INDEPENDENT_CONFIGS.length # 4096 * 9 = 36,864

RSpec.describe 'Exhaustive verification: DecisionTree vs RuleEngine' do
  let(:engine) { Nasfaa::RuleEngine.new }

  it "agrees on all #{EXPECTED_COUNT} combinations (2^12 core x #{INDEPENDENT_CONFIGS.length} independent)" do
    disagreements = []
    count = 0

    (0...(1 << CORE_FIELDS.length)).each do |bits|
      core = CORE_FIELDS.each_with_index.with_object({}) do |(field, i), hash|
        hash[field] = (bits >> i) & 1 == 1
      end

      INDEPENDENT_CONFIGS.each do |indep|
        inputs = core.merge(indep)
        data = Nasfaa::DisclosureData.new(inputs)

        tree_result = Nasfaa::DecisionTree.new(data).disclose?
        trace = engine.evaluate(data)
        engine_permitted = trace.permitted?

        if tree_result != engine_permitted
          disagreements << {
            true_inputs: inputs.select { |_, v| v }.keys,
            tree: tree_result ? :permit : :deny,
            engine_rule: trace.rule_id,
            engine_result: trace.result
          }
        end
        count += 1
      end
    end

    expect(count).to eq(EXPECTED_COUNT)

    next unless disagreements.any?

    summary = disagreements.first(20).map do |d|
      "  True inputs: #{d[:true_inputs].join(', ')}\n  DecisionTree: #{d[:tree]}, RuleEngine: #{d[:engine_result]} (#{d[:engine_rule]})"
    end.join("\n\n")

    raise "#{disagreements.length} disagreements out of #{count} combinations.\n" \
          "First #{[20, disagreements.length].min}:\n\n#{summary}"
  end
end
