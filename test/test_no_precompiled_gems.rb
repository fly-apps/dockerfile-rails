# frozen_string_literal: true

require_relative "base"

class TestNoPrecompiledGems < TestBase
  @rails_options = "--minimal"
  @generate_options = "--no-precompiled-gems"

  def test_ci
    check_dockerfile
  end
end
