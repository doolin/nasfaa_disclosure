require 'rspec'
require_relative '../lib/disclosure_data'

RSpec.describe DisclosureData do
  let(:data) { DisclosureData.new(includes_fti: true, recipient_type: :student) }

  describe 'bracket notation' do
    it 'allows access via bracket notation like a hash' do
      expect(data[:includes_fti]).to be true
      expect(data[:recipient_type]).to eq(:student)
    end

    it 'returns false for missing keys' do
      expect(data[:missing_key]).to be false
    end
  end

  describe 'dot notation' do
    it 'allows access via dot notation like instance variables' do
      expect(data.includes_fti).to be true
      expect(data.recipient_type).to eq(:student)
    end
  end

  describe 'nested data' do
    let(:data_with_consent) { DisclosureData.new(consent: { hea: true, ferpa: false }) }

    it 'handles nested data as hashes' do
      expect(data_with_consent[:consent]).to eq({ hea: true, ferpa: false })
      expect(data_with_consent.consent).to eq({ hea: true, ferpa: false })
    end
  end

  describe 'default values' do
    let(:empty_data) { DisclosureData.new }

    it 'provides sensible defaults' do
      expect(empty_data[:includes_fti]).to be false
      expect(empty_data[:contains_pii]).to be false
      expect(empty_data[:has_educational_interest]).to be false
      expect(empty_data[:other_99_31_exception]).to be false
      expect(empty_data[:consent]).to eq({})
    end
  end
end
