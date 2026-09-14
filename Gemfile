# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rubocop', '~> 1.0', require: false
gem 'simplecov', '~> 0.22', require: false

# Audits the locked gems against the Ruby Advisory Database:
#   bundle exec bundle-audit check --update
gem 'bundler-audit', require: false, groups: %i[development test]
