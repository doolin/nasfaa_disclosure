# frozen_string_literal: true

require_relative 'lib/nasfaa/version'

Gem::Specification.new do |spec|
  spec.name          = 'nasfaa'
  spec.version       = Nasfaa::VERSION
  spec.authors       = ['David Doolin']
  spec.summary       = 'NASFAA FERPA/HEA/FTI data sharing decision tree'
  spec.description = 'Ruby implementation of the NASFAA Data Sharing Decision Tree for determining ' \
                     'whether student financial aid data disclosure is permitted under FERPA, HEA, ' \
                     'and FTI regulations.'
  spec.homepage      = 'https://github.com/daviddoolin/nasfaa'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['lib/**/*.rb', 'nasfaa_rules.yml', 'LICENSE', 'README.md']
  spec.bindir        = 'bin'
  spec.executables   = ['nasfaa']
  spec.require_paths = ['lib']
end
