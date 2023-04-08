# frozen_string_literal: true

require_relative "base"

class TestWindows < TestBase
  @rails_options = "--minimal"
  @generate_options = "--windows"

  def test_bin_cd
    check_dockerfile
  end
end
