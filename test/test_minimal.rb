# frozen_string_literal: true

require_relative "base"

class TestMinimal < TestBase
  @rails_options = "--minimal"
  @generate_options = ""

  def test_minimal
    check_dockerfile
    check_dockerignore
  end
end
