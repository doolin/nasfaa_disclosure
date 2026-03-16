# frozen_string_literal: true

module Nasfaa
  # Provides Unicode box-drawing helpers for CLI output.
  #
  # Two visual styles:
  #   Thin  (┌─┐ / └─┘) — question panels, quiz cards
  #   Heavy (╔═╗ / ╚═╝) — result cards, final scores
  #
  # Box width is 60 horizontal chars (total line = 62 with corners).
  # Plain text longer than the inner width is word-wrapped across
  # multiple box lines.  ANSI-colored strings are padded by visual
  # length (escape codes stripped before measuring) and are not
  # word-wrapped to avoid splitting escape sequences.
  #
  # box_line and box_heavy_line may return multi-line strings when text
  # wraps; Ruby's puts handles embedded newlines correctly.
  module BoxDraw
    BOX_WIDTH = 60      # ─/═ count between corners
    INNER_WIDTH = 58    # BOX_WIDTH - 2 (one space of padding each side)
    TOTAL_WIDTH = 62    # BOX_WIDTH + 2 (corners)

    # ── Thin style ─────────────────────────────────────────────────

    def box_top(title = nil)
      m = box_margin
      if title
        label = "─ #{title} "
        fill = '─' * [BOX_WIDTH - label.length, 0].max
        "#{m}┌#{label}#{fill}┐"
      else
        "#{m}┌#{'─' * BOX_WIDTH}┐"
      end
    end

    def box_divider
      "#{box_margin}├#{'─' * BOX_WIDTH}┤"
    end

    def box_bottom
      "#{box_margin}└#{'─' * BOX_WIDTH}┘"
    end

    # Returns one or more box lines.  Pre-colorized text (containing ANSI codes)
    # is padded by visual length without wrapping — use this for short labels.
    # Plain text is word-wrapped; pass colorize: proc to colorize after wrapping.
    def box_line(text = '', colorize: nil)
      m = box_margin
      text_str = text.to_s
      if text_str.include?("\e[")
        vlen = visual_length(text_str)
        "#{m}│ #{text_str}#{' ' * [INNER_WIDTH - vlen, 0].max} │"
      else
        lines = wrap_text(text_str, INNER_WIDTH)
        lines.map do |line|
          display = colorize ? colorize.call(line) : line
          "#{m}│ #{display}#{' ' * [INNER_WIDTH - visual_length(display), 0].max} │"
        end.join("\n")
      end
    end

    # ── Heavy style ────────────────────────────────────────────────

    def box_heavy_top
      "#{box_margin}╔#{'═' * BOX_WIDTH}╗"
    end

    def box_heavy_divider
      "#{box_margin}╠#{'═' * BOX_WIDTH}╣"
    end

    def box_heavy_bottom
      "#{box_margin}╚#{'═' * BOX_WIDTH}╝"
    end

    # Returns one or more heavy box lines.  Pre-colorized text (containing ANSI
    # codes) is padded by visual length without wrapping — use this for short
    # labels. Plain text is word-wrapped; pass colorize: proc to colorize after
    # wrapping.
    def box_heavy_line(text = '', colorize: nil)
      m = box_margin
      text_str = text.to_s
      if text_str.include?("\e[")
        vlen = visual_length(text_str)
        "#{m}║ #{text_str}#{' ' * [INNER_WIDTH - vlen, 0].max} ║"
      else
        lines = wrap_text(text_str, INNER_WIDTH)
        lines.map do |line|
          display = colorize ? colorize.call(line) : line
          "#{m}║ #{display}#{' ' * [INNER_WIDTH - visual_length(display), 0].max} ║"
        end.join("\n")
      end
    end

    private

    # Returns whitespace to center the box in the terminal.
    # Falls back to no margin if terminal width is unavailable or too narrow.
    def box_margin
      cols = terminal_columns
      padding = (cols - TOTAL_WIDTH) / 2
      padding > 0 ? ' ' * padding : ''
    end

    # Detect terminal width. Returns 0 if not a TTY or unavailable.
    def terminal_columns
      return 0 unless $stdout.respond_to?(:winsize)

      $stdout.winsize[1]
    rescue Errno::ENOTTY, Errno::ENODEV
      0
    end

    # Strip ANSI escape sequences before measuring, so colorized text
    # is padded to the correct visual width.
    def visual_length(text)
      text.to_s.gsub(/\e\[[0-9;]*m/, '').length
    end

    # Word-wrap plain text to fit within +width+ characters.
    # Returns an array of strings, each no longer than +width+ chars.
    # Single words longer than +width+ appear on their own line and
    # overflow the right border (no truncation).
    def wrap_text(text, width)
      return [''] if text.empty?

      lines = []
      current = ''

      text.split.each do |word|
        if current.empty?
          current = word
        elsif current.length + 1 + word.length <= width
          current = "#{current} #{word}"
        else
          lines << current
          current = word
        end
      end
      lines << current
      lines
    end
  end
end
