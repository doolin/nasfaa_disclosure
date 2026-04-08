# frozen_string_literal: true

module Nasfaa
  # Uniform question interface for the Quiz engine.
  #
  # Decouples the quiz loop from any specific domain model (Scenario,
  # RuleEngine, etc.) so the engine can accept questions from any source
  # — a YAML file, a database, or hand-built structs.
  #
  # Fields:
  #   description     — optional narrative (shown when present)
  #   inputs          — Hash of field => value displayed to the user
  #   expected_result — the correct answer as a Symbol
  #                     (:permit, :deny, :permit_with_scope, :permit_with_caution, etc.)
  #   rule_id         — identifier for the rule that produced the answer
  #   citation        — optional regulatory or source citation
  QuizQuestion = Struct.new(
    :description,
    :inputs,
    :expected_result,
    :rule_id,
    :citation,
    keyword_init: true
  ) do
    # Build a QuizQuestion from a Scenario (or any duck-typed object
    # responding to #description, #inputs, #expected_result,
    # #expected_rule_id, and #citation).
    def self.from_scenario(scenario)
      new(
        description: scenario.description,
        inputs: scenario.inputs,
        expected_result: scenario.expected_result,
        rule_id: scenario.expected_rule_id,
        citation: scenario.citation
      )
    end
  end
end
