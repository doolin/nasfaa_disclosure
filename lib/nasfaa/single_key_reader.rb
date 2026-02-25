# frozen_string_literal: true

module Nasfaa
  # Mixin providing single-keystroke getch-based input for interactive CLI modes.
  #
  # Including classes must set:
  #   @input                  — the input stream (responds to getch for single-key mode)
  #   @output                 — the output stream
  #   @single_key_valid_chars — Array of valid single chars (e.g., %w[y n q])
  #
  # In single-key mode (when @input is a real TTY that responds to :getch),
  # read_char returns one character at a time. Valid characters are echoed with
  # a newline; unrecognized characters (including ^M and other control chars)
  # are consumed silently. Ctrl-C (\x03) and Ctrl-\ (\x1c) are mapped to 'q'.
  #
  # When @input responds to :getch but is NOT a TTY (piped stdin, non-interactive
  # subprocess), single_key? returns false and the caller falls back to line-based
  # gets input. This prevents Errno::ENOTTY from io/console patching all IO objects.
  module SingleKeyReader
    def single_key?
      return false unless @input.respond_to?(:getch)

      # Test doubles (SingleKeyInput) don't have isatty — treat them as TTYs.
      # Real IO objects have isatty; check it to avoid ENOTTY on piped stdin.
      @input.respond_to?(:isatty) ? @input.isatty : true
    end

    def read_char
      raw = @input.getch
      raise 'Unexpected end of input' if raw.nil?

      if ["\x03", "\x1c"].include?(raw)
        @output.puts
        return 'q'
      end

      char = raw.downcase
      if @single_key_valid_chars.include?(char)
        @output.print char
        @output.puts
      end
      char
    end
  end
end
