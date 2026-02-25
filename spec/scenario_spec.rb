# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe 'Scenario Library' do
  let(:engine) { Nasfaa::RuleEngine.new }

  describe 'scenario verification' do
    Nasfaa::Scenarios.all.each do |scenario|
      describe scenario.name do
        let(:data) { Nasfaa::DisclosureData.new(scenario.inputs) }

        it "RuleEngine fires #{scenario.expected_rule_id} with result #{scenario.expected_result}" do
          trace = engine.evaluate(data)
          expect(trace.rule_id).to eq(scenario.expected_rule_id)
          expect(trace.result).to eq(scenario.expected_result)
        end

        it 'DecisionTree agrees on permit/deny' do
          tree = Nasfaa::DecisionTree.new(data)
          expected_permitted = %i[permit permit_with_scope permit_with_caution].include?(scenario.expected_result)
          expect(tree.disclose?).to eq(expected_permitted)
        end
      end
    end
  end

  describe 'rule coverage' do
    it 'has at least one scenario for every rule in the YAML' do
      rule_ids = engine.rules.map { |r| r['id'] }
      scenario_rule_ids = Nasfaa::Scenarios.all.map(&:expected_rule_id).uniq
      uncovered = rule_ids - scenario_rule_ids
      expect(uncovered).to be_empty,
                           "Rules without scenarios: #{uncovered.join(', ')}"
    end
  end

  describe 'scenario metadata' do
    it 'every scenario has a unique id' do
      ids = Nasfaa::Scenarios.all.map(&:id)
      expect(ids).to eq(ids.uniq)
    end

    it 'every scenario has a non-empty description' do
      Nasfaa::Scenarios.all.each do |s|
        expect(s.description).not_to be_empty, "#{s.id} has empty description"
      end
    end

    it 'every scenario has a citation' do
      Nasfaa::Scenarios.all.each do |s|
        expect(s.citation).not_to be_empty, "#{s.id} has empty citation"
      end
    end

    it 'every scenario has at least one tag' do
      Nasfaa::Scenarios.all.each do |s|
        expect(s.tags).not_to be_empty, "#{s.id} has no tags"
      end
    end
  end

  describe 'query methods' do
    it '.find returns a single scenario by id' do
      scenario = Nasfaa::Scenarios.find('student_views_own_fti')
      expect(scenario).not_to be_nil
      expect(scenario.name).to eq('Student Views Own Tax Return Information')
    end

    it '.find_by_rule_id returns the scenario that maps to a given rule' do
      scenario = Nasfaa::Scenarios.find_by_rule_id('FTI_R1_student')
      expect(scenario).not_to be_nil
      expect(scenario.id).to eq('student_views_own_fti')
    end

    it '.find_by_rule_id returns nil when no scenario covers the rule' do
      expect(Nasfaa::Scenarios.find_by_rule_id('NONEXISTENT_RULE')).to be_nil
    end

    it '.by_tag filters scenarios' do
      fti_scenarios = Nasfaa::Scenarios.by_tag('fti')
      expect(fti_scenarios.length).to eq(5)
      expect(fti_scenarios.map(&:id)).to all(match(/fti|tribal|contractor|external_auditor/))
    end

    it '.permits returns only permit variants' do
      Nasfaa::Scenarios.permits.each do |s|
        expect(%i[permit permit_with_scope permit_with_caution]).to include(s.expected_result)
      end
    end

    it '.denials returns only deny scenarios' do
      Nasfaa::Scenarios.denials.each do |s|
        expect(s.expected_result).to eq(:deny)
      end
    end
  end

  describe 'result type coverage' do
    it 'includes at least one permit scenario' do
      expect(Nasfaa::Scenarios.all.any? { |s| s.expected_result == :permit }).to be true
    end

    it 'includes at least one deny scenario' do
      expect(Nasfaa::Scenarios.all.any? { |s| s.expected_result == :deny }).to be true
    end

    it 'includes at least one permit_with_caution scenario' do
      expect(Nasfaa::Scenarios.all.any? { |s| s.expected_result == :permit_with_caution }).to be true
    end
  end
end
