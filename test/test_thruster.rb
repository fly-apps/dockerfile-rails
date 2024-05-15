# frozen_string_literal: true

require_relative "base"

class TestThruster < TestBase
  @generate_options = "--thruster"

  def test_thruster
    check_dockerfile
  end
end
