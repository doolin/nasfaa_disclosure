# frozen_string_literal: true

module Nasfaa
  # Wraps strings with ANSI escape codes for colorized CLI output.
  #
  # Designed for colorblind safety (deuteranopia/protanopia): uses blue and
  # yellow as the primary semantic contrast pair rather than red/green.
  #
  # Modes:
  #   :none  — no ANSI codes (default; safe for tests and piped output)
  #   :dark  — palette tuned for dark terminals (bold cyan / bold yellow)
  #   :light — palette tuned for light terminals (bold blue / yellow)
  #
  # Usage:
  #   c = Nasfaa::Colorizer.new(mode: :dark)
  #   puts c.permit("PERMITTED")   # bold cyan
  #   puts c.deny("DENIED")        # bold yellow
  #   puts c.bold("Box 1")
  #   puts c.dim("IRC §6103")
  class Colorizer
    MODES = %i[none light dark].freeze

    RESET = "\e[0m"

    # Colorblind-safe palette: blue family for permit/correct,
    # yellow family for deny/incorrect.
    ANSI = {
      dark: {
        permit: "\e[1;36m", # bold cyan
        deny: "\e[1;33m", # bold yellow
        correct: "\e[1;36m", # bold cyan
        incorrect: "\e[1;33m", # bold yellow
        bold: "\e[1m",
        dim: "\e[2m"
      },
      light: {
        permit: "\e[1;34m", # bold blue
        deny: "\e[33m", # yellow
        correct: "\e[1;34m", # bold blue
        incorrect: "\e[33m", # yellow
        bold: "\e[1m",
        dim: "\e[2m"
      }
    }.freeze

    attr_reader :mode

    def initialize(mode: :none)
      raise ArgumentError, "Invalid color mode: #{mode}. Use #{MODES.join(', ')}" unless MODES.include?(mode)

      @mode = mode
    end

    def permit(text)    = colorize(text, :permit)
    def deny(text)      = colorize(text, :deny)
    def correct(text)   = colorize(text, :correct)
    def incorrect(text) = colorize(text, :incorrect)
    def bold(text)      = colorize(text, :bold)
    def dim(text)       = colorize(text, :dim)

    private

    def colorize(text, role)
      return text if @mode == :none

      code = ANSI[@mode][role]
      "#{code}#{text}#{RESET}"
    end
  end
end
