# frozen_string_literal: true

require_relative "base"

class TestLabel < TestBase
  @rails_options = "--minimal"
  @generate_options = "--label=runtime:rails"

  def test_label
    check_dockerfile
  end
end
