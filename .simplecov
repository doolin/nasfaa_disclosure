# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch

  add_filter '/spec/'
  add_filter '/.ruby-lsp/'
  add_filter '/.git/'

  add_group 'Core Logic', 'lib/'

  track_files 'lib/**/*.rb'

  minimum_coverage 95
  minimum_coverage_by_file 90

  refuse_coverage_drop
end
