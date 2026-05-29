# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe Nasfaa do
  describe 'VERSION' do
    # version.rb loads before SimpleCov's tracking activates (via lib/nasfaa.rb
    # which spec_helper requires).  A bare reference to the constant won't
    # re-execute the file's top-level code, so we `load` it explicitly to give
    # SimpleCov a hit count on the module body.
    it 'is a semver string' do
      load File.expand_path('../lib/nasfaa/version.rb', __dir__)
      expect(Nasfaa::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
