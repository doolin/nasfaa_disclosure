# frozen_string_literal: true

require 'yaml'

module Nasfaa
  # Immutable value object representing a single real-world disclosure scenario.
  # Each scenario maps to exactly one rule in nasfaa_rules.yml and carries
  # enough context for regression testing, documentation, and quiz generation.
  Scenario = Struct.new(
    :id,              # Machine-readable identifier (e.g., "student_views_own_fti")
    :name,            # Human-readable title (e.g., "Student Views Own Tax Return Information")
    :description,     # Narrative description of the real-world situation
    :inputs,          # Hash of boolean DisclosureData fields (Symbol keys)
    :expected_result, # Expected outcome (:permit, :deny, :permit_with_scope, :permit_with_caution)
    :expected_rule_id, # ID of the YAML rule that should fire
    :citation,        # Governing statute or regulation
    :tags,            # Array of category strings for filtering
    keyword_init: true
  )

  # Loads and queries the scenario library from nasfaa_scenarios.yml.
  #
  # The scenario library serves triple duty:
  #   1. Regression tests — each scenario is verified against both engines
  #   2. Documentation  — rich descriptions explain why each rule applies
  #   3. Quiz seed data — descriptions can be presented as training questions
  #
  # Usage:
  #   Nasfaa::Scenarios.all                    # => Array of Scenario structs
  #   Nasfaa::Scenarios.find("student_views_own_fti")  # => single Scenario
  #   Nasfaa::Scenarios.by_tag("fti")          # => Array of FTI-related scenarios
  #   Nasfaa::Scenarios.permits                # => Array of permit scenarios
  #   Nasfaa::Scenarios.denials                # => Array of deny scenarios
  class Scenarios
    SCENARIOS_PATH = File.expand_path('../../nasfaa_scenarios.yml', __dir__)

    # Returns all scenarios from the YAML file (cached after first load).
    def self.all
      @all ||= load_scenarios
    end

    # Find a single scenario by its string ID.
    def self.find(id)
      all.find { |s| s.id == id.to_s }
    end

    # Find a scenario by the rule ID it maps to (expected_rule_id field).
    # Returns nil when no named scenario covers the given rule.
    def self.find_by_rule_id(rule_id)
      all.find { |s| s.expected_rule_id == rule_id.to_s }
    end

    # Filter scenarios by tag (e.g., "fti", "ferpa", "deny").
    def self.by_tag(tag)
      all.select { |s| s.tags.include?(tag.to_s) }
    end

    # All scenarios where the expected result is some form of permit.
    def self.permits
      all.select { |s| %i[permit permit_with_scope permit_with_caution].include?(s.expected_result) }
    end

    # All scenarios where the expected result is deny.
    def self.denials
      all.select { |s| s.expected_result == :deny }
    end

    # Reset the cached scenarios (useful in tests if YAML changes).
    def self.reset!
      @all = nil
    end

    def self.load_scenarios
      data = YAML.safe_load_file(SCENARIOS_PATH)
      data['scenarios'].map { |s| build_scenario(s) }
    end
    private_class_method :load_scenarios

    def self.build_scenario(raw)
      Scenario.new(
        id: raw['id'],
        name: raw['name'],
        description: raw['description']&.strip,
        inputs: (raw['inputs'] || {}).transform_keys(&:to_sym),
        expected_result: raw['expected']['result'].to_sym,
        expected_rule_id: raw['expected']['rule_id'],
        citation: raw['citation'],
        tags: raw['tags'] || []
      )
    end
    private_class_method :build_scenario
  end
end
