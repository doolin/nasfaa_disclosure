# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Nasfaa::BoxDraw do
  # Create a minimal object that includes the module so we can call the
  # public helpers directly without going through Walkthrough or Quiz.
  subject(:drawer) do
    obj = Object.new
    obj.extend(described_module)
    obj
  end

  let(:described_module) { described_class }

  # Verify the module constant values that all helper methods depend on.
  describe 'constants' do
    it 'BOX_WIDTH is 60' do
      expect(described_class::BOX_WIDTH).to eq(60)
    end

    it 'INNER_WIDTH is BOX_WIDTH - 2' do
      expect(described_class::INNER_WIDTH).to eq(described_class::BOX_WIDTH - 2)
    end
  end

  # ── Structural methods ───────────────────────────────────────────

  describe '#box_top' do
    it 'returns a 62-char line without a title' do
      expect(drawer.box_top.length).to eq(62)
      expect(drawer.box_top).to start_with('┌').and(end_with('┐'))
    end

    it 'embeds the title in the top border' do
      line = drawer.box_top('Section')
      expect(line).to include('Section')
      expect(line).to start_with('┌').and(end_with('┐'))
    end

    it 'does not go negative when title is at the width limit' do
      long_title = 'x' * described_class::BOX_WIDTH
      expect { drawer.box_top(long_title) }.not_to raise_error
    end
  end

  describe '#box_divider' do
    it 'returns a full-width thin divider' do
      expect(drawer.box_divider).to eq("├#{'─' * described_class::BOX_WIDTH}┤")
    end
  end

  describe '#box_bottom' do
    it 'returns a full-width thin bottom border' do
      expect(drawer.box_bottom).to eq("└#{'─' * described_class::BOX_WIDTH}┘")
    end
  end

  describe '#box_heavy_top' do
    it 'returns a full-width heavy top border' do
      expect(drawer.box_heavy_top).to eq("╔#{'═' * described_class::BOX_WIDTH}╗")
    end
  end

  describe '#box_heavy_divider' do
    it 'returns a full-width heavy divider' do
      expect(drawer.box_heavy_divider).to eq("╠#{'═' * described_class::BOX_WIDTH}╣")
    end
  end

  describe '#box_heavy_bottom' do
    it 'returns a full-width heavy bottom border' do
      expect(drawer.box_heavy_bottom).to eq("╚#{'═' * described_class::BOX_WIDTH}╝")
    end
  end

  # ── box_line ─────────────────────────────────────────────────────

  describe '#box_line' do
    it 'returns an empty box line when called with no argument' do
      line = drawer.box_line
      expect(line).to start_with('│ ').and(end_with(' │'))
      expect(line.length).to eq(62)
    end

    it 'returns a padded line when plain text fits INNER_WIDTH' do
      line = drawer.box_line('hello')
      expect(line).to start_with('│ hello').and(end_with(' │'))
      expect(line.length).to eq(62)
    end

    it 'word-wraps plain text that exceeds INNER_WIDTH' do
      # Build a sentence longer than 58 chars so at least one wrap occurs
      long_text = ('word ' * 14).strip # 69 chars
      result = drawer.box_line(long_text)
      lines = result.split("\n")
      expect(lines.length).to be > 1
      lines.each do |l|
        expect(l).to start_with('│ ').and(end_with(' │'))
      end
    end

    it 'pads ANSI-colored text by visual length (short — fits)' do
      ansi_text = "\e[1;36mPERMIT\e[0m" # 6 visual chars
      line = drawer.box_line(ansi_text)
      expect(line).to start_with("│ #{ansi_text}")
      expect(line).to end_with(' │')
    end

    it 'does not add trailing padding when ANSI text exceeds INNER_WIDTH' do
      long_ansi = "\e[1;36m#{'x' * 60}\e[0m" # 60 visual chars > 58
      line = drawer.box_line(long_ansi)
      expect(line).to start_with("│ #{long_ansi}")
      expect(line).to end_with(' │') # max(negative, 0) => 0 spaces padding
    end
  end

  # ── box_heavy_line ───────────────────────────────────────────────

  describe '#box_heavy_line' do
    it 'returns an empty heavy line when called with no argument' do
      line = drawer.box_heavy_line
      expect(line).to start_with('║ ').and(end_with(' ║'))
      expect(line.length).to eq(62)
    end

    it 'returns a padded heavy line when plain text fits INNER_WIDTH' do
      line = drawer.box_heavy_line('hello')
      expect(line).to start_with('║ hello').and(end_with(' ║'))
      expect(line.length).to eq(62)
    end

    it 'word-wraps plain text that exceeds INNER_WIDTH' do
      long_text = ('word ' * 14).strip
      result = drawer.box_heavy_line(long_text)
      lines = result.split("\n")
      expect(lines.length).to be > 1
      lines.each do |l|
        expect(l).to start_with('║ ').and(end_with(' ║'))
      end
    end

    it 'pads ANSI-colored text by visual length (short — fits)' do
      ansi_text = "\e[1;36mDENY\e[0m" # 4 visual chars
      line = drawer.box_heavy_line(ansi_text)
      expect(line).to start_with("║ #{ansi_text}")
      expect(line).to end_with(' ║')
    end

    it 'does not add trailing padding when ANSI text exceeds INNER_WIDTH' do
      long_ansi = "\e[1;36m#{'x' * 60}\e[0m" # 60 visual chars > 58
      line = drawer.box_heavy_line(long_ansi)
      expect(line).to start_with("║ #{long_ansi}")
      expect(line).to end_with(' ║')
    end
  end
end
