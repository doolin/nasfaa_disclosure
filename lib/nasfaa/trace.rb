# frozen_string_literal: true

module Nasfaa
  Trace = Struct.new(:rule_id, :result, :path, :scope_note, :caution_note, keyword_init: true) do
    def permitted?
      %i[permit permit_with_scope permit_with_caution].include?(result)
    end

    def denied?
      result == :deny
    end
  end
end
