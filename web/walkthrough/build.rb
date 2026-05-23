#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the JSON copies of the canonical YAML data files into
# web/walkthrough/ so the browser walkthrough and Lambda handler can load
# them without a YAML parser.
#
# The YAML files in the repo root remain the canonical source of truth.
# This script is the one-way build step. Re-run after editing YAML:
#
#   ruby web/walkthrough/build.rb
#
# Output (UTF-8, LF line endings, no BOM):
#   web/walkthrough/rules.json
#   web/walkthrough/questions.json
#   web/walkthrough/scenarios.json

require 'yaml'
require 'json'

ROOT = File.expand_path('../..', __dir__)
OUT  = File.expand_path(__dir__)

SOURCES = {
  'rules.json'     => 'nasfaa_rules.yml',
  'questions.json' => 'nasfaa_questions.yml',
  'scenarios.json' => 'nasfaa_scenarios.yml'
}.freeze

def write_json(out_name, src_name)
  src_path = File.join(ROOT, src_name)
  out_path = File.join(OUT, out_name)
  data = YAML.safe_load_file(src_path)
  json = JSON.pretty_generate(data)
  # Force LF endings, no trailing BOM. File#write with mode 'w' on Unix is LF.
  File.open(out_path, 'w:UTF-8') do |f|
    f.write(json)
    f.write("\n")
  end
  puts "wrote #{out_name} (#{File.size(out_path)} bytes)"
end

SOURCES.each { |out, src| write_json(out, src) }
puts 'done.'
