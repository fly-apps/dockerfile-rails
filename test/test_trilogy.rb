# frozen_string_literal: true

require_relative "base"

class TestTrilogy < TestBase
  @generate_options = "--compose"

  def app_setup
    system "bundle add trilogy"
  end

  def test_trilogy
    check_dockerfile
    check_compose
  end
end
