# frozen_string_literal: true

Context =
  Struct.new(
    :ignore_on_missing,
    :packages,
    :known_hashes,
    keyword_init: true
  ) do
    def ignore_on_missing?
      ignore_on_missing
    end
  end
