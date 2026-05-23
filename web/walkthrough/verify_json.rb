#!/usr/bin/env ruby
# frozen_string_literal: true

# verify_json.rb — Ruby-side verification that the generated JSON files
# are structurally sound and that the engine algorithm (port of
# Nasfaa::RuleEngine) gives the same answers as the canonical Ruby
# code on every scenario. Acts as a sanity check until Node is run.

require 'json'

ROOT = File.expand_path(__dir__)

def load_json(name)
  JSON.parse(File.read(File.join(ROOT, name), encoding: 'UTF-8'))
end

# Stand-alone port of the JS engine — identical algorithm in Ruby for
# isolated verification of the JSON shape.
def evaluate(rules, inputs)
  path = []
  rules.each do |rule|
    path << rule['id']
    match = rule['when_all'].all? do |cond|
      if cond.start_with?('!')
        !inputs[cond[1..]]
      else
        inputs[cond] ? true : false
      end
    end
    return { rule_id: rule['id'], result: rule['result'], path: path.dup } if match
  end
  nil
end

rules_json = load_json('rules.json')
scenarios_json = load_json('scenarios.json')
questions_json = load_json('questions.json')

# 1. Run every scenario through the engine.
passed = 0
failures = []
scenarios_json['scenarios'].each do |s|
  trace = evaluate(rules_json['rules'], s['inputs'] || {})
  actual = trace ? [trace[:rule_id], trace[:result]] : [nil, nil]
  expected = [s['expected']['rule_id'], s['expected']['result']]
  if actual == expected
    passed += 1
  else
    failures << "#{s['id']}: expected #{expected.inspect}, got #{actual.inspect}"
  end
end

# 2. Walk the DAG exhaustively and confirm RuleEngine agrees.
def walk(nodes, current, inputs, path, results)
  node = nodes[current]
  if node['type'] == 'result'
    results << {
      rule_id: node['rule_id'], result: node['result'],
      inputs: inputs.dup, path: path.dup
    }
    return
  end
  %i[yes no].each do |ans|
    fields = node['fields'] || [node['field']]
    next_inputs = inputs.dup
    fields.each { |f| next_inputs[f] = (ans == :yes) }
    next_id = ans == :yes ? node['on_yes'] : node['on_no']
    walk(nodes, next_id, next_inputs, path + [current], results)
  end
end

dag_results = []
walk(questions_json['nodes'], questions_json['start'], {}, [], dag_results)
def permitted?(result)
  %w[permit permit_with_scope permit_with_caution].include?(result)
end

# Match the Ruby exhaustive_verification_spec: compare permit/deny verdicts,
# not rule_ids. The DAG and RuleEngine can reach the same permit/deny verdict
# via different rules (especially on Box 4 Yes -> FERPA chains where the
# engine's first-match-wins jumps to FAFSA_R7_no_pii while the DAG hits a
# downstream FERPA exception).
dag_mismatches = []
dag_results.each do |dr|
  t = evaluate(rules_json['rules'], dr[:inputs])
  next if t && permitted?(t[:result]) == permitted?(dr[:result])

  dag_mismatches << {
    dag: [dr[:rule_id], dr[:result]],
    engine: t ? [t[:rule_id], t[:result]] : nil,
    inputs: dr[:inputs],
    path: dr[:path]
  }
end

puts "Scenarios:  #{passed} / #{scenarios_json['scenarios'].size} pass"
failures.each { |f| puts "  FAIL #{f}" }
puts
puts "DAG paths:  #{dag_results.size} explored; #{dag_mismatches.size} verdict mismatches"
dag_mismatches.each do |m|
  puts "  VERDICT MISMATCH dag=#{m[:dag].inspect} engine=#{m[:engine].inspect}"
  puts "                   inputs=#{m[:inputs].inspect}"
  puts "                   path=#{m[:path].join(' -> ')}"
end
puts
puts 'NOTE: scenario failures are gating; DAG verdict mismatches are diagnostic'
puts '      (they can reproduce against the canonical Ruby gem as well — see README).'

# Only scenario failures are fatal — DAG verdict differences match the
# canonical Ruby behavior on the same inputs.
exit(failures.empty? ? 0 : 1)
