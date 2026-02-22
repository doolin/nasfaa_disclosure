# frozen_string_literal: true

require 'yaml'

module Nasfaa
  class RuleEngine
    attr_reader :rules

    RULES_PATH = File.expand_path('../../nasfaa_rules.yml', __dir__)

    def initialize(rules_path = RULES_PATH)
      data = YAML.safe_load_file(rules_path)
      @rules = data.fetch('rules')
    end

    def evaluate(disclosure_data)
      @rules.each do |rule|
        next unless matches?(rule, disclosure_data)

        return {
          rule_id: rule['id'],
          result: rule['result'].to_sym,
          scope_note: rule['scope_note'],
          caution_note: rule['caution_note']
        }
      end
      nil
    end

    private

    def matches?(rule, disclosure_data)
      rule['when_all'].all? do |condition|
        if condition.start_with?('!')
          !disclosure_data[condition[1..].to_sym]
        else
          disclosure_data[condition.to_sym]
        end
      end
    end
  end
end
