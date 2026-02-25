# frozen_string_literal: true

require 'rspec'
require_relative 'spec_helper'

RSpec.describe Nasfaa::Colorizer do
  # ------------------------------------------------------------------
  # :none mode (default) — pass-through, no ANSI codes
  # ------------------------------------------------------------------
  describe 'mode :none (default)' do
    let(:colorizer) { described_class.new }

    it 'has mode :none by default' do
      expect(colorizer.mode).to eq(:none)
    end

    it 'returns permit text unchanged' do
      expect(colorizer.permit('PERMITTED')).to eq('PERMITTED')
    end

    it 'returns deny text unchanged' do
      expect(colorizer.deny('DENIED')).to eq('DENIED')
    end

    it 'returns correct text unchanged' do
      expect(colorizer.correct('CORRECT!')).to eq('CORRECT!')
    end

    it 'returns incorrect text unchanged' do
      expect(colorizer.incorrect('INCORRECT.')).to eq('INCORRECT.')
    end

    it 'returns bold text unchanged' do
      expect(colorizer.bold('--- Box 1 ---')).to eq('--- Box 1 ---')
    end

    it 'returns dim text unchanged' do
      expect(colorizer.dim('IRC §6103(l)(13)')).to eq('IRC §6103(l)(13)')
    end

    it 'returns yellow text unchanged' do
      expect(colorizer.yellow('PDF: some text')).to eq('PDF: some text')
    end
  end

  # ------------------------------------------------------------------
  # :dark mode — bold cyan for permit/correct, bold yellow for deny/incorrect
  # ------------------------------------------------------------------
  describe 'mode :dark' do
    let(:colorizer) { described_class.new(mode: :dark) }

    it 'has mode :dark' do
      expect(colorizer.mode).to eq(:dark)
    end

    it 'wraps permit text with ANSI codes and preserves the text' do
      result = colorizer.permit('PERMITTED')
      expect(result).to include('PERMITTED')
      expect(result).to start_with("\e[")
      expect(result).to end_with("\e[0m")
    end

    it 'wraps deny text with ANSI codes and preserves the text' do
      result = colorizer.deny('DENIED')
      expect(result).to include('DENIED')
      expect(result).to start_with("\e[")
      expect(result).to end_with("\e[0m")
    end

    it 'uses different codes for permit and deny (blue vs yellow family)' do
      expect(colorizer.permit('x')).not_to eq(colorizer.deny('x'))
    end

    it 'wraps correct text with ANSI codes' do
      result = colorizer.correct('CORRECT!')
      expect(result).to include('CORRECT!')
      expect(result).to start_with("\e[")
    end

    it 'wraps incorrect text with ANSI codes' do
      result = colorizer.incorrect('INCORRECT.')
      expect(result).to include('INCORRECT.')
      expect(result).to start_with("\e[")
    end

    it 'wraps bold text with ANSI codes' do
      result = colorizer.bold('Header')
      expect(result).to include('Header')
      expect(result).to start_with("\e[")
    end

    it 'wraps dim text with ANSI codes' do
      result = colorizer.dim('Citation')
      expect(result).to include('Citation')
      expect(result).to start_with("\e[")
    end

    it 'wraps yellow text with ANSI codes' do
      result = colorizer.yellow('PDF: some text')
      expect(result).to include('PDF: some text')
      expect(result).to start_with("\e[33m")
      expect(result).to end_with("\e[0m")
    end

    it 'uses the same code for correct and permit' do
      expect(colorizer.correct('x')).to eq(colorizer.permit('x'))
    end

    it 'uses the same code for incorrect and deny' do
      expect(colorizer.incorrect('x')).to eq(colorizer.deny('x'))
    end
  end

  # ------------------------------------------------------------------
  # :light mode — bold blue for permit/correct, yellow for deny/incorrect
  # ------------------------------------------------------------------
  describe 'mode :light' do
    let(:colorizer) { described_class.new(mode: :light) }

    it 'wraps permit text with ANSI codes' do
      result = colorizer.permit('PERMITTED')
      expect(result).to include('PERMITTED')
      expect(result).to start_with("\e[")
      expect(result).to end_with("\e[0m")
    end

    it 'uses different codes from :dark mode for permit' do
      dark  = described_class.new(mode: :dark)
      light = described_class.new(mode: :light)
      expect(dark.permit('x')).not_to eq(light.permit('x'))
    end

    it 'uses different codes for permit and deny' do
      expect(colorizer.permit('x')).not_to eq(colorizer.deny('x'))
    end

    it 'wraps yellow text with ANSI codes' do
      result = colorizer.yellow('PDF: some text')
      expect(result).to include('PDF: some text')
      expect(result).to start_with("\e[33m")
      expect(result).to end_with("\e[0m")
    end
  end

  # ------------------------------------------------------------------
  # :rainbow mode — vivid full-spectrum palette
  # ------------------------------------------------------------------
  describe 'mode :rainbow' do
    let(:colorizer) { described_class.new(mode: :rainbow) }

    it 'wraps permit text with ANSI codes' do
      result = colorizer.permit('PERMITTED')
      expect(result).to include('PERMITTED')
      expect(result).to start_with("\e[")
      expect(result).to end_with("\e[0m")
    end

    it 'wraps deny text with ANSI codes' do
      result = colorizer.deny('DENIED')
      expect(result).to include('DENIED')
      expect(result).to start_with("\e[")
      expect(result).to end_with("\e[0m")
    end

    it 'uses different codes for permit and deny (green vs red)' do
      expect(colorizer.permit('x')).not_to eq(colorizer.deny('x'))
    end

    it 'uses the same code for correct and permit' do
      expect(colorizer.correct('x')).to eq(colorizer.permit('x'))
    end

    it 'uses the same code for incorrect and deny' do
      expect(colorizer.incorrect('x')).to eq(colorizer.deny('x'))
    end

    it 'wraps bold text with ANSI codes' do
      result = colorizer.bold('Header')
      expect(result).to include('Header')
      expect(result).to start_with("\e[")
    end

    it 'wraps dim text with ANSI codes' do
      result = colorizer.dim('Citation')
      expect(result).to include('Citation')
      expect(result).to start_with("\e[")
    end

    it 'wraps yellow text with ANSI codes' do
      result = colorizer.yellow('PDF: some text')
      expect(result).to include('PDF: some text')
      expect(result).to start_with("\e[33m")
      expect(result).to end_with("\e[0m")
    end

    it 'uses different codes from :dark mode for permit' do
      dark = described_class.new(mode: :dark)
      expect(colorizer.permit('x')).not_to eq(dark.permit('x'))
    end
  end

  # ------------------------------------------------------------------
  # Invalid mode
  # ------------------------------------------------------------------
  describe 'invalid mode' do
    it 'raises ArgumentError for an unknown mode' do
      expect { described_class.new(mode: :neon) }.to raise_error(ArgumentError, /Invalid color mode/)
    end
  end
end
